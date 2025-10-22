## ADDED Requirements
### Requirement: Moments Home Hub
The system SHALL present a home hub merging encrypted memory stream and chat insights, showing recent artifacts (photos, voice, text) with emotion tags and quick capture actions.

#### Scenario: View recent moments
- **WHEN** partners open the Home tab
- **THEN** the latest encrypted artifacts display in chronological order with emotion chips.

#### Scenario: Capture new moment
- **WHEN** a user taps “Add Memory”
- **THEN** the app opens capture options for text, photo, or voice memo stored with encryption.

### Requirement: Full-Screen Chat Experience
The chat view SHALL extend edge-to-edge with customizable gradient/photo backgrounds, themed message bubbles, and reactions aligned with the encrypted moments style.

#### Scenario: Customize background
- **WHEN** a user selects a background in chat personalization
- **THEN** the chat updates immediately and persists the choice per relationship.

### Requirement: Explorer Discovery
The Explorer tab SHALL showcase curated templates, rituals, and inspiration cards using gradient visuals and emotion chips, allowing preview and application to memory streams.

#### Scenario: Apply template
- **WHEN** a user selects a template card
- **THEN** the chosen template styles future memories until changed.

### Requirement: Personalization & Security Rituals
The Personalization tab SHALL provide theme management, encrypted rituals (timed review, auto-destroy), and AI-generated summary stubs, while keeping all data local.

#### Scenario: Schedule timed review
- **WHEN** a user sets a reminder for a memory
- **THEN** the system schedules a local notification without syncing unencrypted data.
