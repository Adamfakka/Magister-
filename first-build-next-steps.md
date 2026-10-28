# Local school demo: remaining work

## Delivered
- Native Dutch agenda and sliding drawer based on the supplied screenshots, with navy headers, dark lists and orange title dots.
- Editable repeating weekly lessons, homework and grades; existing storage keys and saved records retained.
- Absence landing/overview, Meldingen and Lesregistraties, recovered status and local editors.
- Message inbox, sent and deleted folders; editable sender, recipient, date, subject, body, unread and important status. Composition saves locally, not to a school.
- Study guides and materials with editable notes; announcements and assignments with empty states and assignment status filtering.
- Resource-folder navigation and editable text records.
- Editable local profile reflected in the drawer, dark/light/device theme settings and About.
- Local-demo notices; no fabricated school synchronization timestamps, official publisher identity or login.
- New store decode-failure protection retains original stored bytes and disables persistence rather than replacing data with examples.

## Assumptions and limitations
- Sample identities and school records are fictional. No official Magister account or school connection.
- Layout follows the screenshots but has not been verified as pixel-exact. Unread styling reflects the actual local message state.
- Schedule repeats weekly; date-specific exceptions, holidays, conflicts and cancellations remain to build.
- Student/class lists beyond the single profile and field-level editing permissions are not implemented.
- Resources and materials hold text notes only. Digital-book licenses and actual file uploads are not connected.
- No backend sync, authentication, notifications or export.

## Verification completed
- Integrated source built and ran in the managed iPhone simulator.
- Inspected screenshots of agenda, grades, profile/editor, inbox/message editor and assignment status sheet/empty state.
- Read-only review completed; reported persistence hazards addressed in the new stores.
- Earlier agenda test: temporary lesson added, reopened, confirmed-deleted and removal verified; original records retained.
- Earlier calendar test: Saturday 31 October 2026 selected and empty state verified; Vandaag returned to Monday 26 October 2026.
- Runtime logs showed recovery from initial SwiftData directory warnings; no app crash observed.

## Verification still required
- Reliable end-to-end navigation pass: recent simulator responses changed screens independently of the requested action, and one screenshot differed from its element tree. Do not count those responses as successful CRUD tests.
- Absence add/edit/delete, both tabs and recovered status.
- Message compose/save/edit, all folders, trash/restore and confirmed permanent deletion, using temporary test records only.
- Library notes add/edit/delete, assignment filtered add, resource-folder transitions, material banner and Controle.
- Profile save reflected in drawer; dark/light/device appearance switching.
- Persistence across relaunch without resetting app data.
- Dynamic Type, VoiceOver, iPhone Duo and other device sizes.
- Updated navigation demo is configured but not yet verified end-to-end.
