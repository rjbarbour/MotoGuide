# X-COM2 document principles

Date: 2026-08-05
Status: Working standard for the X-COM2 setup guide and iPhone cheat sheet.

## Setup and stationary-test guide

- Treat the guide as a one-time how-to procedure for a paired iPhone and an installed headset.
- Keep physical installation, app-selection advice, full pairing instructions and road-test instructions out of the main procedure.
- Explain the X-COM2 control structure only where it helps the reader choose the correct action: direct buttons, X-COM2 voice command mode, Siri and the configuration menu.
- Name the active interface in every instruction: **X-COM2 buttons**, **X-COM2 voice**, **Sena app**, **iOS**, **ChatGPT**, **Shortcuts** or **RideHorizon**.
- Separate configuration, phone-only checks and helmet checks. Do not mix the test environments.
- Use numbered steps for sequences. Put the expected result immediately after the action that produces it.
- Use one term for each control and gesture. Write **Centre**, **(+)**, **(-)** and **Centre & (-)** throughout.
- State whether an action is a tap or a hold. State the hold duration.
- Prefer short imperative sentences. Keep conditions before actions. Do not hide alternatives inside one long step.
- Treat ChatGPT Dictation, iOS keyboard Dictation, Siri, Apple Intelligence's ChatGPT extension and ChatGPT Voice as different functions.
- Include only shortcuts that solve a demonstrated setup or feedback-capture problem. Test each shortcut unlocked, locked and through the headset before relying on it.
- Record limitations as test results, not promises about behaviour that depends on iOS, app permissions or lock state.

## iPhone cheat sheet

- Treat the PDF as an operational reference for use on an iPhone, not as a setup tutorial.
- Put frequent actions first, extended controls second, and pairing/reset recovery last.
- Keep one purpose per page so horizontal swiping is predictable.
- Use a portrait page with the iPhone 17 Pro Max display ratio, two columns, narrow margins and a body size of at least 12.4 pt.
- Use compact rows and short lists. Avoid large cards, decorative whitespace and introductory prose.
- Label the controlling system before every group of actions: **Siri**, **X-COM2 voice**, **X-COM2 buttons** or **iPhone**.
- Explain each activation method by the outcome it produces. Do not use an unexplained “mental model” heading.
- Do not mix setup, app-selection advice, training claims, physical fitting, general RideHorizon test instructions or iOS Shortcut construction into the PDF.
- Include only the minimum fallback needed away from home: reconnect, pair a replacement phone, pair another headset, fault reset and factory reset.
- Keep chains visually countable. Use numbered steps for pairing and resetting; never embed a long procedure in prose.
- Preserve the manual's exact timing and command wording, but use **&** rather than **+** between simultaneous button presses.
- Do not use generic cautions or rationale. Include a warning only when it changes the next action or prevents loss of settings.
- Retain source-section references and a version number without competing with the operational content.

## Appendix: reference facts discussed during drafting

These facts are retained for document maintenance. They are not a required section of either user-facing document.

- **Standby** means that X-COM2 is on without an active phone call, intercom, music or FM-radio function.
- In standby, **“Hello Sena”** starts X-COM2's internal fixed-command voice mode. It does not start Siri or the configuration menu.
- During music, FM radio or intercom, start X-COM2 voice mode with **Centre & (-)**.
- To start Siri from X-COM2 standby, hold **Centre** for 3 seconds. X-COM2's internal voice mode is not a route to Siri.
- For a simple music stop, hold **Centre** for 1 second to pause. **Centre & (-)** followed by **“Stop”** is useful only when X-COM2 voice mode is already needed for another command.
- ChatGPT Dictation is distinct from ChatGPT Voice: the Dictation microphone produces editable text in the selected ChatGPT chat, but requires the ChatGPT microphone control to start and a send action to complete.
- A Siri-triggered **Motorcycle Note** Shortcut can capture dictated feedback while stationary. If that path is unavailable, ChatGPT Dictation can be used with the touchscreen while wearing compatible gloves or after removing a glove.
- Siri's **“Ask ChatGPT”** Apple Intelligence integration is a separate, future comparison path. It is not the preferred ChatGPT Dictation workflow.
- Codex Remote keeps local file access, tools and permissions on the connected Mac host. Voice in Codex is a desktop capability; paired iOS remote access should be tested separately for live microphone input.

## Appendix A: Motorcycle Note Shortcut reference

Date: 2026-08-05

The documented Shortcut action sequence is the visual-reference specification for the timestamped ride-feedback capture described in the X-COM2 setup guide.

1. **Current Date**
2. **Format Date** using the **Date** variable
3. **Dictate Text**
   - Language: **English (United Kingdom)**
   - Stop Listening: **After Short Pause**
4. **Text** containing **Formatted Date** followed by **Dictated Text**
5. **Append Text** to the **RideHorizon test notes** note
6. **Speak**: **Feedback saved**

The Shortcut and setup procedure both use the user-facing name **Motorcycle Note**. The destination note remains **RideHorizon test notes**.

No Shortcut-builder screenshot is attached in this version.

## Appendix B: ChatGPT microphone-mode reference

Filename: `assets/ios-chatgpt-mic-mode-voice-isolation.jpg`

This screenshot shows **iOS Control Centre > Audio & Video > ChatGPT** with **Voice Isolation** selected during an active microphone session. If this setting is documented later, label it as an **iOS Control Centre** setting, not a ChatGPT app setting.

![iOS ChatGPT microphone mode with Voice Isolation selected](assets/ios-chatgpt-mic-mode-voice-isolation.jpg)
