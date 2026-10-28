# Nourish & Connect: system design

Oct 28, 2026 · @kaiser

Nourish & Connect is a Cantonese, voice-first client backed by a small cloud service and a worker review console. Every food result is labelled an estimate, uncertain scans go to a human, and the system never recommends medication or predicts glucose.

## Requirements

The system has to make one food choice better and one day less lonely for a single 72-year-old user, with a human always able to step in. Everything below comes from the proposal; assumptions are marked.

**Functional**

1. Scan a packaged-food label or barcode, or photograph a meal, and return a lower / middle / higher sugar-carb rating plus a sodium flag.
2. For mixed Asian dishes, ask the user one clarifying question, then show an estimate.
3. Offer one practical swap per result, optionally from a community-curated list of nearby options.
4. Send any scan or question to a community worker or nurse, who can correct the food entry and reply.
5. Run a three-tap mood check with a Cantonese audio prompt, and a 2-5 minute guided breathing or grounding audio library.
6. Offer optional CBT-style reflection by voice memo, and a chatbot that listens and suggests wellbeing activities.
7. Escalate distress words to a one-touch call to a chosen contact, the community worker, or a crisis service.
8. Give staff a review console, plus a practice mode and staff-assisted setup for the user.

**Non-functional**

| Area | Target | Why |
| --- | --- | --- |
| Accessibility | One screen at a time, large type, high contrast, Cantonese audio on every screen | Poor eyesight, low digital confidence |
| Scan latency | Result in under 5 seconds on 4G (assumed) | A long wait reads as failure to a first-time user |
| Worker response | Flagged scans answered within 1 working day (assumed; to agree with the service) | Keeps the human review meaningful |
| Crisis path | Works with no AI call in the loop; rule-based first | Must not depend on a model being up or correct |
| Privacy | Minimal data, encrypted, role-based, deletable; mood journal private by default | Health and mental-health data |
| Availability | 99.5% for the app and console (assumed) | Pilot scale, not a hospital system |

**Constraints and assumptions**

- Pilot scale: one user, a few staff, then tens of users per community team.
- Hard limits from the proposal: no diabetes-medication or insulin advice, no glucose prediction, no diagnosis of depression.
- The user has a smartphone with a camera and data access (assumed from the proposal's app-based design).
- Prototype built with fake data before any real deployment.

## At a glance

&#91;embedded content: system architecture · 2 clients, gateway, 4 services, 3 shared parts\]

Both clients enter through one gateway that checks role and consent. The four services call the shared parts below; the Companion chat and Wellbeing services also report to the Safety service, which can raise an alert even when the AI adapters are down.

## Components

A modular monolith behind one API gateway is enough at pilot scale; the AI parts sit behind narrow interfaces so they can be swapped or switched off.

| Component | Owns | Must never |
| --- | --- | --- |
| Senior client app (mobile) | One-screen-at-a-time UI, Cantonese audio, camera and barcode capture, voice memo recording, practice mode, offline queue | Store raw photos longer than needed; show a number without the word "estimate" |
| API gateway and auth | Sessions, role checks (user, worker, nurse, admin), rate limits, audit log | Let a role read data outside its scope |
| Nutrition service | Barcode lookup, label OCR, meal estimate, traffic-light rating, sodium flag, one-swap rule | Output glucose, insulin or medication advice; hide low confidence |
| Food knowledge base | Packaged-food data, curated Hong Kong takeaway and canned-food entries, approved swaps | Publish a swap a nurse or dietitian has not approved |
| Vision / AI adapter | Calls a food-recognition model, returns candidates with confidence | Be the only source of truth; its output is a suggestion |
| Review service and worker console | Queue of flagged scans and questions, food-entry correction, replies, escalation log | Auto-close an item without a human action |
| Wellbeing service | Mood check, breathing audio catalogue, reflection templates, voice memos (private by default) | Diagnose or score depression; share memos without consent |
| Companion chat service | Empathic listening and activity suggestions with fixed boundary statements | Claim to be human, a clinician or a crisis service |
| Safety service | Rule-based distress detection first, model-assisted second; one-touch call routing; escalation protocol and audit | Depend on a model being available to raise an alert |
| Notification and telephony | Push, SMS and call hand-off to chosen contact, worker or crisis line | Send clinical detail by SMS |
| Data store and object store | Relational data, encrypted media, retention jobs | Keep data past its retention period |

## Core flows

&#91;embedded content: two core flows · scan review, distress escalation\]

The scan path never ends in advice from the model alone: low confidence, a mixed dish with no clear answer, or a user tap all lead to a worker. The distress path does not wait for a model or for staff to be online before the call screen appears.

## Data model

Relational storage (PostgreSQL) holds structured records; photos and audio go to encrypted object storage and are referenced by ID. Retention periods below are proposals to confirm with the service's data protection lead.

| Entity | Key fields | Readable by | Proposed retention |
| --- | --- | --- | --- |
| User | id, preferred name, language, text size, audio on/off, consent flags | User, assigned worker, nurse | Until deletion request |
| CareTeamLink | user id, staff id, role, active from/to | Admin, nurse | Life of the care relationship |
| EmergencyContact | user id, name, phone, priority, consent date | User, worker, nurse | Until changed |
| Scan | id, user id, source (barcode / label / meal), image ref, candidates, confidence, rating, sodium flag, clarifying answer, status | User, assigned staff | Image 30 days; record 12 months |
| ReviewItem | scan id or question text, assigned staff, status, correction, reply, timestamps | Assigned staff | 12 months |
| Swap | food category, suggestion text (Cantonese), approver, approved date, area | All staff, user (via results) | Until superseded |
| MoodCheck | user id, date, choice (okay / a bit lonely / not well), source (tap / voice) | User, assigned staff (with consent) | 12 months |
| WellbeingSession | user id, activity id, completed at | User, assigned staff | 12 months |
| Reflection | user id, voice memo ref, optional transcript, shared flag (default false) | User only until shared | Until user deletes |
| ChatMessage | user id, role, text, safety flags | User; staff only for flagged escalations | 30 days, flagged items per protocol |
| SafetyEvent | user id, trigger, route taken, who was notified, outcome, follow-up | Nurse, admin | Per protocol (to be set clinically) |
| AuditLog | actor, action, object, time | Admin | 24 months |

**Design rules**

- Estimates are stored with their confidence, so a later review can see why a result was shown.
- A worker's correction is stored as a separate field and never overwrites the model's original output.
- The user's consent flags gate every cross-role read; the console checks them on each request.

## API design

REST over HTTPS with JSON, versioned under `/v1`. The user app and the worker console use the same API with different roles. Responses that reach the user carry a Cantonese `display_text` and an `audio_url`, so the client never composes health wording itself.

| Endpoint | Caller | Purpose |
| --- | --- | --- |
| `POST /v1/scans` | User app | Upload barcode, label or meal photo; returns scan id and status |
| `GET /v1/scans/{id}` | User app, staff | Rating, sodium flag, "estimate" wording, one swap, confidence, clarifying question if any |
| `POST /v1/scans/{id}/answer` | User app | Answer the single clarifying question |
| `POST /v1/scans/{id}/review-request` | User app | Send to a worker (also set automatically when confidence is low) |
| `GET /v1/review-items?status=open` | Console | Queue, oldest first |
| `PATCH /v1/review-items/{id}` | Console | Correct food entry, add reply, close |
| `POST /v1/mood-checks` | User app | Record a tap or voice choice |
| `GET /v1/wellbeing/activities` | User app | Breathing and grounding audio list |
| `POST /v1/wellbeing/sessions` | User app | Log completion only |
| `POST /v1/reflections` | User app | Upload a voice memo; private by default |
| `PATCH /v1/reflections/{id}/share` | User app | Explicit share with a named staff member |
| `POST /v1/chat/messages` | User app | Send a message; reply carries boundary text and any safety action |
| `POST /v1/safety/call` | User app | One-touch call; logs a SafetyEvent and returns the number to dial |
| `GET /v1/safety/events` | Console (nurse) | Review and close escalation events |
| `GET/PATCH /v1/users/{id}/consents` | User app, nurse | View and change consent flags |
| `DELETE /v1/users/{id}/data` | Admin, on user request | Delete or export the user's data |

**Contract details**

- Scan results use a fixed shape: `rating` (`lower` / `middle` / `higher`), `sodium` (`ok` / `high`), `confidence` (0-1), `is_estimate: true`, `swap`, `needs_review`. There is no field for glucose or dose, so the API cannot express either.
- Scans below a confidence threshold (start at 0.6, tune in testing) return `needs_review: true` and enter the worker queue automatically.
- Uploads accept an idempotency key, so a retry on weak signal does not create duplicate scans.
- Errors always include a short Cantonese message and a "call my worker" action.

## Safety and privacy

Safety is built into the structure of the system, so that no single model error can produce a harmful instruction.

**Guardrails**

- **Output allow-list.** The nutrition and chat services can only return fields and templates defined in advance. Free text from a model passes through a filter that blocks medication, dose, insulin, glucose-prediction and diagnosis language, and falls back to a fixed safe reply.
- **Honest uncertainty.** Every result shows "this is an estimate". Low confidence or an unrecognised dish skips the rating and goes to a worker.
- **Chatbot identity.** The first message and a persistent button state that it is not a person, doctor or crisis service. Fixed boundary text is not model-generated.
- **Medication.** No feature reads, sets or reminds about diabetes medication doses. Questions on this topic return a fixed reply and a review request to the nurse.

**Distress escalation**

1. A rule layer matches Cantonese and English distress phrases, a "not well" mood choice repeated over days, and a tap on the help button. A model-assisted classifier adds recall but never removes a rule-based alert.
2. The app shows one large "Call now" screen: a chosen contact first, then the community worker, then the local emergency or crisis number, per the user's saved order.
3. The Safety service logs a SafetyEvent and notifies the nurse. Suspected suicidal thoughts, severe distress or a medical emergency follow the agreed human protocol, which the clinical team must define before pilot.
4. A confirmation step prevents accidental calls (for example, hold for two seconds), tested with the user in practice mode.

**Privacy and access**

| Control | Design |
| --- | --- |
| Data minimisation | Store the scan result, not the household photo, beyond the short image retention; no location tracking |
| Encryption | TLS in transit; encrypted database and object storage; keys in a managed key service |
| Roles | User, community worker, nurse, admin; least privilege; reads checked against consent flags |
| Mood journal | Private by default; staff see it only after the user shares it |
| Deletion | User or guardian can request deletion and export; retention jobs run daily |
| Consent | Explained by voice in Cantonese, repeated in practice mode, recorded with date; staff confirm understanding given the user's memory decline |
| Audit | Every staff read of a user's record is logged and reviewable |
| Third-party AI | Only the minimum input is sent; contract bars training on the data; region and data-processing terms checked against Hong Kong's Personal Data (Privacy) Ordinance |

## Scale and reliability

Load is small, so a single region with one app service, one database and one worker queue is enough through the first thousand users; the real constraints are model cost, human review capacity and failure behaviour. Figures below are assumptions for planning.

| Stage | Users | Scans per day (3 each) | Review items per day (20% flagged) | Staff load |
| --- | --- | --- | --- | --- |
| Prototype | 1 | 3 | under 1 | One worker |
| Pilot | 50 | 150 | 30 | A few workers, one nurse |
| Regional rollout | 1,000 | 3,000 | 600 | A review team; needs triage by risk |

The system limit at every stage is staff review time, not servers. Flagged items need ranking by urgency (high-sodium plus hypertension note, repeated uncertain meals, a "not well" mood) so nurses see the right ones first.

**Failure behaviour**

- **Vision model down or slow:** fall back to barcode and packaged-food database lookup; for meals, show "I can't tell, I've asked your worker" and queue for review.
- **No signal:** the app stores the photo and mood tap locally and uploads later; the help call uses the phone dialler directly.
- **Console unavailable:** the app still records requests; the nurse is notified by SMS of any open safety event.
- **Model returns unsafe text:** the output filter replaces it with a fixed safe reply and logs the event.

**Monitoring**

- Scan confidence distribution and share sent to review, to catch model drift.
- Review queue age against the one-working-day target, with an alert when the oldest open item passes 80% of it.
- Safety rule hit rate and every escalation outcome, reviewed weekly by the nurse.
- Usability signals: failed taps, abandoned screens and calls requested, per the proposal's evaluation table.

## Trade-offs and what to revisit

Each choice below favours safety and simplicity over capability, and each has a trigger for revisiting it.

| Decision | Chosen | Alternative | Cost of the choice | Revisit when |
| --- | --- | --- | --- | --- |
| Architecture | Modular monolith | Microservices | Less independent scaling | Teams or load outgrow one deployable |
| Food estimate | Barcode and label first, meal photo as a conversation starter | Full photo-to-carb estimation | Fewer meals rated automatically | Local validation shows acceptable accuracy on Hong Kong dishes |
| Human review | Low confidence goes to a worker | Fully automated advice | Staff time; slower answers | Review volume exceeds team capacity |
| Distress detection | Rules first, model second | Model-only | More false alerts | Clinical review of false and missed alerts |
| Chatbot | Fixed boundary text, filtered output | Open-ended generative companion | Less natural conversation | Evidence the bot supports contact with people |
| Emergency call | Hold-to-call with confirmation | Single tap | Slower in a true emergency | Practice-mode testing shows accidental or missed calls |
| Mood data | Private by default, shared by consent | Always visible to staff | Staff may miss a worsening trend | Agreed signals, shown with consent, in a dashboard |
| Model hosting | Third-party API with minimum data | On-device or self-hosted | Data leaves the device; vendor dependence | Data-protection review or cost requires it |
| Platform | One native app | Web app or SMS/voice front end | App-store and install friction | Users struggle to install or use the app |

# iOS build plan (Swift)

The demo is a standalone iPhone app with two features, nutrition and emotional support, that stores everything on the phone and calls a server only for DeepSeek text replies. The sections above describe the fuller system; this plan builds the slice the team agreed on and leaves the rest for later.

## Scope decisions

| Topic | Decision | Effect on the design above |
| --- | --- | --- |
| Platform | iOS only, Swift and SwiftUI | Android and web clients are out of scope |
| Features | Nutrition and emotional support only | Practice mode and the "point 7" idea are dropped; no separate modules beyond these two |
| Nurse and worker side | No second app or console in the demo; scans, moods and alerts are saved on the phone only | Review service, worker console, review-request endpoints and SafetyEvent notifications are deferred |
| Emotional alert | Kept as the standout feature: a mood check and distress words trigger a one-touch call or message to a chosen contact | Runs on the phone, with no server in the alert path |
| Language model | DeepSeek for text only (label explanations, chat, healthy-living tips) | It cannot read images, so image work is done by Apple's on-device frameworks |
| Scan options | Two: barcode / nutrition label, and meal | Both stay; the meal scan is limited to a fixed dish list for the demo (below) |

**What sets it apart from other food-scanning apps.** Barcode scanners already exist, so the pitch rests on three things they lack: a Cantonese, voice-first explanation of the label in plain words for an older adult; a mood check that sits beside the food diary so food and mood can be seen together; and an alert that reaches a trusted person when the mood check or chat shows distress. Healthy-living tips come from these two sources, not from a separate feature.

**Nursing role without a nurse app.** Without a console the nursing value moves into the content and the hand-off: a nurse or dietitian signs off the swap list, the traffic-light thresholds, the chat boundary wording and the distress protocol, and the app can produce a one-page weekly summary (meals, moods, alerts) that the user or a worker shows at the bi-weekly visit through the iOS share sheet. The summary is a stretch item and needs no new window.

## How the open questions are resolved

| Question | Resolution |
| --- | --- |
| Which OS? | iOS 17 or later on iPhone, written in Swift with SwiftUI. iOS 17 is chosen so SwiftData and the camera scanner frameworks are available; confirm the test phone runs it. |
| Where does barcode and nutrition data come from? | Open Food Facts (free, open database, queried by barcode) as the first lookup. If the product is missing, the app photographs the nutrition label and reads it on the phone with Apple's text recognition, then parses it. Hong Kong prepackaged food carries a standard "1+7" label (energy plus protein, carbohydrates, total fat, saturated fat, trans fat, sugars, sodium), which gives a fixed set of fields to parse. Check Open Food Facts' licence terms and its Hong Kong coverage; the Centre for Food Safety's nutrient database is a second source to review. |
| How does the app "recognise what the label says"? | On the phone: barcode scan and label text recognition with Apple's VisionKit and Vision frameworks. The numbers are parsed into fixed fields and compared with traffic-light thresholds agreed with a nurse or dietitian. DeepSeek then receives only those numbers as text and returns a short Cantonese explanation, which the phone reads aloud. |
| Where does DeepSeek fit, given it reads text only? | Three text jobs: explain a label in plain Cantonese, power the companion chat, and write healthy-living tips from the day's meals and moods. It never sees a photo. Barcode, label and meal recognition stay on the phone. |
| What if there is no label (mixed Asian dishes)? | Use the meal scan, with limits stated openly. A small image classifier trained with Apple's Create ML runs on the phone for a fixed list of common Hong Kong dishes (target 20 to 30 for the demo). Each dish carries a nutrition range from a published reference, so a result is a range and a traffic light, never a precise figure. The app asks "Is this wonton noodles?" before showing anything. Below a confidence threshold, or for a dish outside the list, it says "I'm not sure" and offers a pick-from-list screen instead of guessing. |
| Won't the meal scan hallucinate beyond its training data? | Yes, which is why it does not generate answers: it only picks from a closed list and can decline. A classifier trained on a few hundred photos per dish will not cover real life, so the demo is built around a known set. Growing the list means more photos and more reference data per dish, and that cost is real; the plan treats it as a post-demo budget line, not something the demo claims to solve. |
| Where does the training data come from? | The team photographs or sources licensed photos for each listed dish (aim for roughly 100 to 200 per dish, varied lighting and plates), plus a "not food / unknown" class. Public food datasets help little with local dishes, and any photos from users are added only with consent. |
| Which model, and where does it run? | The meal classifier runs on the phone (no server cost). DeepSeek runs on DeepSeek's servers, called through a small serverless proxy that holds the API key so it is never inside the app. No language model runs on the phone. |
| What does the server cost? | Two items: the DeepSeek API, billed per token, and the proxy, which fits a serverless free tier at demo traffic. Both should be small at demo scale; confirm the current DeepSeek rate card and set a monthly spending cap. The cost grows with users, so cap each user's daily messages. |
| Data privacy with DeepSeek | Send only numbers and short, name-free text. Treat the call as a transfer to an external provider: confirm where DeepSeek processes data and review it against Hong Kong's Personal Data (Privacy) Ordinance before any real user data is used. The demo uses fictional data. |
| Send to the nurse | Removed for the demo. Records are saved on the phone only; a weekly summary through the share sheet is the stretch item. |
| Practice mode and adding purchases to training data | Dropped. Nothing the user scans is used to train a model. |

## App structure in Swift

One Xcode project, SwiftUI for every screen, and a feature-per-folder layout so two people can work without clashing. Building and testing needs a Mac with Xcode and a real iPhone for the camera and speech; this cloud workspace can draft the Swift source but cannot compile or run it.

| Module | What it does | Apple framework or service |
| --- | --- | --- |
| App shell and navigation | Big-button home screen with Food, Mood and Help; one screen at a time; text size and contrast settings | SwiftUI, Dynamic Type |
| Barcode and label scanning | Live barcode scan; photo of the nutrition label; text recognition | VisionKit `DataScannerViewController`, Vision `VNRecognizeTextRequest` |
| Nutrition lookup and parsing | Open Food Facts call by barcode; parse the "1+7" label text into fields; traffic-light rating | `URLSession`, own parser, a rules file reviewed by the nurse |
| Meal scan | Camera photo, classify against the dish list, confirmation question, pick-from-list fallback | Core ML model from Create ML, Vision |
| Cantonese voice | Read results and prompts aloud; optional voice reply for mood and chat | `AVSpeechSynthesizer` with a Cantonese voice, Speech framework (verify Cantonese recognition on the test phone) |
| Mood check | Three large buttons (okay, a bit lonely, not well), logged with the date | SwiftUI, SwiftData |
| Breathing and grounding audio | Short guided audio with a visual cue | `AVAudioPlayer`, bundled audio files |
| Companion chat | Text and voice chat with fixed boundary wording; healthy-living tips | DeepSeek via the proxy, `URLSession` |
| Distress rules and alert | On-phone word and pattern matching runs before any server call; shows a call screen; places a call or pre-fills a message to the chosen contact | `tel:` link, `MessageUI`, SwiftUI |
| Local storage | Meals, moods, alerts, settings and contacts, all on the phone | SwiftData (encrypted by iOS file protection) |
| Reminders | Gentle daily mood and meal prompts | `UserNotifications` |
| Weekly summary (stretch) | One-page summary for a nurse visit | `ShareLink`, SwiftUI-to-PDF rendering |
| Proxy (server side) | Holds the DeepSeek key, limits requests per user, strips anything but allowed fields | Serverless function, outside the app |

**Project layout**

```
NourishConnect/
  App/            entry point, navigation, settings
  Features/
    Scan/         barcode, label OCR, meal classifier, results screen
    Mood/         mood check, breathing audio
    Chat/         companion chat, distress rules, call screen
  Services/       OpenFoodFacts, DeepSeekClient, Speech, Notifications
  Models/         SwiftData types: Meal, MoodEntry, AlertEvent, Contact
  Resources/      dish list, nutrition rules, audio, Cantonese strings
  Tests/          parser, rating rules, distress rules
```

**Design rules for the code**

- Every health wording shown to the user comes from a reviewed string file or a template, not free model text.
- The distress rules and the call screen import no networking code, so they work offline.
- DeepSeek output passes a filter that blocks medication, dose, glucose-prediction and diagnosis language; a blocked reply is replaced with a fixed safe message.
- The API key is never in the app bundle.

## Roadmap

&#91;embedded content: build roadmap · 6 phases, 6 gates\]

The meal scan comes last because it carries the most technical risk. If it slips, the demo still shows label scanning, the mood check, the chat and the alert.

## Phases, tasks and exit checks

The order puts the emotional features ahead of the meal scan, because they are what sets the app apart and carry less technical risk. Photo collection for the meal scan starts in phase 0 so it does not block phase 4. No dates are given because the demo deadline is not in this document; map the phases onto the weeks you have.

| Phase | Tasks | Exit check |
| --- | --- | --- |
| 0. Setup and decisions | Install Xcode on a Mac; create the project and a shared repository; get a test iPhone on iOS 17 or later; open a DeepSeek account with a spending cap; choose the dish list (20 to 30 dishes) and start photo collection; ask a nurse or dietitian to review the traffic-light thresholds and chat wording | App builds and runs on the phone; dish list and thresholds agreed in writing |
| 1. Foundations | Home screen with three large buttons; text size and contrast settings; SwiftData models; Cantonese strings file; text-to-speech on every screen; local storage of settings and contacts | A first-time tester can reach Food, Mood and Help with voice on |
| 2. Barcode and label nutrition | Live barcode scan; Open Food Facts lookup; label photo and text recognition; "1+7" parser with unit tests; traffic-light rules; results screen with spoken Cantonese explanation (template first, DeepSeek wording after the proxy exists) | Ten real Hong Kong products give correct fields, or a clear "couldn't read it" message |
| 3. Mood, chat and alert | Three-tap mood check; breathing audio; on-phone distress rules; call screen with confirmation hold; message and call to the chosen contact; proxy and DeepSeek client; companion chat with boundary text and output filter; healthy-living tips from the day's meals and moods; mood and meals side by side in a simple weekly view | A scripted "not well" mood and a distress phrase both reach the call screen with the network off; chat never gives medication or diagnosis advice in 20 test prompts |
| 4. Meal scan | Train the Core ML classifier in Create ML; confirmation question; confidence threshold; pick-from-list fallback; nutrition ranges per dish from the reference | Held-out photos of listed dishes meet the accuracy the team sets (suggest at least 85% top-1 on the demo list); an unlisted dish returns "I'm not sure" |
| 5. Polish and demo | Test with an older adult or proxy tester; fix text size, touch targets and speech speed; write a demo script on fictional data; optional weekly summary via the share sheet; install through TestFlight (needs a paid Apple developer account) or directly from Xcode | One full scripted run of food, mood and alert with no stalls; a fallback screen recording ready |

## Risks to the build

| Risk | Impact | Response |
| --- | --- | --- |
| Meal scan misidentifies a dish | Wrong nutrition guidance | Closed dish list, confirmation question, "I'm not sure" state, ranges instead of numbers |
| Product missing from Open Food Facts or label unreadable | No result at the demo | Label photo fallback; keep a small bundled list of demo products |
| Cantonese speech recognition or voice quality is poor on the phone | Voice features fail | Test early in phase 1; use buttons first and voice as an extra |
| DeepSeek cannot read images and cost or availability changes | Features that need it stop | Keep label and meal work on the phone; use template wording as a fallback; set a spending cap |
| Distress rules miss or over-trigger | Missed alert or alarm fatigue | Rules reviewed by a nurse; test with scripted phrases; log every trigger |
| Data leaves the phone to an external provider | Privacy exposure | Send numbers and name-free text only; fictional data in the demo; review before real users |
| No Mac or Apple developer account | Cannot build or install | Settle in phase 0; a Mac and a cable are enough for the demo |

**Next step.** If you want, I can draft the Swift source for phases 1 to 3 (project skeleton, label parser with tests, mood and alert screens, DeepSeek client and proxy), which you would then build and test in Xcode on a Mac.
