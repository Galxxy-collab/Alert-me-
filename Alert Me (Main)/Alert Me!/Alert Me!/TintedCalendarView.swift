//
//  TintedCalendarView.swift
//  Alert Me!
//
//  Created by Eric Ardelean on 2026-08-07.
//

import SwiftUI
import UIKit

struct TintedCalendarView: UIViewRepresentable {
    @Binding var selectedDate: Date
    let reminderDates: Set<DateComponents>

    func makeUIView(context: Context) -> UICalendarView {
        let view = UICalendarView()
        view.calendar = Calendar.current
        view.locale = Locale.current
        view.delegate = context.coordinator
        view.tintColor = UIColor(Color.appOrange)

        let selection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        selection.selectedDate = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
        view.selectionBehavior = selection

        return view
    }

    func updateUIView(_ uiView: UICalendarView, context: Context) {
        context.coordinator.parent = self
        uiView.reloadDecorations(forDateComponents: Array(reminderDates), animated: true)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var parent: TintedCalendarView

        init(parent: TintedCalendarView) {
            self.parent = parent
        }

        func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            guard parent.reminderDates.contains(dateComponents) else { return nil }
            return .default(color: UIColor(Color.appOrange), size: .small)
        }

        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            guard let dateComponents, let date = Calendar.current.date(from: dateComponents) else { return }
            parent.selectedDate = date
        }
    }
}
