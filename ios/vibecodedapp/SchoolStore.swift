import Foundation
import Observation

struct Lesson: Identifiable, Codable {
    var id = UUID()
    var day: Int
    var period: Int
    var subject: String
    var teacher: String
    var room: String
    var start: String
    var end: String
    var homework: String
    var subjectCode: String?
    var teacherCode: String?
    var classGroup: String?
    var homeworkCreatedAt: Date?
    var homeworkModifiedAt: Date?
    var isCancelled: Bool?
    var homeworkTimestampsManual: Bool?

    var cancelled: Bool { isCancelled ?? false }
}

struct Grade: Identifiable, Codable {
    var id = UUID()
    var subject: String
    var title: String
    var value: String
    var weight: Int
    var date: Date
}

@Observable @MainActor
final class SchoolStore {
    var editing = false
    var selectedDay = 0
    var weekOffset = 0
    private let monday: Date = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let daysSinceMonday = (calendar.component(.weekday, from: today) + 5) % 7
        return calendar.date(byAdding: .day, value: -daysSinceMonday, to: today) ?? today
    }()
    var agendaTitle: String {
        let selectedDate = date(for: selectedDay)
        if Calendar.current.isDateInToday(selectedDate) { return "Vandaag" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "d MMM"
        return "\(days[selectedDay]) \(formatter.string(from: selectedDate).replacingOccurrences(of: ".", with: ""))"
    }
    func date(for day: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: weekOffset * 7 + day, to: monday) ?? monday
    }
    func dayNumber(_ day: Int) -> String { date(for: day).formatted(.dateTime.day()) }
    var weekTitle: String {
        "\(dayNumber(0)) – \(date(for: 4).formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "nl_NL"))))"
    }
    var weekNumber: Int { Calendar.current.component(.weekOfYear, from: date(for: 0)) }
    var dayTitle: String {
        "\(days[selectedDay]) \(date(for: selectedDay).formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "nl_NL"))))"
    }
    func today() { select(date: Date()) }
    func select(date: Date) {
        let calendar = Calendar.current
        let target = calendar.startOfDay(for: date)
        let base = calendar.startOfDay(for: monday)
        let offset = calendar.dateComponents([.day], from: base, to: target).day ?? 0
        weekOffset = Int(floor(Double(offset) / 7.0))
        selectedDay = offset - weekOffset * 7
    }
    var lessons: [Lesson] = []
    var grades: [Grade] = []
    private let lessonsKey = "local-school-lessons-v1"
    private let gradesKey = "local-school-grades-v1"
    private let homeworkKey = "local-school-homework-status-v1"
    private(set) var lessonsLoadError: String?
    private(set) var gradesLoadError: String?
    private(set) var homeworkLoadError: String?
    private var homeworkCompletion: [String: Bool] = [:]
    let days = ["Maandag", "Dinsdag", "Woensdag", "Donderdag", "Vrijdag", "Zaterdag", "Zondag"]

    init() {
        today()
        if let data = UserDefaults.standard.data(forKey: lessonsKey) {
            do { lessons = try JSONDecoder().decode([Lesson].self, from: data) }
            catch {
                lessonsLoadError = "Je opgeslagen lessen konden niet worden gelezen. De oorspronkelijke gegevens blijven bewaard; bewerken is tijdelijk uitgeschakeld."
                print("[SchoolStore] Lesson load failed; original data retained: \(error)")
            }
        } else {
            let subjects = ["Nederlands", "Wiskunde", "Engels", "Geschiedenis", "Biologie", "Lichamelijke opvoeding"]
            let teachers = ["De Vries", "Bakker", "Smit", "Van Dijk", "Jansen", "Visser"]
            let rooms = ["B12", "A24", "B08", "C11", "A16", "Gymzaal 1"]
            let starts = ["08:30", "09:20", "10:30", "11:20", "12:40", "13:30"]
            let ends = ["09:20", "10:10", "11:20", "12:10", "13:30", "14:20"]
            for day in 0..<5 {
                for period in 0..<6 {
                    let index = (period + day) % subjects.count
                    lessons.append(Lesson(
                        day: day, period: period + 1, subject: subjects[index], teacher: teachers[index],
                        room: rooms[index], start: starts[period], end: ends[period],
                        homework: period == 1 ? "Maak de opdrachten van hoofdstuk 3.2." : ""
                    ))
                }
            }
            persistLessons()
        }
        if let data = UserDefaults.standard.data(forKey: gradesKey) {
            do { grades = try JSONDecoder().decode([Grade].self, from: data) }
            catch {
                gradesLoadError = "Je opgeslagen cijfers konden niet worden gelezen. De oorspronkelijke gegevens blijven bewaard; bewerken is tijdelijk uitgeschakeld."
                print("[SchoolStore] Grade load failed; original data retained: \(error)")
            }
        } else {
            grades = [
                Grade(subject: "Wiskunde", title: "Vergelijkingen · Proefwerk", value: "7,4", weight: 3, date: Date()),
                Grade(subject: "Nederlands", title: "Leesvaardigheid · SO", value: "8,1", weight: 1, date: Date().addingTimeInterval(-86400)),
                Grade(subject: "Engels", title: "Unit 2 · Proefwerk", value: "6,8", weight: 2, date: Date().addingTimeInterval(-172800)),
                Grade(subject: "Biologie", title: "Cellen · Proefwerk", value: "5,2", weight: 2, date: Date().addingTimeInterval(-259200)),
                Grade(subject: "Geschiedenis", title: "De Republiek · SO", value: "7,8", weight: 1, date: Date().addingTimeInterval(-345600))
            ]
            persistGrades()
        }
        if let data = UserDefaults.standard.data(forKey: homeworkKey) {
            do { homeworkCompletion = try JSONDecoder().decode([String: Bool].self, from: data) }
            catch {
                homeworkLoadError = "De opgeslagen huiswerkstatus kon niet worden gelezen. Je gegevens blijven bewaard; de schakelaar is tijdelijk uitgeschakeld."
                print("[SchoolStore] Homework status load failed; original data retained: \(error)")
            }
        }
    }

    var dayLessons: [Lesson] {
        lessons.filter { $0.day == selectedDay }.sorted { $0.start < $1.start }
    }
    func save(_ lesson: Lesson, preserveHomeworkTimestamps: Bool = false) {
        guard lessonsLoadError == nil else { return }
        var updated = lesson
        let previous = lessons.first(where: { $0.id == lesson.id })
        if preserveHomeworkTimestamps { updated.homeworkTimestampsManual = true }
        if !lesson.homework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let now = Date()
            if updated.homeworkCreatedAt == nil { updated.homeworkCreatedAt = now }
            if updated.homeworkModifiedAt == nil { updated.homeworkModifiedAt = updated.homeworkCreatedAt }
            if updated.homeworkTimestampsManual != true, previous?.homework != lesson.homework {
                updated.homeworkModifiedAt = now
            }
        }
        if let index = lessons.firstIndex(where: { $0.id == lesson.id }) { lessons[index] = updated }
        else { lessons.append(updated) }
        selectedDay = lesson.day
        persistLessons()
        print("[SchoolStore] Lesson saved locally: \(lesson.subject)")
    }
    func save(_ grade: Grade) {
        guard gradesLoadError == nil else { return }
        if let index = grades.firstIndex(where: { $0.id == grade.id }) { grades[index] = grade }
        else { grades.insert(grade, at: 0) }
        persistGrades()
        print("[SchoolStore] Grade saved locally: \(grade.subject) \(grade.value)")
    }
    func deleteLesson(_ id: UUID) {
        guard lessonsLoadError == nil else { return }
        lessons.removeAll { $0.id == id }
        persistLessons()
    }
    func deleteGrade(_ id: UUID) {
        guard gradesLoadError == nil else { return }
        grades.removeAll { $0.id == id }
        persistGrades()
    }
    private func persistLessons() {
        guard lessonsLoadError == nil else { return }
        do { UserDefaults.standard.set(try JSONEncoder().encode(lessons), forKey: lessonsKey) }
        catch { print("[SchoolStore] Lesson save failed: \(error)") }
    }
    private func persistGrades() {
        guard gradesLoadError == nil else { return }
        do { UserDefaults.standard.set(try JSONEncoder().encode(grades), forKey: gradesKey) }
        catch { print("[SchoolStore] Grade save failed: \(error)") }
    }
    func isHomeworkCompleted(_ lesson: Lesson, on date: Date) -> Bool {
        homeworkCompletion[homeworkStatusKey(lesson.id, date: date)] ?? false
    }
    func setHomeworkCompleted(_ completed: Bool, for lesson: Lesson, on date: Date) {
        guard homeworkLoadError == nil, lessonsLoadError == nil,
              lessons.contains(where: { $0.id == lesson.id }), !lesson.homework.isEmpty else { return }
        homeworkCompletion[homeworkStatusKey(lesson.id, date: date)] = completed
        do {
            UserDefaults.standard.set(try JSONEncoder().encode(homeworkCompletion), forKey: homeworkKey)
            print("[SchoolStore] Homework completion saved for lesson \(lesson.id): \(completed)")
        } catch { print("[SchoolStore] Homework status save failed: \(error)") }
    }
    private func homeworkStatusKey(_ id: UUID, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(id.uuidString)-\(formatter.string(from: date))"
    }
    func isPassing(_ grade: Grade) -> Bool {
        (Double(grade.value.replacingOccurrences(of: ",", with: ".")) ?? 0) >= 5.5
    }
}
