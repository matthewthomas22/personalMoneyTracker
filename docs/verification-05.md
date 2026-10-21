# Ticket 05: voice capture

Implemented in the same app as keyboard entry. Tickets 05 and 06 share the capture screen: complete, unambiguous recognized expenses save locally; incomplete recognition remains in the clarification/draft flow. No Xcode, iOS SDK, simulator, microphone, or device is available in the Windows development environment. **The Swift code and device behavior are not yet validated on a Mac/iPhone.**

## Interpretation and privacy decision

The app uses Apple's Speech framework (`SFSpeechRecognizer` / `SFSpeechAudioBufferRecognitionRequest`) with live microphone buffers. Recognition may use Apple's online service; the app does not require on-device recognition. The user selects Indonesian (`id-ID`) or English (`en-US`). The local interpreter accepts Indonesian, English, and mixed vocabulary regardless of that selection. Apple's single-locale recognizer's actual mixed-language transcription quality must be checked on the target iPhone; language selection does not guarantee multilingual recognition accuracy.

Interpretation of the returned text is a deterministic local grammar, with no external LLM, backend, credentials, analytics, audio files, or transcript logging. It supports explicit rupiah amounts, Indonesian/English number words and thousands/millions, one clearly combined purchase with `dan`/`and`, today/yesterday/day-before-yesterday, the configured payment channels, and existing source names/aliases. Unsupported date wording and unclear amount/payment wording require correction. Unmarked item quantities cannot silently become a price. Explicit dates and unsupported number grammar can be resolved using the correction form. Unknown sources require confirmation before creation. This bounded approach makes unsupported wording recoverable rather than inventing financial details.

Audio exists only as live engine/request buffers. The capture ends on Done, a short silence after sound, Cancel, failure, or the 45-second limit. Buffers/tasks are released after completion. No audio archive is created. Successful save and Cancel clear captured text; text retained for a retryable draft is separate from spending records. Draft privacy/cleanup checks are in [ticket 06 verification](verification-06.md).

Apple documents that recognition can send audio to its servers and requires separate Speech permission. Its `requiresOnDeviceRecognition` documentation describes preventing network transfer when supported and enabled; this implementation leaves it false. **Apple's remote retention/deletion behavior for this specific third-party Speech API journey has not been independently verified. Do not claim immediate remote deletion, zero remote retention, or offline voice support.** A remote zero-retention requirement would need a different validated configuration/provider before release.

Primary API references checked during implementation:

- [Apple: Asking permission to use speech recognition](https://developer.apple.com/documentation/speech/asking-permission-to-use-speech-recognition)
- [Apple: Speech recognition requests](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest)
- [Apple: requiresOnDeviceRecognition](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/requiresondevicerecognition)

## Automated checks on a Mac

Generate the project with `xcodegen generate`, select an available iPhone simulator destination, then run the full test scheme described in [baseline verification](verification-01-03.md). `VoiceInterpreterTests` covers the CAP-02, CAP-03, CAP-05 examples, mixed number words, configured aliases, unknown/archived/ambiguous sources, Jakarta year-boundary relative dates, invalid/overflow amounts, item quantities, conflicting payment methods/dates, and no-text/missing-description input. These checks have been written but were **not run here**.

## Actual iPhone checks still required

1. Fresh install: explicitly Record, allow both permission prompts, speak the Indonesian acceptance example, and wait for approximately 1.8 seconds of silence. Verify one Rp15.000 expense, the correct description, QRIS/GoPay, and the capture date. Speech availability and ambient noise can affect timing; verify on the intended device.
2. Repeat in English and mixed language with each language selector. Say `Sosis 15 ribu dan susu 10 ribu, QRIS GoPay`; verify one Rp25.000 expense. If recognition produces incorrect text, confirm the app leaves a correctable draft rather than claiming reliable recognition.
3. Say `kemarin` near a local month/year boundary; verify the phone-local previous date. Omit a date and verify capture date. Conflicting/unsupported dates must not save automatically.
4. Tap Done mid-capture; verify the microphone stops immediately, final trailing words have a brief chance to arrive, and the capture is processed once. If Apple has not produced a final result within 1.5 seconds, verify the text becomes a correctable draft with a truthful failure instead of auto-saving a partial result. Explicit Cancel must stop the mic, remove text/draft, and save nothing. Switching to keyboard must stop the microphone.
5. Deny microphone, deny Speech separately, disable Speech in Settings, and use airplane mode where remote recognition is needed. Verify a truthful error, usable typing/retry, and no false Saved message. Check recording again after permissions are changed.
6. Remain silent for eight seconds, then separately force recognition failure after partial text. Verify no-text actions versus a preserved editable draft. No failure may auto-save partial text.
7. Check microphone indicator clears after Done, Cancel, keyboard switching, failed start, sheet dismissal, and app leaving the foreground. Test a call/audio interruption and inspect preserved text; full shortcut interruption/resume behavior remains ticket 08.
8. Confirm foreground save summary has amount, description, combined payment method, Edit, and Undo. Force local write failure and verify retryable capture without Saved. Relaunch and verify local persistence. Verify no audio file or permanent transcript is added alongside the local stores after successful save/Cancel.

Remote service retention verification and all device checks above remain open acceptance evidence, not completed tests.
