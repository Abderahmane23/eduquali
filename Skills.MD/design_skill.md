---
name: design_skill
description: Rule-based web and mobile-app design defaults derived from published conversion, retention, usability and compliance research and from the choices of leading apps. Covers page structure, persuasion rules, pricing pages, checkout and payments (incl. West African mobile money), trust and security UX, forms, microcopy, consent and anti-dark-pattern rules, accessibility, localisation, mobile-first, app onboarding, visual tokens per domain (tech/banks, restaurant/casual, non-profit, luxury/gallery), motion, dark mode, and how to test. Use when building or reviewing any website, landing page, dashboard, checkout or mobile app.
---

# Design Skill — Rules

Apply in this order: **1 Page & persuasion → 2 Forms, checkout, payments → 3 Trust & security → 4 Pricing pages → 5 Microcopy → 6 Consent & fair design → 7 Accessibility → 8 Localisation → 9 Mobile-first → 10 App structure & onboarding → 11 Visual system & domain presets → 12 Motion, dark mode, tokens → 13 Measure & test.** Rules are defaults; only a test on your own product overrides them. Sources are listed at the end without further commentary.

---

## 1. Page structure & persuasion

**Section order for any conversion page**
1. Hero: outcome-led headline containing one concrete number, one sub-line, one primary CTA, product visual. The strongest single quantified claim is the H1.
2. Proof directly under the hero: one named, quantified claim (customer count, rating + review count, "used by X of Y"). Logo strip only as a supplement.
3. How it works: three blocks maximum.
4. Detail: alternating image/text, or one short silent demo video with a visible CTA.
5. One testimonial: specific result, name, photo.
6. Objections: FAQ accordion, guarantee, price transparency.
7. Final CTA, plus one inline CTA mid-page.

**Rules**
- One page = one offer = one primary CTA. Campaign traffic goes to a dedicated page, never the homepage.
- Headline, CTA and proof fit in the first viewport on a 375 px phone.
- Match the headline to the ad/email/link that brought the visitor.
- Simple offer (signup, order, download): CTA above the fold. Complex or high-ticket offer: CTA after the explanation. Place the CTA where the visitor has enough information to commit.
- Mobile: one sticky bottom CTA + one inline CTA. Do not stack sticky and above-fold CTAs.
- The primary CTA is the largest, darkest element in its area. Change size and weight before colour.
- Paid landing pages: no main navigation, no footer links beyond legal.
- Keep pages light: remove any element that does not support the single offer.
- Text-heavy pages follow an F-pattern (key words at the start of lines and paragraphs); sparse hero pages follow a Z-pattern (logo top-left, CTA top-right and at the end).

**Persuasion rules (choice architecture)**
- Offer ≤ 3 options wherever a choice is required (plans, amounts, sizes). More options go behind "More".
- Always pre-select a recommended default (plan, donation amount, delivery option) and label it.
- Anchor: show the higher-value option first or beside the target option; show the full price struck through next to a discount.
- Frame savings as money ("save 2 400 000 GNF/year") rather than percentages; frame fees before the form, never after.
- Use loss framing only for genuine deadlines and stock; no countdown timers or fake scarcity.
- Progress indicators on any flow with ≥ 2 steps; show completed steps.
- Social proof must be specific and verifiable (numbers, names, third-party ratings). Generic praise is removed.
- Reciprocity before commitment: give value (preview, calculator, free tier) before asking for data or money.
- Reduce cognitive load per screen: one decision per screen on mobile flows.

---

## 2. Forms, checkout & payments

**Forms**
- Ask only what the transaction needs; every extra field must justify itself. Target 6–8 fields for a checkout, ≤ 3 for sign-up, ≤ 5 for a booking, 3 for an enquiry.
- Single column, label above field, 44–48 px field height, correct `type`/`inputmode`, `autocomplete` attributes, inline validation on blur, error text under the field in plain language.
- No placeholder-as-label. Optional fields marked "(optional)"; do not mark required ones with asterisks only.
- Phone number as the primary identifier in West African markets; email optional.
- Split long forms by topic, one topic per step, progress bar on top, "Back" always available, data kept between steps.

**Checkout**
- Guest checkout is the primary, largest button; "Sign in" and "Create account" are secondary. Offer account creation on the confirmation page.
- Single page or accordion checkout; if steps are unavoidable, show a step indicator.
- Show the full total (shipping, taxes, fees, delivery date) before any field is entered and keep it visible.
- One clear primary CTA on every checkout step; no competing links.
- Offer at least three payment types: card, wallet (Apple Pay / Google Pay), and the local rail (mobile money, BNPL, bank transfer). Show payment logos next to the payment form.
- Free trials: no card required.
- Address: country first, then autocomplete; postcode/city auto-fill where available.

**Mobile money & local payments (West Africa)**
- Default payment order in Guinea and francophone West Africa: Orange Money → MTN MoMo → (Wave / Moov / Free Money where present) → card → cash on delivery. Cards last; diaspora traffic gets card/Stripe.
- Integrate through one licensed aggregator (CinetPay, Flutterwave, Boldrails or equivalent) rather than per-rail APIs.
- Payment screen: select wallet → enter phone number → "Confirm on your phone" screen with the PIN-prompt instruction and a countdown → success screen with a receipt/reference number. Never leave the user on a spinner without the instruction.
- Allow USSD fallback instructions for feature phones and offline moments.
- Show amounts in GNF/XOF with thousands separators and no decimals; show fees explicitly.
- Provide an order/transaction reference that can be quoted by phone or WhatsApp.

---

## 3. Trust & security UX

- Above the fold on any money page: regulator/licence mention, real contact details (phone, WhatsApp, physical address), and one quantified proof.
- Trust badges only where a decision is made: next to the payment form and beside the primary CTA. No badge walls.
- Make the payment area look more secure than the rest of the form: bordered card, lock icon, one line of reassurance ("Your card details are encrypted").
- Show accepted payment logos and delivery/return policy inline at checkout, not in a link.
- Third-party ratings (Google, Trustpilot, app-store rating) near the CTA; internal testimonials beside them, not instead of them.
- Banks/fintech: visible compliance lockup in the footer of every page; security actions (freeze card, report fraud) two taps from home; explain every permission and every fee in one sentence before asking.
- Authentication: phone/email + OTP or social sign-in as default; passwords allowed but with show/hide toggle, paste enabled, no composition puzzles; biometric re-login on mobile; no CAPTCHA before the first attempt.
- Errors on payment or login say what happened and what to do next, never "Error 42".
- Consistent branding and zero visible bugs on transactional screens; a broken field is read as a scam.

---

## 4. Pricing pages

- Three tiers; the middle tier is the target plan, visually highlighted (badge "Most popular", border or larger card) and carries the strongest CTA.
- Tier names describe the customer or outcome (Starter / Growth / Business), not sizes.
- Billing toggle directly above the cards; annual shown in monthly units ("20 000 GNF/month, billed annually") with the saving stated as money. Default to annual for self-serve SaaS; default to monthly when the audience is price-sensitive or evaluating. Both always visible.
- 8–10 benefit-phrased features per card; full comparison table below the cards, grouped by category, with check marks.
- Tier-specific CTA labels ("Start free", "Start trial", "Contact sales"). Enterprise/custom tier = "Contact sales".
- Social proof and a guarantee/refund note next to the CTAs; FAQ of 5–8 objections under the table.
- Mobile: cards stacked vertically, highlighted plan first, comparison table as an accordion; no horizontal scrolling.
- No pricing copy above the cards beyond one line; prices are the first thing visible.
- Free tier or trial exists for any self-serve product.

---

## 5. Microcopy

- Buttons state the outcome in the visitor's words: "Create my account", "Get my quote", "Order now", "Donate monthly". First person ("my") on commitment buttons; imperative verbs elsewhere. Never "Submit", "Click here", "Learn more" as a primary CTA.
- One idea per sentence; ≤ 12 words per line of UI text; no jargon; write at a 12-year-old reading level.
- Error messages: what went wrong + how to fix it, next to the field, in a neutral tone. No blame, no humour on payment errors.
- Empty states: one sentence + one CTA + sample content.
- Confirmation screens: what happened, what happens next, reference number, one next action.
- Reassurance micro-lines under CTAs and fields: "No card required", "Cancel anytime", "We never share your number".
- Labels use the local everyday term (e.g. "Orange Money number"), not the technical one ("MSISDN").
- Same term for the same thing everywhere (one glossary per product).

---

## 6. Consent & fair design (no dark patterns)

- Cookie/consent banner: "Reject all" and "Accept all" on the first layer, same size, same weight, same colour treatment; granular settings one tap away; nothing non-essential loads before consent; choice remembered.
- Centred modal on first visit; never re-prompt within the session; never block content behind repeated prompts.
- No pre-ticked boxes, no confirm-shaming ("No, I don't want to save money"), no hidden costs, no fake urgency, no forced continuity.
- Cancellation, opt-out and account deletion take the same number of steps as signing up and are available online, self-serve.
- Marketing consent is a separate, unticked checkbox; consent copy states exactly what will be sent.
- Data requests are explained at the point of need ("We need your location to show nearby branches"), never in a wall of text.
- Prices, fees, delivery dates and renewal terms are shown before commitment, in the same size as the price.

---

## 7. Accessibility (WCAG 2.2 AA as the floor)

- Text contrast ≥ 4.5:1 (3:1 for large text and UI borders); never grey-on-white body text.
- Every interactive target ≥ 44×44 px (24×24 absolute minimum), ≥ 8 px apart.
- Visible focus ring on every focusable element; full keyboard operability; logical tab order; skip link.
- Every image has alt text (decorative = empty alt); every icon-only button has an accessible name.
- Form fields have programmatic labels; errors are announced and linked to fields.
- No information conveyed by colour alone; add icon or text.
- Provide alternatives to drag-and-drop; no login that relies on memorising or transcribing.
- Respect `prefers-reduced-motion`; no auto-playing motion longer than 5 s without a pause control; no flashing.
- Text resizable to 200 % without loss; pinch-zoom never disabled.
- Test with a screen reader (VoiceOver/TalkBack) and keyboard on the three main flows before release; automated scanners are not sufficient.

---

## 8. Localisation

- Language switcher in the header (text label "FR / EN", not flags); default from browser/system language; remember the choice.
- French copy is written natively, not translated word for word; keep UI strings ≤ 30 % longer than English; leave space for expansion.
- Numbers: space as thousands separator and comma decimal in French locales; currency after the number ("15 000 GNF"); dates DD/MM/YYYY; 24-hour time; phone numbers formatted with the +224 prefix.
- Show prices in the local currency by default; optional second currency for diaspora.
- Address forms follow the local model (quartier/commune, landmark field); postcode optional.
- Contact channels reflect local habit: WhatsApp and phone before email; click-to-call and click-to-WhatsApp buttons.
- Imagery shows local people, products and settings; no generic stock photos.
- Low-bandwidth mode: images ≤ 100 KB, pages ≤ 1 MB on first load, offline-tolerant forms (retain input on reconnection), SMS/USSD fallbacks for critical steps.
- RTL support only when Arabic is offered; if so, mirror layout and icons with direction.

---

## 9. Mobile-first & responsive

- Base CSS is the phone layout; `min-width` breakpoints upward at ≈ 640 / 768 / 1024 / 1280 px, adjusted to where content breaks. Design at 360–375 px first. One responsive URL.
- Fluid grid (`fr`, %, `max-width: 100%`); CSS Grid for page layout, Flexbox for components, container queries for reusable cards.
- Type scales with `clamp()`; body ≥ 16 px; 45–75 characters per line.
- Images use `srcset`/`sizes`, WebP/AVIF, explicit dimensions, lazy loading below the fold.
- Primary actions live in the bottom 40 % of the screen. App-like products use a bottom tab bar (3–5 items, icon + label); content sites use a hamburger/overlay plus visible primary CTA.
- Sticky bottom CTA 100–150 px above the screen edge; safe-area padding on fixed bars.
- Full-width primary button on phones; button groups stack.
- Tables become stacked cards on phones; horizontally scrollable with a frozen first column on tablets.
- Bottom sheets replace dropdown menus and modals on phones; native pickers for date/time/select.
- Hover-only interactions are forbidden; every hover state has a tap equivalent.
- Performance budget: LCP < 2.5 s, INP < 200 ms, CLS < 0.1 on a mid-range Android over 4G.
- Release checklist: no horizontal scroll at 320 px · targets ≥ 44 px · text ≥ 16 px · CTA thumb-reachable · forms usable with keyboard open · orientation change tested · reduced-motion respected.

---

## 10. Mobile app structure & onboarding

**Default flow:** splash ≤ 1.5 s → value screen with real or sample content → first meaningful action → sign-up in context (Apple / Google / phone OTP, ≤ 3 fields, "Skip for now" where possible) → permission request in context after the user has acted → first-win confirmation → home with bottom tabs.

**Rules**
- The first action requires no personal data.
- Sign-up appears only when the next action needs it (save, pay, sync).
- Permissions are requested at the moment of use with a one-line reason; never on launch; a pre-permission screen precedes the OS prompt.
- Empty states show sample data and one CTA.
- No paywall, rating prompt or promotional pop-up in the first session.
- Home = the single most valuable screen (feed, balance, menu, collection), never a menu of links.
- Progress indicator or checklist for any setup; a visible "done" moment after the first key action.
- Every onboarding screen has Skip and a CTA; no mandatory tour.

**Onboarding screens decision**

| App type | Rule |
|---|---|
| Self-explanatory (ordering, banking, catalogue, gallery, sales/stock tool) | No welcome carousel. Straight to the value screen; contextual tooltips on first use of a feature. |
| Value depends on personal setup (fitness, finance goals, learning, media) | One to three intent questions ("What do you want to do?"), each with Skip, then a personalised first screen. |
| New or unfamiliar product category | Maximum three benefit screens, one benefit each, progress dots, Skip and CTA on every screen. |
| Complex multi-role / B2B tool | Progressive onboarding: tooltips, coach marks and a checklist that appear when the feature becomes relevant; no upfront tour. |

Delete any onboarding screen that does not change what the user sees next.

---

## 11. Visual system & domain presets

**Universal**
- Max 2 typefaces (3 if the third is a mono or a display face used only for accents). Body 16–18 px, line-height 1.5–1.7; headings on a 1.25–1.33 ratio; captions ≥ 12 px.
- Palette: primary · accent · surface + black/white. Accent reserved for the primary action and focus.
- One icon library, one style, stroke matched to type weight. Default Lucide; Heroicons for Tailwind-only projects; Phosphor when weight variants are needed; Tabler for maximum coverage.
- 8 px spacing scale; container 1200–1440 px; buttons 44–48 px high with horizontal padding ≈ 2× vertical; hierarchy solid / outline / text; one primary per view.
- Tables: toolbar above (search, filters, sort, export), sticky header, identifier first, numbers right-aligned tabular, visible sort direction, active-filter chips, pagination with total count, row height 40/48/56 px.
- Accordion/dropdown: header ≥ 44 px, indicator right, single-open for FAQ, multi-open for settings; searchable select above 8 options.

**Presets**

| | Tech / Professional / Banks | Restaurant / Casual | Non-profit | Luxury / Gallery |
|---|---|---|---|---|
| Fonts (heading · body · third) | Inter · Inter or IBM Plex Sans · mono for figures | Playfair Display · Nunito · script accents only | Merriweather · Source Sans 3 · Open Sans | Cormorant Garamond · Montserrat · Bodoni Moda display |
| Body / H1 | 16 / 40 px | 17–18 / 48 px | 17 / 44 px; impact figures 48–64 px | 16–17 light / 64 px light |
| Palette | `#1E3A8A` · `#0EA5E9` · `#F1F5F9` | `#C2410C` · `#FDE68A` · `#FFF7ED` (charcoal variant for fine dining) | `#0F766E` · `#F59E0B` · `#F8FAFC` | `#1C1917` · `#B08D57` · `#F5F3EF` |
| Icons | Lucide outline | Phosphor regular/duotone | Heroicons or Lucide + flat illustrations | Feather/Iconoir thin; prefer text links |
| Radius / motion | 6–8 px / 150–200 ms | 12–16 px or pill / 250 ms | 8 px / 200 ms | 0 / 300–350 ms |
| Desktop layout | top nav 64 px; sidebar 240 px + 12-col grid, max 1280 px; cards | hero ≤ 60 vh with hours + CTA; inline menu (never PDF), 2-col name/price, sticky category tabs | nav with accent Donate; impact strip; story cards; funds-use chart; registration number in footer | minimal header; full-screen image; gallery 2–3 cols, 48–96 px gaps, lightbox; product image 60 % / sticky details 40 % |
| Mobile nav | bottom tabs (Home · Transfers · Cards · More) | sticky bar Call · Directions · Order/Book | Donate in header + sticky CTA | full-screen overlay menu; sticky Enquire bar |
| Tables | dense, sticky header + frozen first column, filters/sort/export, status badges | hours (today highlighted), allergen icons + chips; otherwise none | 2–3-col transparency tables; events sortable by date, filterable by cause | hairline key/value, uppercase keys, no header row, never zebra |
| Hero proof | quantified claim + regulator/certification lockup | rating + review count, real food photo | audited figure + registration + rating | press mentions, provenance; no star counts, no urgency |
| Conversion action | open account / sign up: pre-qualify before KYC; home = balance + 2 actions | order / book: guest checkout, mobile money first, reservation ≤ 5 fields | donate: amount chips with recommended default + monthly toggle, ≤ 3 steps, outcome per amount, proof beside form | enquire / appointment: single text-link CTA per view, 3-field form, no pop-ups |
| App onboarding | none, or one intent question; KYC after value preview | none — straight to menu | optional one question (cause / amount) | none — straight to collection |
| Tone of copy | precise, sentence case, numbers everywhere | warm, verbs, short | human, first-person plural, concrete outcomes | sparse, uppercase labels, no exclamation marks |

---

## 12. Motion, dark mode, tokens

- Micro-interactions 150–200 ms; panel/sheet transitions 200–300 ms; luxury 300–350 ms; nothing above 400 ms except deliberate hero video.
- Ease-out for entrances, ease-in for exits; no bounce on transactional screens.
- Motion communicates state (loading, success, error) — never decoration on money screens.
- Dark mode follows the system setting by default with a manual override; both themes tested for contrast; brand accent adjusted for dark surfaces; no pure black (#000) backgrounds, no pure white text.
- Banking/fintech and productivity apps ship dark mode at launch; marketing sites may ship light only.
- Design tokens (colour, spacing, radius, type, motion) defined once and consumed by web and app; every component uses tokens, never hard-coded values.
- Skeleton screens for loads > 300 ms; spinners only for < 1 s actions; progress bars for uploads/payments.

---

## 13. Measure & test

- Instrument before designing: page view, CTA click, form start, form submit, payment start, payment success, first meaningful action (app), Day-1/7/30 return.
- Test priority: headline → hero visual → primary CTA → form fields → proof → pricing structure. Colours and below-fold copy last.
- One variable per test; run ≥ 2 full weeks and through at least one full business cycle; stop only at a pre-set sample size; do not peek and stop early.
- Minimum practical volume: ≈ 1 000 conversions per variant for small effects; below that, prefer usability tests (5 users per round) over A/B.
- Pricing pages: test structure (tiers, highlighted plan, default billing) before prices.
- App onboarding: measure completion of the first meaningful action in session 1 and Day-7 retention; cut any screen whose removal does not lower them.
- Re-audit accessibility, consent and performance on every release; keep a changelog of tests and results.

---

## Sources (by section)

1. Digital Applied 2026 landing-page study; Unbounce Conversion Benchmark; SEO Sherpa 2026; Foundry CRO citing HubSpot, CXL, Demio; roast.page; NN/g eye-tracking; Schwartz / Iyengar choice research; Kahneman–Tversky framing and anchoring.
2. Baymard Institute checkout research; Digital Applied checkout guide; ConversionStudio; CorePPC; GSMA State of the Industry 2025; Boldrails, Autoflowly, PayAtlas Guinea, Riverpe (mobile-money rails).
3. Baymard perceived-security studies; BTNG.studio; LogRocket trust UX; Userintuition trust-signal review; Toimi fintech design review.
4. Digital Applied pricing-page framework; 925 Studios; Better Launch; SaaSFrame; InfluenceFlow; Art of Styleframe; Veza Digital (Slack, Notion, Linear examples).
5. Unbounce / ContentVerve first-person CTA tests; NN/g UX writing; Leo9 Studio.
6. CNIL 2025 decisions; CPPA (Honda, Todd Snyder); FTC Negative Option Rule; EDPB guidance; Elementor, ConsentBit, DataGrail, JustAnalytics consent studies.
7. WCAG 2.2; EN 301 549 / European Accessibility Act; ADA Title II rule; WebAIM Million.
8. Localisation practice for francophone West Africa (GSMA, BCEAO PI-SPI, W3C i18n guidelines).
9. Framer, 2POINT, WebHelp Agency, UDT, MB Web responsive guides; Parachute Design, UXPin, UXCam, Brand Vision mobile UX; Google Core Web Vitals.
10. UXCam 2026 retention benchmarks; Adjust / Sensor Tower; Pendo + UserTesting onboarding study; Appy Pie; OneSignal via Userpilot; Appcues; Eleken; Strava, Headspace, Duolingo, Revolut, Slack, Canva onboarding patterns.
11. FontAlternatives, FontPreview; Block Agency, MenuTiger; Elevation, DesignRush / M+R Benchmarks; Techelix, DiverseKit; PkgPulse, Mantlr, AllSVGIcons; Setproduct, Lollypop, Coyle.
12. Material Design motion guidance; Apple HIG; Android Authority / Polar dark-mode surveys; design-token practice (shadcn/ui, Material, Polaris).
13. Digital Applied A/B meta-analysis; CXL testing guidance; NN/g usability-test sizing.
