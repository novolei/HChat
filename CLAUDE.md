<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.


Project Overview

  HChat is a full-stack encrypted chat application with iOS (SwiftUI) frontend and self-hosted backend infrastructure.

  ## Frontend (iOS/SwiftUI)
  
  **Key Features:**
  - Real-time WebSocket chat with command parsing (/join, /nick, /me, /clear, /help)
  - End-to-end encryption using AES-GCM with PBKDF2 key derivation
  - File attachments with MinIO/S3 pre-signed URL upload
  - Rich text rendering (code blocks, links, @mentions, /me actions)
  - Notification system with haptic feedback for @mentions
  - Channel management with join/leave functionality
  - Multiple attachment types: images, videos, audio, files

  **Architecture:**
  - SwiftUI for user interface
  - URLSessionWebSocketTask for real-time communication
  - Modular structure: App/, Core/, UI/, Utils/, Views/
  - Encryption layer for secure messaging
  - MinIO integration for file storage
  - Modern Swift concurrency (@MainActor, async/await)

  ## Backend (Self-hosted at hc.go-lv.com)
  
  **Infrastructure Stack:**
  - **chat-gateway**: Node.js WebSocket server (port 10080)
    - Handles real-time message routing
    - Zero-knowledge design (forwards encrypted text without decryption)
    - Room-based broadcast with automatic cleanup
  
  - **message-service**: Node.js REST API (port 10081)
    - MinIO pre-signed URL generation for file uploads
    - LiveKit token generation for WebRTC sessions
    - Health check endpoint
  
  - **MinIO**: S3-compatible object storage (ports 10090/10091)
    - Stores encrypted files
    - Pre-signed URL direct upload/download
    - Web console for management
  
  - **LiveKit**: WebRTC SFU server (ports 17880, 51000-52000)
    - Real-time audio/video routing
    - Frame-level E2EE support
    - Client-side encryption (server can't decrypt)
  
  - **coturn**: TURN/STUN server (ports 14788, 53100-53200)
    - NAT traversal for WebRTC
    - Relay for restrictive networks

  **Domains:**
  - hc.go-lv.com → Chat Gateway + API
  - livekit.hc.go-lv.com → WebRTC signaling
  - s3.hc.go-lv.com → MinIO S3 API
  - mc.s3.hc.go-lv.com → MinIO console

  **Security Model:**
  - All text messages encrypted client-side before WebSocket transmission
  - Files encrypted before upload to MinIO
  - LiveKit uses frame-level encryption (SFU only forwards ciphertext)
  - Backend never sees plaintext (zero-knowledge architecture)

  **Development Setup:**
  - iOS: Xcode project with SwiftUI, iOS 14+
  - Backend: Docker Compose orchestration
  - Deployment: FASTPANEL with Nginx reverse proxy
  - File structure:
    - /HChat → iOS app source
    - /HCChatBackEnd → Backend services & config

⏺ The project is well-structured with OpenSpec for specification-driven development. Currently, there are no active changes in the OpenSpec system, and the project follows a clean
  architecture with separation of concerns.

  What would you like to work on next? I can help you with:
  - Creating new features or improvements
  - Bug fixes or code optimization
  - Setting up development environment
  - Creating OpenSpec proposals for changes
  - Code review or analysis
<!-- OPENSPEC:END -->