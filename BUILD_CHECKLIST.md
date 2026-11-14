# First-build checklist (Mac + Xcode)

This project was written on a Linux machine with no Xcode, so it has
**not been compiled**. Work through these steps in order on a Mac.

## 0. What you need

- A Mac with Xcode 16 or newer installed (from the App Store).
- An iPhone running iOS 18+ (tested target: iPhone 14 Pro).
- A free Apple ID signed in to Xcode (Xcode > Settings > Accounts).
- A Gemini API key from https://aistudio.google.com (free tier, no card).
  Keep it ready to paste into the app's Settings later — never put it
  in source code.

## 1. Open the project

1. Copy the `ai-reply-keyboard` folder to your Mac.
2. Double-click `ReplyKeyboard.xcodeproj`.
3. If Xcode says the project is damaged or cannot be opened, the
   hand-written `project.pbxproj` is the problem. Do not hand-edit it
   blindly — see "If the project file errors" below.

## 2. Signing (both targets)

1. Select the **ReplyKeyboard** project in the navigator, then the
   **ReplyKeyboard** app target > **Signing & Capabilities**.
2. Tick **Automatically manage signing** and pick your Team
   (your Apple ID / personal team is fine for your own phone).
3. Repeat for the **Keyboard** extension target.
4. The project ships with an empty Development Team — Xcode will fill
   it in when you pick a team. The bundle IDs are placeholders:
   `com.akinsserver.replykeyboard` and
   `com.akinsserver.replykeyboard.keyboard`. Change the team part if
   Xcode complains the bundle ID is taken (unlikely for a personal
   team, but the extension ID must end with the app ID + `.keyboard`).

## 3. App Group

1. In the Apple Developer portal (or in Xcode under Signing &
   Capabilities > **+ Capability > App Groups**), register the group
   `group.com.akinsserver.replykeyboard`.
2. Enable the App Groups capability for **both** targets and tick the
   group in both. The entitlements files already list the group;
   Xcode should pick it up once it exists on your team.
3. If the group cannot be created on a free personal team, the app
   will still build, but settings and the API key will not sync
   between the app and the keyboard (they would fall back to standard
   UserDefaults). A paid Developer Program membership removes this
   friction.

## 4. Build and run

1. Select the **ReplyKeyboard** scheme and your iPhone as the run
   destination.
2. Product > Build (Cmd-B). Fix any errors top-down (see below).
3. Product > Run (Cmd-R) to install the container app on your phone.
4. On the phone: **Settings > General > VPN & Device Management**
   (or Profiles) — trust the developer certificate if asked.
5. Enable the keyboard: **Settings > General > Keyboard > Keyboards >
   Add New Keyboard > Reply Keyboard**, then turn on
   **Allow Full Access**.
6. In the Reply Keyboard app: allow Photos, paste your Gemini API
   key in Settings, tap **Test key**, then **Test with a Screenshot**.

## 5. Test the keyboard flow

1. Open any chat app, take a screenshot of a chat.
2. Tap the text field, tap the globe key, switch to Reply Keyboard.
3. Tap **Screenshot**. Three suggestions should appear. Tap one —
   it inserts at the cursor. Press send yourself.
4. If suggestions do not appear, read the status line in the keyboard:
   it names the problem (no Full Access, no Photos permission, no
   screenshot, bad key, no network).

## If the project file errors

- **"Project cannot be opened / malformed"**: run
  `plutil -lint ReplyKeyboard.xcodeproj/project.pbxproj` in Terminal.
  If it reports a syntax error near a line, the hand-written IDs or
  braces are off. The safest repair is to create a fresh project in
  Xcode (App + Custom Keyboard Extension targets, same bundle IDs
  and file names) and drag the existing `ReplyKeyboard/`,
  `Keyboard/` and `Shared/` folders into it, instead of
  debugging the pbxproj by hand.
- **"No such module ..." for a Shared file**: the `Shared/` files are
  compiled directly into both targets — there is no Swift package
  anymore (it caused "Missing package product" errors and was
  removed in the Nov 13 rebuild). Check the file is listed in the
  target's Build Phases > Compile Sources. If a Shared file is
  missing there, drag it from the `Shared/` folder into the target.
- **"Multiple commands produce … Keyboard.appex"** or an embed error:
  check the app target's Build Phases has exactly one
  "Embed App Extensions" phase containing Keyboard.appex.
- **Signing / provisioning errors**: pick a different team, or set
  the app target to your personal team and let Xcode fix the extension
  bundle ID prefix to match.
- **"FoundationModels is unavailable" / API errors in
  FoundationModelsClient.swift**: check the file against the iOS 26
  SDK in your Xcode version. The code is availability-gated, but the
  `LanguageModelSession` API may have changed. If it will not compile,
  comment out the Foundation Models provider option in Settings and
  the `.foundationModels` / `.auto` branches in SuggestionEngine, and
  use Gemini only — the rest of the app does not depend on it.
- **Keyboard does not appear in the keyboard list**: the extension
  target must have built and been embedded. Build the **app** scheme
  (not the extension scheme alone), then check Settings > General >
  Keyboard > Keyboards > Add New Keyboard. Restarting the phone
  sometimes helps after the first install.
- **"Full Access" prompt never appears / AI says no network**: make
  sure RequestsOpenAccess is YES in `Keyboard/Info.plist` and that
  Allow Full Access is actually on for this keyboard in Settings.
  Toggling the keyboard off and on again re-triggers the prompt.
