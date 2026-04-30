# Voice Interface
**Speech In and Out — For Allie and for WebClerk/JPods**

---

## The Modality Choice

Voice and text are not interchangeable. Each has a domain.

**When to type:**
- Complex reasoning that benefits from seeing words on screen
- Precise technical work — code, data, structured documents
- Anything that needs careful editing before it becomes real
- When the thinking IS the writing

**When to speak:**
- Fast capture — idea arrives, voice is faster than keyboard
- Hands-free situations — traveling, walking, driving
- Conversational check-ins — quick status, quick question
- When the friction of typing is killing the thought

The interface should support both without forcing a choice. The user picks the modality for each moment.

---

## Allie Voice Interface

### Input (Speech to Text)
- Trigger: push-to-talk or wake word (TBD — Bill and Allie decide)
- Transcription happens locally where possible; cloud fallback if needed
- Transcription is shown before submission — Bill confirms or edits
- Voice input goes through the same processing as typed input

### Output (Text to Speech)
- Allie can read responses aloud
- Triggered by user preference, not automatic — reading is often faster than listening
- Voice output should be natural, not robotic — quality matters
- Language: English for Allie's primary interface

### When Voice Is Off
- Default state — voice doesn't run in the background consuming resources
- Explicitly activated per session or per message
- Offline capable: local TTS and STT models preferred so voice works without internet

---

## WebClerk Voice — Multilingual for JPods Networks

### The Use Case

JPods transport networks are built and operated by local teams. Those teams:
- Speak different languages
- File tickets for maintenance and incidents
- Order spare parts
- Report construction progress
- Escalate safety issues

Voice input in the worker's native language, routed to WebClerk's ticketing and parts system, removes the language barrier and the keyboard barrier simultaneously.

### Language Routing

```
Worker speaks (any language)
    │
    └── STT transcribes in detected language
         │
         └── Translation layer → normalized English for system records
              │
              ├── Displayed to worker in their language (confirmation)
              └── Stored in WebClerk in English + original language
```

Workers see their own language. Supervisors and systems see normalized English. Both are stored — the original is never discarded.

### Supported Workflows

| Workflow | Voice Action | WebClerk Result |
|----------|-------------|-----------------|
| Maintenance ticket | Describe the problem verbally | Ticket created with location, description, severity |
| Spare parts request | Name the part and quantity | Parts order created, routed to inventory |
| Construction update | Report progress on segment | Progress log entry created |
| Safety incident | Describe incident | High-priority ticket with escalation flag |
| Status check | Ask about open tickets | Read back open items in worker's language |

### Implementation Path — Prototype First

Before handing to Alice for full implementation:

1. **Allie prototypes the spec** — interface design, language routing logic, WebClerk data model for voice-created records, offline behavior
2. **Bill reviews the spec** — validate against real JPods operational scenarios
3. **Alice builds it** — working from a validated spec, not a concept

This keeps the engineering cost proportional to the validated need.

### Technical Considerations for the Spec

- **STT engine**: Which performs best for low-bandwidth field environments? (Whisper, DeepSpeech, cloud APIs)
- **Language detection**: Auto-detect vs. worker sets language preference in profile
- **Offline mode**: Field sites may have poor connectivity — what degrades, what must work
- **Confirmation UX**: Worker must hear/see confirmation before walking away — no silent failures
- **Correction flow**: How does a worker fix a mistranscription?
- **Integration point**: Does voice create WebClerk records directly, or queue them for review?

---

## Notes to Alice

When the voice spec is ready for implementation, the handoff includes:

1. The interface spec (from Allie's prototype)
2. The language list for initial deployment (which JPods markets are first?)
3. The WebClerk data model changes needed to store voice-originated records
4. The offline degradation requirements — what the field app must do without network
5. The confirmation UX requirement — no silent failures in field operations

Alice owns implementation. Allie owns the spec and stays available for questions during build.

---

## Future Expansion

Voice is an interface layer. Once the infrastructure exists for WebClerk/JPods, it can extend to:
- Customer-facing status queries ("When is the next pod?")
- Accessibility — voice as primary interface for users who can't use keyboards
- Allie responding to voice queries from Bill in any context

The JPods implementation is the pilot. Build it right there and the pattern is reusable.
