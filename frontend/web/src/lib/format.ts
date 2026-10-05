/** Formatage partage — memes conventions que l'application mobile. */

const CURRENCY = 'GNF'

const number = new Intl.NumberFormat('fr-FR')
const longDate = new Intl.DateTimeFormat('fr-FR', {
  day: 'numeric',
  month: 'long',
  year: 'numeric',
})

export const money = (value: number): string =>
  `${number.format(value)} ${CURRENCY}`

/** Fourchette de rémunération, ou `null` si l'offre ne la publié pas. */
export function salaryRange(
  min: number | undefined,
  max: number | undefined,
  published: boolean,
): string | null {
  if (!published || (min == null && max == null)) return null
  if (min != null && max != null && min !== max) {
    return `${number.format(min)} – ${money(max)}`
  }
  return money((min ?? max)!)
}

export const formatDate = (iso: string): string => longDate.format(new Date(iso))

export const publishedOn = (iso: string): string =>
  `Publiée le ${formatDate(iso)}`

/** Durée relative compacte. */
export function relative(iso: string): string {
  const diff = Date.now() - Date.parse(iso)
  const minutes = Math.floor(diff / 60_000)
  if (minutes < 1) return 'à l’instant'
  if (minutes < 60) return `il y a ${minutes} min`
  const hours = Math.floor(minutes / 60)
  if (hours < 24) return `il y a ${hours} h`
  const days = Math.floor(hours / 24)
  if (days === 1) return 'hier'
  if (days < 30) return `il y a ${days} j`
  const months = Math.floor(days / 30)
  if (months < 12) return `il y a ${months} mois`
  return `il y a ${Math.floor(days / 365)} an(s)`
}

/** Chronomètre du test : « 14:05 ». */
export function clock(totalSeconds: number): string {
  const s = Math.max(0, totalSeconds)
  const m = Math.floor(s / 60)
  const sec = s % 60
  return `${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}`
}

export const initials = (first: string, last: string): string =>
  `${first.charAt(0)}${last.charAt(0)}`.toUpperCase() || '?'

export const experienceLabel = (years: number): string =>
  years <= 0
    ? 'Débutant'
    : years === 1
      ? '1 an d’expérience'
      : `${years} ans d’expérience`

export const contractLabel = (code: string): string =>
  ({
    PERMANENT: 'CDI',
    FIXED_TERM: 'CDD',
    HOURLY: 'Vacation',
    INTERNSHIP: 'Stage',
  })[code] ?? code

export const availabilityLabel = (code: string): string =>
  ({
    AVAILABLE: 'Disponible',
    AVAILABLE_SOON: 'Bientôt disponible',
    UNAVAILABLE: 'Indisponible',
  })[code] ?? code

export const applicationStatusLabel = (code: string): string =>
  ({
    SENT: 'Candidature envoyée',
    VIEWED: 'Vue',
    SHORTLISTED: 'Présélectionné',
    INTERVIEW: 'Entretien',
    OFFER_RECEIVED: 'Offre reçue',
    ACCEPTED: 'Acceptée',
    REJECTED: 'Refusée',
    HIRED: 'Recruté',
  })[code] ?? code

export const institutionTypeLabel = (code: string): string =>
  ({
    SCHOOL: 'École',
    HIGH_SCHOOL: 'Lycée',
    UNIVERSITY: 'Université',
    INSTITUTE: 'Institut',
    TRAINING_CENTER: 'Centre de formation',
    OTHER: 'Établissement',
  })[code] ?? code
