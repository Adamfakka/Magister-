import SwiftUI

struct HomeworkTimestampEditor: View {
    let store: SchoolStore
    let lesson: Lesson
    @Environment(\.dismiss) private var dismiss
    @State private var createdAt: Date
    @State private var modifiedAt: Date

    init(store: SchoolStore, lesson: Lesson) {
        self.store = store
        self.lesson = lesson
        _createdAt = State(initialValue: lesson.homeworkCreatedAt ?? Date())
        _modifiedAt = State(initialValue: lesson.homeworkModifiedAt ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Huiswerkdatums") {
                    DatePicker("Ingevoerd", selection: $createdAt, displayedComponents: [.date, .hourAndMinute])
                        .accessibilityIdentifier("homework-created-date")
                    DatePicker("Gewijzigd", selection: $modifiedAt, displayedComponents: [.date, .hourAndMinute])
                        .accessibilityIdentifier("homework-modified-date")
                }
                Section {
                    Text("Je kunt beide datums en tijden zelf kiezen. Deze wijziging geldt alleen in deze demo.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .environment(\.locale, Locale(identifier: "nl_NL"))
            .navigationTitle("Huiswerkdatums wijzigen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleren") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Opslaan") {
                        guard var updated = store.lessons.first(where: { $0.id == lesson.id }) else { return }
                        updated.homeworkCreatedAt = createdAt
                        updated.homeworkModifiedAt = modifiedAt
                        store.save(updated, preserveHomeworkTimestamps: true)
                        print("[Homework] Explicit timestamps saved for lesson \(lesson.id)")
                        dismiss()
                    }.disabled(store.lessonsLoadError != nil)
                        .accessibilityIdentifier("homework-dates-save")
                }
            }
        }.tint(SchoolTheme.blue).interactiveDismissDisabled()
    }
}
