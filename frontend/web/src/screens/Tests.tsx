import { useEffect, useMemo, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { api, canGradeTests } from '../api'
import { useSession } from '../app/session'
import { AppGate } from '../components/AppGate'
import {
  AppBar,
  Banner,
  Button,
  Card,
  Chip,
  EmptyState,
  Icon,
  Progress,
  Skeleton,
} from '../components/ui'
import { clock } from '../lib/format'
import { useAsync } from '../lib/useAsync'
import type { TestResult } from '../api/types'

/**
 * Les tests de competence (§10).
 *
 * **Le catalogue est public.** Un professeur qui n'a pas de compte doit pouvoir
 * voir qu'une certification existe dans sa matiere : c'est une des meilleures
 * raisons d'en ouvrir un, et la cacher derriere l'inscription revenait a la
 * garder pour ceux qui etaient deja convaincus.
 *
 * Passer le test, en revanche, se fait dans l'application. En acces direct a
 * Supabase, `submitTest` leve un 501 : corriger dans le navigateur
 * demanderait de lui livrer les bonnes reponses. Sans ce garde-fou, on
 * repondait a vingt questions avant d'apprendre que rien ne serait
 * enregistre.
 */
export function Tests() {
  const { session } = useSession()
  const navigate = useNavigate()
  const state = useAsync(
    () => api.tests(session?.teacherId),
    [session?.teacherId],
  )

  // Le test ne s'ouvre que si le backend sait le corriger *et* si le compte a
  // une fiche enseignant a certifier.
  const passable = canGradeTests && session?.teacherId != null

  return (
    <>
      <AppBar title="Tests de compétence" />
      <div className="screen stack">
        <p className="muted small">
          Une note au-dessus du seuil ajoute un badge « certifié » à votre
          fiche. C’est ce que les établissements regardent en premier.
        </p>

        {!passable ? (
          <AppGate
            action="passer un test"
            because="La correction se fait sur le serveur, depuis l’application : une note qu’on peut calculer soi-même ne certifierait rien."
          />
        ) : null}

        {state.loading ? (
          <Skeleton height={96} />
        ) : (state.data ?? []).length === 0 ? (
          <EmptyState
            title="Aucun test disponible"
            message="Aucune évaluation n’est ouverte pour le moment."
          />
        ) : (
          <div className="stack grid-cards">
            {(state.data ?? []).map((test) => (
            <Card
              key={test.id}
              onClick={
                passable ? () => navigate(`/tests/${test.id}`) : undefined
              }
            >
              <div className="stack stack--tight">
                <div className="row row--between">
                  <strong>{test.title}</strong>
                  {test.certification ? (
                    <Chip tone="success">{test.certification.score} %</Chip>
                  ) : null}
                </div>
                <div className="row muted small" style={{ gap: 'var(--espace-4)' }}>
                  <span className="row" style={{ gap: 'var(--espace-1)' }}>
                    <Icon name="clipboard" size={14} />
                    {test.questionCount} questions
                  </span>
                  <span className="row" style={{ gap: 'var(--espace-1)' }}>
                    <Icon name="clock" size={14} />
                    {test.durationMinutes} min
                  </span>
                </div>
              </div>
            </Card>
            ))}
          </div>
        )}
      </div>
    </>
  )
}

/**
 * Passage du test (§10.3).
 *
 * Le chronomètre part au premier affichage des questions et la réponse n'est
 * plus modifiable une fois la question quittee.
 */
export function TestRunner() {
  const { id = '' } = useParams()
  const { session } = useSession()
  const [started, setStarted] = useState(false)
  const [index, setIndex] = useState(0)
  const [answers, setAnswers] = useState<Record<string, string>>({})
  const [remaining, setRemaining] = useState(0)
  const [result, setResult] = useState<TestResult>()
  const [submitting, setSubmitting] = useState(false)

  const tests = useAsync(
    () => (session?.teacherId ? api.tests(session.teacherId) : Promise.resolve([])),
    [session?.teacherId],
  )
  const questions = useAsync(
    () => (started ? api.testQuestions(id) : Promise.resolve([])),
    [id, started],
  )

  const test = useMemo(
    () => (tests.data ?? []).find((t) => t.id === id),
    [tests.data, id],
  )

  useEffect(() => {
    if (started && test) setRemaining(test.durationMinutes * 60)
  }, [started, test])

  const submit = useMemo(
    () => async () => {
      setSubmitting(true)
      try {
        setResult(await api.submitTest(id, answers))
      } finally {
        setSubmitting(false)
      }
    },
    [id, answers],
  )

  useEffect(() => {
    if (!started || result) return
    if (remaining <= 0) {
      // Temps ecoule : la copie part en l'etat, comme en salle d'examen.
      void submit()
      return
    }
    const timer = setTimeout(() => setRemaining((r) => r - 1), 1000)
    return () => clearTimeout(timer)
  }, [started, remaining, result, submit])

  if (result) return <Result test={test?.title ?? ''} result={result} />

  if (!started) {
    return (
      <>
        <AppBar title="Test" onBack />
        <div className="screen stack stack--loose">
          <h1 className="page-title">{test?.title ?? 'Test'}</h1>
          <div className="stack stack--tight">
            <Row icon="clipboard" label={`${test?.questionCount ?? 0} questions`} />
            <Row icon="clock" label={`${test?.durationMinutes ?? 0} minutes`} />
            <Row icon="check" label={`${test?.passingScore ?? 70} % pour valider`} />
          </div>
          {test?.rules ? <p className="muted small">{test.rules}</p> : null}
          <Button block onClick={() => setStarted(true)}>
            Commencer le test
          </Button>
        </div>
      </>
    )
  }

  if (questions.loading) {
    return (
      <div className="screen">
        <Skeleton height={48} count={5} />
      </div>
    )
  }

  const list = questions.data ?? []
  const question = list[index]
  if (!question) return <EmptyState title="Question indisponible" />

  const selected = answers[question.id]
  const isLast = index === list.length - 1

  return (
    <>
      <div className="appbar">
        <span className="appbar__title">
          Question {index + 1} / {list.length}
        </span>
        <div className="spacer" />
        <span className={remaining < 60 ? 'strong' : 'muted'}>
          {clock(remaining)}
        </span>
      </div>

      <div className="screen stack stack--loose">
        <Progress value={(index + 1) / list.length} />
        <h2>{question.statement}</h2>

        <div className="stack stack--tight">
          {question.options.map((option) => (
            <button
              key={option.key}
              className="choice"
              aria-pressed={selected === option.key}
              onClick={() =>
                setAnswers((prev) => ({ ...prev, [question.id]: option.key }))
              }
            >
              <span className="chip">{option.key}</span>
              {option.text}
            </button>
          ))}
        </div>

        <Button
          block
          disabled={!selected || submitting}
          onClick={() => (isLast ? void submit() : setIndex((i) => i + 1))}
        >
          {isLast ? (submitting ? 'Correction…' : 'Terminer') : 'Question suivante'}
        </Button>
      </div>
    </>
  )
}

/** Résultat detaille par domaine (§12). */
function Result({ test, result }: { test: string; result: TestResult }) {
  const navigate = useNavigate()

  return (
    <>
      <AppBar title="Résultat" />
      <div className="screen stack stack--loose">
        <div style={{ textAlign: 'center' }}>
          <div
            style={{
              fontSize: '3.5rem',
              fontWeight: 700,
              letterSpacing: '-0.03em',
              color: result.passed ? 'var(--vert-fonce)' : 'var(--bon-point-fonce)',
            }}
          >
            {result.score} %
          </div>
          <p className="muted" style={{ margin: '0 auto' }}>
            {result.correctCount} / {result.totalQuestions} bonnes réponses
          </p>
        </div>

        <Banner tone={result.passed ? 'accent' : 'warning'}>
          {result.passed
            ? `${test} — compétence vérifiée.`
            : `Il faut ${result.passingScore} % pour valider. Vous pourrez repasser ce test.`}
        </Banner>

        <section className="stack stack--tight">
          <h3 className="section-title">Par domaine</h3>
          {result.domainScores.map((domain) => (
            <div key={domain.domain} className="stack stack--tight">
              <div className="row row--between small">
                <span>{domain.domain}</span>
                <span className="strong">{domain.percentage} %</span>
              </div>
              <Progress value={domain.percentage / 100} />
            </div>
          ))}
        </section>

        <Button block onClick={() => navigate('/tests')}>
          Retour aux tests
        </Button>
      </div>
    </>
  )
}

function Row({
  icon,
  label,
}: {
  icon: 'clipboard' | 'clock' | 'check'
  label: string
}) {
  return (
    <div className="row muted small">
      <Icon name={icon} size={16} />
      <span>{label}</span>
    </div>
  )
}
