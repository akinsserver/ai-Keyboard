# Reply Keyboard

A personal iOS AI reply keyboard. Take a screenshot of a chat, switch to
this keyboard with the globe key, tap **Screenshot**, and it reads the
latest screenshot, generates 3 reply suggestions, and inserts the one you
tap at the cursor. You send the message yourself.

This is original starter code, built from the described UX flow only.
It is **not yet build-verified** — it was written on a Linux machine with
no Xcode or Swift available, so it has not been compiled. Open it in
Xcode on a Mac and follow `BUILD_CHECKLIST.md` for the first build.

## How it works

1. Take a screenshot of a chat (in any app).
2. Tap the text field, then the globe key (bottom left) to switch to
   Reply Keyboard.
3. Tap **Screenshot** in the keyboard top bar.
4. The keyboard reads the latest screenshot from Photos and extracts
   the chat text on-device with Vision OCR.
5. It sends **only the extracted chat text** (never the image) to the
   AI and shows 3 reply suggestions.
6. Tap a suggestion. It is inserted at the cursor with
   `textDocumentProxy.insertText`. You press send yourself.

Tones: **Playful tease**, **Proper English**, **Uppercase**, and a
free-text **Custom approach** (for example: "be smooth and confident,
ask about her trip"). Reply length (min/max characters) is configurable
in Settings.

## AI provider

The main provider is the **Gemini cloud API** (default model
`gemini-2.5-flash`, configurable in Settings).

- Get a free API key at [Google AI Studio](https://aistudio.google.com)
  — free tier, no card required.
- A Gemini Pro subscription is **not** an API key. You still need a key
  from AI Studio.
- Apple Foundation Models (on-device Apple Intelligence) is an
  optional fallback for newer phones only: it needs iOS 26+ and
  iPhone 15 Pro or newer. It is availability-gated in code and is
  **not** available on an iPhone 14 Pro. The provider picker has an
  Auto option that tries on-device first and falls back to Gemini.

## Setup (on your iPhone)

1. Build and install the app from Xcode (see below).
2. **Settings > General > Keyboard > Keyboards > Add New Keyboard >
   Reply Keyboard.**
3. Tap Reply Keyboard in that list and turn on **Allow Full Access**.
   The keyboard needs this for network access and Photos. Without it,
   it still works as a plain QWERTY keyboard (App Store Review
   Guideline 4.4.1), but AI suggestions are off and the keyboard
   explains that on screen.
4. In the Reply Keyboard app, allow Photos access and paste your
   Gemini API key in Settings. Use **Test key** to check it.
5. Test first inside the app: **Test with a Screenshot** runs the same
   OCR + generation as the keyboard, without switching keyboards.

## Privacy

- No keystroke logging. No analytics.
- Screenshots are read on-device with Vision OCR.
- Only the extracted chat text is sent to the AI, and only when you
  tap Generate / Screenshot.
- The Gemini API key is stored in the App Group shared UserDefaults in
  v1. That is a deliberate personal-use tradeoff so the keyboard
  extension can read it without a login flow. **TODO: move the key to
  the shared Keychain** (`kSecAttrAccessGroup` with the App Group) and
  delete it from UserDefaults before sharing this app with anyone else.

## Build on a Mac

- Xcode 16+, iOS 18.0 deployment target, Swift 5.
- Open `ReplyKeyboard.xcodeproj` in Xcode.
- Set your own Team in Signing & Capabilities for both targets
  (the project ships with an empty Development Team).
- Register the App Group `group.com.akinsserver.replykeyboard` in the
  Apple Developer portal and enable it for both targets (the
  entitlements files already list it).
- Free provisioning (personal team) works to install on your own
  iPhone. Distributing via TestFlight or the App Store needs the paid
  Apple Developer Program ($99/year).
- See `BUILD_CHECKLIST.md` for the exact first-build steps.

## Project layout

```
ReplyKeyboard/            Container app (SwiftUI)
  App.swift               @main entry point
  ContentView.swift       Setup checklist + status
  SettingsView.swift      Tone, custom approach, length, provider, API key
  ScreenshotTestView.swift  Test OCR + generation inside the app
  Info.plist
  ReplyKeyboard.entitlements   App Group
  Assets.xcassets         App icon placeholder (empty set — add a 1024px icon)
Keyboard/                 Custom keyboard extension (UIKit + SwiftUI)
  KeyboardViewController.swift  UIInputViewController, hosts the SwiftUI view
  KeyboardView.swift      QWERTY layout, tone chips, Screenshot, suggestions
  Info.plist              NSExtension keyboard-service, RequestsOpenAccess YES
  Keyboard.entitlements   App Group
Shared/                   Shared Swift files, compiled into BOTH targets
                          (no Swift package — the package caused
                          "Missing package product" build errors)
  Tone.swift              Tone enum + presets
  SettingsStore.swift     App Group UserDefaults (tone, approach, lengths, provider, key)
  ScreenshotService.swift Latest screenshot (PHAsset) + Vision OCR
  SuggestionEngine.swift  Prompt builder + suggestion parser
  GeminiClient.swift      Gemini generateContent REST client
  FoundationModelsClient.swift  iOS 26-gated on-device client
```

## Known limits

- **Not build-verified.** This code has not been compiled. Expect
  small Xcode project-file or API fixes on the first build — see
  `BUILD_CHECKLIST.md`.
- Keyboard extensions are sandboxed with no network by default.
  Network, Photos, and shared-container writes all need
  `RequestsOpenAccess = YES` **and** the user turning on Allow Full
  Access. `hasFullAccess` is checked at runtime.
- The keyboard cannot read the screen directly. It only sees the
  latest screenshot in Photos, so you must take a screenshot first.
- The keyboard cannot press Send for you. Tapping a suggestion only
  inserts the text; you send it.
- Gemini needs network. If you are offline, or the key is wrong
  (401) or rate-limited (429), the keyboard shows the error and keeps
  typing working.
- OCR quality depends on the screenshot: small or blurry chat text
  may be misread. The container app's test screen shows the exact
  transcript so you can check it.
- The App Icon asset catalog is an empty placeholder. Add a 1024×1024
  icon in Xcode before shipping.
- The Gemini API key lives in shared UserDefaults in v1 (see Privacy
  above). Move it to the shared Keychain before sharing the app.
- Foundation Models is gated to iOS 26+ in code, but the exact
  `LanguageModelSession` API surface should be re-checked against the
  Xcode 16 / iOS 26 SDK on the first build.
