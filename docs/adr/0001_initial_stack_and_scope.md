# ADR-0001: Initial Stack and Vertical Slice Scope

Status: Accepted  
Date: 2026-07-12

## Context

The project is intended for multi-year solo development. The immediate risk is not technical capacity but expanding many management modules before proving the central decision loop.

## Decision

- Build V0.1 in Godot 4.7 stable with GDScript.
- Use a Control-based management UI.
- Implement a deterministic, headless domain simulation first.
- Use custom Resource definitions and separate runtime state.
- Limit V0.1 to one squad, one contract per week, one regional crisis, three factions and four principal screens.
- Defer observable auto-battle and advanced management departments.

## Consequences

Positive:

- Faster validation of core decisions.
- Lower visual and content cost.
- Easier automated testing and Codex collaboration.
- Future battle presentation can consume existing resolution output.

Negative:

- V0.1 will not demonstrate the final battle spectacle.
- Some planned systems remain represented only by modifiers or messages.
- Data schema discipline is required earlier than in a throwaway prototype.

## Revisit conditions

Revisit language or engine integration only after profiling demonstrates a real limitation. Revisit battle presentation only after external players find the planning and consequence loop engaging.
