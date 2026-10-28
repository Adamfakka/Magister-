# Vibecode Workspace

This workspace contains a native iOS app and backend server.

<projects>
  ios/      — SwiftUI iOS app (built & run in Xcode simulator via Vibecode)
  backend/  — Hono API server (port 3000)
</projects>

<environment_variables>
  IMPORTANT: Use the correct env vars for each platform to avoid deployment failures.

  Backend (in backend/src/*.ts):
  - Use `env.BACKEND_URL` from "./env" (validated via Zod)
  - NEVER use process.env directly without Zod validation
  - These are available at runtime: BACKEND_URL, PORT, NODE_ENV

  iOS (in Swift source):
  - Env vars are read from AppConfig.plist (bundled at build time from ios/.env.managed + ios/.env)
  - iPhone installs and App Store builds also bundle ios/.env.production, which deploy writes with the deployed backend URL
  - Available keys: IOS_PROJECT_NAME, IOS_VIBECODE_PROJECT_ID, IOS_BASE_URL, IOS_BACKEND_URL
  - Read them at runtime: `AppConfig.string("IOS_BACKEND_URL") ?? ""`
  - Do NOT hardcode localhost — use IOS_BACKEND_URL

  Testing backend endpoints:
  - Use $BACKEND_URL environment variable in cURL commands
  - Do NOT use localhost
</environment_variables>

<coordination>
  When a feature needs both frontend and backend:
  1. Design the API contract (endpoint, request/response shape) in backend/src/types.ts
  2. Implement backend route first, test using cURL with $BACKEND_URL (do not use localhost)
  3. Implement iOS client second
  4. Test the integration
</coordination>

<startup_triage>
  On every user message, you will receive a <build_error_summary> block (plus raw xcodebuild/ios/backend logs).
  If it contains build-blocking errors (e.g. "Cannot find type", "Value of type has no member", "Build FAILED"), fix those first.
</startup_triage>

<skills>
  Project skills:
  - ios-developer: Changes to the iOS app (read ios/CLAUDE.md)
  - backend-developer: Changes to the backend API (read backend/CLAUDE.md)

  Shared skills:
  - database-auth: Set up Prisma + Better Auth for user accounts and data persistence
  - apple-intelligence: On-device AI with Foundation Models, Siri actions, and Shortcuts in the native Swift app.
  - vibecode-apis: Read before adding any AI or third-party API (LLMs, image, video, voice, search, data) or generating media for the project.
  - upload-assets: Vibecode Storage. Use for ANY photo, image, profile picture, camera pick, video, audio, PDF, or attachment the app uploads or keeps, and to move base64 images out of the database. Never write uploads to local disk or the database.
  - ios-widgets: Use this skill when the user asks you to add an iOS widget (WidgetKit extension) or share data between the main app and a widget via App Groups.

  Frontend only skills:
  - frontend-design: Create distinctive, production-grade SwiftUI interfaces following iOS Human Interface Guidelines and liquid glass design principles. Use when building iOS screens, components, or styling any SwiftUI UI.
</skills>

<environment>
  System manages git and automatically builds after your turn, including compiler-repair retries.
  DO NOT manage git yourself.
  Use the `simulator` MCP tools during feature work to exercise changed UI or behavior on the current source;
  follow the ios-developer skill for interaction, evidence, and release steps.
  On automatic compiler-repair turns, fix the reported errors and finish so the backend can rebuild.
  The user views the app through the iOS simulator via Vibecode WebApp.
  The user cannot see code or terminal. Do everything for them.
  Communicate in an easy to understand manner for non-technical users.
  Be concise and don't talk too much.
</environment>
