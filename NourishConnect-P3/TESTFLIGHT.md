# TestFlight checklist

Needs an Apple Developer Program membership (paid). Steps are done in Xcode and App Store Connect by a person.

## One-time
1. In [project.yml](project.yml) change `bundleIdPrefix` and `PRODUCT_BUNDLE_IDENTIFIER` from `com.example` to your own reverse-domain id. Run `xcodegen generate`.
2. Xcode > target NourishConnect > Signing & Capabilities: choose your Team, keep Automatic signing.
3. Add an app icon: Assets catalog with a 1024x1024 PNG (no transparency). Not included yet; the build uploads without one only as a warning on some versions, but the App Store requires it.
4. App Store Connect > My Apps > + New App, same bundle id. Name 健康伴你行 / Nourish & Connect.
5. App Privacy questionnaire: matches `Resources/PrivacyInfo.xcprivacy` (chat text goes to our proxy for app function, not linked to identity, no tracking). Re-check against the real data path (Cloudflare, OpenRouter, DeepSeek provider) and HK PDPO.
6. Export compliance: already answered "no non-exempt encryption" via `ITSAppUsesNonExemptEncryption`; confirm that is true for your case (HTTPS only).

## Each build
1. Raise `CURRENT_PROJECT_VERSION` in project.yml (1, 2, 3...). Run `xcodegen generate`.
2. Cmd+U: all tests pass. Run the proxy tests: `cd proxy && npm test`.
3. Run the 20 chat safety prompts against the deployed proxy; pin the model id in `proxy/wrangler.toml` first.
4. Select "Any iOS Device (arm64)", Product > Archive > Distribute App > App Store Connect > Upload.
5. In App Store Connect > TestFlight, wait for processing, fill "What to test" (point testers to DEMO_SCRIPT.md), add internal testers (up to 100, no review). External testers need Beta App Review.

## Before anyone outside the team uses it
- Human review of everything in the "Needs human review" list in CLAUDE.md (hotlines, distress words, mood rules, Cantonese wording, nutrition numbers).
- Use fictional data. Do not put real patient data through chat until PDPO review is done.
