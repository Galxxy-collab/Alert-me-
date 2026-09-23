// AlarmFeature.swift
//
// Add this file to your Xcode project (same target as your main UI file).
// It is self-contained — it reuses your existing Color extensions
// (.appNavy, .appOrange, .appCard, etc.) and NotificationManager.requestPermission().
//
// INTEGRATION: only 1 change is needed in your existing file — see the
// bottom of this comment for the exact snippet to add to RootTabView.

import Combine
import SwiftUI
import UserNotifications

// MARK: - Alarm Model

struct Alarm: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var label: String = "Alarm"
    var hour: Int  // 0-23
    var minute: Int  // 0-59
    var repeatDays: Set<Int> = []  // Calendar weekday: 1 = Sun ... 7 = Sat. Empty = one-shot.
    var isEnabled: Bool = true

    var timeString: String {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let date = Calendar.current.date(from: comps) ?? Date()
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    var repeatSummary: String {
        guard !repeatDays.isEmpty else { return "Once" }
        let sorted = repeatDays.sorted()
        if sorted.count == 7 { return "Every day" }
        if sorted == [2, 3, 4, 5, 6] { return "Weekdays" }
        if sorted == [1, 7] { return "Weekends" }
        let symbols = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return sorted.map { symbols[$0] }.joined(separator: " ")
    }

    /// Next time this alarm will fire, honoring repeatDays. Empty repeatDays = next
    /// occurrence of hour:minute (today if still ahead, otherwise tomorrow).
    func nextFireDate(
        after reference: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        if repeatDays.isEmpty {
            var comps = calendar.dateComponents(
                [.year, .month, .day],
                from: reference
            )
            comps.hour = hour
            comps.minute = minute
            comps.second = 0
            guard var candidate = calendar.date(from: comps) else { return nil }
            if candidate <= reference {
                candidate =
                    calendar.date(byAdding: .day, value: 1, to: candidate)
                    ?? candidate
            }
            return candidate
        } else {
            var best: Date?
            for day in repeatDays {
                var comps = DateComponents()
                comps.weekday = day
                comps.hour = hour
                comps.minute = minute
                comps.second = 0
                if let next = calendar.nextDate(
                    after: reference,
                    matching: comps,
                    matchingPolicy: .nextTime
                ) {
                    if best == nil || next < best! { best = next }
                }
            }
            return best
        }
    }
}

// MARK: - Alarm Manager (scheduling)
// Mirrors your NotificationManager, but uses UNCalendarNotificationTrigger
// (clock-time based) instead of UNTimeIntervalNotificationTrigger.

class AlarmManager {
    static let shared = AlarmManager()

    func schedule(_ alarm: Alarm) {
        cancel(id: alarm.id)
        guard alarm.isEnabled else { return }

        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title =
            alarm.label.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Alarm" : alarm.label
        content.body = alarm.timeString
    
        content.sound = UNNotificationSound(named: UNNotificationSoundName("alarmsound.wav"))
        content.interruptionLevel = .timeSensitive

        if alarm.repeatDays.isEmpty {
            // One-shot alarm: fires once at the next occurrence of hour:minute.
            guard let fireDate = alarm.nextFireDate() else { return }
            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: comps,
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: alarm.id.uuidString,
                content: content,
                trigger: trigger
            )
            center.add(request) { error in
                if let error { print("Failed to schedule alarm: \(error)") }
            }
        } else {
            // Repeating alarm: one weekly-repeating request per selected weekday.
            for day in alarm.repeatDays {
                var comps = DateComponents()
                comps.weekday = day
                comps.hour = alarm.hour
                comps.minute = alarm.minute
                comps.second = 0
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: comps,
                    repeats: true
                )
                let request = UNNotificationRequest(
                    identifier: "\(alarm.id.uuidString)-day-\(day)",
                    content: content,
                    trigger: trigger
                )
                center.add(request) { error in
                    if let error {
                        print("Failed to schedule alarm day \(day): \(error)")
                    }
                }
            }
        }
    }

    func cancel(id: UUID) {
        let center = UNUserNotificationCenter.current()
        var ids = [id.uuidString]
        for day in 1...7 { ids.append("\(id.uuidString)-day-\(day)") }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }
}

// MARK: - Alarm Store
// Mirrors your ReminderStore: UserDefaults-backed, publishes changes, auto (re)schedules.

class AlarmStore: ObservableObject {
    @Published var alarms: [Alarm] = [] {
        didSet { save() }
    }

    private let key = "alarms_v1"
    private var isLoading = false

    init() { load() }

    func add(_ a: Alarm) {
        alarms.append(a)
        sortAlarms()
        AlarmManager.shared.schedule(a)
    }

    func update(_ a: Alarm) {
        guard let i = alarms.firstIndex(where: { $0.id == a.id }) else {
            return
        }
        alarms[i] = a
        sortAlarms()
        AlarmManager.shared.schedule(a)
    }

    func toggle(_ a: Alarm) {
        guard let i = alarms.firstIndex(where: { $0.id == a.id }) else {
            return
        }
        alarms[i].isEnabled.toggle()
        AlarmManager.shared.schedule(alarms[i])
    }

    func delete(_ a: Alarm) {
        AlarmManager.shared.cancel(id: a.id)
        alarms.removeAll { $0.id == a.id }
    }

    private func sortAlarms() {
        alarms.sort { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
    }

    private func save() {
        guard !isLoading else { return }
        if let data = try? JSONEncoder().encode(alarms) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        isLoading = true
        if let data = UserDefaults.standard.data(forKey: key),
            let decoded = try? JSONDecoder().decode([Alarm].self, from: data)
        {
            alarms = decoded.sorted {
                ($0.hour, $0.minute) < ($1.hour, $1.minute)
            }
        }
        isLoading = false
    }
}

// MARK: - Alarm Row

struct AlarmRow: View {
    let alarm: Alarm
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(alarm.timeString)
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(alarm.isEnabled ? .white : .appGrey)
                Text(
                    "\(alarm.label.isEmpty ? "Alarm" : alarm.label) · \(alarm.repeatSummary)"
                )
                .font(.system(size: 13))
                .foregroundColor(.appGreyLight)
                .lineLimit(1)
            }

            Spacer()

            Toggle(
                "",
                isOn: Binding(
                    get: { alarm.isEnabled },
                    set: { _ in onToggle() }
                )
            )
            .labelsHidden()
            .tint(.appOrange)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.appCard)
        .cornerRadius(14)
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Add / Edit Alarm Sheet

struct AddAlarmSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: AlarmStore
    var editing: Alarm? = nil

    @State private var time: Date = Date()
    @State private var label: String = ""
    @State private var repeatDays: Set<Int> = []
    @State private var showDeleteConfirm = false

    private let weekdayLabels = ["S", "M", "T", "W", "T", "F", "S"]  // index 0 = Sunday (weekday 1)

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "",
                        selection: $time,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.appCard)

                Section("Repeat") {
                    HStack(spacing: 8) {
                        ForEach(1...7, id: \.self) { day in
                            let isSelected = repeatDays.contains(day)
                            Button {
                                if isSelected {
                                    repeatDays.remove(day)
                                } else {
                                    repeatDays.insert(day)
                                }
                            } label: {
                                Text(weekdayLabels[day - 1])
                                    .font(.system(size: 13, weight: .semibold))
                                    .frame(width: 32, height: 32)
                                    .background(
                                        isSelected
                                            ? Color.appOrange
                                            : Color.appNavyLight
                                    )
                                    .foregroundColor(
                                        isSelected ? .black : .white
                                    )
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.appCard)

                Section {
                    TextField("Label", text: $label)
                        .foregroundColor(.white)
                }
                .listRowBackground(Color.appCard)

                if editing != nil {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Alarm")
                                Spacer()
                            }
                        }
                        .foregroundColor(.red)
                    }
                    .listRowBackground(Color.appCard)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appNavy)
            .navigationTitle(editing == nil ? "New Alarm" : "Edit Alarm")
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
            }
            .onAppear { prefill() }
            .alert(
                "Delete this alarm?",
                isPresented: $showDeleteConfirm,
            ) {
                Button("Delete", role: .destructive) {
                    if let a = editing {
                        store.delete(a)
                    }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func prefill() {
        guard let a = editing else { return }
        var comps = DateComponents()
        comps.hour = a.hour
        comps.minute = a.minute
        time = Calendar.current.date(from: comps) ?? Date()
        label = a.label
        repeatDays = a.repeatDays
    }

    private func save() {
        let comps = Calendar.current.dateComponents(
            [.hour, .minute],
            from: time
        )
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0

        if var a = editing {
            a.hour = hour
            a.minute = minute
            a.label = label
            a.repeatDays = repeatDays
            store.update(a)
        } else {
            let a = Alarm(
                label: label,
                hour: hour,
                minute: minute,
                repeatDays: repeatDays
            )
            store.add(a)
        }
        dismiss()
    }
}

// MARK: - Alarms Tab

struct AlarmsTabView: View {
    @StateObject private var store = AlarmStore()
    @State private var showAdd = false
    @State private var editingAlarm: Alarm? = nil

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.appNavy.ignoresSafeArea()

                ScrollView {
                    Text("Alarms")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 25)

                    if store.alarms.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "alarm")
                                .font(.system(size: 44))
                                .foregroundColor(.appGrey)
                            Text("No alarms set.")
                                .foregroundColor(.appGrey)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(store.alarms) { alarm in
                                AlarmRow(
                                    alarm: alarm,
                                    onToggle: { store.toggle(alarm) },
                                    onEdit: { editingAlarm = alarm },
                                    onDelete: { store.delete(alarm) }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 100)
                }
                .padding(.top, 12)

                Button {
                    showAdd = true
                } label: {
                    ZStack {
                        Circle().fill(Color.appOrange).frame(
                            width: 60,
                            height: 60
                        )
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
                .padding(.bottom, 34)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showAdd) {
            AddAlarmSheet(store: store)
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingAlarm) { a in
            AddAlarmSheet(store: store, editing: a)
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            NotificationManager.shared.requestPermission()
        }
    }
}
