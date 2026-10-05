---
name: code_skill
description: Single-file compilation of the TECHBOX code skill (main conventions + partner API, cost telemetry, AI pipeline and documentation references). Engineering conventions for building production software — backend APIs, web frontends, mobile apps, LLM agents, cron jobs, integrations. Use this skill whenever the user asks to architect, scaffold, code, review, refactor, secure, deploy or document an application, service, script or agent — even for a small request ("add an endpoint", "write the backend", "fix this bug", "make a README", "build a bot"). It tells you how much rigour the project needs, how to lay out the code, and which rules never to bypass.
---

# Code

Conventions distilled from three shipped TECHBOX systems: a WhatsApp sales agent
(AICHAI), an identity-verification platform with a partner API (Nimba Trust), and
an intranet banking operations app (TransferOps). Everything here was paid for by
a real incident or a real constraint.

## 0. Workflow

1. **Classify the project** with the tier grid (§1). State the tier in one line before designing.
2. **Fix the architecture** — data source, surfaces, single exit points (§2).
3. **Lay out the repo** with an annotated tree (§3).
4. **Apply the invariants** for data, state and security at the chosen tier (§4–§5).
5. **Make it runnable, testable and observable** (§6–§7).
6. **Document** with the three-file pattern (§8).
7. Use the reference sections (§10–§13) only when the task needs them (see §9).

Numbers in this file (rate limits, TTLs, windows) are **reference values from the
source systems**, not laws. Keep them unless the context gives a reason to change
them, and say so when you change one.

---

## 1. Tier grid — how much rigour

| Tier | Typical project | Apply |
|---|---|---|
| **T1 Script / one-off** | Import script, data fix, CLI, notebook | §2.2 (one exit per dependency), §4.1 (money/dates types), idempotent re-run, a `.env.example`, a 10-line README |
| **T2 Internal tool** | Intranet app, back-office, cron report, ~50 users | T1 + full §3 layout, §4 invariants, §5 security baseline, §6 config, §7 tests on critical rules, §8 three docs |
| **T3 Exposed product** | Public API, partner integrations, mobile app, metered/LLM agent | T2 + §10 Partner API (async model, sandbox, webhooks), §11 Cost telemetry if a metered channel or LLM is billed, §12 AI pipeline if ML inference is in the path |

Rules of thumb:
- Anything that stores personal data, money or credentials is **at least T2**, whatever its size.
- An LLM agent that sends messages on a metered channel is **T3** on the cost axis even if it is tiny.
- When unsure, design for the tier above and cut, not the reverse — adding audit or migrations later is the expensive direction.

---

## 2. Architecture principles

### 2.1 One backend, one source of truth
- All surfaces (web console, portal, mobile, partner integrations, agent) talk to **one backend** that owns the business logic. Never put a calculation, a state transition or a permission check only in a client.
- **One database is the source of truth.** Any external catalogue or display surface (a messaging-platform product catalogue, a cache, a spreadsheet) is a mirror synced *from* it, never edited in place.
- Frontend bundles are built by their own tooling and **served by the backend** (same origin → no CORS). A single process serving API + static files ("Mode B") is the right default for intranet deployments.
- When two services are needed (real-time agent + daily cron), they share **only** the database and a `shared/` package.

### 2.2 The single-exit rule
Every external dependency is reached through **exactly one module**. Changing a provider, tariff or format must touch one file.

| Dependency | Single module | What it centralises |
|---|---|---|
| Outbound messaging API | `sender` | formatting rules, counting every send, refusing empty sends |
| LLM provider | `shared/llm` | retry, timeout, token counting |
| Database | `shared/repository` | no SQL scattered in handlers |
| HTTP client (frontend) | `lib/api` | credentials, base URL, error mapping |
| File/Excel generation | one `engine` + one thin mapper per export | shared rendering, per-case data shaping |

### 2.3 Reply first, work later
An inbound webhook **verifies the signature, returns `200` immediately, then enqueues**. All processing happens in a worker. Synchronous handling makes the sender retry → duplicated (often billed) events. The queue can be a database table; move to Redis only when load requires it.

### 2.4 Deterministic before intelligent
- Known scenarios run on a **state machine / scripted flow with zero AI calls**; the LLM is called only outside the script.
- **Numbers come from SQL, never from a model.** A `metrics` module contains no AI call; an `insights` module produces no numbers. A model counts badly and that is unacceptable on a management report.
- Anything a model writes to a knowledge store is **append-only and physically separated from facts** (prices, stock, rules) so an insight can never overwrite a fact.
- Keep the agent persona prompt short (< 1 500 tokens), versioned, and reviewed by the client. Long prompts degrade obedience.

### 2.5 Same code, several run modes
One codebase runs as local demo / on-prem / cloud by changing **environment variables and runtime dependencies only** — never business logic. Files carrying a hardware or in-process-state assumption (CPU-only inference provider, in-memory rate limiter, in-memory cache) are marked `⚠` in the tree and wired to an env flag before a second run mode is added.

---

## 3. Repository layout

Use an **annotated tree**: every file gets a one-line role; critical files get `★` and a "why it is critical" line. Add a table **"the N files that decide the cost / the risk"**.

```
project/
├── .env.example          # every variable, no secret; the file that differs per deployment
├── README.md             # start, deploy, operate
├── docker-compose.yml    # same environment locally and in prod
├── Makefile              # make dev / test / deploy
├── config/               # typed settings; rules.yaml (form/cost rules); flows.yaml; persona.md
├── migrations/           # versioned, linear, one per change
├── shared/               # enums + schemas imported by BOTH frontend and backend
├── src/
│   ├── shared/           # db, models, repository, llm, telemetry, logging (structured JSON)
│   ├── <service-a>/      # real-time: webhook → queue → worker → flow | brain → sender
│   └── <service-b>/      # cron: metrics → insights → report → mailer → knowledge
├── templates/            # report / e-mail HTML with the client's identity
├── tests/                # one file per critical rule
└── scripts/              # seed, register, estimate_cost, backup, restore-test, monitors
```

**Backend request path:** Routes → Middleware (auth, rbac, audit) → Controller (validate, call service, respond) → Service (business logic + DB) → DB.

**Frontend:** `contexts/` (auth + permissions), `lib/` (api client, engines, constants, utils), `hooks/` (data + validation schemas), `pages/` (lazy-loaded except Login), `components/`. Statuses and types are **imported from `shared/enums`** on both sides — never duplicated.

Health check (`/health`, pings the DB) and structured JSON logs are part of the scaffold, not an afterthought: they are what lets you debug remotely.

---

## 4. Invariants — data, money, state

### 4.1 Types
- Money is **`DECIMAL`, never `FLOAT`**. Dates and times use **native `DATE`/`TIME`**, never strings. Document rounding per formula (e.g. 4 decimals for intermediates, 2 for finals).
- Text columns carry `CHECK`/max-length constraints (e.g. notes ≤ 2 000 chars) so a client cannot post a multi-MB payload.

### 4.2 Calculations and validation
- Financial calculations live in **one pure server-side function** (`computeOperation(payload)`), unit-tested, with the formulas written in the docs.
- Validate at the client for UX **and re-validate at the server** with the same schema (defence in depth). Reject negative amounts and rates > 100 % in the schema *and* in the service.

### 4.3 Writes
- Multi-table writes are **one transaction**; any failure → full rollback.
- Balances and counters are updated **atomically** (`UPDATE … SET balance = balance - ?`), never read-modify-write.
- References come from a **database sequence** (anti-race) + a filtered `UNIQUE` index.
- Settings are persisted with **UPSERT** so an update works even if the row does not exist.
- **Optimistic locking**: the client sends the expected row version; mismatch → `409 Conflict`. Fields locked after a milestone → `423 Locked`, detected by a pure helper listing the protected fields.

### 4.4 State
- Status transitions are validated by a **backend state machine**; the client only proposes. Admin override is an explicit, audited path.
- Registration needing approval: `202` + `status=pending`; login → `403 pending_approval` until approved.

### 4.5 Migrations
- Linear chain, **one migration per change, never edit an applied migration**. Additive tables are safe on a live database. Keep a revision table and the current head in the docs.
- Init scripts are **idempotent** (safe to re-run). New ORM models are registered where the metadata is collected, or migrations will not see them.

### 4.6 Performance defaults
Server-side pagination on lists; **windowed** statistics (`?windowDays=N`, bounded, default 90) instead of scanning history; computed on the server, rendered on the client; tiny in-memory TTL caches (30–60 s) on hot reads; archive/purge jobs for tables that only grow (audit > 12 months).

---

## 5. Security baseline (T2+)

| Layer | Rules |
|---|---|
| **Secrets** | Required at boot with a minimum length (`JWT_SECRET ≥ 32`); **no fallback**; refuse to start on known demo values; an `init:secrets` script generates random ones; only `.env.example` is versioned. **Never ship an API key client-side** — the server mints a short-lived token and hands only that to browser/app/SDK. |
| **Session vs API auth** | *Browser app*: JWT HS256 in an `httpOnly` + `sameSite=lax` cookie, token never in `localStorage`; middleware also accepts an `Authorization` header for cross-origin dev; stateless logout. *Machine/partner API*: per-client key exchanged for a short-lived JWT (15 min) sent in headers; one token per request. Do not mix the two models on one surface. |
| **Passwords & credentials** | Slow hash (bcrypt ~10 rounds or PBKDF2-HMAC); constant-time comparison (`timingSafeEqual`) for privileged credentials; approval workflow for new accounts; roles (`admin/user/viewer`) plus a granular permissions table. |
| **PII** | Encrypt PII columns (AES-GCM); add a keyed HMAC on identifiers that must be searchable for duplicates without decryption; process raw biometric/document images **in memory and never persist** what is not needed; path-traversal guard on any file storage. |
| **Network** | Explicit CORS origin; Helmet-style headers (HSTS, `X-Frame-Options DENY`, CSP); reverse-proxy mode (`HOST=127.0.0.1` + `TRUST_PROXY=true`). |
| **Anti-abuse** | Global rate limit (~100 req/min) + strict limit on `/auth/*` (~5 req/min); return `X-RateLimit-*` and `Retry-After`. |
| **Audit** | Middleware on **all** requests capturing user, IP, user-agent, machine and a sanitized payload + SHA-256; **redact** passwords, tokens and credentials before hashing or storing; `writeEvent` on every mutation; regulated actions (approve/reject/override) carry an `agent_id`. |
| **Errors** | One `sendError()` helper: full server log (stack, endpoint, user), generic sanitized client message; never leak schema, constraints or file paths. |
| **Frontend** | ErrorBoundary around routes; code-splitting with skeletons; no sensitive data in `console.log`; max-length on every input. |
| **Inbound signatures** | Verify webhook signatures (`X-Hub-Signature-256`, HMAC over `timestamp.body`) **before** trusting a payload. |

Every security item **not yet done** is written in the docs as a numbered **open decision** with the options considered — never left implicit.

---

## 6. Configuration and operations

- Typed settings loaded and **validated at boot** (fail-fast). The README lists the critical variables with their value **per run mode** in a table.
- Docker Compose reproduces one environment everywhere; the entrypoint runs migrations then starts the server.
- Optional integrations (LDAP, Redis queue, GPU inference) ship as **inactive skeletons with graceful fallback** while their env vars are absent.
- Operational scripts are standalone and schedulable: backup with retention, **restore test**, health-check monitor with alert after N failures, disk-space monitor, log rotation, archive/purge jobs, deploy and rollback helpers.
- Process manager with auto-start at boot and rotated logs for on-prem deployments.

---

## 7. Testing

- **One test file per critical rule**, named after the rule: the state machine, the pure financial function, the lock helper, "a response never leaves in several messages", "SQL metrics match a known dataset".
- Pure functions first, so the core is testable with a zero-dependency runner and no infrastructure.
- One unified test-suite script selectable by mode (stack / smoke / pentest / stress / load), reused by CI.
- **Seed scripts** for demo data and demo accounts so any environment is exercisable in minutes.

---

## 8. Documentation — the three-file pattern

| File | Audience | Content |
|---|---|---|
| Overview / pitch | Non-technical | the apps, what each does, the big picture |
| `QUICKSTARTER.md` | Developer | run it locally step by step; then the copy-paste integration flow |
| `ARCHITECTURE.md` (+ full documentation) | Engineer | apps table (folder, stack, served at, role), API surfaces, annotated tree, core pipeline, data model, migration chain, run modes, security, **what actually runs today**, roadmap (✅ done / ⏳ pending), **open decisions** |

Writing rules:
- Open with a one-line product statement and a callout of the non-negotiable facts ("the backend serves on port 8001 — notes saying 8000 are superseded").
- Draw the request sequence as an ASCII diagram.
- State the **rules never to bypass** explicitly, each with the consequence of breaking it.
- Every `curl` example shows its response (`# → …`).
- End with a **Common gotchas** table: `Symptom | Cause / fix`.
- Be honest about environment constraints (RAM of the dev box, cold-start times, what to warm before a demo).
- Keep "what runs today" separate from the roadmap so a plan is never mistaken for a feature.

Full template: §13.

---

## 9. References — read on demand

| Read when… | Section |
|---|---|
| Designing a public or partner API, webhooks, sandbox, SDK strategy | §10 Partner / public API conventions |
| An LLM or a metered messaging channel is on the billing path | §11 Cost control and telemetry |
| ML inference (OCR, vision, embeddings, face match) is in the request path | §12 ML inference in the request path |
| Writing or reviewing the project documentation | §13 Documentation templates |

---

## 10. Partner / public API conventions

Source: Nimba Trust `/v1` gateway (Milestones 1–2). Load when designing an API that
outside developers integrate against.

### 10.1 Two doors

| Surface | Auth | Shape | Response | For |
|---|---|---|---|---|
| Internal `/api/v1` | one shared `X-API-Key` | capability-shaped (`/ocr`, `/face/match`, `/risk/calculate`) | envelope `{success, data, error}` | own apps and consoles |
| Partner `/v1` | per-partner key → short JWT | **journey-shaped** (`/onboarding/biometric`, `/authentication/selfie`, `/screening`) | **flat** JSON | outside businesses |

Why journey-shaped: integrators think in journeys, not in capabilities. One uniform
model means one integration to learn. The partner surface is **additive** — it never
touches the internal domains, so it can be deployed on a live system.

### 10.2 Authentication

- Each partner: `partner_id` + per-environment API keys, stored **HMAC-hashed, never in clear**.
- `POST /v1/token` exchanges `api_key` → HS256 JWT valid **15 min**. Recommend one token per request.
- Every call sends two headers: `<Brand>-Partner-ID` and `<Brand>-Token`.
- The api_key **never leaves the partner's server**. A key seen in a mobile bundle or JS is revoked immediately from the dashboard.
- A **dev bridge** endpoint, gated by the internal key, can mint a partner token for the demo partner so the first-party mobile app exercises the gateway without shipping a key.

### 10.3 Environments

Two strictly separated environments; a key or token from one is rejected in the other (`403 environment_mismatch`).

| Environment | Base URL | Behaviour |
|---|---|---|
| sandbox | `https://sandbox.<domain>` | deterministic canned results, nothing billed |
| production | `https://api.<domain>` | real work, billed |

### 10.4 Uniform async model

1. Client calls the service with the data and a `callback_url`.
2. Server answers **immediately** `202 Accepted` with `{ job_id, user_id, status: "accepted" }` — an acknowledgement, not the result.
3. Result is **pushed** to `callback_url` (preferred) or **polled** at `GET /v1/jobs/{job_id}` (fallback).

A failed business outcome is `200` + `status: "rejected"` — **never** an HTTP error.

#### Result triplet
| Field | For | Meaning |
|---|---|---|
| `status` | your code | machine decision |
| `message` | your teams | human-readable line for a back-office |
| `reason` | your code | precise, branchable motive (`ID_AUTHORITY_MATCH`, `FACE_MATCH`) |

Plus `checks` (per-control pass/fail), a score, and `completed_at`.

#### Status enum — document all of them with the recommended action
| `status` | Meaning | Action |
|---|---|---|
| `accepted` | job taken | wait |
| `approved` | verified | continue |
| `rejected` | failed | refuse or manual review |
| `pending_review` | ambiguous | manual review |
| `expired` | not completed in time | offer to retry |

### 10.5 Webhooks

- Signed with `<Brand>-Signature` = HMAC-SHA256 over `{timestamp}.{body}` using a **per-partner `webhook_secret`** (`whsec_…`) — a different secret from the api_key.
- The receiver **verifies before processing** (constant-time compare) and answers `200` on receipt.
- Delivery is retried with backoff by an in-process worker; each attempt is a row (`attempts`, `status`, `next_retry`).

Verification sample to publish (Node):
```javascript
import crypto from 'node:crypto';
function verify(rawBody, receivedSig, secret) {
  const expected = crypto.createHmac('sha256', secret).update(rawBody).digest('hex');
  return crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(receivedSig));
}
```

### 10.6 Sandbox with magic inputs

Sandbox derives the outcome **deterministically from the input** so every branch can be exercised before any real data exists. Publish the table.

| Service | Input | Result |
|---|---|---|
| onboarding / authentication | `id_number` ends with `00` | `rejected` |
| | ends with `11` | `pending_review` |
| | ends with `99` | `expired` |
| | anything else | `approved` |
| screening | `last_name` = `SANCTION` | `rejected` |
| | `last_name` = `PEP` | `pending_review` |
| | anything else | `approved` |

### 10.7 The boring things that decide whether integration is pleasant

- Clean flat error taxonomy (`invalid_token`, `environment_mismatch`, …).
- Rate limiting per partner + environment with `X-RateLimit-*` and `Retry-After`. In-memory fixed window is fine until there is more than one process (`⚠`).
- A **hosted, self-contained quickstart** at `GET /v1/docs` (token → call → result → sandbox branches, every `curl` with its response).
- A **client portal**: keys CRUD, usage, self-test, webhook sink, session login scoped to the partner (multi-tenant).

### 10.8 SDK strategy (decided)

- Guided capture + quality gating on device is the #1 integration accelerator.
- A Flutter-module SDK is **rejected by native teams** (it drags the whole engine). Treat the Flutter app as the **reference UX**; ship **thin native SDKs** (Kotlin AAR, Swift XCFramework) + a **web SDK**.
- Keep heavy ML (face match, liveness) **server-side**; the SDK ships no model. If on-device inference is later wanted: build once, wrap thrice (TFLite / CoreML / ONNX).
- The SDK **never holds the api_key**; the server mints a token and the app hands it to the SDK.

### 10.9 Quickstart skeleton to publish

```
Step 1 — get a token           POST /v1/token            → { token, expires_at }
Step 2 — call a service        POST /v1/<journey>        → 202 { job_id, status:"accepted" }
Step 3 — get the result        webhook (verify signature) | GET /v1/jobs/{id}
Step 4 — exercise every branch sandbox magic inputs table
Common gotchas                 401 invalid_token · 403 environment_mismatch · wrong port/host
```

---

## 11. Cost control and telemetry — LLM agents on metered channels

Source: AICHAI (WhatsApp sales agent + daily report agent). Load when an LLM, a
per-message API or any billed call is on the request path.

### 11.1 Where the money goes

Identify **the few files that decide the cost** and put them in a table in the docs:

| File | Role | Why critical |
|---|---|---|
| `config/rules.yaml` | rules of form | defines "1 answer = 1 message" |
| `sender.py` | single exit to the messaging API | applies the rule and counts every send |
| `flow.py` | scripted flow | fewer turns = fewer billed messages |
| `shared/telemetry.py` | counter | makes the cost visible in the daily report |

In AICHAI, ~79 % of the bill went through `sender.py`. That is why it is the **only** module allowed to call the messaging API: nothing escapes the count or the single-message rule.

### 11.2 Rules of form (in `rules.yaml`, read by the sender)

- **1 answer = 1 message.** The sender merges any multi-part reply into one; a test guarantees a reply never leaves in several messages.
- Maximum length per message.
- **No politeness-only messages** ("Merci !", "Bonne journée !") — they are billed like any other.
- Group questions into one message instead of asking one per turn.
- Refuse empty sends.

### 11.3 Reduce turns before reducing tokens

- **State machine first** (welcome, order capture, after-sales): deterministic, zero AI calls. The LLM is only called when the conversation leaves the script.
- **Client memory**: durable facts (name, address, tastes) + a conversation summary, so the agent never asks the same question twice.
- **Tools instead of guesses**: expose `search_product`, `check_stock`, `record_order`, `hours_and_address` via function calling; the model reads the database instead of hallucinating.
- Persona prompt < 1 500 tokens, versioned, reviewed by the client.

### 11.4 Webhook discipline

Verify signature → `200` immediately → enqueue → worker. Synchronous handling makes the platform retry and **retries are duplicated, billed messages**. Queue in a Postgres table; Redis only if load demands it.

### 11.5 Telemetry

- Every outbound message and every AI call is journaled: timestamp, conversation, tokens in/out, model, cost estimate.
- One place to change provider or tariff (`shared/llm.py`).
- The running cost appears in the **daily report** next to business metrics, so the client sees value against spend.
- Ship `scripts/estimate_cost.py`: a simulator taking expected volume and average messages per conversation → monthly bill.

### 11.6 The daily internal agent (cron)

Five steps, one AI call:

```
cron 20:00 → main.py
   1. metrics.py    SQL only         conversations, orders, new clients, revenue, top 3
   2. insights.py   1 AI call/day    sentiment, trends, requested-but-uncatalogued products
   3. report.py     template → PDF   client's visual identity
   4. mailer.py     SMTP             to the director (no heavier machinery for a cron)
   5. knowledge.py  append-only      long-term learnings, separate from catalogue facts
```

Rules:
- `metrics.py` has **no AI call**; `insights.py` produces **no number**.
- `knowledge.py` is append-only and physically separate from prices and stock: an insight must never be able to overwrite a fact.

### 11.7 Order capture without payments

When online payment is out of scope, the agent records the order in the database and e-mails the sales rep (`email_commercial.html`). Same for the catalogue: Google Sheet / CSV → database (the client edits a sheet), database → platform catalogue (a display surface only), with an image check (format, weight, background) before sync.

---

## 12. ML inference in the request path

Source: Nimba Trust onboarding pipeline (OCR, MRZ, VLM extraction, face match,
dedup, screening). Load when a request runs through OCR, vision models, embeddings
or any model whose availability and latency vary.

### 12.1 Order the pipeline cheap → expensive, with explicit fallbacks

```
1. Decode inputs        size-capped (≤ 2 MB each), base64/data-URI accepted, held in memory
2. Crop / deskew        best-effort, no-op if no confident boundary
3. Cheap extraction     OCR + MRZ (check-digit validated → authoritative for passports)
4. Rich extraction      VLM, document-type-aware prompt, returns the FULL field set
5. Match                embedding cosine vs a configurable threshold (e.g. 0.40)
6. Dedup                vector search on the embedding + keyed-HMAC on the document number
7. Enrol                store the embedding keyed by user for later authentication
8. Screen + risk        never overrides the identity decision, never fails the flow
9. Persist / deliver    encrypt PII, complete the job row, push the signed webhook
```

Principles:
- Manually confirmed fields **override** model output.
- A cheaper stage that is authoritative (MRZ with valid check digits) wins over a richer one.
- A side process (screening, risk scoring) feeds a status but **cannot break the main decision**.

### 12.2 Decision mapping — write it down

| Outcome | Status |
|---|---|
| match + clean | `approved` |
| mismatch / no face found | `rejected` |
| ambiguous / duplicate / **model unavailable** | `pending_review` |
| timed out | `expired` |

"Model unavailable" is a normal state with a defined answer, not an exception.

### 12.3 Human-in-the-loop readiness

- Locate every extracted value on the image (OCR word boxes) so reviewers get **bounding boxes even for model-read fields**.
- Keep **all** extracted fields per document type (voter card, passport, national ID) so the review profile shows everything, not only the canonical subset.
- Write the per-page quality report next to the data (`idp_json.quality`) for a badge in the console and later tuning.

### 12.4 Image quality gate (optional stage, env-gated, default off)

Runs **before** the display image is encrypted and stored, so the cleaned image is the one OCR'd, sent to the model and shown to reviewers (boxes stay aligned).

- **Assess** cheaply: resolution / estimated DPI, skew (min-area rectangle), contrast as **dynamic range p98−p2** (not std-dev — a crisp white document has low std-dev but full range), blur (variance of Laplacian, *reported only*).
- **Clean conditionally** — never touch a good scan: upscale low-res (Lanczos + unsharp, cap ×3) → deskew small angles → CLAHE on the L channel if low contrast. Blur is flagged, not fixed.
- Config knobs with defaults: `PREPROCESS_ENABLED`, `PREPROCESS_MIN_SHORT` (1000), `PREPROCESS_TARGET_SHORT` (1500), `PREPROCESS_CONTRAST_MIN` (130).

### 12.5 Runtime: CPU, GPU, serverless

- Model registry is **lazy**; binaries and model paths are env-pluggable (`LLAMA_MTMD_CLI`, `VLM_MODEL`); a flag gates the expensive full-document path (`VLM_ALL_DOCS`).
- Inference provider (CPU vs CUDA) must be an env flag, not a hardcoded constant — mark the files that still hardcode it with `⚠`.
- Large vision models are **GPU-gated**: on CPU they OOM, so the app falls back to OCR/MRZ automatically.
- Serverless GPU (scale-to-zero): a cold worker can queue 200–370 s, more than a typical client timeout. **Poll up to ~300 s** server-side so a cold start still returns real fields; **warm the worker before a demo**; document that the client may time out while the backend still saves the correct result.
- If adding CPU-bound jobs (summarisation, embeddings) on a small host, throttle worker concurrency to 1–2.

### 12.6 Data model for vectors

- Face / person embeddings: `Vector(512)`, unique per tenant + user for enrolment.
- Document/text embeddings: `Vector(384)` with an HNSW index for semantic search.
- Both live in the same Postgres with `pgvector` — no separate vector store until proven necessary.

### 12.7 Privacy

- Raw images passed to the background job **in memory, never persisted**.
- Stored crops and documents are encrypted; file storage has a path-traversal guard; on-prem by default.
- Document numbers carry a keyed HMAC so duplicates are found **without decryption**.

---

## 13. Documentation templates

Three cross-linked files. Each opens with a one-paragraph pointer to the other two
("New here? → overview · Just want to run it? → QUICKSTARTER · Internals? →
ARCHITECTURE").

### 13.1 QUICKSTARTER.md

```
# <Product> — Quickstarter
> Non-negotiable facts box (ports, superseded notes)

## A. Run it locally
### Prerequisites        (runtime versions, Docker, venv — "never global pip")
### 1) Database          start container · apply migrations (state the head)
### 2) Backend           exact command under the venv · list of served URLs
### 3) Seed demo data    scripts + the env var they need (PYTHONPATH=.)
### 4) Frontends         build → served by backend · dev-server alternative + proxy
### 5) Mobile app        build · install · adb reverse · default API_BASE_URL · overrides
> Constrained-machine notes (free RAM before builds, warm remote workers before demos)

## B. Integrate the API
### Step 1 — get a token          curl + response
### Step 2 — call a service       curl + 202 response
### Step 3 — get the result       webhook (verify!) | poll · full status list
### Step 4 — exercise every branch  sandbox magic inputs

## Common gotchas
| Symptom | Cause / fix |
```

Gotchas that recur across projects — reuse them:

| Symptom | Cause / fix |
|---|---|
| New routes return 404 | server running under the global runtime or not restarted — run under the venv, restart |
| `No module named 'app'` on a script | missing `PYTHONPATH=.` |
| Docker commands fail | Docker Desktop is down — start it, wait until `docker info` succeeds |
| Mobile build OOMs | free RAM (stop DB container, shut down WSL), rebuild, restart DB |
| Mobile app cannot reach the backend | wrong port/host — physical device needs LAN IP or `adb reverse` |
| `401 invalid_token` | token missing/expired, or sandbox token used in production (`403 environment_mismatch`) |
| Server refuses to start | `.env` still contains demo secrets — run `init:secrets` |

### 13.2 ARCHITECTURE.md

```
# <Product> — Architecture
> Product statement: who it is for, what it grew out of, what it exposes now

## 1. The apps          | App | Folder | Stack | Served at | Role |   + ASCII box diagram
## 2. API surfaces      internal vs partner, auth, shape, envelope
## 3. Annotated tree    every file one line · ★ critical · ⚠ run-mode assumptions
## 4. Core pipeline     numbered steps + decision mapping
## 5. Data model        tables grouped by domain · encryption notes · registration rule
## 6. Migration chain   | # | Revision | Introduces |  + head + conventions + commands
## 7. Optional stages   (quality gate, etc.) with config knobs and defaults
## 8. Run modes         | Setting | mode A | mode B | mode C |  + what is not yet env-driven
## 9. Security & privacy   built · still open
```

### 13.3 FULL_DOCUMENTATION.md (T3)

```
Part 1 — Integration guide (client-facing, in the client's language)
Part 2 — Contract reference: endpoints, canonical enums, sandbox magic inputs, error taxonomy, rate limits, milestone map
Part 3 — Implementation status & design rationale ("what actually runs today", "why the API is shaped this way", "SDK strategy (decided)", "still open")
Part 4 — Roadmap: ✅ done / ⏳ pending, grouped, with a suggested sprint order
Part 5 — Open decisions: numbered, each with the options and the current lean
Part 6 — Support
```

### 13.4 Internal technical doc for a T2 app (single file)

```
1. Overview          diagram + feature list
2. Frontend          stack + annotated tree
3. Backend           stack + annotated tree + request pattern + key services with formulas
4. Database schema
5. REST API
6. Business workflows   lettered (A, B, C…), numbered steps, backend steps a) b) c)
7. Auth & roles      roles table · permissions table · token model · optional directory integration
8. Production security   by layer: network / anti-abuse / DB / auth / audit / errors / frontend / growth / tests
9. Statistics & KPI  windowing, endpoints, charts, bundle size
10. Install & deploy  express summary · critical env vars · npm/pm2 commands · pointers to kickstarter and operations guides
```

### 13.5 Writing rules

- Lead with the fact a reader needs first; put the "why" after.
- Show, don't describe: a tree, a diagram, a `curl` with its response, a table.
- Mark honesty explicitly: "built", "partly built", "not started", "decided", "open".
- Prefer durable phrasing over numbers that go stale; when a number matters (port, head revision, threshold), state it once in a callout and reference it.
- One document per audience; never make a developer read the pitch to find the port.
