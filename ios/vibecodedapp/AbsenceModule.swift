import SwiftUI
import Observation
import Foundation
import UIKit

// Self-contained local demo. This module never reads or changes SchoolStore.
private enum AbsenceSection: String, Codable, CaseIterable, Identifiable {
    case notifications = "Meldingen"
    case lessons = "Lesregistraties"

    var id: String { rawValue }
}

private struct LocalAbsence: Identifiable, Codable {
    var id = UUID()
    var section: AbsenceSection
    var start: Date
    var end: Date
    var allDay = false
    var reason: String
    var recovered = false
    var subject = ""
    var firstPeriod = 1
    var lastPeriod = 1
    var code = "Z"

    var periodLabel: String {
        firstPeriod == lastPeriod
            ? "\(firstPeriod)e uur"
            : "\(firstPeriod)e - \(lastPeriod)e uur"
    }
}

private struct AbsenceSnapshot: Codable {
    var records: [LocalAbsence]
    var overviewIsOpen: Bool
    var selectedSection: AbsenceSection
}

@MainActor
@Observable
private final class LocalAbsenceStore {
    static let shared = LocalAbsenceStore()
    private static let storageKey = "magister.localAbsenceModule.v1"

    private(set) var records: [LocalAbsence] = []
    var overviewIsOpen = false {
        didSet { persist() }
    }
    var selectedSection: AbsenceSection = .notifications {
        didSet { persist() }
    }
    private(set) var storageWarning: String?
    private(set) var isReadOnly = false

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey) {
            do {
                let saved = try JSONDecoder().decode(AbsenceSnapshot.self, from: data)
                records = saved.records
                overviewIsOpen = saved.overviewIsOpen
                selectedSection = saved.selectedSection
            } catch {
                print("[AbsenceModule] Could not restore local demo: \(error)")
                records = Self.seedRecords()
                isReadOnly = true
                storageWarning = "Opgeslagen gegevens konden niet worden geladen. Voorbeelden zijn alleen-lezen; je oorspronkelijke gegevens blijven bewaard."
            }
        } else {
            records = Self.seedRecords()
        }
    }

    func save(_ record: LocalAbsence) {
        guard !isReadOnly else {
            print("[AbsenceModule] Save blocked to preserve unreadable stored data")
            return
        }
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index] = record
        } else {
            records.append(record)
        }
        persist()
        print("[AbsenceModule] Saved local \(record.section.rawValue) record")
    }

    func delete(_ record: LocalAbsence) {
        guard !isReadOnly else {
            print("[AbsenceModule] Delete blocked to preserve unreadable stored data")
            return
        }
        records.removeAll { $0.id == record.id }
        persist()
        print("[AbsenceModule] Deleted local absence record")
    }

    func toggleRecovered(_ record: LocalAbsence) {
        guard !isReadOnly else {
            print("[AbsenceModule] Status change blocked to preserve unreadable stored data")
            return
        }
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return }
        records[index].recovered.toggle()
        persist()
    }

    func records(in section: AbsenceSection) -> [LocalAbsence] {
        records.filter { $0.section == section }.sorted {
            if $0.start == $1.start { return $0.id.uuidString < $1.id.uuidString }
            return $0.start > $1.start
        }
    }

    private func persist() {
        // Navigation may still change in memory, but must never replace bytes
        // we failed to decode with a fictional seed snapshot.
        guard !isReadOnly else { return }
        do {
            let snapshot = AbsenceSnapshot(
                records: records,
                overviewIsOpen: overviewIsOpen,
                selectedSection: selectedSection
            )
            let data = try JSONEncoder().encode(snapshot)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
            storageWarning = nil
        } catch {
            storageWarning = "De wijziging kon niet lokaal worden opgeslagen."
            print("[AbsenceModule] Local save failed: \(error)")
        }
    }

    private static func seedRecords() -> [LocalAbsence] {
        // Fictional examples, deliberately separate from any school data.
        func date(_ month: Int, _ day: Int, _ hour: Int = 8, _ minute: Int = 30) -> Date {
            Calendar.current.date(from: DateComponents(
                year: 2026, month: month, day: day, hour: hour, minute: minute
            )) ?? .now
        }
        var result: [LocalAbsence] = [
            LocalAbsence(section: .notifications, start: date(10, 20), end: date(10, 20, 15, 15), reason: "Ziek", recovered: true),
            LocalAbsence(section: .notifications, start: date(10, 16, 13), end: date(10, 16, 16), reason: "Ziek naar huis"),
            LocalAbsence(section: .notifications, start: date(10, 13, 10), end: date(10, 13, 12), reason: "Medisch"),
            LocalAbsence(section: .notifications, start: date(10, 5), end: date(10, 6, 16), allDay: true, reason: "Ziek", recovered: true),
            LocalAbsence(section: .notifications, start: date(9, 28, 12, 45), end: date(9, 28, 16), reason: "Ziek naar huis"),
            LocalAbsence(section: .notifications, start: date(9, 17), end: date(9, 18, 16), allDay: true, reason: "Ziek", recovered: true)
        ]
        let lessons: [(Int, Int, String, String, Int, Int, String)] = [
            (10, 22, "Afwezig zonder reden", "Nederlands", 5, 5, "A"),
            (10, 21, "Boeken vergeten", "Engels", 1, 1, "BV"),
            (10, 19, "Boeken vergeten", "Wiskunde", 4, 4, "BV"),
            (10, 16, "Ziek", "Lichamelijke opvoeding", 7, 8, "Z"),
            (10, 16, "Ziek", "Geschiedenis", 6, 6, "Z"),
            (10, 16, "Ziek", "Biologie", 5, 5, "Z"),
            (10, 5, "Ziek", "Frans", 4, 4, "Z"),
            (10, 5, "Ziek", "Aardrijkskunde", 3, 3, "Z"),
            (9, 28, "Ziek", "Wiskunde", 5, 5, "Z")
        ]
        for (month, day, reason, subject, first, last, code) in lessons {
            result.append(LocalAbsence(
                section: .lessons,
                start: date(month, day, 8 + first),
                end: date(month, day, 9 + last),
                reason: reason,
                subject: subject,
                firstPeriod: first,
                lastPeriod: last,
                code: code
            ))
        }
        return result
    }
}

private enum AbsenceStyle {
    // Reference-specific neutral surfaces; shared navy, blue and orange from Theme.swift.
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.13, alpha: 1)
            : UIColor(white: 0.95, alpha: 1)
    })
    static let card = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.24, alpha: 1)
            : UIColor(white: 0.88, alpha: 1)
    })
    static let border = Color(uiColor: UIColor { traits in
        UIColor(white: traits.userInterfaceStyle == .dark ? 0.43 : 0.68, alpha: 1)
    })
    static var muted: Color { SchoolTheme.ink.opacity(0.83) }
    static let lessonInk = Color(red: 0.12, green: 0.16, blue: 0.19)
    static let lessonSecondary = Color(red: 0.34, green: 0.39, blue: 0.43)
    static let dutch = Locale(identifier: "nl_NL")

    static func formatted(_ date: Date, _ format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = dutch
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    static func dateRange(_ record: LocalAbsence) -> String {
        let sameDay = Calendar.current.isDate(record.start, inSameDayAs: record.end)
        if sameDay {
            let day = formatted(record.start, "d MMM yyyy")
            return record.allDay ? day : "\(day) \(formatted(record.start, "HH:mm")) - \(formatted(record.end, "HH:mm"))"
        }
        if record.allDay {
            let sameYear = Calendar.current.component(.year, from: record.start) == Calendar.current.component(.year, from: record.end)
            return "\(formatted(record.start, sameYear ? "d MMM" : "d MMM yyyy")) t/m \(formatted(record.end, "d MMM yyyy"))"
        }
        return "\(formatted(record.start, "d MMM yyyy HH:mm")) t/m \(formatted(record.end, "d MMM yyyy HH:mm"))"
    }
}

/// Standalone root with its own header. The parent only supplies the drawer callback.
struct AbsenceModule: View {
    private let onMenu: () -> Void
    @State private var store = LocalAbsenceStore.shared
    @State private var editor: AbsenceEditorRequest?
    @State private var pendingDeletion: LocalAbsence?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(onMenu: @escaping () -> Void) {
        self.onMenu = onMenu
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if store.overviewIsOpen {
                overview
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                landing
                    .transition(.opacity)
            }
            footer
        }
        .background(AbsenceStyle.background)
        .background(alignment: .top) {
            SchoolTheme.navy.ignoresSafeArea(edges: .top)
        }
        .sheet(item: $editor) { request in
            AbsenceEditor(record: request.record, isNew: request.isNew) { record in
                store.save(record)
            } onDelete: { record in
                store.delete(record)
            }
        }
        .alert("Registratie verwijderen?", isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )) {
            Button("Annuleren", role: .cancel) { pendingDeletion = nil }
            Button("Verwijderen", role: .destructive) {
                if let record = pendingDeletion { store.delete(record) }
                pendingDeletion = nil
            }
        } message: {
            Text("Dit verwijdert alleen deze lokale demoregistratie.")
        }
    }

    private var header: some View {
        ZStack {
            HStack(spacing: 5) {
                Text(store.overviewIsOpen ? "Afwezigheidsoverzicht" : "Afwezigheid")
                    .font(.system(size: 20, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Circle().fill(SchoolTheme.orange).frame(width: 5, height: 5)
                    .padding(.top, 9)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 47)
            .accessibilityAddTraits(.isHeader)

            HStack {
                Button {
                    if store.overviewIsOpen {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                            store.overviewIsOpen = false
                        }
                    } else {
                        onMenu()
                    }
                } label: {
                    Image(systemName: store.overviewIsOpen ? "chevron.left" : "line.3.horizontal")
                        .font(.system(size: 22, weight: .regular))
                        .frame(width: 44, height: 50)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(store.overviewIsOpen ? "Terug naar afwezigheid" : "Menu openen")
                .accessibilityIdentifier("absence-menu-back")
                Spacer()
                if store.overviewIsOpen {
                    Button(action: addRecord) {
                        Image(systemName: "plus")
                            .font(.system(size: 21, weight: .regular))
                            .frame(width: 44, height: 50)
                    }
                    .accessibilityLabel(store.selectedSection == .notifications ? "Melding toevoegen" : "Lesregistratie toevoegen")
                    .accessibilityIdentifier("absence-add")
                    .disabled(store.isReadOnly)
                }
            }
        }
        .foregroundStyle(.white)
        .frame(height: 50)
        .background(SchoolTheme.navy)
    }

    private var landing: some View {
        ScrollView {
            Button {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                    store.overviewIsOpen = true
                }
            } label: {
                VStack(spacing: 11) {
                    Image(systemName: "calendar.badge.checkmark")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(SchoolTheme.blue, Color(red: 0.02, green: 0.35, blue: 0.59))
                        .font(.system(size: 58, weight: .semibold))
                        .frame(height: 70)
                        .padding(.top, 25)
                    Text("Overzicht")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Bekijk alle ziek- en afwezigheidsmeldingen")
                        .font(.system(size: 17))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    Spacer(minLength: 40)
                }
                .foregroundStyle(AbsenceStyle.muted)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 198)
                .background(AbsenceStyle.card)
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(SchoolTheme.blue)
                        .frame(width: 62, height: 62)
                        .overlay {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .offset(x: 18, y: 18)
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(AbsenceStyle.border, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("absence-open-overview")
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var overview: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(AbsenceSection.allCases) { section in
                    Button {
                        store.selectedSection = section
                    } label: {
                        VStack(spacing: 0) {
                            Text(section.rawValue)
                                .font(.system(size: 17))
                                .foregroundStyle(store.selectedSection == section ? SchoolTheme.blue : SchoolTheme.ink)
                                .frame(maxWidth: .infinity, minHeight: 44)
                            Rectangle()
                                .fill(store.selectedSection == section ? SchoolTheme.blue : .clear)
                                .frame(height: 3)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(store.selectedSection == section ? [.isSelected] : [])
                    .accessibilityIdentifier(section == .notifications ? "absence-tab-notifications" : "absence-tab-lessons")
                }
                Spacer(minLength: 8)
            }
            .padding(.leading, 16)
            .padding(.top, 2)
            Rectangle().fill(AbsenceStyle.border).frame(height: 1)
            ScrollView {
                if store.records(in: store.selectedSection).isEmpty {
                    emptyState
                } else if store.selectedSection == .notifications {
                    LazyVStack(spacing: 0) {
                        ForEach(store.records(in: .notifications)) { record in
                            recordButton(record) { notificationRow(record) }
                            Rectangle().fill(AbsenceStyle.border).frame(height: 1)
                        }
                    }
                    .background(AbsenceStyle.card)
                    .overlay {
                        Rectangle().strokeBorder(AbsenceStyle.border, lineWidth: 1)
                    }
                } else {
                    lessonGroups
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var lessonGroups: some View {
        let records = store.records(in: .lessons)
        let months = Array(Set(records.map { AbsenceStyle.formatted($0.start, "yyyy-MM") })).sorted(by: >)
        return LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(months, id: \.self) { month in
                let entries = records.filter { AbsenceStyle.formatted($0.start, "yyyy-MM") == month }
                if let first = entries.first {
                    Text(AbsenceStyle.formatted(first.start, "MMMM yyyy").capitalized(with: AbsenceStyle.dutch))
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(AbsenceStyle.muted)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 9)
                        .accessibilityAddTraits(.isHeader)
                }
                LazyVStack(spacing: 0) {
                    ForEach(entries) { record in
                        recordButton(record) { lessonRow(record) }
                        if record.id != entries.last?.id {
                            Rectangle().fill(Color.black.opacity(0.09)).frame(height: 1)
                                .padding(.leading, 62)
                        }
                    }
                }
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }
        }
        .padding(.bottom, 12)
    }

    private func recordButton<Content: View>(_ record: LocalAbsence, @ViewBuilder content: () -> Content) -> some View {
        Button {
            editor = AbsenceEditorRequest(record: record, isNew: false)
        } label: {
            content().frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Tik om deze lokale registratie te bewerken")
        .accessibilityIdentifier("absence-record-\(record.id.uuidString)")
        .contextMenu {
            Button("Bewerken", systemImage: "pencil") {
                editor = AbsenceEditorRequest(record: record, isNew: false)
            }
            if record.section == .notifications {
                Button(record.recovered ? "Beter gemeld ongedaan maken" : "Beter melden", systemImage: "checkmark.circle") {
                    store.toggleRecovered(record)
                }
            }
            Button("Verwijderen", systemImage: "trash", role: .destructive) {
                pendingDeletion = record
            }
        }
        .disabled(store.isReadOnly)
    }

    private func notificationRow(_ record: LocalAbsence) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    Text(record.reason).font(.system(size: 18, weight: .bold))
                    if record.recovered { recoveredBadge }
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(record.reason).font(.system(size: 18, weight: .bold))
                    if record.recovered { recoveredBadge }
                }
            }
            Text(AbsenceStyle.dateRange(record))
                .font(.system(size: 17))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(AbsenceStyle.muted)
        .padding(.horizontal, 17)
        .padding(.vertical, 17)
        .frame(minHeight: 73, alignment: .leading)
    }

    private var recoveredBadge: some View {
        Text("Beter gemeld")
            .font(.system(size: 15))
            .foregroundStyle(Color(red: 0.75, green: 0.88, blue: 1))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(Color(red: 0.13, green: 0.33, blue: 0.46), in: Capsule())
    }

    private func lessonRow(_ record: LocalAbsence) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(record.code)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(record.code.uppercased() == "A" ? Color(red: 0.57, green: 0.12, blue: 0.17) : Color(red: 0.03, green: 0.36, blue: 0.32))
                .padding(.horizontal, 6)
                .frame(minWidth: 23, minHeight: 23)
                .background(record.code.uppercased() == "A" ? Color(red: 0.98, green: 0.83, blue: 0.84) : Color(red: 0.78, green: 0.91, blue: 0.88), in: Capsule())
                .accessibilityLabel("Code \(record.code)")
            VStack(alignment: .leading, spacing: 5) {
                Text(record.reason)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AbsenceStyle.lessonInk)
                Text(record.subject)
                    .font(.system(size: 14))
                    .foregroundStyle(AbsenceStyle.lessonSecondary)
                Text(AbsenceStyle.formatted(record.start, "EEE d MMM"))
                    .font(.system(size: 13))
                    .foregroundStyle(AbsenceStyle.lessonSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(record.periodLabel)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 6)
                .background(Color(red: 0.13, green: 0.13, blue: 0.13), in: RoundedRectangle(cornerRadius: 6))
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 15)
        .frame(minHeight: 88)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 38))
                .foregroundStyle(SchoolTheme.blue)
            Text("Nog geen \(store.selectedSection.rawValue.lowercased())")
                .font(.headline)
            Button(store.selectedSection == .notifications ? "Melding toevoegen" : "Lesregistratie toevoegen", action: addRecord)
                .buttonStyle(.borderedProminent)
                .tint(SchoolTheme.blue)
                .accessibilityIdentifier("absence-empty-add")
                .disabled(store.isReadOnly)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    private var footer: some View {
        VStack(spacing: 3) {
            if let warning = store.storageWarning {
                Text(warning).foregroundStyle(Color.orange)
            }
            Text("Lokale demo · geen koppeling met school")
                .foregroundStyle(AbsenceStyle.muted)
        }
        .font(.system(size: 11))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(SchoolTheme.background.ignoresSafeArea(edges: .bottom))
    }

    private func addRecord() {
        guard !store.isReadOnly else { return }
        let now = Date.now
        editor = AbsenceEditorRequest(record: LocalAbsence(
            section: store.selectedSection,
            start: now,
            end: now.addingTimeInterval(3600),
            reason: "Ziek"
        ), isNew: true)
    }
}

private struct AbsenceEditorRequest: Identifiable {
    let id = UUID()
    let record: LocalAbsence
    let isNew: Bool
}

private struct AbsenceEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: LocalAbsence
    @State private var confirmDelete = false
    let isNew: Bool
    let onSave: (LocalAbsence) -> Void
    let onDelete: (LocalAbsence) -> Void

    init(record: LocalAbsence, isNew: Bool, onSave: @escaping (LocalAbsence) -> Void, onDelete: @escaping (LocalAbsence) -> Void) {
        _draft = State(initialValue: record)
        self.isNew = isNew
        self.onSave = onSave
        self.onDelete = onDelete
    }

    private var valid: Bool {
        !draft.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && draft.end >= draft.start
            && (draft.section == .notifications || (
                !draft.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !draft.code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && draft.firstPeriod >= 1 && draft.lastPeriod >= draft.firstPeriod
            ))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reden") {
                    TextField("Bijvoorbeeld ziek of medisch", text: $draft.reason, axis: .vertical)
                        .accessibilityIdentifier("absence-edit-reason")
                    Menu("Kies een veelgebruikte reden") {
                        ForEach(["Ziek", "Ziek naar huis", "Medisch", "Afwezig zonder reden", "Boeken vergeten", "Te laat"], id: \.self) { reason in
                            Button(reason) { draft.reason = reason }
                        }
                    }
                    .accessibilityIdentifier("absence-reason-presets")
                }
                Section("Datum en tijd") {
                    Toggle("Hele dag", isOn: $draft.allDay)
                        .accessibilityIdentifier("absence-edit-all-day")
                    DatePicker("Vanaf", selection: $draft.start, displayedComponents: draft.allDay ? [.date] : [.date, .hourAndMinute])
                        .accessibilityIdentifier("absence-edit-start")
                    DatePicker("Tot en met", selection: $draft.end, in: draft.start..., displayedComponents: draft.allDay ? [.date] : [.date, .hourAndMinute])
                        .accessibilityIdentifier("absence-edit-end")
                }
                if draft.section == .notifications {
                    Section("Status") {
                        Toggle("Beter gemeld", isOn: $draft.recovered)
                            .accessibilityIdentifier("absence-edit-recovered")
                    }
                } else {
                    Section("Lesregistratie") {
                        TextField("Vak", text: $draft.subject)
                            .accessibilityIdentifier("absence-edit-subject")
                        TextField("Code (bijv. Z, A of BV)", text: $draft.code)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("absence-edit-code")
                        Stepper("Eerste lesuur: \(draft.firstPeriod)", value: $draft.firstPeriod, in: 1...12)
                            .accessibilityIdentifier("absence-edit-first-period")
                        Stepper("Laatste lesuur: \(draft.lastPeriod)", value: $draft.lastPeriod, in: draft.firstPeriod...12)
                            .accessibilityIdentifier("absence-edit-last-period")
                    }
                }
                Section {
                    if !isNew {
                        Button("Registratie verwijderen", role: .destructive) { confirmDelete = true }
                            .accessibilityIdentifier("absence-edit-delete")
                    }
                } footer: {
                    Text("Deze gegevens staan alleen op dit apparaat. Wijzigingen worden niet naar een school verstuurd.")
                }
            }
            .navigationTitle(isNew ? "\(draft.section == .notifications ? "Melding" : "Lesregistratie") toevoegen" : "Registratie bewerken")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleren") { dismiss() }
                        .accessibilityIdentifier("absence-edit-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Opslaan") {
                        draft.reason = draft.reason.trimmingCharacters(in: .whitespacesAndNewlines)
                        draft.subject = draft.subject.trimmingCharacters(in: .whitespacesAndNewlines)
                        draft.code = draft.code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(!valid)
                    .accessibilityIdentifier("absence-edit-save")
                }
            }
            .onChange(of: draft.start) { _, start in
                if draft.end < start { draft.end = start }
            }
            .onChange(of: draft.firstPeriod) { _, first in
                if draft.lastPeriod < first { draft.lastPeriod = first }
            }
            .alert("Registratie verwijderen?", isPresented: $confirmDelete) {
                Button("Annuleren", role: .cancel) { }
                Button("Verwijderen", role: .destructive) {
                    onDelete(draft)
                    dismiss()
                }
            } message: {
                Text("Dit verwijdert alleen deze lokale demoregistratie.")
            }
        }
        .environment(\.locale, AbsenceStyle.dutch)
        .tint(SchoolTheme.blue)
        .interactiveDismissDisabled()
    }
}
