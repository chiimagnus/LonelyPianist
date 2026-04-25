# Generation Metadata

## Run info
| Item | Value |
| --- | --- |
| Commit hash | rectangular-ar-light-beams branch work, latest implementation commit pending PR CI |
| Branch name | rectangular-ar-light-beams |
| Generated at | 2026-04-25T00:00:00+09:00 |
| Output language | Chinese |
| Generation mode | Incremental update for rectangular AR light beams |

## Generated / updated pages
- `GENERATION.md`
- `data-flow.md`
- `configuration.md`
- `modules/lonelypianist-avp-practice.md`

## Existing pages retained
- `INDEX.md`
- `overview.md`
- `architecture.md`
- `testing.md`
- `workflow.md`
- `troubleshooting.md`
- `business-context.md`
- `dependencies.md`
- `storage.md`
- `glossary.md`
- `modules/lonelypianist-macos.md`
- `modules/lonelypianist-macos-runtime.md`
- `modules/lonelypianist-macos-mapping.md`
- `modules/lonelypianist-macos-recording.md`
- `modules/lonelypianist-macos-dialogue.md`
- `modules/lonelypianist-avp.md`
- `modules/lonelypianist-avp-library.md`
- `modules/lonelypianist-avp-calibration.md`
- `modules/lonelypianist-avp-musicxml.md`
- `modules/lonelypianist-avp-tracking.md`
- `modules/piano-dialogue-server.md`
- `modules/piano-dialogue-server-protocol.md`
- `modules/piano-dialogue-server-inference.md`
- `modules/piano-dialogue-server-debug.md`

## Copied assets
- None. `.github/deepwiki/assets/` remains reserved for future diagrams or screenshots.

## Evidence used
- `LonelyPianistAVP/Services/RealityKit/PianoGuideOverlayController.swift` for rectangular volumetric beam implementation.
- `LonelyPianistAVPTests/PianoGuideBeamGeometryTests.swift` for pure geometry coverage.
- `LonelyPianistAVP/Services/PianoKeyGeometryService.swift` and `PianoKeyRegion` model for key region shape assumptions.
- Existing deepwiki pages and module boundaries.

## Key updates in this generation
| Area | Update |
| --- | --- |
| AVP practice | Replaced RealityKit cylinder light-beam wording with rectangular volumetric beam details. |
| AR guide geometry | Documented key-top placement, rectangular footprint, black-key overlay scaling, three body segments, base glow, and deterministic dust particles. |
| Configuration | Replaced cylinder radius/alpha settings with rectangular beam parameters and misconfiguration notes. |
| Data flow | Updated the spatial prompt flow from single `ModelEntity` cylinder to compound `KeyBeamMarker`. |

## Current Coverage Gaps
- Python smoke tests are not yet part of GitHub Actions.
- There is no unified release workflow.
- There is no full macOS -> Python -> AVP end-to-end automated test.
- AVP simulator tests can verify build and logic, but real Vision Pro hand tracking, optical comfort, and perceived Tyndall-style light scattering still require manual device testing.

## Validation checklist
- [x] AVP light-beam implementation documented in module page.
- [x] Data flow updated for rectangular compound beams.
- [x] Configuration updated for rectangular beam parameters.
- [x] Deprecated cylinder/radius wording removed from updated pages.
- [x] Geometry helper tests added for footprint, key-top placement, segment stacking/fade, and deterministic dust offsets.
- [ ] PR CI pending after pull request creation.
