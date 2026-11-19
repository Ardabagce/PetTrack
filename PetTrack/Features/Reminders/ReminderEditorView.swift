import SwiftData
import SwiftUI

struct ReminderEditorView: View {
    let pet: Pet
    var reminder: Reminder?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var category: ReminderCategory = .medication
    @State private var dueDate = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
    @State private var repeats: ReminderRepeat = .never
    @State private var notes = ""

    var body: some View {
        Form {
            Section {
                TextField("What should we remind you about?", text: $title, axis: .vertical)
                    .font(.headline)
            }
            Section("Type") {
                FlowLayout(spacing: 8) {
                    ForEach(ReminderCategory.allCases) { item in
                        ChoiceChip(title: item.title, symbol: item.symbol, isSelected: category == item) {
                            category = item
                            if title.isEmpty || ReminderCategory.allCases.contains(where: { String(localized: $0.title) == title }) {
                                title = String(localized: item.title)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            Section("When") {
                DatePicker("Date & time", selection: $dueDate)
                Picker("Repeat", selection: $repeats) {
                    ForEach(ReminderRepeat.allCases) { Text($0.title).tag($0) }
                }
            }
            Section {
                TextField("Notes", text: $notes, axis: .vertical)
            }
            if let reminder {
                Section {
                    Button("Delete reminder", role: .destructive) {
                        NotificationManager.shared.cancel(reminder)
                        context.delete(reminder)
                        try? context.save()
                        dismiss()
                    }
                }
            }
        }
        .formCanvas()
        .navigationTitle(reminder == nil ? Text("New reminder") : Text("Edit reminder"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            guard let reminder else { return }
            title = reminder.title
            category = reminder.category
            dueDate = reminder.dueDate
            repeats = reminder.repeats
            notes = reminder.notes
        }
    }

    private func save() {
        let target = reminder ?? Reminder(title: title, dueDate: dueDate)
        target.title = title.trimmingCharacters(in: .whitespaces)
        target.category = category
        target.dueDate = dueDate
        target.repeats = repeats
        target.notes = notes
        target.isCompleted = false
        if reminder == nil {
            target.pet = pet
            context.insert(target)
        }
        try? context.save()
        Task {
            await NotificationManager.shared.requestAuthorization()
            NotificationManager.shared.schedule(target, petName: pet.name)
        }
        dismiss()
    }
}
