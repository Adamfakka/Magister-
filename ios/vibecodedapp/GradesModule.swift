import SwiftUI
import Foundation

// Reference direction: navy chrome, system type, uninterrupted compact rows.
// Uses the existing catalog; navigation and filters never change stored grades.
struct SchoolGradesModule: View {
    var store: SchoolStore
    var onMenu: () -> Void

    @State private var showingAllGrades = false
    @State private var selectedSubject: String?
    @State private var selectedGrade: Grade?
    @State private var editor: SchoolGradeEditRequest?
    @ScaledMetric(relativeTo: .body) private var minimumRowHeight = 69.0

    private var canEdit: Bool { store.gradesLoadError == nil }

    private var sortedGrades: [Grade] {
        // Preserve catalog order when dates are equal, including after an edit.
        store.grades.enumerated().sorted { left, right in
            if left.element.date == right.element.date { return left.offset < right.offset }
            return left.element.date > right.element.date
        }.map(\.element)
    }

    private var subjects: [String] {
        Array(Set(store.grades.map(\.subject))).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    private var visibleGrades: [Grade] {
        guard showingAllGrades, let selectedSubject else { return sortedGrades }
        return sortedGrades.filter { $0.subject == selectedSubject }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if let warning = store.gradesLoadError {
                SchoolGradesWarning(message: warning)
            }
            if showingAllGrades { subjectFilter }
            ScrollView {
                LazyVStack(spacing: 0) {
                    SchoolTheme.divider.frame(height: 0.5)
                    if visibleGrades.isEmpty {
                        emptyState
                    } else {
                        ForEach(visibleGrades) { grade in
                            gradeRow(grade)
                            SchoolTheme.divider.frame(height: 0.5)
                        }
                    }
                }
                .padding(.top, 16)
                .padding(.leading, 13)
                .padding(.trailing, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier(showingAllGrades ? "all-grades-list" : "latest-grades-list")
            actionBar
            Text("Lokale demo • Geen officiële schoolgegevens")
                .font(.system(size: 10))
                .foregroundStyle(Color.white.opacity(0.65))
                .frame(maxWidth: .infinity)
                .padding(.top, 5)
                .padding(.bottom, 4)
                .background(SchoolTheme.footer.ignoresSafeArea(edges: .bottom))
        }
        .background(SchoolTheme.background)
        .foregroundStyle(SchoolTheme.ink)
        .tint(SchoolTheme.blue)
        .sheet(item: $selectedGrade) { grade in
            SchoolGradeDetail(store: store, gradeID: grade.id)
        }
        .sheet(item: $editor) { request in
            if canEdit {
                GradeEditor(store: store, grade: request.grade, isNew: request.isNew)
            } else {
                SchoolGradesReadOnlySheet(message: store.gradesLoadError ?? "Cijfers zijn alleen-lezen.")
            }
        }
        .onChange(of: store.gradesLoadError) { _, warning in
            if warning != nil { editor = nil }
        }
        .onChange(of: subjects) { _, currentSubjects in
            if let selectedSubject, !currentSubjects.contains(selectedSubject) {
                self.selectedSubject = nil
            }
        }
    }

    private var header: some View {
        ZStack {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(showingAllGrades ? "Alle cijfers" : "Laatste cijfers")
                    .font(.system(size: 17, weight: .bold))
                Circle().fill(SchoolTheme.orange).frame(width: 4, height: 4)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 60)
            .accessibilityAddTraits(.isHeader)
            HStack {
                Button(action: onMenu) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 19))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Menu")
                .accessibilityIdentifier("grades-open-menu")
                Spacer()
                if store.editing {
                    Button { store.editing = false } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 19))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Bewerken gereed")
                    .accessibilityIdentifier("grades-edit-done")
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .frame(minHeight: 50)
        .background(SchoolTheme.navy.ignoresSafeArea(edges: .top))
    }

    private var subjectFilter: some View {
        HStack {
            Text("Vak").font(.system(size: 14))
            Spacer()
            Menu {
                Picker("Vak", selection: $selectedSubject) {
                    Text("Alle vakken").tag(Optional<String>.none)
                    ForEach(subjects, id: \.self) { subject in
                        Text(subject.isEmpty ? "Zonder vak" : subject).tag(Optional(subject))
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selectedSubject.map { $0.isEmpty ? "Zonder vak" : $0 } ?? "Alle vakken")
                    Image(systemName: "chevron.down").font(.system(size: 11))
                }
                .font(.system(size: 14))
                .foregroundStyle(SchoolTheme.blue)
                .frame(minHeight: 44)
            }
            .accessibilityLabel("Filter op vak")
            .accessibilityValue(selectedSubject ?? "Alle vakken")
            .accessibilityIdentifier("grades-subject-filter")
        }
        .padding(.horizontal, 16)
        .overlay(alignment: .bottom) { SchoolTheme.divider.frame(height: 0.5) }
    }

    private func gradeRow(_ grade: Grade) -> some View {
        HStack(spacing: 0) {
            Button { selectedGrade = grade } label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(grade.subject)
                            .font(.system(size: 16, weight: .bold))
                        Text(grade.title)
                            .font(.system(size: 14))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(grade.value)
                            .font(.system(size: 16, weight: .bold))
                            .fixedSize(horizontal: true, vertical: false)
                        HStack(spacing: 16) {
                            Text("\(grade.weight)x")
                            Text(SchoolGradeDates.short.string(from: grade.date))
                                .monospacedDigit()
                        }
                        .font(.system(size: 11))
                        .fixedSize(horizontal: true, vertical: false)
                    }
                }
                .foregroundStyle(SchoolTheme.ink)
                .padding(.vertical, 10)
                .frame(minHeight: minimumRowHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(grade.subject), \(grade.title), cijfer \(grade.value), weegfactor \(grade.weight), \(SchoolGradeDates.full.string(from: grade.date))")
            .accessibilityHint("Toon cijferdetails. Houd ingedrukt om te wijzigen.")
            .accessibilityIdentifier("grade-detail-\(grade.id.uuidString.lowercased())")
            .contextMenu {
                Button("Wijzig", systemImage: "pencil") { edit(grade) }
                    .disabled(!canEdit)
                    .accessibilityIdentifier("grade-context-edit-\(grade.id.uuidString.lowercased())")
            }
            if store.editing {
                Button { edit(grade) } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 15))
                        .foregroundStyle(SchoolTheme.blue)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(!canEdit)
                .accessibilityLabel("Wijzig cijfer voor \(grade.subject)")
                .accessibilityIdentifier("grade-edit-\(grade.id.uuidString.lowercased())")
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(showingAllGrades && selectedSubject != nil ? "Geen cijfers voor dit vak" : "Geen cijfers")
                .font(.system(size: 16, weight: .bold))
            Text(canEdit ? "Voeg in de bewerkmodus een lokaal cijfer toe." : "Opgeslagen cijfers kunnen niet worden geladen. Wijzigen is uitgeschakeld om je gegevens te behouden.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 24)
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            if showingAllGrades {
                Button {
                    showingAllGrades = false
                    selectedSubject = nil
                } label: {
                    Label("Laatste cijfers", systemImage: "chevron.left")
                        .font(.system(size: 14))
                        .frame(minHeight: 44)
                }
                .accessibilityIdentifier("grades-back-latest")
            }
            if store.editing {
                Button {
                    guard canEdit else { return }
                    editor = SchoolGradeEditRequest(
                        grade: Grade(subject: selectedSubject ?? "", title: "", value: "", weight: 1, date: Date()),
                        isNew: true
                    )
                } label: {
                    Label("Toevoegen", systemImage: "plus")
                        .font(.system(size: 14))
                        .frame(minHeight: 44)
                }
                .disabled(!canEdit)
                .accessibilityIdentifier("grades-add")
            }
            Spacer(minLength: 0)
            if !showingAllGrades {
                Button { showingAllGrades = true } label: {
                    Text("Alle cijfers").font(.system(size: 15)).frame(minHeight: 44)
                }
                .accessibilityIdentifier("grades-show-all")
            }
        }
        .padding(.horizontal, 16)
        .background(SchoolTheme.background)
        .overlay(alignment: .top) { SchoolTheme.divider.frame(height: 0.5) }
    }

    private func edit(_ grade: Grade) {
        guard canEdit else { return }
        editor = SchoolGradeEditRequest(grade: grade, isNew: false)
    }
}

private struct SchoolGradeEditRequest: Identifiable {
    let id = UUID()
    let grade: Grade
    let isNew: Bool
}

@MainActor
private enum SchoolGradeDates {
    static let short: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "dd-MM"
        return formatter
    }()
    static let full: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateStyle = .long
        return formatter
    }()
}

private struct SchoolGradesWarning: View {
    let message: String
    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.system(size: 13))
            .foregroundStyle(SchoolTheme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(SchoolTheme.orange.opacity(0.12))
            .accessibilityIdentifier("grades-load-warning")
    }
}

private struct SchoolGradeDetail: View {
    var store: SchoolStore
    let gradeID: UUID
    @State private var editor: SchoolGradeEditRequest?
    @Environment(\.dismiss) private var dismiss

    private var grade: Grade? { store.grades.first { $0.id == gradeID } }

    var body: some View {
        NavigationStack {
            Form {
                if let warning = store.gradesLoadError {
                    Section { SchoolGradesWarning(message: warning) }
                }
                if let grade {
                    Section("Cijfergegevens") {
                        LabeledContent("Vak", value: grade.subject)
                        LabeledContent("Omschrijving", value: grade.title)
                        LabeledContent("Cijfer") {
                            Text(grade.value).font(.system(size: 20, weight: .bold))
                        }
                        LabeledContent("Weegfactor", value: "\(grade.weight)x")
                        LabeledContent("Datum", value: SchoolGradeDates.full.string(from: grade.date))
                    }
                    Section {
                        Label("Dit is een lokaal democijfer, geen officieel schoolresultaat.", systemImage: "iphone")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                } else {
                    Section { Text("Dit cijfer is verwijderd.") }
                }
            }
            .navigationTitle("Cijferdetails")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sluiten") { dismiss() }
                        .accessibilityIdentifier("grade-detail-close")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Wijzig") {
                        guard store.gradesLoadError == nil, let grade else { return }
                        editor = SchoolGradeEditRequest(grade: grade, isNew: false)
                    }
                    .disabled(store.gradesLoadError != nil || grade == nil)
                    .accessibilityIdentifier("grade-detail-edit")
                }
            }
        }
        .tint(SchoolTheme.blue)
        .sheet(item: $editor) { request in
            if store.gradesLoadError == nil {
                GradeEditor(store: store, grade: request.grade, isNew: false)
            } else {
                SchoolGradesReadOnlySheet(message: store.gradesLoadError ?? "Cijfers zijn alleen-lezen.")
            }
        }
        .onChange(of: store.gradesLoadError) { _, warning in
            if warning != nil { editor = nil }
        }
    }
}

private struct SchoolGradesReadOnlySheet: View {
    let message: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            SchoolGradesWarning(message: message)
                .navigationTitle("Cijfers zijn alleen-lezen")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Sluiten") { dismiss() }
                            .accessibilityIdentifier("grades-readonly-close")
                    }
                }
        }
    }
}
