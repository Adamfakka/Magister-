import SwiftUI
import Observation

@Observable @MainActor
final class LessonDraft {
    var lesson: Lesson
    var start: Date
    var end: Date
    let isNew: Bool
    var timestampsEdited = false
    init(lesson: Lesson, isNew: Bool) {
        var initialLesson = lesson
        initialLesson.homeworkCreatedAt = lesson.homeworkCreatedAt ?? Date()
        initialLesson.homeworkModifiedAt = lesson.homeworkModifiedAt ?? initialLesson.homeworkCreatedAt
        self.lesson = initialLesson
        self.isNew = isNew
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        start = formatter.date(from: lesson.start) ?? Date()
        end = formatter.date(from: lesson.end) ?? Date().addingTimeInterval(3000)
    }
    var valid: Bool {
        !lesson.subject.trimmingCharacters(in: .whitespaces).isEmpty && end > start
    }
    func save(to store: SchoolStore) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        lesson.start = formatter.string(from: start)
        lesson.end = formatter.string(from: end)
        if timestampsEdited {
            if lesson.homeworkCreatedAt == nil { lesson.homeworkCreatedAt = Date() }
            if lesson.homeworkModifiedAt == nil { lesson.homeworkModifiedAt = Date() }
        }
        store.save(lesson, preserveHomeworkTimestamps: timestampsEdited)
    }
}

struct LessonEditor: View {
    var store: SchoolStore
    @State private var draft: LessonDraft
    @State private var confirmDelete = false
    @Environment(\.dismiss) private var dismiss
    init(store: SchoolStore, lesson: Lesson, isNew: Bool) {
        self.store = store
        _draft = State(initialValue: LessonDraft(lesson: lesson, isNew: isNew))
    }
    var body: some View {
        @Bindable var draft = draft
        NavigationStack {
            Form {
                Section("Lesgegevens") {
                    TextField("Vak", text: $draft.lesson.subject).accessibilityLabel("Vak")
                    TextField("Docent", text: $draft.lesson.teacher).accessibilityLabel("Docent")
                    TextField("Lokaal", text: $draft.lesson.room).accessibilityLabel("Lokaal")
                }
                Section("Codes in lesinformatie") {
                    TextField("Vakcode (optioneel)", text: Binding(get: { draft.lesson.subjectCode ?? "" }, set: { draft.lesson.subjectCode = $0 }))
                        .accessibilityIdentifier("lesson-subject-code")
                    TextField("Docentcode (optioneel)", text: Binding(get: { draft.lesson.teacherCode ?? "" }, set: { draft.lesson.teacherCode = $0 }))
                        .accessibilityIdentifier("lesson-teacher-code")
                    TextField("Klas / groep (optioneel)", text: Binding(get: { draft.lesson.classGroup ?? "" }, set: { draft.lesson.classGroup = $0 }))
                        .accessibilityIdentifier("lesson-class-group")
                }
                Section("Rooster") {
                    Picker("Dag", selection: $draft.lesson.day) {
                        ForEach(0..<7) { day in Text(store.days[day]).tag(day) }
                    }
                    Stepper("Lesuur \(draft.lesson.period)", value: $draft.lesson.period, in: 1...12)
                    DatePicker("Begintijd", selection: $draft.start, displayedComponents: .hourAndMinute)
                    DatePicker("Eindtijd", selection: $draft.end, displayedComponents: .hourAndMinute)
                    Toggle("Les laten vervallen", isOn: Binding(
                        get: { draft.lesson.cancelled },
                        set: { draft.lesson.isCancelled = $0 }
                    )).accessibilityIdentifier("lesson-cancelled-toggle")
                    if draft.end <= draft.start {
                        Text("De eindtijd moet na de begintijd liggen.").foregroundStyle(.red).font(.footnote)
                    }
                }
                Section("Huiswerk") {
                    TextField("Opdracht of notitie", text: $draft.lesson.homework, axis: .vertical)
                        .lineLimit(3...5).accessibilityIdentifier("lesson-homework-field")
                    if !draft.lesson.homework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        DatePicker("Ingevoerd", selection: Binding(
                            get: { draft.lesson.homeworkCreatedAt ?? Date() },
                            set: { draft.lesson.homeworkCreatedAt = $0; draft.timestampsEdited = true }
                        ), displayedComponents: [.date, .hourAndMinute])
                        .accessibilityIdentifier("lesson-homework-created-date")
                        DatePicker("Gewijzigd", selection: Binding(
                            get: { draft.lesson.homeworkModifiedAt ?? Date() },
                            set: { draft.lesson.homeworkModifiedAt = $0; draft.timestampsEdited = true }
                        ), displayedComponents: [.date, .hourAndMinute])
                        .accessibilityIdentifier("lesson-homework-modified-date")
                    }
                }
                Section {
                    Label("Alleen op dit apparaat. Je schoolrooster verandert niet.", systemImage: "iphone")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if !draft.isNew {
                    Section {
                        Button("Les verwijderen", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(draft.isNew ? "Les toevoegen" : "Les bewerken")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuleren") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Opslaan") { draft.save(to: store); dismiss() }
                        .disabled(!draft.valid || store.lessonsLoadError != nil).fontWeight(.semibold)
                        .accessibilityIdentifier("lesson-editor-save")
                }
            }
            .confirmationDialog("Deze les lokaal verwijderen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Les verwijderen", role: .destructive) { store.deleteLesson(draft.lesson.id); dismiss() }
                Button("Annuleren", role: .cancel) {}
            }
        }.tint(SchoolTheme.blue).interactiveDismissDisabled()
    }
}

@Observable @MainActor
final class GradeDraft {
    var grade: Grade
    let isNew: Bool
    var textualResult: Bool
    init(grade: Grade, isNew: Bool) {
        self.grade = grade
        self.isNew = isNew
        textualResult = !grade.value.isEmpty && Double(grade.value.replacingOccurrences(of: ",", with: ".")) == nil
    }
    var valid: Bool {
        guard !grade.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if textualResult { return !grade.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard let number = Double(grade.value.replacingOccurrences(of: ",", with: ".")) else { return false }
        return (1...10).contains(number)
    }
}

struct GradeEditor: View {
    var store: SchoolStore
    @State private var draft: GradeDraft
    @State private var confirmDelete = false
    @Environment(\.dismiss) private var dismiss
    init(store: SchoolStore, grade: Grade, isNew: Bool) {
        self.store = store
        _draft = State(initialValue: GradeDraft(grade: grade, isNew: isNew))
    }
    var body: some View {
        @Bindable var draft = draft
        NavigationStack {
            Form {
                Section("Cijfer") {
                    TextField("Vak", text: $draft.grade.subject).accessibilityLabel("Vak")
                    TextField("Omschrijving", text: $draft.grade.title).accessibilityLabel("Omschrijving")
                    Toggle("Tekstresultaat", isOn: $draft.textualResult)
                        .accessibilityIdentifier("grade-text-result-toggle")
                    HStack {
                        Text(draft.textualResult ? "Resultaat" : "Cijfer")
                        Spacer()
                        TextField(draft.textualResult ? "Bijvoorbeeld: voldoende" : "1,0 – 10,0", text: $draft.grade.value)
                            .keyboardType(draft.textualResult ? .default : .decimalPad).multilineTextAlignment(.trailing)
                            .accessibilityLabel(draft.textualResult ? "Resultaat" : "Cijfer").frame(width: 170)
                            .accessibilityIdentifier("grade-value-field")
                    }
                    Stepper("Weegfactor \(draft.grade.weight)", value: $draft.grade.weight, in: 0...10)
                    DatePicker("Datum", selection: $draft.grade.date, displayedComponents: .date)
                }
                Section {
                    Label("Dit is een lokaal democijfer, geen officieel schoolresultaat.", systemImage: "iphone")
                        .foregroundStyle(.secondary).font(.footnote)
                }
                if !draft.isNew {
                    Section { Button("Cijfer verwijderen", role: .destructive) { confirmDelete = true } }
                }
            }
            .navigationTitle(draft.isNew ? "Cijfer toevoegen" : "Cijfer bewerken")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuleren") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Opslaan") { store.save(draft.grade); dismiss() }
                        .disabled(!draft.valid || store.gradesLoadError != nil).fontWeight(.semibold)
                        .accessibilityIdentifier("grade-editor-save")
                }
            }
            .confirmationDialog("Dit cijfer lokaal verwijderen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Cijfer verwijderen", role: .destructive) { store.deleteGrade(draft.grade.id); dismiss() }
                Button("Annuleren", role: .cancel) {}
            }
        }.tint(SchoolTheme.blue).interactiveDismissDisabled()
    }
}
