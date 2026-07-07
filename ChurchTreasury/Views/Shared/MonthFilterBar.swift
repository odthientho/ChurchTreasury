import SwiftUI

/// A compact month/year filter: `‹ August 2026 ›` with prev/next stepping and
/// a tap-to-pick sheet (month + year wheels, plus a "This Month" reset). Binds
/// to a `Date` normalized to the first of the selected month. Shared by the
/// Offerings and Expenses tabs so both browse period-by-period the same way.
struct MonthFilterBar: View {
    @Binding var month: Date
    @State private var showingPicker = false

    var body: some View {
        HStack {
            Button {
                step(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)

            Spacer()

            Button {
                showingPicker = true
            } label: {
                HStack(spacing: 6) {
                    Text(month.monthYearLabel)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tint)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                step(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
        }
        .sheet(isPresented: $showingPicker) {
            MonthYearPickerSheet(month: $month)
                .presentationDetents([.height(320)])
        }
    }

    private func step(_ delta: Int) {
        if let stepped = Calendar.current.date(byAdding: .month, value: delta, to: month) {
            month = stepped.startOfMonth
        }
    }
}

/// Month + year wheel pickers for jumping the filter to an arbitrary period.
private struct MonthYearPickerSheet: View {
    @Binding var month: Date
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMonth: Int
    @State private var selectedYear: Int

    init(month: Binding<Date>) {
        _month = month
        let comps = Calendar.current.dateComponents([.month, .year], from: month.wrappedValue)
        _selectedMonth = State(initialValue: comps.month ?? 1)
        _selectedYear = State(initialValue: comps.year
            ?? Calendar.current.component(.year, from: Date()))
    }

    /// A generous window around the current year — treasury records don't run
    /// far into the future, but past years must stay reachable for history.
    private var years: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array((current - 15)...(current + 1))
    }

    private var monthSymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.standaloneMonthSymbols
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                Picker(String(localized: "field.month"), selection: $selectedMonth) {
                    ForEach(1...12, id: \.self) { month in
                        Text(monthSymbols[month - 1]).tag(month)
                    }
                }
                .pickerStyle(.wheel)

                Picker(String(localized: "field.year"), selection: $selectedYear) {
                    ForEach(years, id: \.self) { year in
                        Text(verbatim: String(year)).tag(year)
                    }
                }
                .pickerStyle(.wheel)
            }
            .labelsHidden()
            .navigationTitle(String(localized: "filter.selectMonth"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "filter.thisMonth")) {
                        month = Date().startOfMonth
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.done")) {
                        apply()
                        dismiss()
                    }
                }
            }
        }
    }

    private func apply() {
        var comps = DateComponents()
        comps.year = selectedYear
        comps.month = selectedMonth
        comps.day = 1
        if let date = Calendar.current.date(from: comps) {
            month = date.startOfMonth
        }
    }
}
