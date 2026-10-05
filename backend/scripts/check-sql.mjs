#!/usr/bin/env node
/**
 * Verifie que les migrations Postgres s'analysent sans erreur.
 *
 * Une migration ne se relit pas : elle s'execute une fois, sur la base de
 * production, et une virgule manquante y est decouverte au pire moment. Ce
 * controle utilise l'analyseur de Postgres lui-meme — `pglast`, qui embarque
 * `libpg_query` — et non une expression reguliere.
 *
 * Il verifie la syntaxe, pas la semantique : une contrainte qui reference une
 * colonne inexistante passe ici et echoue a l'execution. Pour cela il faut
 * une vraie base — `supabase db reset` en local, ou une branche Supabase.
 *
 * Sans `pglast` installe, le controle s'annonce et laisse passer : un outil
 * facultatif absent ne doit pas bloquer une machine qui n'en a pas besoin.
 *
 * Usage : npm run check:sql   (pip install pglast)
 */
import { execFileSync } from 'node:child_process'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const ici = dirname(fileURLToPath(import.meta.url))
const dossier = join(ici, '..', 'supabase', 'migrations')

// Le dossier passe en argument, jamais interpole dans la source Python : un
// chemin Windows contient des antislashs, qui deviendraient des echappements.
const PYTHON = `
import glob, io, os, sys
try:
    from pglast import parse_sql
    from pglast.parser import ParseError
except ImportError:
    print("  pglast absent — controle ignore (pip install pglast)")
    sys.exit(2)

ok = True
for chemin in sorted(glob.glob(os.path.join(sys.argv[1], "*.sql"))):
    nom = os.path.basename(chemin)
    sql = io.open(chemin, encoding="utf-8").read()
    try:
        arbre = parse_sql(sql)
        print("  %-34s OK  (%d instructions)" % (nom, len(arbre)))
    except ParseError as e:
        ok = False
        print("  %-34s ERREUR : %s" % (nom, e))
sys.exit(0 if ok else 1)
`

try {
  process.stdout.write(
    execFileSync('python', ['-c', PYTHON, dossier], { encoding: 'utf8' }),
  )
} catch (erreur) {
  process.stdout.write(erreur.stdout ?? '')
  process.stderr.write(erreur.stderr ?? '')
  // 2 = outil absent, pas un echec du SQL.
  process.exit(erreur.status === 2 ? 0 : 1)
}
