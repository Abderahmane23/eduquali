# WhatsApp Cloud API — référence de travail

Base de connaissances destinée à être relue par un LLM avant d'écrire du code
WhatsApp pour le projet **AICHAI** (Aicha + Hermes, Galerie EDF, Conakry).

Vérifié le **9 septembre 2026** sur `developers.facebook.com`.
Les points non confirmés à la source sont marqués **[À VÉRIFIER]**.

---

## 1. Notions de base

| Terme | Sens |
|---|---|
| **WABA** | WhatsApp Business Account, conteneur du numéro et du catalogue |
| **Phone-Number-ID** | Identifiant du numéro professionnel. C'est lui, jamais le numéro, qui va dans les URL |
| **wa_id** | Identifiant WhatsApp du client. **Peut différer du numéro composé** — ne jamais supposer l'égalité |
| **Fenêtre de service** | 24 h après le dernier message du client. Hors fenêtre, seuls les templates approuvés passent |

**Base URL** : `https://graph.facebook.com/{version}` — version courante `v21.0`.
**Auth** : en-tête `Authorization: Bearer <token>` sur tous les appels.

---

## 2. Enregistrement du numéro

Le numéro doit être **vierge** : aucun compte WhatsApp ni WhatsApp Business
actif. Sinon, le supprimer depuis l'application mobile pour le libérer.

L'enregistrement passe **obligatoirement par l'API** — ni WhatsApp Manager ni
le tableau de bord de l'application ne le permettent.

```http
POST /{version}/{Phone-Number-ID}/register
{
  "messaging_product": "whatsapp",
  "pin": "<code à 6 chiffres>"   // PIN de validation en deux étapes, à conserver
}
```

Avant cela : créer une application de type Business, y ajouter le produit
WhatsApp, associer le portefeuille Business, puis valider la propriété du
numéro par code OTP (SMS ou appel vocal).

**Vérification de l'entreprise** (Centre de sécurité du Business Manager) :
2 à 5 jours ouvrés en général, jusqu'à 14. Le nom légal et l'adresse des
documents doivent correspondre **mot pour mot** à la saisie.

---

## 3. Envoyer un message

```http
POST /{version}/{Phone-Number-ID}/messages
```

Enveloppe commune à tous les types :

```json
{
  "messaging_product": "whatsapp",
  "recipient_type": "individual",
  "to": "224620000000",
  "type": "<type>",
  "context": { "message_id": "wamid..." }
}
```

`context` est facultatif et sert à répondre à un message précis.
`recipient_type` accepte aussi `"group"` (messagerie de groupe).

### Types disponibles

**Médias et texte** : `text`, `image`, `audio`, `video`, `document`, `sticker`
**Interactifs** : `button`, `list`, `product`, `product_list`, `catalog_message`, `flow`, `cta_url`, `call_permission_request`
**Autres** : `location`, `contacts`, `template`, `reaction`

### Texte

```json
{ "type": "text", "text": { "preview_url": false, "body": "..." } }
```

### Image par URL ou par identifiant

```json
{ "type": "image", "image": { "link": "https://...", "caption": "..." } }
{ "type": "image", "image": { "id": "<media-id>", "caption": "..." } }
```

### Liste interactive — le format le plus utile à Aicha

Permet de proposer des choix sans coûter un message par option.

```json
{
  "type": "interactive",
  "interactive": {
    "type": "list",
    "header": { "type": "text", "text": "Nos canapés" },
    "body":   { "text": "Voici ce qui correspond à votre recherche." },
    "footer": { "text": "Galerie EDF" },
    "action": {
      "button": "Voir les modèles",
      "sections": [{
        "title": "Salon",
        "rows": [
          { "id": "CAN-001", "title": "Canapé d'angle cuir", "description": "8 500 000 GNF" }
        ]
      }]
    }
  }
}
```

Le choix du client revient en webhook sous `interactive.list_reply` avec l'`id`.

### Réponse

`200` renvoie un `messages[].id` (le `wamid`) et un statut :
`accepted`, `held_for_quality_assessment` ou `paused`.

---

## 4. Accusé de lecture et indicateur de saisie

Un seul appel fait les deux. **Non facturé.**

```json
{
  "messaging_product": "whatsapp",
  "status": "read",
  "message_id": "<wamid du message reçu>",
  "typing_indicator": { "type": "text" }
}
```

L'indicateur dure **25 secondes** ou disparaît dès l'envoi de la réponse.
Ne l'afficher que si une réponse va suivre.
Marquer comme lu reste possible **30 jours** après réception.

> **Pour Aicha** : envoyer ce seul appel dès la réception, avant d'interroger le
> modèle. Le client voit « en train d'écrire » pendant la réflexion, sans que
> cela coûte un message.

---

## 5. Webhook entrant

```
{ object: "whatsapp_business_account",
  entry: [ { id: <WABA-ID>, changes: [ { field, value } ] } ] }
```

`field` vaut `messages`, `group_lifecycle_update`, `group_settings_update`
ou `group_participant_update`.

`value` contient toujours `metadata` (`display_phone_number`, `phone_number_id`)
puis, selon le cas :

| Contenu | Champs |
|---|---|
| Message client | `contacts[]` (`wa_id`, `profile.name`) + `messages[]` |
| Message système | `messages[]` de type `system` |
| Accusé | `statuses[]` |
| Groupe | `groups[]` |

Chaque message porte `from`, `id` (le `wamid`), `timestamp`.

### Types reçus

| Type | Charge utile |
|---|---|
| `text` | `text.body`. Peut porter `context` ou `referral` (publicité Click-to-WhatsApp) |
| `image` `audio` `video` `document` `sticker` | `mime_type`, `sha256`, `id` du média |
| `location` | coordonnées et libellé |
| `contacts` | fiches contact complètes |
| `interactive` | `list_reply` ou `button_reply` → `{id, title}` |
| `reaction` | emoji sur un message |
| `order` | **commande depuis le catalogue** — lignes produits |
| `system` | événements de compte |
| `unsupported` | message non interprétable → répondre poliment |

---

## 6. Accusés de réception et facturation

`statuses[]` : `id`, `status` (`sent`/`delivered`/`read`/`failed`),
`timestamp`, `recipient_id`, `conversation`, `pricing`, `errors[]`.

```json
"pricing": { "billable": true, "pricing_model": "PMP" }
```

> **Point capital pour ce projet.** Meta indique lui-même si un message est
> facturé. Notre estimation locale (quota de 1 000 puis 0,0085 USD) sert à
> *prévoir* ; `pricing.billable` sert à *constater*.
>
> À faire : stocker `pricing.billable` sur `messages` à la réception du statut,
> et faire afficher par Hermes l'écart entre estimation et facturation réelle.
> C'est le seul moyen de détecter une dérive tarifaire sans attendre la facture.

---

## 7. Médias

### Envoyer

```http
POST /{version}/{Phone-Number-ID}/media
multipart/form-data : file=@chemin, type=<mime>, messaging_product=whatsapp
```

| Type | Taille max | Formats |
|---|---|---|
| Image | **5 Mo** | JPEG, PNG (8 bits RGB/RGBA) |
| Audio | 16 Mo | AAC, AMR, MP3, M4A, OGG (OPUS, mono) |
| Vidéo | 16 Mo | MP4, 3GPP — H.264 + AAC, sans B-frames |
| Document | 100 Mo | PDF, Word, Excel, PowerPoint, TXT |
| Sticker | 100 Ko fixe / 500 Ko animé | WebP |

⚠️ Ne pas confondre : **5 Mo** pour une image envoyée en message,
**8 Mo** pour un visuel de catalogue (que Meta va chercher par URL).

### Recevoir

Deux étapes obligatoires :

```http
GET /{version}/{Media-ID}          → { url, mime_type, sha256, file_size }
GET <url>  + Authorization: Bearer  → binaire
```

**L'URL expire au bout de 5 minutes** — la redemander si le traitement traîne.
Ne jamais stocker l'URL, toujours le `Media-ID`.

**Validité des identifiants** : 30 jours pour un média téléversé par l'API,
**7 jours** pour un média reçu par webhook.

`DELETE /{version}/{Media-ID}` supprime un média.

> **Pour Aicha** : les clients envoient des photos de meubles pour demander
> « avez-vous ceci ? ». Télécharger dans les 5 minutes, archiver le binaire,
> et ne jamais dépendre du média chez Meta au-delà de 7 jours.

---

## 8. Codes d'erreur à traiter

| Code | Sens | Conduite à tenir |
|---|---|---|
| `0`, `190`, `200` | Jeton expiré, invalide ou absent | Renouveler le jeton, alerter |
| `3`, `10` | Permission manquante | Vérifier les droits de l'application |
| `4` | Limite d'appels de l'application | Attente exponentielle |
| `80007` | Limite du WABA atteinte | Attente exponentielle |
| `130429` | Débit Cloud API dépassé | Ralentir la file, réessayer |
| **`131047`** | **Plus de 24 h depuis la dernière réponse du client** | Passer par un template approuvé |
| `131049` | Message bloqué pour la santé de l'écosystème | Attendre 24 h |
| `131026` | Destinataire absent de WhatsApp | Marquer et ne pas réessayer |
| `131050` | Client désabonné du marketing | Ne plus le solliciter |
| `131052` / `131053` | Média non téléchargeable / non téléversable | Journaliser, prévenir le client |
| `131048` / `131056` | Signalements de spam / trop de messages au même destinataire | Revoir la cadence |
| `132000`, `132001`, `132007`, `132015`, `132016` | Problèmes de template | Corriger et resoumettre |

`131047` est la plus structurante : elle décide de la frontière entre message
gratuit et template payant.

---

## 9. API annexes

**Bot Details** — `GET /{version}/{WABA-Bot-ID}`
Renvoie `prompts`, `commands`, `enable_welcome_message`. Sert à auditer la
configuration du bot avant déploiement.

**Message History Events** — `GET /{version}/{Message-History-ID}/events`
Historique paginé des transitions de statut d'un message
(`ACCEPTED`, `SENT`, `DELIVERED`, `READ`, `ERROR`), 100 par page au maximum.
Utile pour instruire un litige de livraison.
Ce n'est **pas** l'API de reprise d'historique de la Coexistence.

---

## 10. Catalogue et commerce

**Synchroniser** — `POST /{version}/{Catalog-ID}/items_batch`
`item_type: "PRODUCT_ITEM"`, `allow_upsert: true`, `requests[]` de
`{method: CREATE|UPDATE|DELETE, data: {...}}`. Jusqu'à 5 000 éléments,
3 000 recommandés.

Champs de `data` : `id` (≤ 100 car.), `title` (≤ 100), `description` (≤ 5 000),
`availability` (`in stock`/`out of stock`/`available for order`/`discontinued`),
`condition` (`new`/`refurbished`/`used`), `brand`, `price`, `link`,
`image[{url}]`, plus `color`, `material`, `product_type`.

**Format du prix** : `"montant DEVISE"`, par exemple `"8500000 GNF"`.
Le franc guinéen n'a **pas de sous-unité** : jamais de décimales.
Autres devises sans sous-unité utiles ici : XOF, XAF.

`/{Catalog-ID}/batch` est **déprécié**, ne plus l'utiliser.

**Visuels** : jusqu'à 10 par produit, minimum 500 × 500 px,
1024 × 1024 recommandé, 8 Mo maximum, JPEG ou PNG.

**Commandes** : le client compose son panier puis envoie une commande, reçue en
webhook comme message de type `order`.

---

## 11. Règles retenues pour AICHAI

1. **Le webhook répond 200 avant tout traitement.** Une réponse lente déclenche
   une relance Meta, donc un doublon — et le doublon est facturé.
2. **`wamid` unique en base.** C'est la garantie d'idempotence.
3. **Une réponse = un message.** Chaque message délivré est facturé
   séparément ; trois bulles coûtent trois fois.
4. **`sender.py` est le seul module qui appelle Meta.** Rien n'échappe ainsi au
   comptage ni à la règle du message unique.
5. **Accusé de lecture + saisie dès réception**, avant d'appeler le modèle.
   Gratuit, et le client voit que ça avance.
6. **Aucun envoi hors fenêtre de 24 h.** La commande part par e-mail au
   commercial : aucun template payant n'est nécessaire.
7. **Ne jamais demander le numéro** : il arrive dans le webhook.
8. **PostgreSQL est la source de vérité du catalogue**, Meta n'est qu'un
   affichage.

---

## 12. À vérifier ou à instruire

- **[À VÉRIFIER]** Tarif exact du message de service pour la Guinée (+224) sur
  la grille Meta du 2 septembre 2026. Toute l'estimation de coût en dépend.
- **CONFIRMÉ (client, 09/09/2026)** : les fonctions commerce sont disponibles
  en Guinée. Le message multi-produits natif et le panier sont donc
  utilisables dès que `WA_CATALOG_ID` sera renseigné. La planche d'images
  reste en repli automatique tant que ce n'est pas le cas.
- **[À VÉRIFIER]** Paliers de messages (250 / 1 000 / 10 000 / illimité) et
  débit maximal par seconde — page non accessible lors de cette vérification.
- **À implémenter** : stockage de `pricing.billable` reçu en webhook de statut,
  puis rapprochement estimation / facturation dans le rapport Hermes.
- **À implémenter** : téléchargement des médias entrants dans la fenêtre de
  5 minutes, avec archivage local.
- **À étudier** : messagerie de groupe (`recipient_type: "group"`) — sans usage
  identifié pour Galerie EDF à ce stade.
