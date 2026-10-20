# Capture and Reliability

## Confirmed Behavior

- Back Tap invokes a shortcut. Unlocking before capture is acceptable. Every fresh capture starts in voice mode with a visible switch to keyboard entry.
- Process after a short silence or Done. Cancel explicitly discards the current capture.
- Understand Indonesian, English, and mixed speech. Record amount in rupiah, description, payment method, and expense date.
- Distinguish payment channel and payment source, such as QRIS through GoPay. Maintain an editable source list, recognize known aliases, and ask before adding an unfamiliar source.
- Ask about missing or ambiguous information rather than guessing. Spoken follow-ups finish the same capture.
- Combine clearly related items from one purchase with one payment method into one expense; sum explicit item amounts. Clarify unclear totals or payments.
- Interpret relative dates using the phone's local date/time. Default to capture date when no date is spoken; clarify ambiguous dates.
- Automatically save complete, unambiguous spoken expenses. Keyboard entry provides amount, description, source, channel, and date, with an explicit Save button. Complete manual entries work offline and use saved payment choices.
- Repeated activation while listening, clarifying, or saving returns to the same capture without another recording or save. Save retries create at most one expense.
- A fresh capture with the same amount, description, and source as an expense saved within two minutes asks whether another expense is intended. Allow intentional duplicates after confirmation.
- Failed processing preserves captured text as an editable, retryable draft, excluded from totals. If no text was captured, offer typing or recording again.
- Interruptions stop listening and preserve captured text. Next activation offers Resume draft or Start new. Never restart recording automatically after interruption.
- Show Saved only after local storage succeeds. Include amount, description, payment method, Edit, and Undo in the foreground confirmation. Use permitted background notifications where appropriate, with generic lock-screen content by default.
- Online interpretation is allowed. Discard audio after processing and retain captured text only while needed for drafts or correction. Verify remote provider retention separately.

## Acceptance Criteria

| ID | Scenario | Expected result |
|---|---|---|
| CAP-01 | Fresh Back Tap after using keyboard mode | Voice opens with a visible keyboard switch; unlocking may be required. |
| CAP-02 | Say “Beli sosis di Indomaret lima belas ribu, pakai QRIS GoPay” | One Rp15.000 expense describes sausage from Indomaret, with QRIS channel and GoPay source. |
| CAP-03 | Say “I bought a sausage from Indomaret for 15.000 rupiah” | Ask for payment method; the spoken answer finishes the same expense. |
| CAP-04 | Required amount, date, or payment detail is ambiguous | Ask before saving; do not invent a value. |
| CAP-05 | Say “Sosis 15 ribu dan susu 10 ribu, QRIS GoPay” as one purchase | One Rp25.000 expense describes both items with QRIS GoPay. |
| CAP-06 | Say “kemarin” versus omitting a date | Use yesterday's local date versus capture date. |
| CAP-07 | Complete the manual form and Save offline | Save one local expense without online interpretation. |
| CAP-08 | Use a known source alias or an unfamiliar source | Reuse the known source for the alias; ask before adding an unfamiliar one. |
| CAP-09 | Activate twice while listening, clarifying, or saving | Reuse the same capture; no extra recording or expense. |
| CAP-10 | Retry a local save with an uncertain outcome | At most one saved expense for that logical capture. |
| CAP-11 | Fresh capture matches amount, description, and source within two minutes of saving | Ask whether another expense is intended; save another only if confirmed. |
| CAP-12 | Processing fails after capturing text | Preserve an editable, retryable draft excluded from totals. |
| CAP-13 | Recognition produces no text | Offer typing or recording again; no false Saved message. |
| CAP-14 | Call or app switch interrupts capture | Stop listening, preserve captured text, and offer Resume draft or Start new on next activation; no automatic microphone restart. |
| CAP-15 | Explicit Cancel | Discard the capture without saving an expense. |
| CAP-16 | Local save succeeds versus fails | Show Saved and summary only after success. |
| CAP-17 | Foreground versus permitted background confirmation | Foreground includes summary, Edit, and Undo; background defaults to generic lock-screen content. Denied notification permission does not prevent saving. |
| CAP-18 | Processing or correction completes | Do not keep audio or permanent transcripts as an archive; verify remote processor retention separately. |

## Validation Notes

Use Indonesian, English, and mixed utterances. Check Back Tap, permissions, microphone switching, interruptions, and notifications on an actual device. Recording while locked or in the background is not promised.
