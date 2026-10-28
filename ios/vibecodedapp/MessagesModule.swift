import SwiftUI
import Foundation
import Observation

// Standalone local demo. Integrate with MessagesModule(onMenu: { ... }).
// No SchoolStore dependency, network requests, or real attachment files.
@MainActor
struct MessagesModule: View {
    let onMenu: () -> Void

    @State private var store = LocalMessagesStore()
    @State private var folder: LocalMessageFolder?
    @State private var selectedID: UUID?
    @State private var editor: LocalMessageEditorRequest?
    @State private var permanentDeleteID: UUID?
    @State private var actionError: String?

    init(onMenu: @escaping () -> Void) {
        self.onMenu = onMenu
    }

    private var selectedMessage: LocalMessageRecord? {
        store.messages.first { $0.id == selectedID }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if let message = selectedMessage {
                detail(message)
            } else if let folder {
                folderContents(folder)
            } else {
                folders
            }
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SchoolTheme.background)
        .foregroundStyle(SchoolTheme.ink)
        .sheet(item: $editor) { request in
            LocalMessageEditor(request: request) { record in
                try store.save(record)
                if request.isCompose {
                    folder = .sent
                    selectedID = nil
                }
            }
        }
        .alert("Bericht definitief verwijderen?", isPresented: Binding(
            get: { permanentDeleteID != nil },
            set: { if !$0 { permanentDeleteID = nil } }
        )) {
            Button("Annuleren", role: .cancel) { permanentDeleteID = nil }
            Button("Definitief verwijderen", role: .destructive) {
                guard let id = permanentDeleteID else { return }
                perform {
                    try store.removePermanently(id)
                    if selectedID == id { selectedID = nil }
                }
                permanentDeleteID = nil
            }
        } message: {
            Text("Dit lokale bericht verdwijnt voorgoed. Je kunt dit niet ongedaan maken.")
        }
        .alert("Wijziging niet opgeslagen", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "Probeer het opnieuw.")
        }
    }

    private var header: some View {
        ZStack {
            Text(selectedMessage != nil ? "Bericht" : (folder?.title ?? "Mappen"))
                .font(.system(size: 18, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, folder == nil ? 55 : 100)
                .frame(maxWidth: .infinity)
            HStack(spacing: 0) {
                if folder == nil {
                    Button(action: onMenu) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 23, weight: .regular))
                            .frame(width: 50, height: 50)
                    }
                    .accessibilityLabel("Menu openen")
                    .accessibilityIdentifier("messages-menu-button")
                } else {
                    Button {
                        if selectedID != nil {
                            selectedID = nil
                        } else {
                            folder = nil
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 22, weight: .regular))
                            Text(selectedID != nil ? "Terug" : "Mappen")
                                .font(.system(size: 17))
                                .underline()
                        }
                        .padding(.horizontal, 9)
                        .frame(height: 50)
                    }
                    .accessibilityIdentifier("messages-back-button")
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: 50)
        .foregroundStyle(.white)
        .background(SchoolTheme.navy.ignoresSafeArea(edges: .top))
        .buttonStyle(.plain)
    }

    private var folders: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(LocalMessageFolder.allCases) { item in
                    Button {
                        folder = item
                        selectedID = nil
                    } label: {
                        HStack(spacing: 18) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 21))
                                .foregroundStyle(SchoolTheme.ink.opacity(0.4))
                                .frame(width: 24)
                            Text(item.title)
                                .font(.system(size: 21))
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 17)
                        .frame(minHeight: 60)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("messages-folder-\(item.rawValue)")
                }
            }
        }
    }

    private func folderContents(_ folder: LocalMessageFolder) -> some View {
        let records = store.records(in: folder)
        return ZStack(alignment: .bottomTrailing) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if records.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: folder.symbol)
                                .font(.system(size: 30))
                                .foregroundStyle(SchoolTheme.ink.opacity(0.4))
                            Text("Deze map is leeg")
                                .font(.headline)
                            Text(folder == .trash
                                 ? "Verwijderde berichten verschijnen hier."
                                 : "Maak een lokaal bericht met de blauwe knop.")
                                .font(.subheadline)
                                .foregroundStyle(SchoolTheme.ink.opacity(0.55))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 70)
                        .padding(.horizontal, 24)
                    }
                    ForEach(records) { message in
                        Button {
                            perform {
                                try store.markRead(message.id)
                                selectedID = message.id
                            }
                        } label: {
                            LocalMessageRow(message: message)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("messages-row-\(message.id.uuidString)")
                        .accessibilityLabel("\(message.correspondent), \(message.subject), \(message.isUnread ? "ongelezen" : "gelezen")")
                    }
                }
                .padding(.bottom, 90)
            }
            Button {
                editor = .compose()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 29, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(LocalMessagePalette.accent, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 16)
            .padding(.bottom, 16)
            .accessibilityLabel("Nieuw lokaal bericht")
            .accessibilityIdentifier("messages-compose-button")
        }
    }

    private func detail(_ message: LocalMessageRecord) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        LocalMessageAvatar(name: message.correspondent)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(message.subject)
                                .font(.system(size: 22, weight: .semibold))
                            if message.isImportant {
                                Label("Belangrijk", systemImage: "exclamationmark")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            if message.isUnread {
                                Text("Ongelezen")
                                    .font(.caption)
                                    .foregroundStyle(LocalMessagePalette.accent)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 9) {
                        metadata("Van", value: message.sender)
                        metadata("Aan", value: message.recipient)
                        metadata("Datum", value: message.date.formatted(
                            .dateTime.day().month(.wide).year().hour().minute().locale(Locale(identifier: "nl_NL"))
                        ))
                    }
                    .font(.system(size: 14))
                    Rectangle()
                        .fill(SchoolTheme.divider)
                        .frame(height: 0.5)
                    Text(message.body)
                        .font(.system(size: 16))
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                    // This demo intentionally has no files: never show a paperclip
                    // simply because the subject mentions slides or worksheets.
                }
                .padding(18)
            }
            HStack(spacing: 12) {
                Button {
                    editor = .edit(message)
                } label: {
                    Label("Bewerken", systemImage: "pencil")
                }
                .accessibilityIdentifier("messages-edit-button")
                Spacer(minLength: 0)
                if message.folder == .trash {
                    Button {
                        perform {
                            let destination = message.originalFolder ?? .inbox
                            try store.restore(message.id)
                            folder = destination
                            selectedID = nil
                        }
                    } label: {
                        Label("Herstellen", systemImage: "arrow.uturn.backward")
                    }
                    .accessibilityIdentifier("messages-restore-button")
                    Button(role: .destructive) {
                        permanentDeleteID = message.id
                    } label: {
                        Image(systemName: "trash")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Definitief verwijderen")
                    .accessibilityIdentifier("messages-permanent-delete-button")
                } else {
                    Button(role: .destructive) {
                        perform {
                            try store.moveToTrash(message.id)
                            selectedID = nil
                        }
                    } label: {
                        Label("Verwijderen", systemImage: "trash")
                    }
                    .accessibilityIdentifier("messages-delete-button")
                }
            }
            .font(.system(size: 14))
            .tint(LocalMessagePalette.accent)
            .buttonStyle(.borderless)
            .frame(minHeight: 48)
            .padding(.horizontal, 16)
            .background(SchoolTheme.navy.opacity(0.55))
        }
    }

    private func metadata(_ label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .foregroundStyle(SchoolTheme.ink.opacity(0.55))
                .frame(width: 48, alignment: .leading)
            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    private var footer: some View {
        VStack(spacing: 4) {
            if let error = store.loadError {
                Text(error)
                    .foregroundStyle(.orange)
            }
            Text("Lokale demo · fictieve berichten · niets wordt verstuurd")
                .foregroundStyle(SchoolTheme.ink.opacity(0.5))
        }
        .font(.system(size: 10))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(SchoolTheme.background)
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            actionError = error.localizedDescription
            print("[MessagesModule] Local mutation failed: \(error.localizedDescription)")
        }
    }
}

private enum LocalMessagePalette {
    static let accent = Color(red: 0, green: 0.61, blue: 0.84)
    static let avatar = Color(red: 0.70, green: 0.89, blue: 0.98)
    static var muted: Color { SchoolTheme.ink.opacity(0.5) }
}

private enum LocalMessageFolder: String, CaseIterable, Codable, Identifiable {
    case inbox, sent, trash

    var id: String { rawValue }
    var title: String {
        switch self {
        case .inbox: return "Postvak IN"
        case .sent: return "Verzonden items"
        case .trash: return "Verwijderde items"
        }
    }
    var symbol: String {
        switch self {
        case .inbox: return "tray"
        case .sent: return "paperplane"
        case .trash: return "trash"
        }
    }
}

private struct LocalMessageRecord: Identifiable, Codable {
    var id = UUID()
    var folder: LocalMessageFolder
    var originalFolder: LocalMessageFolder?
    var sender: String
    var recipient: String
    var date: Date
    var subject: String
    var body: String
    var isUnread: Bool
    var isImportant: Bool

    // Sent messages display the recipient, like the supplied sent-folder reference.
    var correspondent: String {
        (folder == .sent || (folder == .trash && originalFolder == .sent)) ? recipient : sender
    }

    var validationMessage: String? {
        if sender.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Vul een afzender in." }
        if recipient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Vul een ontvanger in." }
        if subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Vul een onderwerp in." }
        if body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Schrijf een bericht." }
        return nil
    }
}

@MainActor
@Observable
private final class LocalMessagesStore {
    private(set) var messages: [LocalMessageRecord] = []
    private(set) var loadError: String?
    @ObservationIgnored private let defaults: UserDefaults
    private static let storageKey = "magister.local-editable-messages.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey) {
            do {
                messages = try JSONDecoder().decode([LocalMessageRecord].self, from: data)
            } catch {
                // Keep the stored bytes intact; don't replace a failed decode with seeds.
                loadError = "Opgeslagen berichten konden niet worden geladen."
                print("[MessagesModule] Decode failed: \(error.localizedDescription)")
            }
        } else {
            do {
                try commit(Self.seededMessages())
            } catch {
                loadError = "Voorbeeldberichten konden niet worden opgeslagen."
                print("[MessagesModule] Initial save failed: \(error.localizedDescription)")
            }
        }
    }

    func records(in folder: LocalMessageFolder) -> [LocalMessageRecord] {
        messages.filter { $0.folder == folder }.sorted {
            if $0.date == $1.date { return $0.id.uuidString < $1.id.uuidString }
            return $0.date > $1.date
        }
    }

    func save(_ message: LocalMessageRecord) throws {
        if let validation = message.validationMessage {
            throw LocalMessageError.invalid(validation)
        }
        var record = message
        record.sender = record.sender.trimmingCharacters(in: .whitespacesAndNewlines)
        record.recipient = record.recipient.trimmingCharacters(in: .whitespacesAndNewlines)
        record.subject = record.subject.trimmingCharacters(in: .whitespacesAndNewlines)
        var updated = messages
        if let index = updated.firstIndex(where: { $0.id == record.id }) {
            updated[index] = record
        } else {
            updated.append(record)
        }
        try commit(updated)
        print("[MessagesModule] Saved local message in \(record.folder.rawValue)")
    }

    func markRead(_ id: UUID) throws {
        guard var message = messages.first(where: { $0.id == id }) else { return }
        guard message.isUnread else { return }
        message.isUnread = false
        try save(message)
    }

    func moveToTrash(_ id: UUID) throws {
        guard var message = messages.first(where: { $0.id == id }), message.folder != .trash else { return }
        message.originalFolder = message.folder
        message.folder = .trash
        try save(message)
    }

    func restore(_ id: UUID) throws {
        guard var message = messages.first(where: { $0.id == id }), message.folder == .trash else { return }
        message.folder = message.originalFolder == .sent ? .sent : .inbox
        message.originalFolder = nil
        try save(message)
    }

    func removePermanently(_ id: UUID) throws {
        guard messages.contains(where: { $0.id == id && $0.folder == .trash }) else { return }
        try commit(messages.filter { $0.id != id })
        print("[MessagesModule] Permanently deleted local message")
    }

    private func commit(_ updated: [LocalMessageRecord]) throws {
        // A decode error is not permission to overwrite the previous saved collection.
        guard loadError == nil else {
            throw LocalMessageError.invalid("De opgeslagen berichten zijn niet leesbaar. Ze blijven bewaard; wijzigingen zijn nu niet mogelijk.")
        }
        let data = try JSONEncoder().encode(updated)
        defaults.set(data, forKey: Self.storageKey)
        messages = updated
    }

    private static func seededMessages() -> [LocalMessageRecord] {
        let now = Date()
        func daysAgo(_ days: Int) -> Date {
            Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
        }
        func record(_ folder: LocalMessageFolder, _ name: String, _ subject: String,
                    _ days: Int, _ body: String, unread: Bool = false,
                    important: Bool = false, original: LocalMessageFolder? = nil) -> LocalMessageRecord {
            let outgoing = folder == .sent || original == .sent
            return LocalMessageRecord(
                folder: folder, originalFolder: original,
                sender: outgoing ? "Sam Voorbeeld (leerling)" : name,
                recipient: outgoing ? name : "Sam Voorbeeld (leerling)",
                date: daysAgo(days), subject: subject, body: body,
                isUnread: unread, isImportant: important
            )
        }
        return [
            record(.inbox, "T. van Dalen (TVD)", "Toets verplaatst", 0,
                   "Beste Sam,\n\nDe oefentoets is verplaatst naar donderdag. Neem je schrift en rekenmachine mee.\n\nGroet,\nT. van Dalen", important: true),
            record(.inbox, "T. van Dalen (TVD)", "Nieuwe planning", 1,
                   "Beste klas,\n\nDeze week bespreken we hoofdstuk 3. De nieuwe planning staat in je agenda.\n\nGroet,\nT. van Dalen"),
            record(.inbox, "B. de Vries (BDV)", "Werkbladen hoofdstuk 2", 2,
                   "Hoi Sam,\n\nDe werkbladen liggen klaar in het lokaal. Vraag er bij de volgende les naar. Er zijn geen bestanden bij dit voorbeeldbericht."),
            record(.inbox, "A. Groen (AGR)", "Oefenen voor de toets", 2,
                   "Beste Sam,\n\nMaak opdracht 4 tot en met 8 als voorbereiding op de toets. We bespreken de antwoorden in de les."),
            record(.inbox, "B. de Vries (BDV)", "Video's van hoofdstuk 2", 3,
                   "Hoi Sam,\n\nTijdens de volgende les bekijken we samen de uitlegvideo's van hoofdstuk 2.", unread: true),
            record(.inbox, "K. Meijer (KME)", "Oefenresultaten verwerkt", 7,
                   "Beste Sam,\n\nJe oefenresultaten zijn besproken. Goed gewerkt! Bekijk je eigen doelen nog eens voor de volgende les."),
            record(.inbox, "S. Vermeer (SVE)", "Gymles", 8,
                   "Morgen is de gymles buiten. Neem geschikte schoenen en een jas mee."),
            record(.inbox, "M. Bakker (MBA)", "Nooduitgang", 9,
                   "Beste klas,\n\nHoud de nooduitgang vrij van tassen. We nemen de afspraken morgen nog even door.", important: true),
            record(.inbox, "K. Bos (KBO)", "Computers", 10,
                   "Volgende week werken we met de computers in lokaal 12. Neem je eigen aantekeningen mee."),
            record(.sent, "S. Jansen (SJA)", "Vraag over de schrijftoets", 1,
                   "Beste meneer Jansen,\n\nKan ik de oefenopdracht tijdens de volgende les met u bespreken?\n\nGroet,\nSam"),
            record(.sent, "C. Geurts (CGE)", "RE: nieuwe afspraak", 4,
                   "Beste mevrouw Geurts,\n\nDank voor uw bericht. Donderdag na de les past goed.\n\nGroet,\nSam"),
            record(.sent, "A. van den Berg (AVB)", "Planning", 6,
                   "Beste meneer Van den Berg,\n\nIk heb mijn planning aangepast. Kunt u er tijdens het mentoruur naar kijken?\n\nGroet,\nSam"),
            record(.sent, "M. Smit (MSM)", "Fijn weekend!", 9,
                   "Dank voor de hulp deze week. Fijn weekend!\n\nSam"),
            record(.trash, "L. Visser (LVI)", "Brieven", 30,
                   "Dit is een fictief verwijderd bericht. Je kunt het herstellen naar Postvak IN of definitief verwijderen.", original: .inbox),
            record(.trash, "A. Groen (AGR)", "Oude afspraak", 40,
                   "Beste mevrouw Groen,\n\nDit voorbeeld van een verzonden bericht is verwijderd. Herstellen zet het terug in Verzonden items.\n\nGroet,\nSam", original: .sent)
        ]
    }
}

private enum LocalMessageError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case .invalid(let message): return message }
    }
}

private struct LocalMessageAvatar: View {
    let name: String

    private var initials: String {
        let clean = name.components(separatedBy: "(").first ?? name
        let parts = clean.split(whereSeparator: { $0.isWhitespace || $0 == "." || $0 == "-" })
        let letters = [parts.first?.first, parts.count > 1 ? parts.last?.first : nil]
            .compactMap { $0 }
        return String(letters).uppercased()
    }

    var body: some View {
        Text(initials)
            .font(.system(size: 23, weight: .regular))
            .foregroundStyle(LocalMessagePalette.accent)
            .frame(width: 52, height: 52)
            .background(LocalMessagePalette.avatar, in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 0.75))
            .accessibilityHidden(true)
    }
}

private struct LocalMessageRow: View {
    let message: LocalMessageRecord

    private var dateLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(message.date) {
            return message.date.formatted(.dateTime.hour().minute().locale(Locale(identifier: "nl_NL")))
        }
        if calendar.component(.year, from: message.date) == calendar.component(.year, from: Date()) {
            return message.date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "nl_NL")))
        }
        return message.date.formatted(.dateTime.day().month(.twoDigits).year().locale(Locale(identifier: "nl_NL")))
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(message.isUnread ? LocalMessagePalette.accent : SchoolTheme.ink.opacity(0.92))
                .frame(width: 4)
            HStack(spacing: 10) {
                LocalMessageAvatar(name: message.correspondent)
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(message.correspondent)
                            .font(.system(size: 19, weight: message.isUnread ? .bold : .regular))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(dateLabel)
                            .font(.system(size: 14, weight: message.isUnread ? .bold : .regular))
                            .foregroundStyle(LocalMessagePalette.muted)
                            .fixedSize()
                    }
                    HStack(spacing: 7) {
                        Text(message.subject)
                            .font(.system(size: 15, weight: message.isUnread ? .bold : .regular))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if message.isImportant {
                            Image(systemName: "exclamationmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.red)
                                .accessibilityLabel("Belangrijk")
                        }
                    }
                }
            }
            .padding(.leading, 11)
            .padding(.trailing, 16)
            .padding(.vertical, 15)
        }
        .frame(minHeight: 87)
        .background(SchoolTheme.background)
        .overlay(alignment: .bottom) {
            Rectangle().fill(SchoolTheme.divider).frame(height: 0.5)
        }
        .contentShape(Rectangle())
    }
}

private struct LocalMessageEditorRequest: Identifiable {
    let id = UUID()
    var record: LocalMessageRecord
    var isCompose: Bool

    static func compose() -> Self {
        Self(record: LocalMessageRecord(
            folder: .sent, sender: "Sam Voorbeeld (leerling)", recipient: "",
            date: Date(), subject: "", body: "", isUnread: false, isImportant: false
        ), isCompose: true)
    }

    static func edit(_ record: LocalMessageRecord) -> Self {
        Self(record: record, isCompose: false)
    }
}

@MainActor
private struct LocalMessageEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: LocalMessageRecord
    @State private var saveError: String?
    @State private var confirmsDiscard = false
    let request: LocalMessageEditorRequest
    let onSave: (LocalMessageRecord) throws -> Void

    init(request: LocalMessageEditorRequest, onSave: @escaping (LocalMessageRecord) throws -> Void) {
        self.request = request
        self.onSave = onSave
        _draft = State(initialValue: request.record)
    }

    private var hasChanges: Bool {
        let original = request.record
        return draft.sender != original.sender || draft.recipient != original.recipient
            || draft.date != original.date || draft.subject != original.subject
            || draft.body != original.body || draft.isUnread != original.isUnread
            || draft.isImportant != original.isImportant
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Berichtgegevens") {
                    TextField("Afzender", text: $draft.sender)
                        .accessibilityIdentifier("messages-editor-sender")
                    TextField("Ontvanger", text: $draft.recipient)
                        .accessibilityIdentifier("messages-editor-recipient")
                    DatePicker("Datum", selection: $draft.date, displayedComponents: [.date, .hourAndMinute])
                        .accessibilityIdentifier("messages-editor-date")
                    TextField("Onderwerp", text: $draft.subject)
                        .accessibilityIdentifier("messages-editor-subject")
                }
                Section("Inhoud") {
                    TextEditor(text: $draft.body)
                        .frame(minHeight: 180)
                        .accessibilityLabel("Berichttekst")
                        .accessibilityIdentifier("messages-editor-body")
                }
                Section("Status") {
                    Toggle("Ongelezen", isOn: $draft.isUnread)
                        .accessibilityIdentifier("messages-editor-unread")
                    Toggle("Belangrijk", isOn: $draft.isImportant)
                        .accessibilityIdentifier("messages-editor-important")
                }
                Section {
                    if let validation = draft.validationMessage {
                        Text(validation)
                            .foregroundStyle(.orange)
                    }
                    if let saveError {
                        Text(saveError)
                            .foregroundStyle(.red)
                    }
                    Text(request.isCompose
                         ? "Lokale demo: opslaan plaatst dit bericht in Verzonden items. Er wordt niets verstuurd."
                         : "Je wijzigt alleen dit fictieve bericht op dit apparaat.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(request.isCompose ? "Nieuw bericht" : "Bericht bewerken")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleren") {
                        if hasChanges { confirmsDiscard = true } else { dismiss() }
                    }
                    .accessibilityIdentifier("messages-editor-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Opslaan") {
                        do {
                            try onSave(draft)
                            dismiss()
                        } catch {
                            saveError = error.localizedDescription
                            print("[MessagesModule] Editor save failed: \(error.localizedDescription)")
                        }
                    }
                    .disabled(draft.validationMessage != nil)
                    .accessibilityIdentifier("messages-editor-save")
                }
            }
            .confirmationDialog("Wijzigingen weggooien?", isPresented: $confirmsDiscard, titleVisibility: .visible) {
                Button("Wijzigingen weggooien", role: .destructive) { dismiss() }
                Button("Verder bewerken", role: .cancel) { }
            }
        }
        .environment(\.locale, Locale(identifier: "nl_NL"))
        .tint(LocalMessagePalette.accent)
        .interactiveDismissDisabled(hasChanges)
    }
}
