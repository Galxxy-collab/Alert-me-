//
//  CalendarManager.swift
//  Alert Me!
//
//  Created by Eric Ardelean on 2026-08-07.
//

import Combine
import EventKit

class CalendarManager: ObservableObject {
    static let shared = CalendarManager()
    let store = EKEventStore()

    @Published var authorized = false
    @Published var appleEvents: [EKEvent] = []

    init() {
        checkAuthorizationStatus()
    }

    func checkAuthorizationStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .fullAccess, .authorized:
            authorized = true
            fetchEvents()
        default:
            authorized = false
        }
    }

    func requestAccess() {
        store.requestFullAccessToEvents { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.authorized = granted
                if granted { self?.fetchEvents() }
            }
        }
    }

    func fetchEvents(daysAhead: Int = 30, daysBehind: Int = 7) {
        guard authorized else { return }
        let start = Calendar.current.date(
            byAdding: .day,
            value: -daysBehind,
            to: Date()
        )!
        let end = Calendar.current.date(
            byAdding: .day,
            value: daysAhead,
            to: Date()
        )!
        let predicate = store.predicateForEvents(
            withStart: start,
            end: end,
            calendars: nil
        )
        appleEvents = store.events(matching: predicate).sorted {
            $0.startDate < $1.startDate
        }
    }

    // Writes a Reminder into Apple Calendar. Returns the EKEvent identifier to store back on the Reminder if you want two-way linking.
    func addEvent(for reminder: Reminder) -> String? {
        guard authorized, let due = reminder.dueDate else { return nil }
        let event = EKEvent(eventStore: store)
        event.title = reminder.title
        event.startDate = due
        event.endDate = due.addingTimeInterval(1800)  // 30 min block
        // event.calendar = store.defaultCalendarForNewEvents
        if let defaultCal = store.defaultCalendarForNewEvents {
            event.calendar = defaultCal
        } else if let writableCal = store.calendars(for: .event).first(where: {
            $0.allowsContentModifications
        }) {
            event.calendar = writableCal
        } else {
            print("No writable calendar available, cannot save event")
            return nil
        }
        event.notes =
            "Created from Alert Me, category: \(reminder.category.rawValue)"

        do {
            try store.save(event, span: .thisEvent)
            fetchEvents()
            return event.eventIdentifier
        } catch {
            print("Failed to save event: \(error)")
            return nil
        }
    }

    func removeEvent(identifier: String) {
        guard let event = store.event(withIdentifier: identifier) else {
            print("removeEvent: no event found for identifier \(identifier)")
            return
        }
        do {
            try store.remove(event, span: .thisEvent)
            print("removeEvent: successfully removed \(identifier)")
        } catch {
            print("removeEvent: failed — \(error)")
        }
        fetchEvents()
    }

    func updateEvent(for reminder: Reminder) -> String? {
        guard authorized else { return reminder.calendarEventID }

        // No due date anymore, remove the existing event if there was one
        guard let due = reminder.dueDate else {
            if let existingID = reminder.calendarEventID {
                removeEvent(identifier: existingID)
            }
            return nil
        }

        if let existingID = reminder.calendarEventID,
            let event = store.event(withIdentifier: existingID)
        {
            // Event already exists, update it in place
            event.title = reminder.title
            event.startDate = due
            event.endDate = due.addingTimeInterval(1800)
            event.notes =
                "Created from Alert Me — \(reminder.category.rawValue)"
            do {
                try store.save(event, span: .thisEvent)
                fetchEvents()
                return event.eventIdentifier
            } catch {
                print("Failed to update event: \(error)")
                return existingID
            }
        } else {
            // No linked event yet (or it was removed externally), create one
            return addEvent(for: reminder)
        }
    }
}
