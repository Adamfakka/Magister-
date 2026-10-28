import SwiftUI

struct LessonInformationView: View {
    var store: SchoolStore
    let lesson: Lesson
    let onBack: () -> Void
    @State private var showHomework = false
    @State private var showEditor = false
    @State private var showTimestampEditor = false

    private var current: Lesson { store.lessons.first(where: { $0.id == lesson.id }) ?? lesson }
    private var lessonDate: Date { store.date(for: current.day) }
    private var identity: String {
        [current.subjectCode?.isEmpty == false ? current.subjectCode! : current.subject,
         current.teacherCode?.isEmpty == false ? current.teacherCode! : current.teacher,
         current.classGroup ?? ""].filter { !$0.isEmpty }.joined(separator: " – ")
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(showHomework ? "Huiswerk" : identity)
                        .font(.system(size: 19, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                        .padding(.horizontal, 9)
                        .contextMenu {
                            Button("Les bewerken", systemImage: "pencil") { showEditor = true }
                                .disabled(store.lessonsLoadError != nil)
                        }
                    SchoolTheme.divider.frame(height: 0.5)
                    if showHomework { homeworkContent }
                    else { lessonContent }
                }
            }.frame(maxHeight: .infinity)
            Text("Lokale demo • Geen officiële schoolgegevens")
                .font(.system(size: 10)).foregroundStyle(.gray)
                .frame(maxWidth: .infinity).padding(.vertical, 7)
                .background(SchoolTheme.footer)
                .overlay(alignment: .top) { SchoolTheme.divider.frame(height: 0.5) }
        }
        .foregroundStyle(SchoolTheme.ink).background(SchoolTheme.background)
        .sheet(isPresented: $showEditor) { LessonEditor(store: store, lesson: current, isNew: false) }
        .sheet(isPresented: $showTimestampEditor) { HomeworkTimestampEditor(store: store, lesson: current) }
        .onChange(of: store.lessons.count) { _, _ in
            if !store.lessons.contains(where: { $0.id == lesson.id }) { onBack() }
        }
    }

    private var header: some View {
        ZStack {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("Lesinformatie").font(.system(size: 19, weight: .bold))
                if showHomework { Circle().fill(SchoolTheme.orange).frame(width: 5, height: 5) }
            }
            HStack {
                Button {
                    if showHomework { showHomework = false }
                    else { onBack() }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left").font(.system(size: 24, weight: .light))
                        if !showHomework {
                            Text(Calendar.current.isDateInToday(lessonDate) ? "vandaag" : "agenda")
                                .font(.system(size: 17)).underline()
                        }
                    }.frame(minWidth: 44, minHeight: 44, alignment: .leading)
                }
                .accessibilityLabel(showHomework ? "Terug naar lesinformatie" : "Terug naar agenda")
                .accessibilityIdentifier("lesson-details-back")
                Spacer()
                if store.editing {
                    Button {
                        if showHomework { showTimestampEditor = true }
                        else { showEditor = true }
                    } label: {
                        Image(systemName: "pencil").font(.system(size: 20)).frame(width: 44, height: 44)
                    }.accessibilityLabel(showHomework ? "Huiswerkdatums wijzigen" : "Les bewerken")
                        .accessibilityIdentifier("lesson-details-edit")
                        .disabled(store.lessonsLoadError != nil)
                }
            }
        }
        .padding(.horizontal, 9).frame(height: 50).foregroundStyle(.white)
        .background(SchoolTheme.navy)
    }

    private var lessonContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            informationSection("Tijdstip", lines: [lessonDate.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "nl_NL"))), "\(current.start) - \(current.end)"])
            informationSection("Locatie", lines: [current.room.isEmpty ? "—" : current.room])
            informationSection("Vak", lines: [current.subject])
            informationSection("Docenten", lines: [current.teacher.isEmpty ? "—" : current.teacher], divider: !current.homework.isEmpty)
            if !current.homework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Huiswerk").font(.system(size: 19, weight: .bold))
                    Button {
                        showHomework = true
                        print("[LessonInformation] Opened homework for lesson \(current.id)")
                    } label: {
                        HStack(alignment: .center, spacing: 13) {
                            Image(systemName: store.isHomeworkCompleted(current, on: lessonDate) ? "checkmark.circle" : "pencil")
                                .font(.system(size: 23))
                                .foregroundStyle(store.isHomeworkCompleted(current, on: lessonDate) ? SchoolTheme.homework : SchoolTheme.ink)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(current.homework).font(.system(size: 17)).lineLimit(2)
                                if store.isHomeworkCompleted(current, on: lessonDate) {
                                    Text("Afgerond").font(.system(size: 13)).foregroundStyle(SchoolTheme.homework)
                                }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.system(size: 20))
                        }.frame(maxWidth: .infinity, minHeight: 48, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("lesson-open-homework")
                        .accessibilityLabel("Huiswerk: \(current.homework)")
                        .accessibilityValue(store.isHomeworkCompleted(current, on: lessonDate) ? "Afgerond" : "Niet afgerond")
                }.padding(.horizontal, 9).padding(.vertical, 14)
            }
        }
    }

    private func informationSection(_ title: String, lines: [String], divider: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 19, weight: .bold))
            ForEach(Array(lines.enumerated()), id: \.offset) { _, text in
                Text(text).font(.system(size: 19))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9).padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            if divider { SchoolTheme.divider.frame(height: 0.5).padding(.horizontal, 4) }
        }
    }

    private var homeworkContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if store.editing {
                Button { showTimestampEditor = true } label: {
                    VStack(spacing: 14) {
                        timestampRow("Ingevoerd", date: current.homeworkCreatedAt)
                        timestampRow("Gewijzigd", date: current.homeworkModifiedAt)
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel("Huiswerkdatums wijzigen")
                    .accessibilityIdentifier("homework-edit-dates")
                    .disabled(store.lessonsLoadError != nil)
            } else {
                timestampRow("Ingevoerd", date: current.homeworkCreatedAt)
                timestampRow("Gewijzigd", date: current.homeworkModifiedAt)
            }
            Toggle("Afgerond", isOn: Binding(
                get: { store.isHomeworkCompleted(current, on: lessonDate) },
                set: { store.setHomeworkCompleted($0, for: current, on: lessonDate) }
            ))
            .font(.system(size: 16, weight: .semibold)).tint(.green)
            .padding(.top, 3).accessibilityIdentifier("homework-completed-toggle")
            .disabled(store.homeworkLoadError != nil || store.lessonsLoadError != nil)
            if let error = store.homeworkLoadError ?? store.lessonsLoadError {
                Text(error).font(.footnote).foregroundStyle(.secondary)
            }
            SchoolTheme.divider.frame(height: 0.5).padding(.horizontal, 4)
            Text(current.homework).font(.system(size: 19)).lineSpacing(7)
                .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 1).accessibilityIdentifier("homework-full-text")
        }.padding(.horizontal, 9).padding(.vertical, 14)
    }

    private func timestampRow(_ label: String, date: Date?) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).font(.system(size: 15, weight: .semibold))
                Spacer(minLength: 8)
                Text(timestamp(date)).font(.system(size: 17))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(label).font(.system(size: 15, weight: .semibold))
                Text(timestamp(date)).font(.system(size: 17))
            }
        }
    }

    private func timestamp(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute().locale(Locale(identifier: "nl_NL")))
    }
}
