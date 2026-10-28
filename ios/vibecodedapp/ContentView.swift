import SwiftUI

struct ContentView: View {
    @State private var store = SchoolStore()
    @State private var library = SchoolLibraryStore()
    @State private var profile = SchoolProfileStore()
    @State private var module = "Agenda"
    @State private var menuOpen = false
    @State private var showCalendar = false
    @State private var calendarDate = Date()
    @State private var selectedLesson: Lesson?
    @State private var editingLesson: Lesson?
    @State private var newLesson = false
    @State private var newGrade = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let modules: [(String, String)] = [
        ("Agenda", "calendar"), ("Huiswerk", "pencil"),
        ("Afwezigheid", "calendar.badge.checkmark"), ("Cijfers", "doc.badge.ellipsis"),
        ("Berichten", "envelope"), ("Mededelingen", "megaphone"),
        ("Studiewijzers", "signpost.right"), ("Opdrachten", "pencil"),
        ("Leermiddelen", "books.vertical"), ("Bronnen", "folder"),
        ("Mijn gegevens", "person.crop.circle"), ("Thema's", "circle.lefthalf.filled"),
        ("Over deze app", "info.circle")
    ]
    private var isAgenda: Bool { module == "Agenda" || module == "Huiswerk" }

    var body: some View {
        GeometryReader { geometry in
            let drawerWidth = min(geometry.size.width * 0.80, 380)
            ZStack(alignment: .leading) {
                SchoolTheme.navy.ignoresSafeArea()
                mainScreen
                    .frame(width: geometry.size.width)
                    .offset(x: menuOpen ? drawerWidth : 0)
                    .allowsHitTesting(!menuOpen)
                    .accessibilityHidden(menuOpen)
                if menuOpen {
                    Color.clear.contentShape(Rectangle())
                        .frame(width: geometry.size.width - drawerWidth)
                        .offset(x: drawerWidth)
                        .onTapGesture { toggleMenu() }
                        .accessibilityLabel("Menu sluiten")
                        .accessibilityAddTraits(.isButton)
                    drawer.frame(width: drawerWidth, height: geometry.size.height)
                        .transition(.move(edge: .leading))
                }
            }
            .clipped()
        }
        .background(SchoolTheme.navy.ignoresSafeArea(edges: .top))
        .background(SchoolTheme.footer.ignoresSafeArea(edges: .bottom))
        .preferredColorScheme(profile.appearance == "Donker" ? .dark : (profile.appearance == "Licht" ? .light : nil))
        .tint(SchoolTheme.blue)
        .sheet(item: $editingLesson) { lesson in
            LessonEditor(store: store, lesson: lesson, isNew: false)
        }
        .sheet(isPresented: $newLesson) {
            LessonEditor(store: store, lesson: Lesson(
                day: store.selectedDay, period: store.dayLessons.count + 1,
                subject: "", teacher: "", room: "", start: "14:30", end: "15:20", homework: ""
            ), isNew: true)
        }
        .sheet(isPresented: $newGrade) {
            GradeEditor(store: store, grade: Grade(subject: "", title: "", value: "", weight: 1, date: Date()), isNew: true)
        }
        .sheet(isPresented: $showCalendar) {
            NavigationStack {
                DatePicker("Datum", selection: $calendarDate, displayedComponents: .date)
                    .datePickerStyle(.graphical).padding()
                    .environment(\.locale, Locale(identifier: "nl_NL"))
                    .navigationTitle("Ga naar datum")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Annuleren") { showCalendar = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Toon") { store.select(date: calendarDate); showCalendar = false }
                        }
                    }
            }.presentationDetents([.medium, .large])
        }
    }

    private var mainScreen: some View {
        VStack(spacing: 0) {
            if let selectedLesson, isAgenda {
                LessonInformationView(store: store, lesson: selectedLesson, onBack: { self.selectedLesson = nil })
            } else if module == "Cijfers" {
                SchoolGradesModule(store: store, onMenu: toggleMenu)
            } else if module == "Afwezigheid" {
                AbsenceModule(onMenu: toggleMenu)
            } else if module == "Berichten" {
                MessagesModule(onMenu: toggleMenu)
            } else {
                header
                if isAgenda {
                    weekStrip
                    agenda
                } else if module == "Mijn gegevens" {
                    ProfileModule(store: profile)
                } else if module == "Thema's" {
                    ThemeSettingsView(store: profile)
                } else if module == "Over deze app" {
                    AboutSchoolView()
                } else {
                    LibraryModule(module: module, store: library, editing: store.editing)
                        .id(module)
                }
                if isAgenda { actionBar }
                Text("Lokale demo • Geen officiële schoolgegevens")
                    .font(.system(size: 10)).foregroundStyle(.gray)
                    .frame(maxWidth: .infinity).padding(.top, 7).padding(.bottom, 5)
                    .background(SchoolTheme.footer)
            }
        }
        .background(SchoolTheme.background)
        .foregroundStyle(SchoolTheme.ink)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SchoolTheme.footer.frame(height: 0)
        }
    }

    private var header: some View {
        ZStack {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TimelineView(.periodic(from: .now, by: 60)) { _ in
                    Text(module == "Agenda" ? store.agendaTitle : module)
                        .font(.system(size: 21, weight: .bold))
                        .lineLimit(1).minimumScaleFactor(0.75)
                        .accessibilityIdentifier("agenda-title")
                }
                Circle().fill(SchoolTheme.orange).frame(width: 5, height: 5)
            }.padding(.horizontal, 52)
            HStack {
                Button { toggleMenu() } label: {
                    Image(systemName: "line.3.horizontal").font(.system(size: 24))
                        .frame(width: 44, height: 44)
                }.accessibilityLabel("Menu").accessibilityIdentifier("open-menu")
                Spacer()
                if isAgenda || module == "Cijfers" || store.editing {
                    Button {
                        if isAgenda {
                            calendarDate = store.date(for: store.selectedDay)
                            showCalendar = true
                        } else { store.editing.toggle() }
                    } label: {
                        Image(systemName: isAgenda ? "calendar" : (store.editing ? "checkmark" : "pencil"))
                            .font(.system(size: 23)).frame(width: 44, height: 44)
                    }.accessibilityLabel(isAgenda ? "Kalender" : (store.editing ? "Bewerken gereed" : "Bewerkmodus"))
                }
            }
        }
        .foregroundStyle(.white).padding(.horizontal, 8).frame(height: 50)
        .background(SchoolTheme.navy.ignoresSafeArea(edges: .top))
    }

    private var weekStrip: some View {
        HStack(spacing: 0) {
            Button { store.weekOffset -= 1 } label: {
                Image(systemName: "chevron.left").font(.system(size: 22))
                    .frame(width: 32, height: 64)
            }.accessibilityLabel("Vorige week")
            ForEach(0..<7) { day in
                Button { store.selectedDay = day } label: {
                    VStack(spacing: 5) {
                        Text(["ma", "di", "wo", "do", "vr", "za", "zo"][day])
                            .font(.system(size: 18))
                        Text(store.dayNumber(day))
                            .font(.system(size: 19, weight: store.selectedDay == day ? .semibold : .regular))
                            .frame(width: 37, height: 37)
                            .foregroundStyle(dayNumberColor(day))
                            .background(daySelectionColor(day), in: Circle())
                    }.frame(maxWidth: .infinity)
                }.accessibilityLabel("\(store.days[day]) \(store.date(for: day).formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "nl_NL"))))")
                    .accessibilityAddTraits(store.selectedDay == day ? .isSelected : [])
            }
            Button { store.weekOffset += 1 } label: {
                Image(systemName: "chevron.right").font(.system(size: 22))
                    .frame(width: 32, height: 64)
            }.accessibilityLabel("Volgende week")
        }
        .foregroundStyle(.white)
        .background(SchoolTheme.week)
        .overlay(alignment: .bottom) { SchoolTheme.divider.frame(height: 0.5) }
    }

    private var agenda: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if store.editing {
                    Text("Bewerkmodus · Open een les en tik op het potlood")
                        .font(.system(size: 12)).foregroundStyle(SchoolTheme.blue)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                }
                let lessons = store.dayLessons.filter { module != "Huiswerk" || !$0.homework.isEmpty }
                if let error = store.lessonsLoadError {
                    Text(error).font(.footnote).padding(12)
                }
                ForEach(lessons) { lesson in
                    Button {
                        guard !lesson.cancelled || store.editing else { return }
                        selectedLesson = lesson
                        print("[Agenda] Opened lesson details: \(lesson.id)")
                    } label: {
                        LessonRow(lesson: lesson, editing: store.editing, homeworkCompleted: store.isHomeworkCompleted(lesson, on: store.date(for: lesson.day)))
                    }.buttonStyle(.plain)
                        .accessibilityIdentifier("agenda-lesson-\(lesson.id.uuidString.lowercased())")
                        .accessibilityLabel(lesson.cancelled
                            ? "Vervallen les, lesuur \(lesson.period)"
                            : "Lesinformatie \(lesson.subject), lesuur \(lesson.period)")
                        .disabled(lesson.cancelled && !store.editing)
                        .contextMenu {
                            if !lesson.cancelled || store.editing {
                                Button("Les bewerken", systemImage: "pencil") { editingLesson = lesson }
                                    .disabled(store.lessonsLoadError != nil)
                            }
                        }
                    SchoolTheme.divider.frame(height: 0.5).padding(.leading, 16)
                }
                if lessons.isEmpty {
                    ContentUnavailableView(
                        module == "Huiswerk" ? "Geen huiswerk" : "Geen lessen", systemImage: "calendar",
                        description: Text(module == "Huiswerk"
                            ? "Voor deze dag is geen huiswerk ingevuld." : "Je kunt met Nieuw een les toevoegen.")
                    )
                        .padding(.top, 30)
                }
            }
        }.frame(maxHeight: .infinity)
    }

    private var actionBar: some View {
        HStack {
            Button(isAgenda ? "Vandaag" : (store.editing ? "Gereed" : "Bewerken")) {
                if isAgenda { store.today() } else { store.editing.toggle() }
            }
            Spacer()
            Button("Nieuw") {
                if isAgenda { newLesson = true } else { newGrade = true }
            }.accessibilityLabel(isAgenda ? "Les toevoegen" : "Cijfer toevoegen")
                .disabled(isAgenda ? store.lessonsLoadError != nil : store.gradesLoadError != nil)
        }
        .font(.system(size: 21)).foregroundStyle(SchoolTheme.blue)
        .padding(.horizontal, 16).frame(height: 51)
        .overlay(alignment: .top) { SchoolTheme.divider.frame(height: 0.5) }
        .overlay(alignment: .bottom) { SchoolTheme.divider.frame(height: 0.5) }
    }

    private var drawer: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        SchoolProfileAvatar(url: profile.photoURL, size: 64)
                        Spacer()
                        Button { toggleMenu() } label: {
                            Image(systemName: "line.3.horizontal").font(.system(size: 24))
                                .frame(width: 44, height: 44)
                        }.accessibilityLabel("Menu sluiten")
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(profile.name).font(.system(size: 27, weight: .bold))
                        Text(".").font(.system(size: 30, weight: .bold)).foregroundStyle(SchoolTheme.orange)
                    }
                    Text(profile.className).font(.system(size: 18))
                }
                .padding(16).padding(.bottom, 17)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [SchoolTheme.blue, SchoolTheme.navy], startPoint: .leading, endPoint: .trailing))
                ForEach(modules, id: \.0) { item in
                    Button {
                        module = item.0
                        toggleMenu()
                    } label: {
                        HStack(spacing: 27) {
                            Image(systemName: item.1).font(.system(size: 23))
                                .frame(width: 32)
                            Text(item.0).font(.system(size: 23))
                            Spacer(minLength: 0)
                        }.padding(.horizontal, 24).frame(minHeight: 63)
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("module-\(item.0.lowercased())")
                }
                Button {
                    store.editing.toggle()
                    toggleMenu()
                } label: {
                    HStack(spacing: 27) {
                        Image(systemName: store.editing ? "checkmark" : "pencil.circle").font(.system(size: 23)).frame(width: 32)
                        Text(store.editing ? "Bewerken gereed" : "Bewerkmodus").font(.system(size: 21))
                    }.padding(.horizontal, 24).frame(minHeight: 63)
                }.buttonStyle(.plain)
                Text("Onafhankelijke demo. Agenda en profielvelden blijven op dit apparaat. Een gekozen profielfoto wordt na toestemming online opgeslagen.")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.65)).padding(24)
            }
        }.background(SchoolTheme.navy.ignoresSafeArea()).foregroundStyle(.white)
    }

    private func dayNumberColor(_ day: Int) -> Color {
        let isToday = Calendar.current.isDateInToday(store.date(for: day))
        if store.selectedDay == day { return isToday ? .white : SchoolTheme.navy }
        return isToday ? Color(red: 0.28, green: 0.58, blue: 0.90) : .white
    }

    private func daySelectionColor(_ day: Int) -> Color {
        guard store.selectedDay == day else { return .clear }
        return Calendar.current.isDateInToday(store.date(for: day))
            ? Color(red: 0.18, green: 0.43, blue: 0.75) : Color(white: 0.90)
    }

    private func toggleMenu() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { menuOpen.toggle() }
    }
}

struct LessonRow: View {
    var lesson: Lesson
    var editing: Bool
    var homeworkCompleted = false
    private var badgeColor: Color {
        homeworkCompleted ? SchoolTheme.homework : Color(red: 0.18, green: 0.43, blue: 0.75)
    }
    var body: some View {
        HStack(spacing: 8) {
            Text("\(lesson.period)").font(.system(size: 21, weight: .bold))
                .foregroundStyle(.white).frame(width: 48, height: 48)
                .background(SchoolTheme.navy, in: RoundedRectangle(cornerRadius: 4))
            VStack(alignment: .leading, spacing: 8) {
                Text(lesson.cancelled ? "–" : "\(lesson.subject)\(lesson.teacher.isEmpty ? "" : " – \(lesson.teacher)")\(lesson.room.isEmpty ? "" : " (\(lesson.room))")")
                    .font(.system(size: 17, weight: .bold))
                    .lineLimit(1).minimumScaleFactor(0.7)
                HStack(spacing: 5) {
                    Text("\(lesson.start) - \(lesson.end)").font(.system(size: 16))
                    Spacer(minLength: 0)
                    if lesson.cancelled {
                        Text("Vervallen").font(.system(size: 15))
                            .foregroundStyle(SchoolTheme.ink)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.red.opacity(0.08), in: Capsule())
                            .overlay(Capsule().stroke(Color.red, lineWidth: 1))
                    } else if !lesson.homework.isEmpty {
                        Text(homeworkCompleted ? "Afgerond" : "Huiswerk").font(.system(size: 15))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(badgeColor.opacity(0.18), in: Capsule())
                            .overlay(Capsule().stroke(badgeColor, lineWidth: 1))
                    }
                    if editing { Image(systemName: "pencil").font(.system(size: 13)).foregroundStyle(SchoolTheme.blue) }
                }
            }
        }
        .foregroundStyle(lesson.cancelled ? SchoolTheme.ink.opacity(0.55) : SchoolTheme.ink)
        .padding(.leading, 8).padding(.trailing, 9).padding(.vertical, 8)
        .frame(minHeight: 62).contentShape(Rectangle())
        .overlay(alignment: .leading) {
            if lesson.cancelled { Color.red.frame(width: 4) }
        }
    }
}

