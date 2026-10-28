# Demo script (about 5 minutes)

Use fictional data only. Phone: iPhone, Cantonese voice installed (Settings > Accessibility > Spoken Content > Voices), volume up, Do Not Disturb on, Wi-Fi on.

## Before the demo
1. Install the build. Open **設定** and check text size (1.4 or larger) and that 試聽聲音 speaks Cantonese.
2. Add two fictional emergency contacts (e.g. 「阿女 (示範)」 and a number you control).
3. Tap **加入示範資料** so the weekly view is filled. Tap **清除示範資料** afterwards.
4. Print or carry: one packaged food with a barcode, one with a nutrition label, one real meal (or a photo of one).
5. Do a full dry run in airplane mode too: the chat must show its offline message, not crash.

## Story (Mr Choi, 72: diabetes, hypertension, knee problems)
| Min | Do | Say / point out |
|-----|----|-----------------|
| 0:00 | Open app. Home speaks the greeting. | Three big buttons. Voice on arrival. Nothing to type. |
| 0:30 | **食物 > 掃描條碼**, scan the packaged food. | Traffic light for sugar, sodium, fat. Carbs shown, not rated. Read-aloud. Saved on the phone only. |
| 1:15 | **食物 > 睇營養標籤**. | Works when no barcode match. HK 1+7 label. |
| 1:45 | **食物 > 影餐飯**. | App asks 「係咪呢樣?」 before using a guess; falls back to the dish list. (Needs the trained model, otherwise show the list.) |
| 2:30 | **心情**, tap 「有啲孤單」. | Gentle reply, tip, and a way to talk to someone. Emotional features are visually prominent. |
| 3:00 | **呼吸練習**. | Slow guided breathing, spoken. |
| 3:30 | **傾偈**, type or speak a normal question. Then ask a medication question. | Normal reply. Medication/diagnosis gets a fixed safe answer, never AI advice. |
| 4:00 | Say a distress phrase (see DistressDetector, fictional). | Message is NOT sent; call screen opens; hold-to-call prevents accidental calls. |
| 4:30 | **心情 > 今個星期**, then **分享今個星期**. | Food and mood side by side. Share sheet: user chooses the recipient; counts only, no product names. |
| 5:00 | Close. | No account, no nurse app, nothing sent anywhere except chat text (via our proxy). |

## If something fails
- No Cantonese voice: text is still on screen; read-aloud button silent. Say so.
- Camera denied: Settings > Privacy > Camera.
- Chat error: the offline/limit messages are by design; show the 求助 button instead.
- Do not improvise health advice during the demo; stay with the fixed wording.

## Claims to avoid
No clinical validation, no diagnosis, no monitoring by staff. The app does not notify anyone when an alert fires.
