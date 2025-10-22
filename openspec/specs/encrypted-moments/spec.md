# Encrypted Moments UI Capability

## Requirements

### Requirement: Moments Home Hub
The system SHALL present a home hub that merges encrypted memory stream and chat summary information for the couple. It SHALL surface recent encrypted artifacts (photos, voice notes, text highlights) and provide quick actions to capture new moments.

#### Scenario: View recent moments
- **WHEN** both partners open the Home tab
- **THEN** the latest encrypted artifacts appear in chronological order with emotion tags.

#### Scenario: Capture new moment
- **WHEN** the user taps the quick capture button
- **THEN** the app offers options for text note, photo, or voice memo creation stored with encryption.

### Requirement: Full-Screen Chat Experience
The chat view SHALL span edge-to-edge, allow customizable gradient/photo backgrounds, and display message bubbles with reaction/status overlays consistent with the theme.

#### Scenario: Customize background
- **WHEN** the user opens chat settings and selects a background
- **THEN** the chat updates immediately and persists the choice locally for that relationship.

### Requirement: Explorer Discovery
The Explorer tab SHALL curate templates, rituals, and inspiration, organized via gradient cards and emotion chips. It SHALL allow users to preview and apply memory stream templates.

#### Scenario: Apply template
- **WHEN** the user selects a template card and confirms
- **THEN** the app applies the styling and layout guidelines to future memories.

### Requirement: Personalization & Security Rituals
A Personalization tab SHALL centralize theme, privacy rituals, and AI-generated summaries. It SHALL expose schedule options for timed review or auto-destruction of memories.

#### Scenario: Schedule timed review
- **WHEN** the user chooses a memory and sets a review reminder
- **THEN** the system schedules a local reminder while keeping content encrypted locally.
