# Local School Demo

A native SwiftUI iPhone app with a Dutch, Magister-inspired interface based on the user's supplied screenshots. This is an independent local demo, not an official Magister client.

## Features
- Navy headers, dark lists, orange title dots and a sliding navigation drawer.
- Calendar date selection, seven-day navigation and a repeating, editable weekly agenda with teachers, rooms, periods, times and homework.
- Homework filtering and locally editable grades with description, value, weighting and date.
- Absence overview with Meldingen and Lesregistraties, local editing and recovered status.
- Message folders, unread/important styling, details, local composition, editing, trash and restore. No messages are sent externally.
- Study guides and teaching-material lists with editable text notes.
- Announcements and assignments; assignment status filtering and reference-style empty states.
- Resources grouped into Mijn ELO-documenten, Gedeelde documenten, Portfolio documenten and Prullenbak. Resources are text notes, not uploaded files.
- Editable local profile, dark/light/device appearance settings and an independent-demo About screen.
- Local JSON persistence in UserDefaults. Existing lesson/grade keys are unchanged. New module stores preserve their original bytes and block writes when decoding fails.

## Structure
- `ios/vibecodedapp/ContentView.swift`: root navigation, drawer, agenda, calendar and grades.
- `ios/vibecodedapp/SchoolStore.swift`: schedule, grades and date navigation.
- `ios/vibecodedapp/Editors.swift`: lesson/grade forms and validation.
- `ios/vibecodedapp/AbsenceModule.swift`: absence screens, editors and local store.
- `ios/vibecodedapp/MessagesModule.swift`: folders, message screens, editor and local store.
- `ios/vibecodedapp/LibraryModule.swift`: study guides, assignments, materials, resources and local text storage.
- `ios/vibecodedapp/ProfileModule.swift`: profile, theme settings and About.
- `ios/vibecodedapp/Theme.swift`: adaptive colors with the reference navy/blue palette.

## Verification
The integrated source built and ran in the managed iPhone simulator. Screenshots were inspected for the dark agenda, grades, profile, profile editor, message inbox/editor, and assignment filter/empty state. A read-only code review found persistence hazards in the new stores; guards were added to preserve stored data after failed decoding.

Earlier tests verified homework filtering, temporary lesson creation/reopening/confirmed deletion, calendar selection of Saturday 31 October 2026, and Today returning to Monday 26 October 2026. The temporary lesson was removed.

The latest navigation-testing pass returned inconsistent screen states: some screenshots/element trees did not correspond to the immediately preceding action. New module CRUD and relaunch persistence therefore are not verified end-to-end. Appearance changes, remaining module screens, Dynamic Type, VoiceOver and other devices still need a reliable interactive test pass. Runtime logs showed recovery from initial SwiftData directory warnings, with no observed app crash.

See `first-build-next-steps.md` for remaining work and limitations.
