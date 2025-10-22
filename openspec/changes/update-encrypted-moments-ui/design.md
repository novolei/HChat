## Context
- Audience: couples using HChat as a private “Encrypted Moments” diary.
- Goal: transform the UI into a cohesive memory stream experience across Home, Chat, Explorer, and Personalization tabs.
- Constraints: iOS 17 SwiftUI, existing code uses ModernTheme, local encryption already available at service layer.

## Goals / Non-Goals
- Goals:
  - Introduce four-tab navigation with moments-centric Home hub.
  - Deliver full-screen customizable chat with flexible backgrounds.
  - Present Explorer with discoverable templates and rituals.
  - Provide Personalization space for themes, security rituals, and AI summaries.
- Non-Goals:
  - Implement actual emotion AI models (stub only).
  - Replace existing encryption backend.
  - Implement Android client.

## Decisions
- Navigation: Use `TabView` with custom pill indicator and frosted background.
- Visual system: Gradient-driven color tokens (dawn, dusk, twilight), glassmorphism cards, rounded corners.
- Components: MemoryMomentCard, EmotionChip, RitualActionButton reusable across tabs.
- Chat background: inject via customizable gradient or photo, persisted per relationship.

## Risks / Trade-offs
- Risk: Increased gradient usage impacting performance → mitigate with cached `LinearGradient` assets.
- Risk: Complex gestures interfering with keyboard → reuse refined `KeyboardHelper` overlay.
- Trade-off: Keeping AI summaries as stub may reduce immediate value but enables incremental rollout.

## Migration Plan
1. Implement new `MainTabView` structure.
2. Build out Home/Moments feed views referencing new components.
3. Apply new chat layout and background customization flow.
4. Update Explorer and Personalization tabs.
5. Wire up storage stubs and ensure compatibility with existing data.

## Open Questions
- Should timed memories trigger local notifications?
- Do we need accessibility toggles for high-contrast themes?
