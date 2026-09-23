// Main UI file
// (with help from several AI's such as claude, gemini, and chatgpt)

import Combine
import EventKit
import SwiftUI
import UserNotifications

// MARK: - Colour Palette

extension Color {
    static let appNavy = Color(red: 0.03, green: 0.06, blue: 0.18)
    static let appNavyLight = Color(red: 0.10, green: 0.17, blue: 0.35)
    static let appNavyLight2 = Color(red: 0.09, green: 0.16, blue: 0.34)
    static let appRoyalBlue = Color(red: 0.16, green: 0.32, blue: 0.75)
    static let appBlack = Color(red: 0.07, green: 0.07, blue: 0.09)
    static let appGrey = Color(red: 0.38, green: 0.39, blue: 0.42)
    static let appGreyLight = Color(red: 0.55, green: 0.56, blue: 0.60)
    static let appGreyDark = Color(red: 0.18, green: 0.19, blue: 0.22)
    static let appOrange = Color(red: 1.00, green: 0.45, blue: 0.10)
    static let appOrangeDeep = Color(red: 0.85, green: 0.35, blue: 0.05)
    static let appSurface = Color(red: 0.11, green: 0.13, blue: 0.18)
    static let appCard = Color(red: 0.14, green: 0.16, blue: 0.22)
}

// MARK: - Models

enum ReminderCategory: String, CaseIterable, Codable, Identifiable {
    case work = "Work"
    case personal = "Personal"
    case health = "Health"
    case urgent = "Urgent"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .work: return "briefcase.fill"
        case .personal: return "person.fill"
        case .health: return "heart.fill"
        case .urgent: return "exclamationmark.triangle.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .work: return .appRoyalBlue
        case .personal: return .appGreyLight
        case .health: return Color(red: 0.2, green: 0.6, blue: 0.5)
        case .urgent: return .appOrange
        case .other: return .appGrey
        }
    }
}

enum RepeatInterval: Hashable, Codable {
    case none
    case minutes(Int)  // preset: 5, 10, 15, 20, 30
    case hours(Int)  // preset: 1
    case days(Int)  // preset: 1 day
    case weeks(Int)  // preset: 1 week
    case custom(Int)  // user-entered minutes

    var label: String {
        switch self {
        case .none: return "No repeat"
        case .minutes(let m): return "Every \(m) min"
        case .hours(let h): return h == 1 ? "Every hour" : "Every \(h) hrs"
        case .days(let d): return d == 1 ? "Every day" : "Every \(d) days"
        case .weeks(let w): return w == 1 ? "Every week" : "Every \(w) weeks"
        case .custom(let m): return "Every \(m) min"
        }
    }

    var seconds: TimeInterval? {
        switch self {
        case .none: return nil
        case .minutes(let m): return TimeInterval(m * 60)
        case .hours(let h): return TimeInterval(h * 3600)
        case .days(let d): return TimeInterval(d * 86400)
        case .weeks(let w): return TimeInterval(w * 604800)
        case .custom(let m): return TimeInterval(m * 60)
        }
    }

    static let presets: [RepeatInterval] = [
        .none,
        .minutes(5),
        .minutes(10),
        .minutes(15),
        .minutes(30),
        .days(1),
        .weeks(1),
    ]
}

enum ReminderTimeLabel {
    private static func pluralize(
        _ count: Int,
        _ singular: String,
        _ plural: String
    ) -> String {
        "\(count) \(count == 1 ? singular : plural)"
    }

    static func label(from referenceDate: Date, dueDate: Date) -> String {
        let diff = dueDate.timeIntervalSince(referenceDate)
        let isOverdue = diff < 0
        let total = Int(abs(diff))
        let mins = total / 60
        let hours = total / 3600
        let days = total / 86400
        let weeks = days / 7

        let label: String
        if weeks >= 1 && days % 7 == 0 {
            label = pluralize(weeks, "week", "weeks")
        } else if weeks >= 1 {
            label =
                "\(pluralize(weeks, "week", "weeks")) \(pluralize(days % 7, "day", "days"))"
        } else if days >= 1 && hours % 24 == 0 {
            label = pluralize(days, "day", "days")
        } else if days >= 1 {
            label =
                "\(pluralize(days, "day", "days")) \(pluralize(hours % 24, "hr", "hrs"))"
        } else if hours >= 1 && mins % 60 == 0 {
            label = pluralize(hours, "hr", "hrs")
        } else if hours >= 1 {
            label =
                "\(pluralize(hours, "hr", "hrs")) \(pluralize(mins % 60, "min", "mins"))"
        } else if mins >= 1 {
            label = pluralize(mins, "min", "mins")
        } else {
            label = "< 1 min"
        }
        return isOverdue ? "started \(label) ago" : "in \(label)"
    }
}

extension RepeatInterval: Equatable {
    static func == (lhs: RepeatInterval, rhs: RepeatInterval) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case (.minutes(let a), .minutes(let b)):
            return a == b
        case (.hours(let a), .hours(let b)):
            return a == b
        case (.days(let a), .days(let b)):
            return a == b
        case (.weeks(let a), .weeks(let b)):
            return a == b
        case (.custom(let a), .custom(let b)):
            return a == b
        default:
            return false
        }
    }
}

struct Reminder: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var category: ReminderCategory
    var dueDate: Date?
    var repeatInterval: RepeatInterval
    var repeatUntilEvent: Bool = true
    var timesTriggered: Int = 0
    var isDone: Bool = false
    var createdAt: Date = Date()
    var remindersOvertime: Bool = false
    var overtimeCount: Int = 1
    var calendarEventID: String? = nil
    var syncToCalendar: Bool = true
    var note: String? = nil
    var startDate: Date? = nil

    var isOverdue: Bool {
        guard let due = dueDate, !isDone else { return false }
        return due < Date()
    }

    var dueLabel: String? {
        guard let due = dueDate else { return nil }
        return ReminderTimeLabel.label(from: Date(), dueDate: due)
    }
}

// MARK: - Notification Alignment

enum NotificationAlignment {

    // The first fire date for a repeating reminder with no due date is
    // snapped forward to the next clean point on the clock.
    static func firstAlignedDate(
        after reference: Date,
        interval: RepeatInterval,
        calendar: Calendar = .current
    ) -> Date? {
        switch interval {
        case .none:
            return nil
        case .minutes(let m), .custom(let m):
            guard m > 0 else { return nil }
            return calendar.date(byAdding: .minute, value: m, to: reference)
        case .hours(let h):
            return nextHourAligned(
                after: reference,
                every: h,
                calendar: calendar
            )
        case .days:
            return nextDayStart(after: reference, calendar: calendar)
        case .weeks:
            return nextWeekStart(after: reference, calendar: calendar)
        }
    }

    // steps an already aligned date forward by one interval
    // uses Calendar rather than raw seconds
    static func advance(
        _ date: Date,
        by interval: RepeatInterval,
        calendar: Calendar = .current
    ) -> Date? {
        switch interval {
        case .none: return nil
        case .minutes(let m), .custom(let m):
            return calendar.date(byAdding: .minute, value: m, to: date)
        case .hours(let h):
            return calendar.date(byAdding: .hour, value: h, to: date)
        case .days(let d):
            return calendar.date(byAdding: .day, value: d, to: date)
        case .weeks(let w):
            return calendar.date(byAdding: .weekOfYear, value: w, to: date)
        }
    }

    // MARK: Helpers

    //    private static func nextMinuteAligned(
    //        after reference: Date,
    //        every m: Int,
    //        calendar: Calendar
    //    ) -> Date? {
    //        guard m > 0 else { return nil }
    //        guard let hourStart = calendar.dateInterval(of: .hour, for: reference)?.start
    //        else { return nil }
    //
    //        // Intervals of an hour or more just start on the next hour
    //        if m >= 60 {
    //            return calendar.date(byAdding: .hour, value: 1, to: hourStart)
    //        }
    //
    //        let minutesIn = Int(reference.timeIntervalSince(hourStart) / 60)  // 0...59
    //        let nextMultiple = ((minutesIn / m) + 1) * m
    //
    //        if nextMultiple >= 60 {
    //            return calendar.date(byAdding: .hour, value: 1, to: hourStart)
    //        }
    //        return calendar.date(byAdding: .minute, value: nextMultiple, to: hourStart)
    //    }

    // ex. every 1 hr at 5:13pm -> 6:00pm exactly, then 7:00pm, 8:00pm...
    private static func nextHourAligned(
        after reference: Date,
        every h: Int,
        calendar: Calendar
    ) -> Date? {
        guard h > 0 else { return nil }
        let dayStart = calendar.startOfDay(for: reference)

        if h >= 24 {
            return nextDayStart(after: reference, calendar: calendar)
        }

        let hourIn = calendar.component(.hour, from: reference)
        let nextMultiple = ((hourIn / h) + 1) * h

        if nextMultiple >= 24 {
            return nextDayStart(after: reference, calendar: calendar)
        }
        return calendar.date(byAdding: .hour, value: nextMultiple, to: dayStart)
    }

    // Daily repeats start at the next midnight
    private static func nextDayStart(after reference: Date, calendar: Calendar)
        -> Date?
    {
        calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: reference)
        )
    }

    // Weekly repeats start at midnight on the first day of the next week
    private static func nextWeekStart(after reference: Date, calendar: Calendar)
        -> Date?
    {
        if let week = calendar.dateInterval(of: .weekOfYear, for: reference) {
            return week.end
        }
        return nextDayStart(after: reference, calendar: calendar)
    }
}

// MARK: - Notification Manager

class NotificationManager: NSObject, ObservableObject,
    UNUserNotificationCenterDelegate
{

    static let shared = NotificationManager()

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [
            .alert, .sound, .badge,
        ]) { granted, error in
            if !granted {
                print("Notification permission denied")
            }
        }
    }

    // Tells iOS to show the banner/sound even while the app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    func schedule(reminder: Reminder) {
        guard let due = reminder.dueDate, !reminder.isDone else { return }
        let center = UNUserNotificationCenter.current()
        cancel(id: reminder.id)
        let now = Date()
        let start = max(now, reminder.startDate ?? now)

        var repeatTimes: [Date] = []
        if let interval = reminder.repeatInterval.seconds {
            var t = start.addingTimeInterval(interval)
            while t < due && repeatTimes.count < 20 {
                repeatTimes.append(t)
                t = t.addingTimeInterval(interval)
            }
        }

        let overtimeTotal =
            reminder.remindersOvertime ? max(1, reminder.overtimeCount) : 0
        let totalCount = repeatTimes.count + 1 + overtimeTotal

        func makeContent(index: Int, fireDate: Date)
            -> UNMutableNotificationContent
        {
            let content = UNMutableNotificationContent()
            let timeText =
                abs(fireDate.timeIntervalSince(due)) < 1
                ? "now"
                : ReminderTimeLabel.label(from: fireDate, dueDate: due)
            content.title = "\(reminder.title) (\(index)/\(totalCount))"

            // this is for the 'Note' section
            var body = "\(timeText)"
            if let note = reminder.note,
                !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                body += " - check note."
            }

            content.body = body
            content.sound = .default
            return content
        }

        if due > now {
            for (i, fireDate) in repeatTimes.enumerated() {
                let index = i + 1
                let delay = fireDate.timeIntervalSinceNow
                guard delay > 0 else { continue }
                let request = UNNotificationRequest(
                    identifier: "\(reminder.id.uuidString)-repeat-\(index)",
                    content: makeContent(index: index, fireDate: fireDate),
                    trigger: UNTimeIntervalNotificationTrigger(
                        timeInterval: delay,
                        repeats: false
                    )
                )
                center.add(request) { error in
                    if let error {
                        print("Failed to schedule repeat: \(error)")
                    }
                }
            }

            let mainIndex = repeatTimes.count + 1
            let request = UNNotificationRequest(
                identifier: reminder.id.uuidString,
                content: makeContent(index: mainIndex, fireDate: due),
                trigger: UNTimeIntervalNotificationTrigger(
                    timeInterval: max(1, due.timeIntervalSinceNow),
                    repeats: false
                )
            )
            center.add(request) { error in
                if let error { print("Failed to schedule: \(error)") }
            }
        }

        if reminder.remindersOvertime {
            let interval = reminder.repeatInterval.seconds ?? 300
            for i in 1...max(1, reminder.overtimeCount) {
                let overtimeDate = due.addingTimeInterval(interval * Double(i))
                let delay = overtimeDate.timeIntervalSinceNow
                guard delay > 0 else { continue }
                let index = repeatTimes.count + 1 + i
                let content = makeContent(index: index, fireDate: overtimeDate)
                content.title =
                    "\(reminder.title) Overtime! (\(index)/\(totalCount))"
                let request = UNNotificationRequest(
                    identifier: "\(reminder.id.uuidString)-overtime-\(i)",
                    content: content,
                    trigger: UNTimeIntervalNotificationTrigger(
                        timeInterval: delay,
                        repeats: false
                    )
                )
                center.add(request) { error in
                    if let error {
                        print("Failed to schedule overtime: \(error)")
                    }
                }
            }
        }

        center.getPendingNotificationRequests { requests in
            print("Pending notifications (\(requests.count)):")
            for r in requests {
                print("  - \(r.identifier): \(r.trigger.debugDescription)")
            }
        }
    }

    func cancel(id: UUID) {
        let center = UNUserNotificationCenter.current()
        var ids = [id.uuidString]
        for i in 1...20 { ids.append("\(id.uuidString)-repeat-\(i)") }
        for i in 1...20 { ids.append("\(id.uuidString)-overtime-\(i)") }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }
}

// MARK: - Store

class ReminderStore: ObservableObject {
    @Published var reminders: [Reminder] = [] {
        didSet { save() }
    }

    private let key = "reminders_v1"
    private var isLoading = false

    init() { load() }

    func add(_ r: Reminder) {
        var reminder = r
        if reminder.syncToCalendar && reminder.dueDate != nil {
            reminder.calendarEventID = CalendarManager.shared.addEvent(
                for: reminder
            )
        }
        reminders.insert(reminder, at: 0)
        NotificationManager.shared.schedule(reminder: r)
    }

    func toggle(_ r: Reminder) {
        if let i = reminders.firstIndex(where: { $0.id == r.id }) {
            reminders[i].isDone.toggle()
            if reminders[i].isDone {
                NotificationManager.shared.cancel(id: r.id)
            } else {
                NotificationManager.shared.schedule(reminder: reminders[i])
            }
        }
    }

    func delete(_ r: Reminder) {
        NotificationManager.shared.cancel(id: r.id)
        print(
            "Deleting reminder, calendarEventID: \(String(describing: r.calendarEventID))"
        )
        if let eventID = r.calendarEventID {
            CalendarManager.shared.removeEvent(identifier: eventID)
        }
        reminders.removeAll { $0.id == r.id }
    }

    func update(_ r: Reminder) {
        if let i = reminders.firstIndex(where: { $0.id == r.id }) {
            var reminder = r
            if reminder.syncToCalendar {
                reminder.calendarEventID = CalendarManager.shared.updateEvent(
                    for: reminder
                )
            } else if let existingID = reminder.calendarEventID {
                // Sync was turned off, remove the existing event
                CalendarManager.shared.removeEvent(identifier: existingID)
                reminder.calendarEventID = nil
            }
            reminders[i] = r
            NotificationManager.shared.schedule(reminder: r)
        }
    }

    private func save() {
        guard !isLoading else { return }
        if let data = try? JSONEncoder().encode(reminders) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        isLoading = true
        if let data = UserDefaults.standard.data(forKey: key),
            let decoded = try? JSONDecoder().decode([Reminder].self, from: data)
        {
            reminders = decoded
        } else {
            reminders = sampleData()
        }
        isLoading = false
    }

    private func sampleData() -> [Reminder] {
        [
            Reminder(
                title: "Review project proposal",
                category: .work,
                dueDate: Date().addingTimeInterval(7200),
                repeatInterval: .none,
                repeatUntilEvent: true
            ),
            Reminder(
                title: "Take medication",
                category: .health,
                dueDate: Date().addingTimeInterval(1800),
                repeatInterval: .hours(1),
                repeatUntilEvent: true
            ),
            Reminder(
                title: "Call client back",
                category: .urgent,
                dueDate: Date().addingTimeInterval(-3600),
                repeatInterval: .minutes(15),
                repeatUntilEvent: true
            ),
        ]
    }
}

// MARK: - Add / Edit Sheet

struct AddReminderSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: ReminderStore

    var editing: Reminder? = nil

    @State private var title: String = ""
    @State private var category: ReminderCategory = .work
    @State private var hasDue: Bool = false
    @State private var dueDate: Date = Date().addingTimeInterval(3600)
    @State private var repeatInterval: RepeatInterval = .none
    @State private var repeatCount: Int = 0  // 0 = until done
    @State private var customHours: Int = 0  // custom hours (slider)
    @State private var customMinutes: Int = 5  // custom minutes (slider)
    @State private var showCustomField: Bool = false
    @State private var repeatUntilEvent: Bool = true
    @State private var remindersOvertime: Bool = false
    @State private var overtimeCount: Int = 1
    @State private var syncToCalendar: Bool = false
    @State private var showTitleError = false
    @State private var note: String = ""
    @State private var startDate: Date = Date()
    @State private var showDateError = false
    @State private var dateErrorMessage = ""
    @FocusState private var noteFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Reminder title", text: $title)
                        .foregroundColor(.white)
                    Picker("Category", selection: $category) {
                        ForEach(ReminderCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                        }
                    }
                }
                .listRowBackground(Color.appCard)

                Section("Date & Time") {
                    Toggle("Set Date", isOn: $hasDue)
                        .tint(.appOrange)

                    if hasDue {
                        Button(action: {
                            startDate = Date()
                        }) {
                            HStack {
                                Text("Update to current time")
                                    // .font(.subheadline)
                                    // .fontWeight(.medium)
                                    .foregroundColor(.appOrange)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)

                        DatePicker(
                            "Starts",
                            selection: $startDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .colorScheme(.dark)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        DatePicker(
                            "Ends",
                            selection: $dueDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .colorScheme(.dark)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                        Toggle("Sync to Apple Calendar", isOn: $syncToCalendar)
                            .tint(.appOrange)
                    }
                }
                .listRowBackground(Color.appCard)

                Section("Repeat") {
                    Picker("Interval", selection: $repeatInterval) {
                        ForEach(RepeatInterval.presets, id: \.self) {
                            interval in
                            Text(interval.label).tag(interval)
                        }
                        if case .custom(let m) = repeatInterval {
                            Text(repeatInterval.label).tag(
                                RepeatInterval.custom(m)
                            )
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.appOrange)

                    Button(
                        showCustomField ? "Hide custom" : "Set custom interval"
                    ) {
                        showCustomField.toggle()
                        if showCustomField {
                            updateCustomInterval()
                        }
                    }
                    .foregroundColor(.appOrange)

                    if showCustomField {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Custom interval")
                                .foregroundColor(.white)
                                .font(.headline)

                            HStack(spacing: 20) {

                                Picker("Hours", selection: $customHours) {
                                    ForEach(0..<24, id: \.self) { hour in
                                        Text("\(hour) h").tag(hour)
                                    }
                                }
                                .frame(maxWidth: .infinity)

                                Picker("Minutes", selection: $customMinutes) {
                                    ForEach(0..<60, id: \.self) { min in
                                        Text("\(min) m").tag(min)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 120)
                            .onChange(of: customHours) {
                                updateCustomInterval()
                            }
                            .onChange(of: customMinutes) {
                                updateCustomInterval()
                            }
                        }
                    }

                    if repeatInterval != .none {
                        Toggle(
                            "Repeat until event time",
                            isOn: $repeatUntilEvent
                        )
                        .tint(.appOrange)
                        //.foregroundColor(.white)
                    }
                }
                .listRowBackground(Color.appCard)

                //                Section {
                //                    NavigationLink {
                //                        Form {
                //                            Toggle("Overtime Reminders", isOn: $remindersOvertime)
                //                                    .tint(.appOrange)
                //                        }
                //                        .navigationTitle("Advanced Options")
                //                    } label: {
                //                        Text("Advanced Options")
                //                            .foregroundColor(.appOrange)
                //                    }
                //                }
                //                .listRowBackground(Color.appCard)

                Section("Notes") {
                    TextField(
                        "Add a short note (optional)",
                        text: $note,
                        axis: .vertical
                    )
                    .lineLimit(2...4)
                    .foregroundColor(.white)
                    .focused($noteFieldFocused)
                }
                .listRowBackground(Color.appCard)

                Section {
                    NavigationLink {
                        Form {
                            Section {
                                Toggle(
                                    "Overtime Reminders",
                                    isOn: $remindersOvertime
                                )
                                .tint(.appOrange)
                            }
                            .listRowBackground(Color.appCard)

                            if remindersOvertime {
                                Section("Overtime Notifications") {
                                    Stepper(
                                        "Notify \(overtimeCount) time\(overtimeCount == 1 ? "" : "s")",
                                        value: $overtimeCount,
                                        in: 1...20
                                    )
                                    .foregroundColor(.white)
                                }
                                .listRowBackground(Color.appCard)
                            }
                        }
                        .scrollContentBackground(.hidden)
                        // .background(Color.appNavy)
                        .navigationTitle("Advanced Options")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarColorScheme(.dark, for: .navigationBar)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Save") { save() }
                                    .foregroundColor(.appOrange)
                            }
                        }
                        .alert("Missing Title", isPresented: $showTitleError) {
                            Button("OK", role: .cancel) {}
                        } message: {
                            Text("Please enter a title before saving.")
                        }
                        .alert(
                            "Invalid Date or Time",
                            isPresented: $showDateError
                        ) {
                            Button("OK", role: .cancel) {}
                        } message: {
                            Text(dateErrorMessage)
                        }
                    } label: {
                        Text("Advanced Options")
                            .foregroundColor(.appOrange)
                    }
                }
                .listRowBackground(Color.appCard)
            }
            .scrollContentBackground(.hidden)
            .background(Color.appNavy)
            .scrollDismissesKeyboard(.interactively)  // maybe remove if annoying
            .navigationTitle(editing == nil ? "New Reminder" : "Edit Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.appGreyLight)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .foregroundColor(.appOrange)
                }
//                ToolbarItem(placement: .keyboard) {
//                    HStack {
//                        Spacer()
//                        Button {
//                            noteFieldFocused = false
//                        } label: {
//                            Text("Done")
//                                .font(.system(size: 15, weight: .semibold))
//                                .foregroundColor(.white)
//                                .padding(.horizontal, 20)
//                                .padding(.vertical, 8)
//                                .background(Color.appGreyLight)
//                                .clipShape(Capsule())
//                        }
//                        Spacer()
//                    }
//                    .padding(.horizontal, 16)
//                    .padding(.vertical, 6)
//                    //  .background(Color.appGrey)
//                    .foregroundColor(.appOrange)
//                }
            }
            .onAppear { prefill() }
            .alert("Missing Title", isPresented: $showTitleError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please enter a title before saving.")
            }
            .alert("Invalid Date or Time", isPresented: $showDateError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(dateErrorMessage)
            }
        }
    }

    private func prefill() {
        guard let r = editing else { return }
        title = r.title
        category = r.category
        hasDue = r.dueDate != nil
        startDate =
            r.startDate ?? r.dueDate?.addingTimeInterval(-3600) ?? Date()
        dueDate = r.dueDate ?? Date().addingTimeInterval(3600)
        repeatInterval = r.repeatInterval
        repeatUntilEvent = r.repeatUntilEvent
        remindersOvertime = r.remindersOvertime
        overtimeCount = r.overtimeCount
        syncToCalendar = r.syncToCalendar
        note = r.note ?? ""
        if case .custom(let m) = r.repeatInterval {
            customHours = m / 60
            customMinutes = m % 60
            showCustomField = true
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            showTitleError = true
            return
        }

        if hasDue {
            let calendar = Calendar.current
            let now = Date()

            // allow startDate to be exactly "now" or later, only reject past times
            if calendar.compare(startDate, to: now, toGranularity: .minute)
                == .orderedAscending
            {
                dateErrorMessage =
                    "The start time can't be in the past. Please choose a start date/time at or after the current date/time."
                showDateError = true
                return
            }
            if startDate >= dueDate {
                dateErrorMessage =
                    "The start date must be before the end date/time."
                showDateError = true
                return
            }
        }

        if var r = editing {
            r.title = trimmed
            r.category = category
            r.startDate = hasDue ? startDate : nil
            r.dueDate = hasDue ? dueDate : nil
            r.repeatInterval = repeatInterval
            r.repeatUntilEvent = repeatUntilEvent
            r.remindersOvertime = remindersOvertime
            r.overtimeCount = overtimeCount
            r.syncToCalendar = syncToCalendar
            r.note =
                note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil : note
            store.update(r)

        } else {
            var r = Reminder(
                title: trimmed,
                category: category,
                dueDate: hasDue ? dueDate : nil,
                repeatInterval: repeatInterval,
                repeatUntilEvent: repeatUntilEvent
            )
            r.startDate = hasDue ? startDate : nil
            r.remindersOvertime = remindersOvertime
            r.overtimeCount = overtimeCount
            r.syncToCalendar = syncToCalendar
            r.note =
                note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil : note

            store.add(r)
        }
        dismiss()
    }

    // helper function to update the custom interval (slider)
    private func updateCustomInterval() {
        let totalMinutes = (customHours * 60) + customMinutes
        if totalMinutes > 0 {
            repeatInterval = .custom(totalMinutes)
        }
    }
}

// MARK: - Reminder Row

struct ReminderRow: View {
    let reminder: Reminder
    let now: Date
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    @EnvironmentObject var settings: AppSettings

    private static let dueDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d 'at' h:mma"
        f.amSymbol = "am"
        f.pmSymbol = "pm"
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            reminder.isDone ? Color.appOrange : Color.appGrey,
                            lineWidth: 2
                        )
                        .frame(width: 26, height: 26)
                    if reminder.isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.appOrange)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    Text(reminder.title)
                        .font(.system(size: 16))
                        .foregroundColor(reminder.isDone ? .appGrey : .white)
                        .strikethrough(reminder.isDone, color: .appGrey)
                        .lineLimit(1)
                        .layoutPriority(1)

                    Spacer(minLength: 8)

                    // reminder due date on side of reminder box
                    if !settings.hideDueDateOnRow, let due = reminder.dueDate {
                        Text(Self.dueDateFormatter.string(from: due))
                            .font(.system(size: 12))
                            .foregroundColor(.appGreyLight)
                            .lineLimit(1)
                    }

                    // Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    Label(
                        reminder.category.rawValue,
                        systemImage: reminder.category.icon
                    )
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(reminder.category.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(reminder.category.color.opacity(0.15))
                    .clipShape(Capsule())
                    .lineLimit(2)
                    // .layoutPriority(1)
                    .fixedSize(horizontal: true, vertical: false)

                    if let label = reminder.dueLabel {
                        Label(label, systemImage: "clock")
                            .font(.system(size: 11))
                            .foregroundColor(
                                reminder.isOverdue ? .appOrange : .appGreyLight
                            )
                            .lineLimit(2)
                        // .lineLimit(1)
                        // .fixedSize(horizontal: true, vertical: false)
                    }
                    // Spacer()

                    if reminder.repeatInterval != .none {
                        Label(
                            reminder.repeatInterval.label,
                            systemImage: "repeat"
                        )
                        .font(.system(size: 11))
                        .foregroundColor(.appGreyLight)
                        .lineLimit(2)
                        // .lineLimit(1)
                        // .fixedSize(horizontal: true, vertical: false)
                    }

                    Spacer(minLength: 24)
                }
            }

            //            Menu {
            //                Button("Edit", systemImage: "pencil", action: onEdit)
            //                Button(
            //                    "Delete",
            //                    systemImage: "trash",
            //                    role: .destructive,
            //                    action: onDelete
            //                )
            //            } label: {
            //                Image(systemName: "ellipsis")
            //                    .foregroundColor(.appGrey)
            //                    .frame(width: 30, height: 30)
            //            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.appCard)
        .cornerRadius(14)
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
        .overlay(alignment: .topTrailing) {
            Menu {
                Button("Edit", systemImage: "pencil", action: onEdit)
                Button(
                    "Delete",
                    systemImage: "trash",
                    role: .destructive,
                    action: onDelete
                )
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.appGrey)
                    .frame(width: 30, height: 30)
            }
            .padding(.top, 34)
            .padding(.trailing, 12)
        }
    }
}

// MARK: - Stats Bar

struct StatsBar: View {
    let reminders: [Reminder]

    var total: Int { reminders.count }
    var active: Int { reminders.filter { !$0.isDone }.count }
    var done: Int { reminders.filter { $0.isDone }.count }
    var overdue: Int { reminders.filter { $0.isOverdue }.count }

    var body: some View {
        HStack(spacing: 10) {
            StatPill(label: "Total", value: total, color: .white)
            StatPill(label: "Active", value: active, color: .appRoyalBlue)
            StatPill(label: "Done", value: done, color: .appGrey)
            StatPill(label: "Overdue", value: overdue, color: .appOrange)
        }
    }
}

struct StatPill: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.appGreyLight)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.appCard)
        .cornerRadius(12)
    }
}

// MARK: - Filter Bar

enum FilterOption: String, CaseIterable {
    case all = "All"
    case active = "Active"
    case done = "Done"
    case work = "Work"
    case personal = "Personal"
    case health = "Health"
    case urgent = "Urgent"
    case other = "Other"
}

struct FilterBar: View {
    @Binding var selected: FilterOption

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FilterOption.allCases, id: \.self) { opt in
                    Button(opt.rawValue) { selected = opt }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(
                            selected == opt ? .black : .appGreyLight
                        )
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            selected == opt ? Color.appOrange : Color.appCard
                        )
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 1)
        }
    }
}

// MARK: - Splash Screen

struct SplashView: View {
    @State private var animate = false
    @State private var showMain = false

    var body: some View {
        if showMain {
            RootTabView()
        } else {
            ZStack {

                LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.18, blue: 0.38),
                        Color(red: 0.07, green: 0.13, blue: 0.30),
                        Color(red: 0.10, green: 0.18, blue: 0.38),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 30) {

                    Image("AlertMeMainLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                        .scaleEffect(animate ? 1.0 : 0.85)
                        .opacity(animate ? 1 : 0)
                        .animation(.easeOut(duration: 1.0), value: animate)
                        .offset(y: -30)

                    HStack(spacing: 10) {
                        BounceDot(delay: 0.0)
                        BounceDot(delay: 0.2)
                        BounceDot(delay: 0.4)
                    }
                }
            }
            .onAppear {
                animate = true

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        showMain = true
                    }
                }
            }
        }
    }
}

struct BounceDot: View {
    let delay: Double
    @State private var move = false

    var body: some View {
        Circle()
            .fill(Color.appOrange)
            .frame(width: 14, height: 14)
            .offset(y: move ? -8 : 8)
            .animation(
                .easeInOut(duration: 0.55)
                    .repeatForever()
                    .delay(delay),
                value: move
            )
            .onAppear {
                move = true
            }
    }
}

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject var store: ReminderStore
    @State private var showAdd = false
    @State private var editingReminder: Reminder? = nil
    @State private var filter: FilterOption = .all
    @State private var repeatUntilEvent: Bool = true
    @State private var now: Date = Date()
    @State private var showDeleteCompletedConfirm = false

    var filtered: [Reminder] {
        switch filter {
        case .all: return store.reminders
        case .active: return store.reminders.filter { !$0.isDone }
        case .done: return store.reminders.filter { $0.isDone }
        case .work: return store.reminders.filter { $0.category == .work }
        case .personal:
            return store.reminders.filter { $0.category == .personal }
        case .health: return store.reminders.filter { $0.category == .health }
        case .urgent: return store.reminders.filter { $0.category == .urgent }
        case .other: return store.reminders.filter { $0.category == .other }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.appNavy
                    .ignoresSafeArea(.all)

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 0) {
                            Text("Alert")
                                .foregroundColor(.appOrange)
                            Text(" Me!")
                                .foregroundColor(.white)
                        }
                        .font(.system(size: 34, weight: .bold))

                        Text("Your personal reminder assistant")
                            .foregroundColor(.appGreyLight)
                            .font(.system(size: 14))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 25)

                    StatsBar(reminders: store.reminders)
                        .padding(.horizontal)
                    FilterBar(selected: $filter)
                        .padding(.horizontal)

                    if filtered.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "bell.slash.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.appGrey)
                            Text("Peace of mind, no reminders.")
                                .foregroundColor(.appGrey)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(filtered) { reminder in
                                ReminderRow(
                                    reminder: reminder,
                                    now: now,
                                    onToggle: { store.toggle(reminder) },
                                    onDelete: { store.delete(reminder) },
                                    onEdit: { editingReminder = reminder }
                                )
                                //                                .onTapGesture(count: 1) {
                                //                                    editingReminder = reminder
                                //                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 100)
                }
                .padding(.top, 12)

                // FAB
                Button {
                    showAdd = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.appOrange)
                            .frame(width: 60, height: 60)
                        Image(systemName: "plus")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .shadow(
                        color: Color.appOrangeDeep.opacity(0.5),
                        radius: 8,
                        y: 4
                    )
                }
                // .padding(.trailing, 24)
                .padding(.bottom, 34)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if store.reminders.contains(where: { $0.isDone }) {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Delete ✓") {
//                            let doneReminders = store.reminders.filter {
//                                $0.isDone
//                            }
//                            for r in doneReminders {
//                                store.delete(r)
//                            }
                            showDeleteCompletedConfirm = true
                        }
                        .foregroundColor(.appOrange)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .toolbarBackground(Color.appNavy, for: .bottomBar)
        .sheet(isPresented: $showAdd) {
            AddReminderSheet(store: store)
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingReminder) { r in
            AddReminderSheet(store: store, editing: r)
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            NotificationManager.shared.requestPermission()
        }
        .onReceive(
            Timer.publish(every: 60, on: .main, in: .common).autoconnect()
        ) { _ in
            now = Date()
        }
        .alert( "Delete completed reminders?", isPresented: $showDeleteCompletedConfirm ) { Button("Delete", role: .destructive) {
            let doneReminders = store.reminders.filter {
                $0.isDone
            }
            for r in doneReminders {
                store.delete(r)
            }
        }
        Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all completed reminders.")
        }
    }
}

// MARK: - Root Tab View

struct RootTabView: View {
    @StateObject private var store = ReminderStore()
    @StateObject private var settings = AppSettings.shared

    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("Reminders", systemImage: "clock")
                }

            CalendarTabView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
            AlarmsTabView()
                .tabItem {
                    Label("Alarms", systemImage: "alarm")
                }

            MoreView()
                .tabItem {
                    Label("More", systemImage: "ellipsis")
                }
        }
        .environmentObject(store)
        .environmentObject(settings)
        .tint(.appOrange)
        .toolbarBackground(Color.appNavyLight, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
    }

}

// MARK: - More View

struct MoreView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appNavy.ignoresSafeArea()

                List {
                    Section {
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Label("Settings", systemImage: "gearshape.fill")
                                .foregroundColor(.white)
                        }

                        NavigationLink {
                            TutorialsHomeView()
                        } label: {
                            Label(
                                "Tutorials",
                                systemImage: "questionmark.circle.fill"
                            )
                            .foregroundColor(.white)
                        }
                    }
                    .listRowBackground(Color.appCard)

                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 44))
                                .foregroundColor(.appGrey)
                            Text("More options coming soon")
                                .foregroundColor(.appGreyLight)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .scrollContentBackground(.hidden)
                .padding(.top, 10)
                .listSectionSpacing(.compact)
            }
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
    }
}

// MARK: - App Settings

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var hideDueDateOnRow: Bool {
        didSet {
            UserDefaults.standard.set(
                hideDueDateOnRow,
                forKey: "hideDueDateOnRow"
            )
        }
    }

    init() {
        self.hideDueDateOnRow = UserDefaults.standard.bool(
            forKey: "hideDueDateOnRow"
        )
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        ZStack {
            Color.appNavy.ignoresSafeArea()

            List {
                Section("Reminders Display") {
                    Toggle(
                        "Hide Due Date on Reminders",
                        isOn: $settings.hideDueDateOnRow
                    )
                    .tint(.appOrange)
                    .foregroundColor(.white)
                }
                .listRowBackground(Color.appCard)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Tutroials View

struct TutorialsHomeView: View {
    var body: some View {
        ZStack {
            Color.appNavy.ignoresSafeArea()

            List {
                Section {
                    NavigationLink {
                        TutorialView()
                    } label: {
                        Label(
                            "How do I use Reminders?",
                            systemImage: "clock.fill"
                        )
                        .foregroundColor(.white)
                    }

                    NavigationLink {
                        CalendarTutorialView()
                    } label: {
                        Label(
                            "How do I navigate the Calendar?",
                            systemImage: "calendar"
                        )
                        .foregroundColor(.white)
                    }
                }
                .listRowBackground(Color.appCard)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Tutorials")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Tutorial Models

struct TutorialStep: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let color: Color
}

private let tutorialSteps: [TutorialStep] = [
    TutorialStep(
        icon: "plus.circle.fill",
        title: "Creating a Reminder",
        description:
            "Tap the orange + button on the Reminders tab. Give it a title, pick a category, and optionally set a date & time.",
        color: .appOrange
    ),
    TutorialStep(
        icon: "tag.fill",
        title: "Categories",
        description:
            "Sort reminders into Work, Personal, Health, Urgent, or Other. Each has its own color and icon so you can find your categories easily.",
        color: .appRoyalBlue
    ),
    TutorialStep(
        icon: "clock.arrow.circlepath",
        title: "Start & End Times",
        description:
            "The Start time controls when repeating notifications begin counting down from. The End time is when the reminder is actually due. You can automatically update a reminder's start time by tapping 'Update to current time'.",
        color: Color(red: 0.2, green: 0.6, blue: 0.5)
    ),
    TutorialStep(
        icon: "repeat",
        title: "Repeating Notifications",
        description:
            "Set a reminder to repeat notifications/alerts every few minutes or hours leading up to the due time (great for things you don't want to miss!)",
        color: .appGreyLight
    ),
    TutorialStep(
        icon: "clock.badge.exclamationmark",
        title: "Custom Intervals",
        description:
            "Need something else other than the presets? Tap 'Set custom interval' in the Repeat section to customize an exact hours/minutes repeating invterval.",
        color: .appOrangeDeep
    ),
    TutorialStep(
        icon: "note.text",
        title: "Adding Notes",
        description:
            "Add a short note to any reminder in the Notes section. When a notification for that reminder arrives, it'll say \" - check note.\" as a reminder to open the app.",
        color: .appRoyalBlue
    ),
    TutorialStep(
        icon: "arrow.triangle.2.circlepath",
        title: "Syncing to Apple Calendar",
        description:
            "Turn on 'Sync to Apple Calendar' when creating or editing a reminder to automatically create a matching event inside of Apple Calendar. Deleting the reminder removes the event from both platforms.",
        color: .appOrange
    ),
    TutorialStep(
        icon: "bolt.fill",
        title: "Overtime Notifications",
        description:
            "In Advanced Options, turn on Overtime Reminders to keep getting notified even after a reminder's due time has passed.",
        color: Color(red: 0.2, green: 0.6, blue: 0.5)
    ),
    TutorialStep(
        icon: "checkmark.circle.fill",
        title: "Completing & Editing",
        description:
            "Tap the circle to mark a reminder as 'completed'. Tap a reminder, or use the ⋯ menu, to edit or delete it.",
        color: .appOrange
    ),
    TutorialStep(
        icon: "line.3.horizontal.decrease.circle.fill",
        title: "Filtering Your List",
        description:
            "Use the filter bar to quickly jump between All, Active, Done, or specific category reminders.",
        color: .appRoyalBlue
    ),
    TutorialStep(
        icon: "gearshape.fill",
        title: "Settings",
        description:
            "Visit Settings in the More tab to customize how reminders are displayed, like hiding the due date shown on each reminder card.",
        color: .appGrey
    ),
]

private let calendarTutorialSteps: [TutorialStep] = [
    TutorialStep(
        icon: "calendar",
        title: "Viewing Your Day",
        description:
            "Tap any date on the calendar to see everything scheduled for that day, shown below the calendar grid.",
        color: .appRoyalBlue
    ),
    TutorialStep(
        icon: "app.badge.checkmark",
        title: "Sorting through Events",
        description:
            "Reminders that you create in Alert Me! appear under 'Reminders'. Events from your Apple Calendar, or created directly in the Calendar app, appear separately under 'Apple Calendar' so nothing shows twice.",
        color: Color(red: 0.2, green: 0.6, blue: 0.5)
    ),
    TutorialStep(
        icon: "arrow.triangle.2.circlepath",
        title: "Syncing to Calendar",
        description:
            "When you add a reminder with a due date and turn on 'Sync to Apple Calendar', Alert Me! automatically creates a matching event in your Apple Calendar. Deleting a reminder in either app removes it from both, keeping everything in sync.",
        color: .appOrange
    ),
]

// MARK: - Tutorial View

struct TutorialView: View {
    var body: some View {
        ZStack {
            Color.appNavy.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("How to use Reminders")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        Text(
                            "A quick walkthrough of the app's reminder features."
                        )
                        .font(.system(size: 14))
                        .foregroundColor(.appGreyLight)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    VStack(spacing: 12) {
                        ForEach(tutorialSteps) { step in
                            TutorialCard(step: step)
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle("Reminders Tutorial")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

struct CalendarTutorialView: View {
    var body: some View {
        ZStack {
            Color.appNavy.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("How do I navigate the Calendar?")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        Text("Understanding the Calendar tab.")
                            .font(.system(size: 14))
                            .foregroundColor(.appGreyLight)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    VStack(spacing: 12) {
                        ForEach(calendarTutorialSteps) { step in
                            TutorialCard(step: step)
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle("Calendar Tutorial")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

private struct TutorialCard: View {
    let step: TutorialStep

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(step.color.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: step.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(step.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(step.description)
                    .font(.system(size: 13))
                    .foregroundColor(.appGreyLight)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(14)
        .background(Color.appCard)
        .cornerRadius(14)
    }
}

struct CalendarTabView: View {
    @EnvironmentObject var store: ReminderStore
    @StateObject private var calendarManager = CalendarManager.shared
    @State private var selectedDate = Date()

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        return formatter
    }()

    var reminderItems: [Reminder] {
        store.reminders.filter { r in
            guard let due = r.dueDate else { return false }
            return Calendar.current.isDate(due, inSameDayAs: selectedDate)
        }
    }

    var eventItems: [EKEvent] {
        //        calendarManager.appleEvents.filter {
        //            Calendar.current.isDate($0.startDate, inSameDayAs: selectedDate)
        //        }
        let appManagedIDs = Set(
            store.reminders.compactMap { $0.calendarEventID }
        )
        return calendarManager.appleEvents.filter {
            Calendar.current.isDate($0.startDate, inSameDayAs: selectedDate)
                && !appManagedIDs.contains($0.eventIdentifier)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appNavy.ignoresSafeArea()

                VStack(spacing: 0) {
                    DatePicker(
                        "",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .colorScheme(.dark)
                    .tint(.appOrange)
                    .padding(.horizontal)
                    .background(Color.appCard)
                    .cornerRadius(14)
                    .padding()

                    if !calendarManager.authorized {
                        VStack(spacing: 10) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: 36))
                                .foregroundColor(.appGrey)
                            Text("Calendar access needed")
                                .foregroundColor(.appGreyLight)
                            Button("Grant Access") {
                                calendarManager.requestAccess()
                            }
                            .foregroundColor(.appOrange)
                        }
                        .padding(.top, 40)
                    } else {
                        List {
                            //                            if !eventItems.isEmpty {
                            //                                Section("Apple Calendar") {
                            //                                    ForEach(eventItems, id: \.eventIdentifier) { event in
                            //                                        Label(event.title, systemImage: "calendar")
                            //                                            .foregroundColor(.white)
                            //                                    }
                            //                                }
                            //                                .listRowBackground(Color.appCard)
                            //                            }
                            if !eventItems.isEmpty {
                                Section("Apple Calendar") {
                                    ForEach(eventItems, id: \.eventIdentifier) {
                                        event in
                                        HStack {
                                            Label(
                                                event.title,
                                                systemImage: "calendar"
                                            )
                                            .foregroundColor(.white)
                                            Spacer()
                                            Text(
                                                "at \(timeFormatter.string(from: event.startDate).lowercased())"
                                            )
                                            .font(.system(size: 16))
                                            .foregroundColor(.appGreyLight)
                                        }
                                    }
                                }
                                .listRowBackground(Color.appCard)
                            }

                            //                            if !reminderItems.isEmpty {
                            //                                Section("Reminders") {
                            //                                    ForEach(reminderItems) { r in
                            //                                        Label(r.title, systemImage: r.category.icon)
                            //                                            .foregroundColor(r.category.color)
                            //                                    }
                            //                                }
                            //                                .listRowBackground(Color.appCard)
                            //                            }

                            if !reminderItems.isEmpty {
                                Section("Reminders") {
                                    ForEach(reminderItems) { r in
                                        HStack {
                                            Label(
                                                r.title,
                                                systemImage: r.category.icon
                                            )
                                            .foregroundColor(r.category.color)
                                            Spacer()
                                            if let due = r.dueDate {
                                                Text(
                                                    "at \(timeFormatter.string(from: due).lowercased())"
                                                )
                                                .font(.system(size: 16))
                                                .foregroundColor(.appGreyLight)
                                            }
                                        }
                                    }
                                }
                                .listRowBackground(Color.appCard)
                            }

                            if eventItems.isEmpty && reminderItems.isEmpty {
                                Text("Nothing scheduled this day")
                                    .foregroundColor(.appGreyLight)
                                    .listRowBackground(Color.clear)
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
        .onAppear {
            //            // if calendarManager.authorized {
            //                calendarManager.fetchEvents()
            //            }
            calendarManager.checkAuthorizationStatus()
        }
    }
}

#Preview {
    SplashView()
}
