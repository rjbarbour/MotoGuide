# Interactive Motorcycle Tour Guide Reference

Date: 2026-08-04

## Purpose

This is the service-design reference for RideHorizon's interactive contextual tour-guide level. It extends the passive guide described in `HUMAN_MOTORCYCLE_TOUR_GUIDE_REFERENCE.md` with spoken questions, follow-up requests, preference refinement and bounded actions. It is not an implementation specification and does not authorise microphone, speech-recognition, navigation or backend work.

## Experience Goal

The interactive guide should feel like speaking briefly to a knowledgeable human guide who already knows:

- the rider's best-available current location;
- the current geographic hierarchy and meaningful region;
- the subject of the last announcement;
- what has already been said during this ride;
- the rider's selected interests and detail preference; and
- whether the current riding situation permits a short response or requires deferral.

The rider should not need to restate that context. "What is that?", "Why are the houses built like this?" and "Tell me more about the bridge" are useful only if the guide can resolve their references honestly.

## Interaction Contract

Listening is explicit and bounded by default:

1. The rider deliberately starts listening through an in-app control while stopped, a supported headset action or another clearly defined activation.
2. RideHorizon gives an audible indication that listening has started.
3. It listens for a limited period and stops visibly and audibly.
4. It resolves the request against current ride context.
5. It answers briefly, defers detail, asks one concise clarification or declines.
6. "Stop", "cancel" or an equivalent action ends listening or speech immediately.

Always-on microphone listening is not the default assumption. A wake phrase can be evaluated later only after privacy, battery, false-activation and audio-coexistence evidence justifies it.

## Context Available To The Guide

Use a bounded context stack rather than an unbounded transcript or location history:

1. Current location estimate, age, accuracy and place-resolution state.
2. Current street, town, county, nation/region, country and any verified landscape region.
3. Current or most recently indicated landmark, view, road feature or point of interest.
4. Last announcement and its subject.
5. Recent places, topics and facts from the active ride.
6. Rider's current content depth, selected interests and session refinements.
7. Whether the rider is stopped, moving steadily or in a high-demand/uncertain state.
8. Any open interaction, such as a proposed place awaiting acceptance.

When two subjects are plausible, do not guess silently. Ask a short clarification when safe or defer it until stopped.

## Core Rider Intentions

### Control And Refinement

- "Stop talking."
- "Repeat that."
- "Shorter."
- "More detail."
- "Less history; more landscape."
- "Only tell me about major places today."
- "Save the longer version until I stop."

Distinguish a **session refinement** from a **durable preference**. A request such as "less history today" should not permanently rewrite the rider's profile unless they explicitly ask to save it.

### Contextual Questions

- "Where am I?"
- "What is that tower?"
- "Why does the landscape change here?"
- "Why are these villages built from the same stone?"
- "Who built this road?"
- "Tell me more about the place you just mentioned."

Answer the question first. Use one principal idea while moving. Offer or automatically defer a longer explanation for the next stop when appropriate.

### Discovery And Action

- "Is there anything worth seeing nearby?"
- "Any motorcycle cafés around here?"
- "Tell me more about the second one."
- "Navigate there."

RideHorizon may identify and describe a destination, then hand the selected place to the chosen navigation app. The navigation app continues to own route calculation and turn instructions.

## Response Policy

| Situation | Response |
| --- | --- |
| Confident current-place question on a calm section | Give a short direct answer. |
| Longer explanation requested while moving | Give the headline and offer or schedule detail for a stop. |
| Ambiguous "that" or "there" | Ask one short clarification if safe; otherwise defer. |
| Location or subject confidence is weak | State the uncertainty; do not manufacture precision. |
| General chat unrelated to the place | Decline or postpone; preserve the product boundary. |
| Route, speed or riding-technique request | Keep navigation and riding decisions outside the guide role. |
| Safety-critical or high-demand riding state | Stop listening and commentary, or acknowledge and defer. |

Responses remain subordinate to navigation audio and immediate riding needs. A rider interruption cancels or truncates the answer; the system does not insist on finishing.

## Conversation Shape

Good interaction is shallow while moving and may deepen when stopped.

Example:

> **Guide:** "Ahead on the left is the old mill complex that shaped this valley."
>
> **Rider:** "What did it make?"
>
> **Guide:** "Woollen cloth, using the river to power the machinery. I can give you the longer story when you stop."

Example with uncertainty:

> **Rider:** "What is that tower?"
>
> **Guide:** "I cannot identify which tower you mean from the current context. Ask again when you are closer or stopped."

Example of refinement:

> **Rider:** "Less history today. Tell me about the landscape and roads."
>
> **Guide:** "Understood for this ride. I will prioritise landscape and road context."

## Relationship With The Passive Guide

Interaction does not replace passive interpretation. It modifies and deepens it:

- passive guidance supplies the shared subject and narrative context;
- questions reveal what the rider wants to understand;
- refinements adapt later selection, depth and frequency;
- deferred answers bridge moving and stopped experiences; and
- accepted destinations flow to navigation without turning RideHorizon into navigation.

The passive guide must work first. An interactive interface cannot compensate for repetitive facts, weak timing or unreliable place context.

## Functional Deltas From The Current App

RideHorizon currently has user-selected fact interests, custom fact focus, content-depth settings and replay of the last announcement. It does not currently listen to the microphone or interpret speech.

The main capability deltas are:

- explicit activation and microphone permission;
- audible and visible listening state;
- speech recognition with cancellation and timeout;
- a small, ride-safe intent model before broad questions;
- contextual reference resolution using current place and recent subjects;
- concise answer generation grounded in reliable place material;
- stopped/deferred handling for long answers;
- session-scoped and explicitly saved preference changes;
- audio-session coexistence across listening, navigation, music and TTS;
- privacy disclosure, data minimisation and retention policy for captured speech and transcripts;
- evaluation of recognition quality through the target helmet microphone; and
- POI selection and navigation handoff after a destination is explicitly accepted.

## Suggested Capability Order

1. Voice control for stop, cancel, repeat, shorter and tell-me-more.
2. Contextual follow-up about the last announcement.
3. Questions about the current place and verified nearby features.
4. Session preference refinement and explicit durable preference saving.
5. Nearby-place discovery, selection and navigation handoff.
6. Broader questions only after safety, grounding, latency and rider value are demonstrated.

This ordering is provisional. Real rider evidence may show that stopped-only questions or headset controls are more valuable than moving speech interaction.
