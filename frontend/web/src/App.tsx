import { Suspense, lazy } from 'react'
import {
  Link,
  NavLink,
  Navigate,
  Route,
  Routes,
  useLocation,
  useNavigate,
} from 'react-router-dom'
import { isMockBackend } from './api'
import { useSession } from './app/session'
import { ErrorBoundary } from './components/ErrorBoundary'
import { PresenceBanner } from './components/PresenceBanner'
import { Icon, Skeleton } from './components/ui'
import { Landing, Login } from './screens/Auth'
import type { Role } from './onboarding/spec'

/*
 * Decoupage du bundle (§5 du code_skill) : seul l'accueil est charge
 * d'emblee. Les autres ecrans arrivent a la demande — sur un reseau 3G, ce
 * que l'on ne telecharge pas est la seule optimisation qui compte vraiment.
 */
const Discover = lazy(() =>
  import('./screens/Discover').then((m) => ({ default: m.Discover })),
)
const Signup = lazy(() =>
  import('./onboarding/Signup').then((m) => ({ default: m.Signup })),
)
const Offers = lazy(() =>
  import('./screens/Offers').then((m) => ({ default: m.Offers })),
)
const OfferDetail = lazy(() =>
  import('./screens/Offers').then((m) => ({ default: m.OfferDetail })),
)
const Profile = lazy(() =>
  import('./screens/Profile').then((m) => ({ default: m.Profile })),
)
const Applications = lazy(() =>
  import('./screens/Profile').then((m) => ({ default: m.Applications })),
)
const Tests = lazy(() =>
  import('./screens/Tests').then((m) => ({ default: m.Tests })),
)
const Schools = lazy(() =>
  import('./screens/Schools').then((m) => ({ default: m.Schools })),
)
const Teachers = lazy(() =>
  import('./screens/Teachers').then((m) => ({ default: m.Teachers })),
)
const LiveGrid = lazy(() =>
  import('./screens/Live').then((m) => ({ default: m.LiveGrid })),
)
const LiveRoom = lazy(() =>
  import('./screens/Room').then((m) => ({ default: m.LiveRoom })),
)
/*
 * La rediffusion est chargée à part, comme la salle : elle n'a besoin d'aucune
 * bibliothèque (le lecteur vient de Cloudflare Stream dans un `iframe`), mais un visiteur
 * qui parcourt le catalogue n'a aucune raison d'en télécharger le code.
 */
const Replay = lazy(() =>
  import('./screens/Replay').then((m) => ({ default: m.Replay })),
)
const LiveCourseForm = lazy(() =>
  import('./screens/Live').then((m) => ({ default: m.LiveCourseForm })),
)
const Courses = lazy(() =>
  import('./screens/Courses').then((m) => ({ default: m.Courses })),
)
const CourseDetail = lazy(() =>
  import('./screens/Courses').then((m) => ({ default: m.CourseDetail })),
)
const TeacherDetail = lazy(() =>
  import('./screens/Teachers').then((m) => ({ default: m.TeacherDetail })),
)
const SchoolDetail = lazy(() =>
  import('./screens/Schools').then((m) => ({ default: m.SchoolDetail })),
)
const TestRunner = lazy(() =>
  import('./screens/Tests').then((m) => ({ default: m.TestRunner })),
)

/** Ossature de l'application et routage. */
export default function App() {
  const { session, ready } = useSession()
  const location = useLocation()

  if (!ready) return <div className="screen" />

  // Le parcours d'inscription occupe l'ecran entier : ni barre d'onglets ni
  // en-tete ne doivent distraire de la question posee.
  const isFlow = location.pathname.startsWith('/inscription')

  return (
    <div className="shell">
      <a className="skip-link" href="#contenu">
        Aller au contenu
      </a>

      {/*
        La mise en garde vit dans l'ossature, et non sur l'accueil seul.
        Depuis le 02/10, les listes sont publiques : on arrive directement sur
        `/etablissements` par un lien, et on y lisait des annonces d'ecoles
        reelles — avec des offres inventees — sans qu'un mot dise que ce sont
        des donnees de demonstration.
      */}
      {isMockBackend ? (
        <p className="demo-note" role="status">
          Données de démonstration : aucun serveur n’est connecté. Les
          professeurs, écoles et annonces affichés sont fictifs.
        </p>
      ) : null}

      {/*
        « Fatoumata suit Mathématiques — en direct depuis 23 min ».

        Dans l'ossature et non sur une page : un parent qui veut savoir si son
        enfant est en cours ne va pas chercher un écran, il regarde là où il est
        déjà. Le composant ne rend rien quand personne ne suit de cours, donc il
        ne coûte rien aux autres comptes.
      */}
      <PresenceBanner />

      <main id="contenu">
        <ErrorBoundary>
          <Suspense fallback={<ScreenFallback />}>
            <Routes>
              <Route
                path="/"
                element={session ? <Navigate to="/offres" replace /> : <Landing />}
              />
              {/* Publique : on regarde avant d'ouvrir un compte. Une
                  session ouverte peut la parcourir aussi — elle a les
                  memes raisons de chercher. */}
              <Route path="/recherche" element={<Discover />} />
              <Route path="/connexion" element={<Login />} />
              <Route path="/inscription" element={<SignupRoute />} />
              {/* Entrees directes : le lien « Publier une offre » saute la
                  decouverte et le choix du profil. */}
              <Route
                path="/inscription/etablissement"
                element={<SignupRoute presetRole="INSTITUTION" />}
              />
              <Route
                path="/inscription/enseignant"
                element={<SignupRoute presetRole="TEACHER" />}
              />
              <Route
                path="/inscription/parent"
                element={<SignupRoute presetRole="PARENT" />}
              />

              {/*
                Publiques. L'accueil promet deja que « le compte n'est
                reclame qu'au moment de contacter quelqu'un » : derriere une
                authentification, ces listes demandaient de s'inscrire pour
                savoir s'il y avait une raison de s'inscrire. C'est ce que
                fait le telephone depuis le debut (`publicPaths`), et RLS
                l'autorise cote serveur depuis la migration 0009.

                Ce qu'elles ne montrent pas, et ne doivent jamais montrer :
                le telephone, le courriel et les documents. Ils ne circulent
                qu'apres mise en relation (§30), et c'est RLS qui le tient.
              */}
              <Route path="/offres" element={<Offers />} />
              <Route path="/offres/:id" element={<OfferDetail />} />
              <Route path="/etablissements" element={<Schools />} />
              <Route path="/etablissements/:id" element={<SchoolDetail />} />
              <Route path="/professeurs" element={<Teachers />} />
              <Route path="/professeurs/:id" element={<TeacherDetail />} />
              {/* Le programme d'un cours est public : on doit savoir ce qu'on
                  achete. La lecture, elle, vit dans l'application. */}
              {/* La grille des cours en direct est publique : on consulte
                  un emploi du temps avant d'ouvrir un compte. Ouvrir un cours,
                  en revanche, demande une fiche enseignant — l'ecran le dit. */}
              <Route path="/direct" element={<LiveGrid />} />
              <Route
                path="/direct/nouveau"
                element={<Guard><LiveCourseForm /></Guard>}
              />
              {/* La salle est gardee : le serveur refusera de toute facon un
                  jeton a qui n'est pas inscrit, mais envoyer un visiteur sur un
                  ecran qui echoue vaut moins que l'envoyer se connecter. */}
              <Route
                path="/direct/:id/salle"
                element={<Guard><LiveRoom /></Guard>}
              />
              {/* Gardée pour la même raison : le serveur ne signera pas
                  l'adresse du lecteur à qui n'a pas payé la séance, et envoyer
                  un visiteur sur un écran qui échoue vaut moins que l'envoyer se
                  connecter. */}
              <Route
                path="/direct/:id/rediffusion"
                element={<Guard><Replay /></Guard>}
              />

              <Route path="/cours" element={<Courses />} />
              <Route path="/cours/:id" element={<CourseDetail />} />

              {/* Ce qui appartient a un compte le reste : candidatures,
                  tests notes, profil. */}
              {/* Le catalogue des tests est public ; le passage reste garde,
                  et l'ecran lui-meme refuse de commencer quand le backend ne
                  sait pas corriger. */}
              <Route path="/tests" element={<Tests />} />

              <Route path="/candidatures" element={<Guard><Applications /></Guard>} />
              <Route path="/tests/:id" element={<Guard><TestRunner /></Guard>} />
              <Route path="/profil" element={<Guard><Profile /></Guard>} />

              <Route path="*" element={<NotFound />} />
            </Routes>
          </Suspense>
        </ErrorBoundary>
      </main>

      {/* Un visiteur a maintenant des pages a parcourir : sans barre, il
          atterrit sur une liste et n'a aucun moyen d'aller voir l'autre. */}
      {isFlow ? null : <TabBar />}
    </div>
  )
}

/** Squelette plutot que roue : l'attente garde la forme de la page. */
function ScreenFallback() {
  return (
    <div className="screen">
      <span className="sr-only" role="status">
        Chargement en cours
      </span>
      <Skeleton height={72} count={4} />
    </div>
  )
}

function NotFound() {
  return (
    <div className="screen stack stack--loose">
      <h1 className="page-title">Cette page n’existe pas</h1>
      <p className="page-lede">
        Le lien est peut-être ancien. Les offres en cours sont toujours
        accessibles depuis l’accueil.
      </p>
      <a className="btn btn--primary btn--block" href="/">
        Revenir à l’accueil
      </a>
    </div>
  )
}

function Guard({ children }: { children: React.ReactNode }) {
  const { session } = useSession()
  const location = useLocation()
  if (!session) {
    // On garde la destination : après connexion, l'utilisateur revient là
    // où il voulait aller, et non sur une liste générique.
    return <Navigate to="/connexion" replace state={{ from: location }} />
  }
  return <>{children}</>
}

/**
 * Inscription.
 *
 * Le parcours choisit lui-meme son profil (decouverte -> `role_select`) ;
 * cette route ne fait que traduire les reponses en creation de compte.
 */
function SignupRoute({ presetRole }: { presetRole?: Role }) {
  const { register } = useSession()
  const navigate = useNavigate()

  return (
    <Signup
      presetRole={presetRole}
      onDone={async (role, answers) => {
        const text = (key: string) => {
          const value = answers[key]
          return value == null ? '' : String(value)
        }

        const liste = (key: string): string[] => {
          const value = answers[key]
          return Array.isArray(value)
            ? value.map(String).filter((v) => v.trim() !== '')
            : []
        }

        /*
         * Les reponses du parcours, enregistrees.
         *
         * Cet appel ne transmettait que le nom, le numero, le mot de passe et
         * la ville — « les reponses alimenteront le profil des que l'API
         * existera ». L'audit du 04/10 a releve ce que cela coutait :
         *
         *   - la region et le quartier etaient perdus, alors que l'etape qui
         *     les recueille annonce « Le quartier decide des professeurs qui
         *     peuvent venir » ;
         *   - **aucun enfant n'etait cree** pour un compte parent, la ou le
         *     mobile en cree un : meme questionnaire, deux resultats selon la
         *     porte d'entree, et une famille inscrite ici arrivait sur un
         *     espace vide ;
         *   - un etablissement etait nomme d'apres son directeur, parce que
         *     `manager_name` partait en `firstName` et que `institutions.name`
         *     prenait cette valeur.
         *
         * Un universitaire decrit la personne qu'il est lui-meme, un parent
         * decrit un tiers prefixe `child_` : c'est la meme regle que
         * `SignupCompletion.attachLearner` cote mobile.
         */
        const prefixe = role === 'PARENT' ? 'child_' : ''
        const apprenant = text(`${prefixe}first_name`)

        await register({
          firstName:
            role === 'INSTITUTION'
              ? text('manager_name') || 'Direction'
              : text('first_name'),
          lastName: role === 'INSTITUTION' ? '' : text('last_name'),
          phone: text('phone'),
          // L'etape `credentials` du parcours, juste apres le numero. Sans
          // elle, le compte s'ouvrait avec un secret partage ecrit dans le
          // bundle et n'appartenait a personne.
          password: text('password'),
          city: text('city') || undefined,
          region: text('region') || undefined,
          district: text('district') || undefined,
          institutionName: text('institution_name') || undefined,
          institutionType: text('institution_type') || undefined,
          pendingPlan: text('subscription') || undefined,
          learner:
            (role === 'PARENT' || role === 'STUDENT') && apprenant !== ''
              ? {
                  firstName: apprenant,
                  // Aucune etape ne demande le nom de l'enfant : il porte en
                  // general celui du compte.
                  lastName: text('last_name') || undefined,
                  levelId: text(`${prefixe}level_id`) || undefined,
                  filiereId: text(`${prefixe}filiere_id`) || undefined,
                  schoolName: text(`${prefixe}institution`) || undefined,
                  subjectIds: liste(`${prefixe}subject_ids`),
                }
              : undefined,
          role,
        })

        // Chaque profil arrive sur ce qui lui sert : un enseignant sur les
        // offres, une famille sur les etablissements et les repetiteurs. Un
        // etudiant majeur cherche la meme chose qu'une famille.
        navigate(
          role === 'PARENT' || role === 'STUDENT'
            ? '/etablissements'
            : '/offres',
          { replace: true },
        )
      }}
    />
  )
}


const TABS_BY_ROLE = {
  TEACHER: [
    { to: '/direct', label: 'Direct', icon: 'clock' as const },
    { to: '/offres', label: 'Offres', icon: 'briefcase' as const },
    { to: '/candidatures', label: 'Candidatures', icon: 'clipboard' as const },
    { to: '/tests', label: 'Tests', icon: 'check' as const },
    { to: '/profil', label: 'Profil', icon: 'user' as const },
  ],
  INSTITUTION: [
    { to: '/offres', label: 'Offres', icon: 'briefcase' as const },
    { to: '/candidatures', label: 'Candidatures', icon: 'clipboard' as const },
    { to: '/profil', label: 'Profil', icon: 'user' as const },
  ],
  PARENT: [
    { to: '/etablissements', label: 'Écoles', icon: 'home' as const },
    { to: '/professeurs', label: 'Professeurs', icon: 'user' as const },
    { to: '/cours', label: 'Cours', icon: 'play' as const },
    { to: '/profil', label: 'Profil', icon: 'user' as const },
  ],
  // Un etudiant majeur voit la meme chose qu'une famille : c'est le meme
  // besoin, et c'est deja le choix fait cote mobile. Des onglets a lui
  // couteraient un second jeu d'ecrans a tenir sans rien ajouter.
  STUDENT: [
    { to: '/etablissements', label: 'Écoles', icon: 'home' as const },
    { to: '/professeurs', label: 'Professeurs', icon: 'user' as const },
    { to: '/cours', label: 'Cours', icon: 'play' as const },
    { to: '/profil', label: 'Profil', icon: 'user' as const },
  ],
  ADMIN: [{ to: '/profil', label: 'Profil', icon: 'user' as const }],
}

/**
 * Ce qu'un visiteur peut parcourir.
 *
 * Les trois listes publiques, puis la porte d'entree. « Se connecter » en
 * dernier et non en premier : on regarde d'abord, on ouvre un compte quand on
 * a trouve une raison.
 */
const PUBLIC_TABS = [
  { to: '/direct', label: 'Direct', icon: 'clock' as const },
  { to: '/professeurs', label: 'Professeurs', icon: 'user' as const },
  { to: '/cours', label: 'Cours', icon: 'play' as const },
  { to: '/connexion', label: 'Compte', icon: 'user' as const },
]

function TabBar() {
  const { session } = useSession()
  const tabs = session
    ? (TABS_BY_ROLE[session.role] ?? TABS_BY_ROLE.TEACHER)
    : PUBLIC_TABS

  return (
    <nav className="tabbar" aria-label="Navigation principale">
      {/*
        La marque n'est visible qu'a partir de 600 px, ou la barre devient un
        en-tete : en bas d'un telephone il n'y a pas la place, et un en-tete
        d'ordinateur sans nom de produit se lit comme une page inachevee.
        Masquee en CSS et non retiree du DOM — le lien vers l'accueil reste
        atteignable au clavier et par un lecteur d'ecran.
      */}
      <Link to="/" className="tabbar__brand">
        Eduquali
      </Link>

      {tabs.map((tab) => (
        <NavLink
          key={tab.to}
          to={tab.to}
          className="tabbar__item"
          aria-label={tab.label}
        >
          {({ isActive }) => (
            <>
              {/* L'icone double le libelle : jamais d'information portee par
                  la seule icone ni par la seule couleur (§7). */}
              <Icon name={tab.icon} size={22} />
              <span aria-current={isActive ? 'page' : undefined}>
                {tab.label}
              </span>
            </>
          )}
        </NavLink>
      ))}
    </nav>
  )
}
