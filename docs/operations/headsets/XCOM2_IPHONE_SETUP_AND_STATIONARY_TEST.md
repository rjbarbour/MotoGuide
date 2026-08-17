# X-COM2 and iPhone setup check

Date: 2026-08-05
Version: 0.8
Applies to: NEXX X-COM2, paired iPhone 17 Pro Max and iOS 26.5.1

Complete this procedure once at home. It checks only that the paired phone, headset voice paths and feedback Shortcut are configured correctly. RideHorizon stationary testing is a separate test-manager procedure.

## How X-COM2 reaches the function you want

| You want to… | Start with… | What listens |
| --- | --- | --- |
| Play, pause, change track, answer a call or start intercom | The relevant tap or hold | X-COM2 acts directly |
| Run a headset function by voice | Say **“Hello Sena”** while X-COM2 is in standby, or tap **Centre & (-)** | X-COM2 listens for one of its fixed English commands |
| Control the iPhone or an iPhone app | Hold **Centre** for 3 seconds while X-COM2 is in standby | Siri listens through the headset |
| Change a rare headset setting or pairing | Hold **Centre** for 12 seconds | X-COM2 opens its spoken configuration menu; **(+)** and **(-)** move through items and **Centre** selects |

“Hello Sena” starts X-COM2 voice command mode. It does not start Siri and it does not by itself open the configuration menu. During music, FM radio or intercom, use **Centre & (-)** instead.

## 1. Configure the iPhone

1. **[iOS]** Open **Settings > Apple Intelligence & Siri > Talk & Type to Siri**. Enable Siri.
2. **[iOS]** Open **Settings > Apple Intelligence & Siri > Siri Responses**. Select **Prefer Spoken Responses**.
3. **[iOS]** Confirm that Siri is allowed when the iPhone is locked.
4. **[iOS]** Open **Settings > Privacy & Security > Microphone**. Allow microphone access for ChatGPT. Shortcuts can request its own permission when **Dictate Text** first runs.
5. **[iOS]** Open **Settings > General > Keyboard**. Enable **Dictation**. This is the fallback for text fields that use the iPhone keyboard.

Expected result: Siri speaks its replies, ChatGPT can record dictation, and keyboard Dictation is available.

## 2. Set a controlled X-COM2 baseline

1. **[Sena app]** Set **Voice Command** to **On**.
2. **[Sena app]** Set **Smart Volume Control** to **Off** for the first tests.
3. **[Sena app]** Set **VOX Phone** to **Off** for the first tests. Use the Centre button to answer calls.
4. **[iOS]** Open **Settings > Bluetooth**. Keep both X-COM2 connections connected:
   - **XCOM2 V1.0.1** is the normal Bluetooth audio and phone connection.
   - **XCOM2 BLE** is the low-energy connection used by the Sena app.
5. **[iOS]** If an information screen for **XCOM2 V1.0.1** offers **Device Type**, select **Headphones**. Do not select Car Stereo.
6. **[X-COM2 buttons]** Turn on X-COM2 and wait for **“Phone connected”**.

These settings remove automatic volume changes and voice-answer behaviour from the first test. Change them only after the baseline works.

X-COM2 does not have a Sena-app setting that separately activates its microphone for ChatGPT. The iPhone or the active app selects the audio input.

## 3. Create the Motorcycle Note shortcut

This shortcut records a timestamped spoken note. It does not use ChatGPT Voice.

1. **[Notes]** Create a note named **RideHorizon test notes**.
2. **[Shortcuts]** Tap **(+)**. Rename the shortcut **Motorcycle Note**.
3. Add **Date**. It returns the date and time when the Shortcut runs.
4. Add **Format Date**. Select **Custom** and enter `yyyy-MM-dd'T'HH:mm:ssZZZZZ`.
5. Add **Dictate Text**. Set **Stop Listening** to **After Pause**.
6. Add **Text**. Insert the **Formatted Date** variable, a line break, then the **Dictated Text** variable.
7. Add **Append to Note**. Select **RideHorizon test notes**.
8. Add **Speak Text**. Enter **“Feedback saved.”**
9. Optional: add **Open App** and select **RideHorizon**. Keep this only if the unlocked-phone test is useful; iOS can require an unlock before a shortcut opens an app.
10. Tap **Done**.

Expected result: saying **“Motorcycle Note”** to Siri starts dictation, appends the result to the note and speaks the confirmation.

## 4. Confirm the configuration through the helmet

1. **CONF-001 — Reconnect after power-on.** **[X-COM2 buttons]** Turn on X-COM2. Wait for **“Phone connected”**.

   Pass: the iPhone reconnects without opening Bluetooth settings.

2. **CONF-002 — Report battery.** **[X-COM2 voice]** In standby, say **“Hello Sena”**. After the prompt, say **“Check battery”**.

   Pass: X-COM2 reports its battery level.

3. **CONF-003 — Use voice control while music plays.** **[iPhone]** Start music. Use the activation method that works on this headset, then give the required voice command.

   Pass: the voice command works after music has paused. Current observed activation: hold **Centre** for 3 seconds; music pauses, then the voice command works. Retest **Centre & (-)** separately if X-COM2 voice-command control while music continues is required.

4. **CONF-004 — Start Siri through X-COM2.** **[X-COM2 buttons]** Hold **Centre** for 3 seconds. **[Siri]** Say **“What time is it?”**

   Pass: Siri hears the request and replies through the helmet speakers.

5. **CONF-005 — Check the ChatGPT Dictation microphone.** **[ChatGPT]** Open a chat and tap ChatGPT's own microphone. Keep the iPhone away from your mouth and dictate **“ChatGPT microphone check.”**

   Current result: ChatGPT Dictation records from the iPhone microphone on this phone. It is not the helmet-microphone route.

6. **CONF-006 — Check iOS keyboard Dictation.** **[ChatGPT]** Tap the message field, then tap the **iPhone keyboard microphone**. Keep the iPhone away from your mouth and dictate **“Keyboard microphone check.”**

   Pass: editable text is inserted and is intelligible. This confirms that iOS keyboard Dictation uses the X-COM2 microphone.

7. **CONF-007 — Run Motorcycle Note while unlocked.** **[X-COM2 buttons]** Hold **Centre** for 3 seconds. **[Siri]** Say **“Motorcycle Note”**. Wait for Siri to ask for the text. Dictate **“Helmet feedback check.”** Then pause.

   Pass: Siri says **“Feedback saved”** and the timestamped text appears in **RideHorizon test notes**.

   Current observed timing: say the Siri wake phrase and **“Motorcycle Note”** as separate utterances. Wait for Siri's prompt before dictating the note. Combining the wake phrase and shortcut name caused Siri to search instead of running the shortcut.

8. **CONF-008 — Run Motorcycle Note while locked.** Lock the iPhone and repeat CONF-007.

   Pass: the note is saved without touching the iPhone. If iOS requests an unlock, remove the optional **Open App** action and repeat. Record the workflow as unlocked-only if the remaining Shortcut still requires an unlock.

9. **CONF-009 — Set the shared iPhone-media volume and make a test call.** **[X-COM2 buttons]** While RideHorizon, music or Google Maps speaks, set a usable shared iPhone-media volume with **(+)** or **(-)**. Start Siri and set its volume while it speaks. Make one test call and set call volume during the call.

   Pass: shared iPhone media, Siri and call audio are intelligible.

## Stationary feedback fallback

Use the **Motorcycle Note** Shortcut while stationary. If it does not work, use the touchscreen with your gloves or remove a glove:

1. **[ChatGPT]** Open the required chat and tap the message field.
2. Tap the **iPhone keyboard microphone**. Dictate the feedback, review the inserted text and send it.

On the tested phone, this uses the X-COM2 microphone. ChatGPT's own microphone records from the iPhone microphone instead. Siri can open ChatGPT, but it does not focus the message field or start either microphone control. Therefore, one touchscreen action is required for this fallback.

## Test status and configuration record

Recorded: 2026-08-05
Device: iPhone 17 Pro Max, iOS 26.5.1, NEXX X-COM2

| Test or configuration item | Status | Recorded result or next test |
| --- | --- | --- |
| X-COM2 Bluetooth connections | Observed | **XCOM2 V1.0.1** and **XCOM2 BLE** are both connected. Confirm that the first connection's Device Type is **Headphones** if that setting is available. |
| CONF-001 — Reconnect after power-on | Pass | X-COM2 reconnects to the iPhone. |
| CONF-002 — Report battery | Pass | X-COM2 reported its battery level. |
| CONF-003 — Use voice control while music plays | Pass, with observed route | Holding **Centre** for 3 seconds paused music; the voice command then worked. The **Centre & (-)** route has not been separately tested. |
| CONF-004 — Start Siri through X-COM2 | Pass | Siri accepts commands through the helmet microphone. |
| CONF-005 — ChatGPT Dictation microphone | Limitation confirmed | ChatGPT's own microphone records from the iPhone microphone. Control Centre shows Mic Mode but no input-source picker for this recording. |
| CONF-006 — iOS keyboard Dictation in ChatGPT | Pass | The keyboard microphone records from the X-COM2 microphone and inserts editable text in the ChatGPT message field. |
| Hands-free start of a ChatGPT microphone | Not available in tested configuration | Siri can open ChatGPT, but cannot focus its message field or start the keyboard microphone or ChatGPT microphone. |
| CONF-007 — Motorcycle Note, unlocked | Pass | Wait after the wake phrase, then say **“Motorcycle Note”**. Wait for Siri's question before dictating. Saying the wake phrase and shortcut name together caused a search. |
| CONF-008 — Motorcycle Note, locked | Pass | The Shortcut saved the note while the iPhone was locked. |
| CONF-009 — Shared iPhone-media, Siri and call volumes | Not recorded | Set the shared iPhone-media volume, then check Siri and make one test call. |

The ChatGPT microphone result and the keyboard-Dictation result are application-specific observations, not general iPhone audio-routing rules. Retest them after an iOS, ChatGPT or X-COM2 firmware update.

### Volume-routing note

X-COM2 stores levels by headset audio-source category, not by iPhone app. On this iPhone, RideHorizon, music and Google Maps share the iPhone media level; changing X-COM2 volume during a RideHorizon announcement changes that shared level. A separately paired GPS, intercom, FM radio or phone-call audio can use a different X-COM2 source category. App-specific volume, if available, must be set in that app.

## Ready state

The stationary setup is complete when:

- X-COM2 voice mode works from standby and during music;
- Siri works through the headset;
- iOS keyboard Dictation receives intelligible speech from the helmet microphone;
- Motorcycle Note has a recorded unlocked and locked result, or a known unlock limitation; and
- music, Siri and calls have usable source-specific levels.

## References

- NEXX X-COM2 User's Guide, sections 4.6, 7, 8, 12, 20 and 23.
- [OpenAI Voice Dictation FAQ](https://help.openai.com/en/articles/12168547-voice-dictation-faq)
- [Apple: Use Siri to run shortcuts with your voice](https://support.apple.com/guide/shortcuts/apd07c25bb38/ios)
- [Apple: Create a custom shortcut](https://support.apple.com/guide/shortcuts/apd84c576f8c/ios)
