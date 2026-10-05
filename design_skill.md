---
name: design_skill
description: Rule-based design defaults for web and mobile products, derived from published conversion, usability, accessibility and performance research and from shipped work. Covers the order of operations, page structure and persuasion, action-first entry screens and where an account becomes necessary, forms and checkout, payments including West African mobile money, trust UX, microcopy, consent, accessibility as a computed property, localisation and money formatting, mobile-first and low-end device budgets, app structure and onboarding, design tokens shared across web and app, component layers, layout traps that fail silently, data and numbers on screen, motion and micro-interactions, dark mode, the 2026 platform baseline, and tests that pass for the wrong reason. Use when building or reviewing any website, landing page, dashboard, checkout, or mobile app.
---

# Design Skill — Rules

Rules are defaults. Only a measurement on your own product overrides one.

**Order of operations — do not reorder.**

```
0  Decide      what decision does this screen serve, and what data exists?
1  Tokens      colour, type, spacing, radius, motion — defined once
2  Components  the shared layer every screen draws from
3  Screens     built out of 1 and 2, never out of raw values
4  States      empty, loading, error, partial — designed, not improvised
5  Verify      contrast computed, layout tested at 320 px, motion at 60 fps
```

Skipping 0 produces beautiful screens showing data you do not have. Skipping 1–2 on anything over ten screens produces a system that diverges before it ships.

Two questions belong at step 0 and nowhere later, because both are expensive to retrofit: **what can a stranger see before signing up**, and **are the tokens resolved at runtime** (without that, dark mode and re-theming are a rewrite, not a setting).

---

## 0. Before drawing anything

- **Name the decision.** Every screen exists so someone can decide something: what to buy, whom to hire, whether to pay. Write that sentence first. Elements that serve no decision are deleted, not shrunk.
- **Inventory the real data.** List the fields the backend actually returns. A mock-up showing a rating, a duration, a thumbnail or a trend is a *feature request*, not a design — say so before building it.
- **Never invent a number to fill a layout.** A metric with no source is removed from the design. A tile with no data is removed, not stubbed with `0` or `—` unless the absence itself is meaningful and labelled.
- **Comparisons need a comparison.** Show `+3` only when a previous period exists. Showing `+0` implies a measured flat result.
- **Rank by decision value, not by availability.** The easiest number to compute is rarely the one worth the top of the screen.
- **Show before asking.** Work out what a stranger can be given *before* any account exists, and give it. Whatever the product does, someone arriving cold has one question — is there anything here for me? — and no reason to hand over a phone number to find out.

---

## 1. Page structure & persuasion

**Section order for a conversion page**
1. Hero: outcome-led headline containing one concrete number, one sub-line, one primary CTA, product visual.
2. Proof directly under the hero: one named, quantified claim. Logo strips supplement, never replace it.
3. How it works: three blocks maximum.
4. Detail: alternating image/text, or one short silent demo with a visible CTA.
5. One testimonial: specific result, name, photo.
6. Objections: FAQ accordion, guarantee, price transparency.
7. Final CTA, plus one inline CTA mid-page.

**Rules**
- One page = one offer = one primary CTA. Campaign traffic gets a dedicated page, never the homepage.
- Headline, CTA and proof fit the first viewport on a 375 px phone.
- Match the headline to the ad, email or link that brought the visitor.
- Simple offer: CTA above the fold. Complex or high-ticket: CTA after the explanation. Place it where the visitor has enough information to commit.
- Mobile: one sticky bottom CTA plus one inline CTA. Never stack sticky and above-fold CTAs.
- The primary CTA is the largest, heaviest element in its area. Change size and weight before colour.
- Paid landing pages: no main navigation, no footer links beyond legal.
- Text-heavy pages follow an F-pattern; sparse hero pages a Z-pattern.

**Choice architecture**
- Offer ≤ 3 options wherever a choice is required. More go behind "More".
- Pre-select a recommended default and label it as recommended.
- Anchor: show the higher-value option first or beside the target; show the struck-through full price next to a discount.
- Frame savings as a money amount in local currency, not a percentage. State fees before the form, never after.
- Loss framing only for genuine deadlines and stock. No countdown timers, no fake scarcity.
- Progress indicators on any flow with ≥ 2 steps; show completed steps.
- Social proof must be specific and verifiable. Generic praise is removed.
- Give value before asking for data or money: preview, calculator, free tier.
- One decision per screen in mobile flows.

---

## 2. Forms, checkout & payments

**Forms**
- Ask only what the transaction needs. Target 6–8 fields for checkout, ≤ 3 for sign-up, ≤ 5 for a booking, 3 for an enquiry.
- Single column. **Label above the field, never floating** — a floating label disappears the moment someone types, and they must then remember what they were filling in.
- 44–48 px field height, correct `type`/`inputmode`, `autocomplete` attributes, inline validation on blur, error text under the field in plain language.
- Optional fields marked "optional". Do not mark required ones with asterisks only.
- Group fields into titled sections of three to five. An ungrouped long form is an undifferentiated column: nobody knows where they are or what remains.
- Split multi-topic forms by step, one topic per step, progress on top, "Back" always available, data kept between steps.
- **The primary action does not scroll with the form.** Pin it to the bottom of the viewport. A submit button that is the last element of a long page is a button nobody knows exists until they have finished.
- **What blocks the button is written above the button**, not hidden in the disabled state: "Declare your subjects first", "Costs 12 credits". Nobody should discover the cost of an action at the moment of committing to it.
- Prefer keeping the button visible and disabled with a stated reason over hiding it.

**Choosing from a long list**
- Under about eight entries, show them all as tappable chips: reading them is faster than typing, and the list is the answer to "what are my options?".
- Above that, replace the chips with **a field you type into**, its matches under it, and what has been chosen as removable tags **below** the field. Twenty-four subjects shown at once is a wall: it has to be read entirely to find one, it pushes the button off-screen, and it grows every year.
- After a choice, **empty the field and keep the focus**. The next entry is typed without leaving the keyboard; a field that keeps its text forces a manual erase between every selection.
- **Do not re-offer what has already been chosen.** It is visible as a tag underneath; offering it again invites the second tap, which would remove it.
- Matching ignores accents, case and extra spaces — nobody types "Nzérékoré" with its accents on a phone keyboard. This is one shared function, not one per screen.
- **A reference list is never complete.** Where new entries are legitimate (schools, subjects), offer "Add « X »" as the first row once what is typed matches nothing — and never when it matches an existing entry, accents folded, or the list gains a duplicate on a mistyped tap.
- Show a handful of entries at rest, before anything is typed. A field that shows nothing until a first keystroke hides the fact that a list exists at all.
- The switch is **declared, not computed from the list length**: a threshold silently converts a four-option list the day someone adds a fifth.


**Checkout**
- Guest checkout is the primary, largest button. Offer account creation on the confirmation page.
- Single page or accordion. If steps are unavoidable, show a step indicator.
- Show the full total — shipping, taxes, fees, delivery date — before any field is entered, and keep it visible.
- One primary CTA per step; no competing links.
- Keep every entered value on error; scroll to and focus the first invalid field.

**Payments — West Africa**
- Phone number is the primary identifier; email is optional.
- Mobile money first in the payment list, card second, and name the operators explicitly (Orange Money, MTN MoMo, Wave) rather than a generic "mobile payment".
- Show the operator's own flow honestly: the PIN prompt happens on the phone, not in your app. Display the reference, a countdown, and what to do if the SMS does not arrive.
- Never claim success before the operator confirms. Payments are never optimistic.
- State fees and who pays them before the form.
- Offer the amount in local currency only; no dual pricing.

---

## 3. Trust & security UX

- Show the real company: legal name, address, registration number, a reachable human.
- Security claims are specific and verifiable — named certification, named regulator, named processor. "Bank-grade security" is noise.
- Padlocks and badges only where the data is entered, and only if genuine.
- Explain *why* each sensitive field is needed, at the field.
- Identity documents and biometrics: process in memory, persist only what is required, say so in one line at the point of capture.
- Never display a full card number, full ID number or full phone number back to the user; mask consistently.
- An action that informs a third party (terminating a contract, publishing, cancelling an order) says so in the confirmation.

---

## 4. Pricing pages

- Three tiers or fewer; one highlighted as recommended, with a reason.
- Monthly/annual toggle with the annual saving shown as a money amount.
- Feature lists compare on outcomes, not feature names; cap at seven rows before "compare all".
- State what happens at the limit: blocked, throttled, or charged.
- Show the total first charge including any setup fee.
- Free tiers state what they permanently include, not what they lack.
- **Write the amount the way the country writes it.** In Guinea that is `100 000 GNF`: currency on the right, a space every three digits, no decimals — the franc has no subunit in use, so `GNF100000.00` is three mistakes in one string and six digits nobody can read at a glance. Format from one shared helper, never with `toStringAsFixed` at the call site.
- **Ask for the money at the refused gesture, not on arrival.** Someone who has just typed a question knows exactly what the subscription buys; the same sheet shown when the screen opens answers a question nobody has asked yet. A locked feature keeps its button visible and disabled with the reason written above it — a button that disappears reads as "this does not exist".
- **Meter a feature or include it in the plan — never both.** A per-action counter next to a monthly subscription makes a paying customer watch a balance while they work, which is the feeling they paid to be rid of.
- **When metering goes, take the meter with it.** A half-removed pricing model is worse than either model: the balance is hidden but the ledger still debits, so the feature stops working at zero for someone who is paying, and nothing on screen explains why. Remove the store, the purchase sheet, the per-action costs and the daily caps in the same change — a daily cap is usually a metering artefact too, a free door next to a paid one, and it has no meaning once the door is the subscription. Then check the copy: "· 1 crédit" survives in tooltips and button labels long after the system is gone.
- **Keep the model routing when you drop the tariff.** What a call costs you does not disappear with what you charge for it — it moves onto your own margin. Which model answers which request is now a cost decision you own, so it stays written down, separately from any price.
- **Enforce the plan where the action happens, not only on the button.** A gate that lives in a screen is bypassed by the next caller; put it in the layer that performs the action, and have it raise a refusal that names the plan required rather than a sentence to display. The screen catches that and offers the plan.
- **The plan's name belongs where the plan is enforced**, in one word, next to the title of the feature it gates. The free tier is named, not described: "Basic", not "Gratuit" — a word that reads as a promise about the feature rather than a level.

---

## 5. Microcopy

- Buttons name the outcome, not the mechanism: "Publish the offer", not "Submit".
- First person for the user's own things ("My profile"), second person for instructions.
- Errors say what happened, why, and the next action. No codes without a human sentence.
- Empty states say what will appear here and how to make it appear.
- Numbers in the sentence beat adjectives: "12 schools" beats "many schools".
- **Do not infer gender.** Names carry no reliable gender signal — in Guinea, Alpha, Ibrahima and Ousmane are masculine names ending in *a*. Rewrite to avoid agreement ("Fiche de X retirée") rather than guessing or littering the interface with "(e)".
- Sentence case everywhere except acronyms. No exclamation marks in transactional copy.
- The same object has the same name in every screen. Two names for one thing is a bug.

---

## 6. Consent & fair design (no dark patterns)

- Reject is as easy and as visible as Accept — same level, same weight, first screen.
- No pre-ticked boxes for anything optional. Consent is granular and separable.
- Cancel a subscription in the same number of steps as subscribing.
- No confirmshaming, no disguised ads, no hidden costs, no forced continuity.
- Trial ending: notify before charging, not after.
- Unsubscribe from one link, no login required.

---

## 7. Accessibility — a computed property, not a judgement call

WCAG 2.2 AA is the floor, not the target.

- **Compute contrast, never eyeball it.** Put the ratios in a test that fails the build. A desktop monitor in a dark room forgives everything a phone in sunlight refuses. Minimums: 4.5:1 body text, 3:1 large text and non-text UI (borders, icons, chart marks, focus rings).
- Colour never carries meaning alone. Status = icon + colour + word. Series = colour + direct label or legend.
- Touch targets ≥ 44 px with ≥ 8 px between them. Assert this in a test; it regresses silently.
- Every icon-only control has an accessible name. Assert that too — a scan for tooltip-less icon buttons catches what review misses.
- Focus-visible on everything reachable by keyboard: 2 px ring, 2 px offset, ≥ 3:1.
- Respect `prefers-reduced-motion` and `prefers-contrast`; test with the OS setting on.
- Do not trap focus outside modals; return focus to the trigger on close.
- Text resizes to 200 % without loss; no fixed-height text containers.
- Form errors are announced, associated with their field, and survive submission.

---

## 8. Localisation & money

- French for francophone West Africa: thousands separated by a narrow space, decimal comma, currency after the amount — `1 500 000 GNF`.
- **Currencies without subunits in practice (GNF, XOF) show no decimals.** Never `1 500 000,00 GNF`.
- **Long amounts shrink, they do not truncate.** A cut number reads wrong; a smaller number reads right. Scale text down to fit rather than ellipsising.
- Compact forms for tight columns only: `320k`, `1,2 M`. Keep the exact figure one tap away.
- Dates written out in body copy (`14 juin 2025`), short in table columns (`14/06`). Never ambiguous numeric order.
- Reserve 30 % extra width for French versus English in buttons and labels.
- Phone numbers formatted with the country prefix visible and non-editable.
- Never translate a proper noun, a level name or a legal term without a source.

---

## 9. Mobile-first & the low-end device budget

Design for a 4-year-old Android on an intermittent connection. That is the device your product runs on.

- Layout works at 320 px with no horizontal scroll. Test it; do not assume it.
- **Performance budget for a directly distributed app** (shared by Bluetooth or Xender, not a store): every megabyte is minutes of transfer.
  - Strip native debug symbols before shipping.
  - Ship only the architectures real phones use; `x86_64` is emulator-only dead weight.
  - Do not add a charting library to draw seven bars. Do not add an animation library for a 120 ms scale.
  - Audit declared-but-unimported dependencies before every release.
- **Compute what you can locally.** A number that requires the network is a number that shows a spinner. Local SQL on device beats a round trip for anything the device already knows.
- Images: explicit dimensions, modern formats, no layout shift.
- Every screen works offline in a degraded but honest state, and says which parts are stale.

---

## 10. App structure & onboarding

**Default flow:** splash ≤ 1.5 s → value screen with real or sample content → first meaningful action → sign-up in context → permission in context after the user has acted → first-win confirmation → home with bottom tabs.

**The entry screen is an action, not a form.**
- The first screen carries the product's central action — a search, a quote, a calculation — inside a card that overlaps the header. Not a headline with a *Sign up* button; the thing itself, usable immediately.
- **Results are public; commitment is not.** The line is not "how valuable is this data" but "does this step involve another person". Browsing a list involves nobody. Contacting, booking, paying or publishing involves someone else — that is where the account belongs, and the button that asks for it says why in one line.
- Offer at most two or three *doors* under the action, one per audience ("I am a teacher", "I represent a school"), each naming what that person comes to do. Sign-in is a text link, not a button: most arrivals are new.
- What a public screen exposes is what its subject published about themselves. Contact details stay masked by the same rule that governs the rest of the product — a public page is not an exemption from it.

**Rules**
- The first action requires no personal data.
- Sign-up appears only when the next action needs it: save, pay, sync.
- Permissions requested at the moment of use, with a one-line reason and a pre-prompt screen. Never on launch.
- Home is the single most valuable screen, never a menu of links. Four quick actions at most — seven links turn the home screen into a table of contents.
- **A destructive action lives where its object lives.** "Terminate contract" belongs inside the contract, never in a list of quick actions where the user cannot see which one they are terminating.
- No paywall, rating prompt or promotional pop-up in the first session.
- Every onboarding screen has Skip and a CTA. Delete any screen that does not change what the user sees next.
- **Every account can be left.** A logout is reachable in one gesture from the profile, and does not require the profile to have finished loading — a shared phone must not stay open on someone else's account because their data failed to load.

**Onboarding screens decision**

| App type | Rule |
|---|---|
| Self-explanatory (ordering, banking, catalogue, internal tools) | No carousel. Straight to the value screen; contextual tooltips on first use. |
| Value depends on personal setup (fitness, finance, learning) | One to three intent questions, each skippable, then a personalised first screen. |
| Unfamiliar product category | Three benefit screens maximum, one benefit each, dots, Skip and CTA on every screen. |
| Complex multi-role / B2B | Progressive: tooltips and a checklist appearing when the feature becomes relevant. No upfront tour. |

Onboarding shown once per account, not per launch. Re-showing it to a returning user is a punishment.

**When the product has several audiences**
- **Value screens are written per role, not shared.** A teacher and a school open the same app for opposite reasons; one generic screen persuades neither, and it is the screen that has to justify the eleven questions behind it. Each role gets its own screens, gated on the answer that named the role — and a role with less to explain gets fewer screens, not the same number padded out.
- **Never ask twice for what a previous screen already established.** "Do you give home lessons?" two screens after "Select your services · Home lessons ☑" reads as an app that was not listening. Derive it, and gate the follow-up screens on the earlier answer.
- **Numbers in value copy are claims a reader can check.** "3 000+ students" on a platform at launch is falsifiable by anyone in the city, and the first screen is the worst place to be caught. Use a number you can defend, or an argument that needs none.
- A screen that becomes visible *because of the answer just given* must be reachable. Advance logic that reads state captured before the answer was written will skip it — and a missing step raises no error, it simply never appears.

---

## 11. Visual system, tokens & the component layer

**One definition, consumed everywhere**
- Colour, spacing, radius, type and motion are defined **once**. A second definition of the same palette is not a duplicate, it is a future bug: the two diverge, corrections land in the copy nobody renders, and the fix appears to work while the screen stays wrong.
- Assert it: a test that fails when the palette class or token file is defined more than once costs nothing and catches a whole class of silent drift.
- Components reference tokens only. A hard-coded hex in a screen is a defect.

**One token file across surfaces**
- Web and app consume the same token names and the same values, from one source. Someone who starts on a phone and finishes on a laptop should recognise the same product, not two cousins.
- Parity is in the tokens and the entry flow, not in the layout. The same palette, the same first action and the same wording; the grid is free to differ.

**Build the component layer before the screens**
- Over ten screens, build tokens and shared components first, then screens. Sixty screens redesigned one at a time will diverge before the last one is done.
- **Restyle the shared primitive in place; do not ship a parallel "new" one.** Renaming `Card` to `NewCard` leaves thirty-four screens on the old look and guarantees they will never all migrate. Change `Card` itself and every screen inherits.
- The shared layer for most products: card · list row · section title · icon tile · initials tile · tag chip · filter chips · metric tile · empty state · sticky action bar · form section · bottom navigation · sheet header. If two screens disagree on any of these, one of them is wrong.

**Universal**
- Max 2 typefaces, 3 if the third is a mono used only for figures. Body 16–18 px, line-height 1.5–1.7, headings on a 1.25–1.33 ratio, captions ≥ 12 px.
- Palette: primary · accent · surface · foreground, plus status.
- **The accent is one word in a title, and nothing else.** Never a surface, never a status, never a button fill. A single coloured word is what makes a three-line headline get read to the end; two accented words cancel each other out. Colouring a whole panel with it produces something nobody can put text on.
- **Compute the accent against the surface it will actually sit on.** The same yellow reads 5.7:1 on a deep blue and 3.4:1 on the light end of the gradient that blue fades into. Never carry an accent across a palette change without re-measuring it — and measure it against *both* ends of a gradient, not the name of the colour.
- **Match the floor to the use.** An accent that only ever appears in a 34 px 800-weight title is large text: its floor is 3:1. Writing the rule down is what stops it drifting into a caption six weeks later; a test that forbids it as a fill is what enforces it.
- One icon library, one style, stroke matched to type weight. Lucide by default; Phosphor when weight variants are needed.
- 8 px spacing scale. Buttons 48–56 px high; pill radius for the primary action so it never reads as a field.
- **A surface that is nearly the page colour needs no border once it has a shadow.** Thirty grey hairlines make a page noisy; a page tint one or two percent off white plus a two-layer shadow does the same job silently.
- Shadows come in two layers: one short and dense at the contact point, one long and diffuse beneath. A single wide blur is a halo, not an object.
- Every interactive component ships all its states. One without a pressed and a focus state is not finished.
- **Bottom navigation holds five items, six at a squeeze.** Past that, shorten the labels before dropping a destination — "Agenda" says what "Calendar" says. Past six, the labels truncate and the bar stops being readable.
- **When the bar is full, cut by frequency, not by importance.** A catalogue somebody opens monthly leaves the bar for a card on the home screen; the messages they open daily take its place. Importance decides whether a feature exists; frequency decides whether it deserves a permanent tab.
- **A selectable row carries a checkbox.** An accordion that must be expanded to reveal what selects it reads as information, not as a choice. If checking the row implies a sensible default — every slot in the day, the whole category — apply it and let the person narrow it down; the reverse leaves rows half-chosen and a *Continue* button that refuses without saying why.
- Tables: toolbar above, sticky header, identifier first, numbers right-aligned and tabular, visible sort direction, active-filter chips, pagination with a total.
- Searchable select above eight options; plain list below.

**Domain adjustments**

| | Professional / fintech / education | Consumer / community |
|---|---|---|
| Fonts | Inter or IBM Plex Sans; mono for figures | Warmer sans, generous weight contrast |
| Radius / motion | 8–16 px, fast and crisp, no bounce | 12–20 px or pill, light spring on non-critical elements |
| Density | Compact; numbers visible without scrolling | Roomier; one decision per screen |
| Proof | Quantified claim, regulator or certification | Ratings with review counts, real photos |
| Tone | Precise, sentence case, numbers everywhere | Warm, verb-led, short |

---

## 12. Layout traps that fail silently

These do not throw in release builds. They produce a screen that is wrong and a developer who cannot reproduce it.

- **Unbounded cross-axis inside a scroll view.** A horizontal row stretching its children inside a vertical list gets an *infinite* height constraint: children are laid out off-screen while keeping their hit areas. Symptom: the page looks empty, overflows, and a tap on blank space triggers the first invisible element. Fix: measure with an intrinsic-height wrapper, or stop stretching.
- **A grid inside a list.** Grid widgets demand bounded height and refuse to live in a scroll view. Build rows manually; give an odd last item an empty cell, not a stretched one.
- **Lazy lists do not build what is off-screen.** Anything below the fold is absent from the tree — tests must scroll to it, and so must the user. If something matters, it does not belong at the bottom of a long list.
- **Two tap recognisers on one element.** A pressable wrapper around an inkwell puts both in the gesture arena; the inner one wins and the outer stays visually pressed. One gesture owner per element.
- **Text with no maximum.** Every label that can receive user or currency data declares its line limit and its overflow behaviour.
- **A themed fill under coloured text.** A search field placed on a coloured header sets its text to white, but the app-wide input theme still paints the field white: the text is typed, stored, submitted — and invisible. Any component that inverts its text must also switch off the inherited fill, border and hint colour. Symptom to recognise: *"it works but nothing appears."*
- **Components that inherit the wrong surface.** Move a tab bar under a dark app bar and its labels stay dark. Fix it in the theme, once, not in the four screens that happen to have tabs today — the fifth will be born unreadable.
- **A nullable column is a table rewrite.** Relaxing a constraint in SQLite recreates the table. A botched rewrite throws nothing: it returns an empty table, and the data is gone on phones that already had it — never on the developer's, who reinstalls. Write the migration test with rows in the old shape first.
- Write a layout test at the narrowest supported width, with the longest realistic string, and assert that no overflow is reported. Reproduce the bug in the test before fixing it — a test that never failed proves nothing.

---

## 13. Data & numbers on screen

- A dashboard answers "what should I do now?". Tiles that answer "what happened?" without implying an action belong in a report.
- **Two to four figures per screen.** Beyond four, none of them stands out and the screen becomes wallpaper.
- Each figure states its period and its unit. "320k" alone is not a fact.
- **One measure, one colour.** A single series across several categories is one hue; the category names are already written beside it. A rainbow palette on one measure invents five meanings that do not exist.
- Sequential scales: one hue, light to dark. Diverging: two hues with a neutral midpoint. Never a rainbow, never a hue at the midpoint.
- Never a dual-axis chart. Two measures of different scale get two charts or an index to a common base.
- Colour follows the entity, never its rank. Filtering must not repaint the survivors.
- A chart with no axis is legitimate when the shape is the message; make the exact figure reachable in one tap.
- Empty days, empty categories and zero values are drawn, not skipped. Skipping an empty day turns a week into six days.
- Text on a chart wears text colours; the coloured mark beside it carries the identity.

---

## 14. Motion & micro-interactions

**Purpose test — apply to every animation.** It must answer *did my action work?*, *where did this come from?*, or *what can I do here?*. If it answers none, delete it. Motion is state, never decoration, on money, form and data screens. Animations never block input.

**Response-time thresholds**

| Delay | Required response |
|---|---|
| ≤ 100 ms | Visible state change. Feels instant. |
| 100 ms – 1 s | State change only, no loader. |
| 1 – 10 s | Loader plus text naming the step after 2 s. |
| > 10 s | Determinate progress, the option to leave and be notified, never a bare spinner. |

**Duration tokens** — `instant` 0–50 ms (colour swap, press-in) · `fast` 100–150 ms (hover, toggle, tab, icon) · `medium` 200–250 ms (tooltip, dropdown, accordion, toast) · `slow` 300–400 ms (modal, sheet, route, shared element).

- Exits run at 70–80 % of their entry. Nothing above 400 ms outside hero media.
- Larger element or longer distance = longer duration within the band. When unsure, go faster.

**Easing** — `standard` `cubic-bezier(0.2,0,0,1)` for A-to-B movement · `enter` `cubic-bezier(0,0,0,1)` for anything arriving · `exit` `cubic-bezier(0.3,0,1,1)` for anything leaving · `linear` for spinners and shimmer only · spring for gesture-driven motion.

Never linear for UI movement. No bounce on transactional, form or data screens.

**Interaction states**

| State | Rule |
|---|---|
| Default | Reads as interactive without hovering. |
| Hover (pointer only) | Background or elevation shift at `fast`; no layout movement. Wrap in `@media (hover: hover)`. |
| Focus-visible | 2 px ring, 2 px offset, ≥ 3:1, keyboard only, never removed. |
| Pressed | Immediate: scale 0.97–0.98 or darken 8–12 %. Confirms the tap before the network answers. |
| Selected | Distinct from hover — fill, check, weight — not colour alone. |
| Loading | Button keeps its width, label names the step, repeat taps disabled. |
| Disabled | Reduced contrast plus a stated reason. Prefer enabled-with-explanation. |
| Error / success | Icon + colour + text. |

**Feedback**
- Toggles, likes and ratings change on tap, before the server answers.
- Optimistic UI for low-risk reversible actions only. Never for payments, transfers, orders or anything irreversible.
- **Reversible destructive actions act immediately and offer Undo for ~5 s instead of a confirmation dialog.** The dialog asks before the user can see what they are losing, and asks every time, including the ninety-nine times the answer is yes.
- **Confirmation dialogs are reserved for what cannot be undone** — anything that notifies a third party, leaves the device, or removes something from other people's screens. Five seconds do not recall a sent message. Name the object and label the destructive button with its verb.
- Undo copy must be unambiguous: after "Session cancelled", the undo affordance is "Restore", not "Cancel".
- Haptics: a light tick on selection, success and error patterns on payment outcomes. Never on scroll or every tap.
- Changing totals animate briefly or flash-highlight so the change is seen.

**Loading**
- No indicator under 300 ms. Once shown, keep it 400–500 ms so it cannot blink.
- Lists and dashboards: skeletons matching the final layout block for block. A skeleton that does not match is worse than a spinner.
- Short actions of unknown shape: spinner inside the triggering button.
- Uploads and multi-step processing: determinate progress or a step list.
- Shimmer is low-contrast, 1.2–1.8 s linear, stops under reduced motion, container marked busy.
- Reserve space for everything that loads. Nothing shifts under a finger.

**Spatial continuity**
- Elements come from and return to where they were triggered. Sheets slide from their edge, menus grow from their trigger, modals fade and scale from 0.95.
- A card opening into a detail view expands from the card; back reverses it.
- Forward moves right-to-left, back reverses, same-level tabs cross-fade. Never mixed.
- Only the changing region animates; header, tab bar and totals stay still.
- List items animate in and out so additions and removals are seen. Stagger 20–40 ms for the first five items only.
- No scroll hijacking, no default parallax. Restore scroll position on back.

**Form micro-interactions**
- Validate on blur; once a field has an error, re-validate on every keystroke so it clears as soon as it is fixed.
- Errors appear in a reserved line that does not shift the layout.
- Show/hide on passwords; the label names the action to come ("Show"), not the current state.
- Masks format as the user types without moving the caret.

**Reduced motion**
- Replace movement with cross-fades or instant changes. Keep the feedback — states, toasts, progress, success — only the movement goes.
- Stop shimmer and anything auto-advancing. Offer an in-app setting for motion-heavy products.

**Performance**
- Animate `transform` and `opacity` only. Never `width`, `height`, `top`, `left`, `margin`.
- Target 60 fps on a throttled mid-range Android. Drop anything that misses.

```css
:root {
  --dur-instant: 50ms; --dur-fast: 120ms; --dur-medium: 220ms; --dur-slow: 340ms;
  --ease-standard: cubic-bezier(0.2, 0, 0, 1);
  --ease-enter: cubic-bezier(0, 0, 0, 1);
  --ease-exit: cubic-bezier(0.3, 0, 1, 1);
}
@media (prefers-reduced-motion: reduce) {
  :root { --dur-medium: 1ms; --dur-slow: 1ms; }
  *, *::before, *::after { animation-iteration-count: 1 !important; scroll-behavior: auto !important; }
}
```

---

## 15. Dark mode

- **A palette of compile-time constants cannot do dark mode.** If screens read `Colors.primary` directly, no amount of palette work will switch them — half the product renders black on black. Tokens must be resolved at runtime: CSS custom properties on the web, a theme extension or context on native. Decide this at step 1, not after sixty screens.
- Follow the system setting by default, with a manual override.
- Both themes' contrast is computed and tested, not inspected.
- No pure black background, no pure white text. Elevation in dark mode comes from lighter surfaces, not shadows.
- The brand accent is re-stepped for dark surfaces; the light-mode hue rarely survives.
- Theme switches cross-fade at `medium`, never flash.
- Fintech and productivity apps ship dark mode at launch. Outdoor-use products in high-sunlight markets should prioritise light-mode legibility first.

---

## 16. Platform baseline (2026)

Use these unless a supported target forbids them.

**Web**
- `light-dark()` and `color-mix()` for theming; OKLCH for palettes that need perceptually even steps.
- Container queries for components that must work in several widths; `:has()` instead of state classes on parents.
- `text-wrap: balance` on headings, `pretty` on body; `clamp()` for fluid type.
- Native `<dialog>` and the Popover API instead of hand-rolled overlays — focus trapping and dismissal come free.
- View Transitions API for card-to-detail continuity and cross-document navigation.
- `field-sizing: content` for inputs that grow; `scroll-driven animations` sparingly and never as the only signal.
- Core Web Vitals are design constraints: reserve space (CLS), keep the main thread free on tap (INP).

**Android**
- Edge-to-edge is mandatory from Android 15; headers must handle insets themselves rather than relying on a safe-area wrapper somewhere up the tree.
- Support predictive back: the back gesture previews the destination, so route transitions must be interruptible.
- Adaptive launcher icons with the artwork inside the safe zone; the legacy icon still ships for older devices.
- Material 3 expressive motion is available, but transactional screens stay on the restrained set.

**iOS**
- Respect Dynamic Type to the largest accessibility sizes; no fixed-height text rows.
- Bottom sheets with detents rather than full-screen modals for secondary tasks.

**AI features**
- Stream output; never a blank screen with a spinner while a model works.
- Name the step in progress ("Reading the syllabus…") and allow cancellation.
- State the cost before the action, next to the button, in the unit the user holds — credits, not tokens.
- Never present generated content as verified. Label it, and show the source where one exists.
- The model produces prose; **numbers come from queries**. A metrics module contains no model call.

---

## 17. Measure & test

**Tests that pass for the wrong reason**
- **A test that passes because the thing is absent is worse than no test.** `indexOf('age_step') < indexOf('level')` stays green forever once the step is deleted: `-1` is less than everything. Assert presence *and* order, or assert absence explicitly.
- **When a design decision is reversed, retarget the test, do not delete it.** "No search on this screen" was a proxy for the real rule — "this list never leaves the teacher's own subjects". Search came back; the rule did not change. The test now guards the rule.
- **Every change that opens something must be paired with a test that the rest stayed shut.** Making two routes public deserves an assertion that the role spaces, the full profiles and the private rooms are still closed.
- **Reproduce the defect in the test before fixing it.** A test that has never failed proves nothing about the bug it claims to cover.

**Measurement**
- Instrument before designing: page view, CTA click, form start, form submit, payment start, payment success, first meaningful action, Day-1/7/30 return.
- Test priority: headline → hero visual → primary CTA → form fields → proof → pricing structure. Colour, motion and below-fold copy last.
- One variable per test, ≥ 2 full weeks, one full business cycle, a pre-set sample size. Do not peek and stop early.
- Below ~1 000 conversions per variant, prefer usability tests (5 users per round) over A/B.
- App onboarding: measure completion of the first meaningful action in session 1 and Day-7 retention. Cut any screen whose removal does not lower them.
- Track rage taps, double submits and abandonment on loading screens.
- Re-audit contrast, touch targets, consent, performance and reduced motion on every release.

---

## Release checklist

**Data** — every figure maps to a real query · no invented metric · deltas only where a prior period exists · periods and units labelled.

**Layout** — 320 px with the longest realistic string, no overflow · no unbounded cross-axis in a scroll view · every user-data label has a line limit · nothing shifts on load or on error.

**Accessibility** — contrast computed in a test · touch targets ≥ 44 px asserted · every icon-only control named · focus-visible everywhere · status never colour alone · reduced motion tested with the OS setting on.

**States** — empty, loading, error and partial designed for every screen · skeletons match the final layout · no loader flashes under 300 ms.

**Actions** — one primary per view · primary action pinned on long forms · blocking reason and cost stated above the button · reversible destruction offers Undo · irreversible destruction confirms and names the object · destructive actions live with their object · every account can be logged out of.

**Entry** — the first screen carries the product's action, not a form · results are browsable without an account · the account is asked for at the first step that involves another person, with the reason stated · public screens expose only what their subject published · access rules live in one named, testable list, never inside a router closure.

**Tests** — no assertion that passes when its subject is missing · reversed decisions retarget their test rather than delete it · anything newly opened is paired with proof the rest stayed closed.

**System** — tokens defined once · no hard-coded values in screens · shared primitives restyled in place, not forked · unused dependencies removed · debug symbols stripped · only real device architectures shipped.

---

## Sources

WCAG 2.2 and EN 301 549 · Baymard Institute checkout and perceived-security research · Nielsen Norman Group on response times, animation duration and visibility of system status · Material Design 3 motion and adaptive-icon guidance · Apple Human Interface Guidelines · GSMA State of the Industry (mobile money) and West African aggregator documentation · CNIL, EDPB and FTC decisions on consent and negative option · Google Core Web Vitals · skeleton-screen studies (Mejtoft et al., Viget, LinkedIn) · plus corrections paid for in shipped work, which is what most of the "fails silently" and "before drawing anything" rules are.
