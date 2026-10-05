import assert from 'node:assert/strict'
import { createHash, createHmac } from 'node:crypto'
import { describe, it } from 'node:test'
import { R2, sigv4Signature } from './r2.ts'

/**
 * La signature S3, vérifiée contre les vecteurs publiés par AWS.
 *
 * --- Pourquoi ce test est construit comme ça ------------------------------
 *
 * Une routine de signature ne se vérifie pas en la comparant à une seconde
 * version écrite par la même personne : les deux porteraient la même
 * incompréhension et s'accorderaient à tort. Il faut un point d'appui extérieur.
 *
 * Il y en a deux ici, et ce sont des constantes publiées :
 *
 *   * la **clé dérivée** pour `20150830/us-east-1/iam` — l'exemple « how to
 *     derive a signing key » ;
 *   * l'**empreinte de la requête canonique** de l'exemple « GET Object »,
 *     `3bfa2928…`. Une empreinte SHA-256 ne se rencontre pas par hasard : si
 *     elle correspond, le texte canonique est au caractère près celui d'AWS.
 *
 * La réimplémentation en `node:crypto` ci-dessous sert de référence **parce
 * qu'elle est elle-même validée par le premier vecteur**, et elle emprunte un
 * tout autre chemin que `s3.ts`, qui passe par WebCrypto.
 */

/** La chaîne de dérivation, écrite ici avec node:crypto. */
function cleDeSignature(secret: string, portee: string): Buffer {
  let cle = Buffer.from(`AWS4${secret}`, 'utf8')
  for (const element of portee.split('/')) {
    cle = createHmac('sha256', cle).update(element, 'utf8').digest()
  }
  return cle
}

function signatureDeReference(input: {
  canonicalRequest: string
  timestamp: string
  scope: string
  secret: string
}): string {
  const aSigner = [
    'AWS4-HMAC-SHA256',
    input.timestamp,
    input.scope,
    createHash('sha256').update(input.canonicalRequest, 'utf8').digest('hex'),
  ].join('\n')
  return createHmac('sha256', cleDeSignature(input.secret, input.scope))
    .update(aSigner, 'utf8')
    .digest('hex')
}

// Les clés de démonstration d'AWS, publiées dans la documentation. Elles
// n'ouvrent aucun compte.
const SECRET = 'wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY'

describe('la signature AWS version 4', () => {
  it('dérive la clé publiée par la documentation', () => {
    // Ce vecteur valide l'implémentation de référence de ce fichier. Sans lui,
    // tout le reste ne serait que deux erreurs d'accord.
    assert.equal(
      cleDeSignature(SECRET, '20150830/us-east-1/iam/aws4_request').toString(
        'hex',
      ),
      'c4afb1cc5771d871763a393e44b703571b55cc28424d1a5e86da6ed3c154a4b9',
    )
  })

  // La requête canonique de l'exemple « GET Object », en style sous-domaine —
  // celui de l'exemple, pas le nôtre. C'est volontaire : ce qui est vérifié ici
  // est la dérivation et la chaîne à signer, qui ne dépendent pas du style.
  const canonique = [
    'GET',
    '/test.txt',
    'X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAIOSFODNN7EXAMPLE%2F20130524%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20130524T000000Z&X-Amz-Expires=86400&X-Amz-SignedHeaders=host',
    'host:examplebucket.s3.amazonaws.com',
    '',
    'host',
    'UNSIGNED-PAYLOAD',
  ].join('\n')

  it('part de la requête canonique documentée', () => {
    assert.equal(
      createHash('sha256').update(canonique, 'utf8').digest('hex'),
      '3bfa292879f6447bbcda7001decf97f4a54dc650c8942174ae0a9121cf58ad04',
    )
  })

  it('signe comme l’implémentation de référence', async () => {
    const parametres = {
      canonicalRequest: canonique,
      timestamp: '20130524T000000Z',
      scope: '20130524/us-east-1/s3/aws4_request',
      secret: SECRET,
    }
    assert.equal(
      await sigv4Signature(parametres),
      signatureDeReference(parametres),
    )
  })
})

describe('l’URL pré-signée d’un enregistrement', () => {
  const depot = new R2({
    endpoint: 'https://compte.r2.cloudflarestorage.com',
    bucket: 'eduquali-enregistrements',
    accessKey: 'CLE',
    secret: 'SECRET',
    region: 'auto',
  })

  // Horloge figée : une signature dépend de la minute, donc un test sans horloge
  // injectée ne vérifierait que lui-même.
  const le2octobre = new Date('2026-10-02T08:30:00.000Z')

  const url = () =>
    depot.presign({
      method: 'GET',
      key: 'seances/abc-123.mp4',
      expiresInSeconds: 7200,
      now: le2octobre,
    })

  it('adresse l’objet en style chemin', async () => {
    // L'egress LiveKit écrit en `force_path_style`. Signer dans un style et lire
    // dans l'autre donne `SignatureDoesNotMatch`, un message qui ne dit jamais
    // lequel des deux est en cause.
    const adresse = new URL(await url())
    assert.equal(adresse.host, 'compte.r2.cloudflarestorage.com')
    assert.equal(
      adresse.pathname,
      '/eduquali-enregistrements/seances/abc-123.mp4',
    )
  })

  it('porte les paramètres attendus, triés', async () => {
    const adresse = new URL(await url())
    assert.deepEqual([...adresse.searchParams.keys()], [
      'X-Amz-Algorithm',
      'X-Amz-Credential',
      'X-Amz-Date',
      'X-Amz-Expires',
      'X-Amz-SignedHeaders',
      'X-Amz-Signature',
    ])
    assert.equal(adresse.searchParams.get('X-Amz-Date'), '20261002T083000Z')
    assert.equal(adresse.searchParams.get('X-Amz-Expires'), '7200')
    assert.equal(
      adresse.searchParams.get('X-Amz-Credential'),
      'CLE/20261002/auto/s3/aws4_request',
    )
  })

  it('signe comme l’implémentation de référence, chemin compris', async () => {
    // Le contrôle qui porte sur *notre* requête canonique, celle en style
    // chemin : elle n'a pas de vecteur publié, donc elle est comparée à la
    // référence validée plus haut.
    const signature = new URL(await url()).searchParams.get('X-Amz-Signature')
    const attendue = signatureDeReference({
      canonicalRequest: [
        'GET',
        '/eduquali-enregistrements/seances/abc-123.mp4',
        'X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=CLE%2F20261002%2Fauto%2Fs3%2Faws4_request&X-Amz-Date=20261002T083000Z&X-Amz-Expires=7200&X-Amz-SignedHeaders=host',
        'host:compte.r2.cloudflarestorage.com',
        '',
        'host',
        'UNSIGNED-PAYLOAD',
      ].join('\n'),
      timestamp: '20261002T083000Z',
      scope: '20261002/auto/s3/aws4_request',
      secret: 'SECRET',
    })
    assert.equal(signature, attendue)
  })

  it('est stable à horloge figée et change avec l’objet', async () => {
    assert.equal(await url(), await url())

    const autre = await depot.presign({
      method: 'GET',
      key: 'seances/abc-124.mp4',
      expiresInSeconds: 7200,
      now: le2octobre,
    })
    assert.notEqual(
      new URL(await url()).searchParams.get('X-Amz-Signature'),
      new URL(autre).searchParams.get('X-Amz-Signature'),
    )
  })

  it('distingue GET de DELETE', async () => {
    // La méthode entre dans la requête canonique : une URL signée pour lire ne
    // doit pas permettre de supprimer.
    const suppression = await depot.presign({
      method: 'DELETE',
      key: 'seances/abc-123.mp4',
      expiresInSeconds: 60,
      now: le2octobre,
    })
    assert.notEqual(
      new URL(await url()).searchParams.get('X-Amz-Signature'),
      new URL(suppression).searchParams.get('X-Amz-Signature'),
    )
  })

  it('encode une clé à caractères spéciaux sans toucher aux séparateurs', async () => {
    const brute = await depot.presign({
      method: 'GET',
      key: "seances/rattrapage (2)/cours d'ete.mp4",
      expiresInSeconds: 60,
      now: le2octobre,
    })
    // Les `/` restent des `/` — sinon l'objet n'est pas celui qu'on croit — et
    // les parenthèses comme l'apostrophe sont encodées : `encodeURIComponent`
    // les laisse passer, S3 les exige, et la signature est calculée sur la forme
    // encodée.
    assert.ok(brute.includes('/seances/rattrapage%20%282%29/'))
    assert.ok(brute.includes("cours%20d%27ete.mp4"))
  })

  it('refuse de se croire configuré à moitié', () => {
    // Un déploiement avec un dépôt nommé mais sans clé ne doit pas démarrer
    // d'enregistrement : il échouerait à la fin de la séance, quand il est trop
    // tard pour refaire le cours.
    assert.equal(
      R2.isConfigured({ endpoint: 'https://x', bucket: 'b', accessKey: 'k' }),
      false,
    )
    assert.equal(
      R2.isConfigured({
        endpoint: 'https://x',
        bucket: 'b',
        accessKey: 'k',
        secret: 's',
        region: 'auto',
      }),
      true,
    )
  })
})
