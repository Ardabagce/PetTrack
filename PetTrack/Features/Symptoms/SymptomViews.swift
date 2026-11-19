import PhotosUI
import SwiftData
import SwiftUI
import UIKit

enum BodyArea: String, CaseIterable, Identifiable {
    case skin, ear, eye, mouth, paw, leg, belly, back, tail, other

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .skin: "Skin"
        case .ear: "Ear"
        case .eye: "Eye"
        case .mouth: "Mouth & teeth"
        case .paw: "Paw"
        case .leg: "Leg"
        case .belly: "Belly"
        case .back: "Back"
        case .tail: "Tail"
        case .other: "Other"
        }
    }
}

enum SeverityScale {
    static func title(_ value: Int) -> LocalizedStringResource {
        switch value {
        case ...1: "Mild"
        case 2: "Noticeable"
        case 3: "Moderate"
        case 4: "Strong"
        default: "Severe"
        }
    }

    static func color(_ value: Int) -> Color {
        switch value {
        case ...1: Theme.sage
        case 2: Color(light: 0x8FA65A, dark: 0xB2C77F)
        case 3: Theme.butter
        case 4: Theme.accent
        default: Theme.danger
        }
    }
}

// MARK: - Section in Health

struct SymptomsSection: View {
    let pet: Pet
    @Environment(StoreManager.self) private var store
    @State private var showEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Symptom diary", actionTitle: "New") { startCase() }

            Text("Noticed a rash, lump, limp or sore eye? Take a photo each day. At the vet, show exactly how it changed – by day and time.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)

            if pet.sortedSymptomCases.isEmpty {
                EmptyStateView(symbol: "camera.metering.spot", title: "Nothing being tracked",
                               message: "Start a diary the moment you notice something unusual.",
                               actionTitle: "Start a diary") { startCase() }
                    .card()
            } else {
                VStack(spacing: 10) {
                    ForEach(pet.sortedSymptomCases) { symptomCase in
                        NavigationLink(value: symptomCase) { SymptomCaseRow(symptomCase: symptomCase) }
                            .buttonStyle(PressableStyle())
                    }
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack { SymptomCaseEditorView(pet: pet) }
        }
    }

    private func startCase() {
        if pet.openSymptomCases.count >= FreeTier.maxSymptomCases && !store.isPremium {
            store.presentPaywall(.symptomDiary)
        } else {
            showEditor = true
        }
    }
}

struct SymptomCaseRow: View {
    let symptomCase: SymptomCase

    var body: some View {
        HStack(spacing: 14) {
            SymptomThumbnail(data: symptomCase.latestEntry?.photoData, size: 58)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(symptomCase.title)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    if symptomCase.isResolved {
                        StatusPill(text: "Resolved", tint: Theme.sage)
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
                if let trend = symptomCase.severityTrend {
                    TrendLabel(trend: trend)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.inkTertiary)
        }
        .card(padding: 14)
    }

    private var subtitle: String {
        let entries = String(localized: "\(symptomCase.sortedEntries.count) entries")
        let days = String(localized: "Day \(symptomCase.dayCount)")
        return [symptomCase.bodyArea, days, entries].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

struct TrendLabel: View {
    let trend: Int

    var body: some View {
        Label {
            Text(trend < 0 ? LocalizedStringKey("Improving") : trend > 0 ? LocalizedStringKey("Getting worse") : LocalizedStringKey("No change"))
        } icon: {
            Image(systemName: trend < 0 ? "arrow.down.right" : trend > 0 ? "arrow.up.right" : "arrow.right")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(trend < 0 ? Theme.sage : trend > 0 ? Theme.danger : Theme.inkSecondary)
    }
}

struct SymptomThumbnail: View {
    let data: Data?
    var size: CGFloat = 58

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Theme.surfaceMuted
                    Image(systemName: "camera.metering.spot")
                        .font(.system(size: size * 0.35))
                        .foregroundStyle(Theme.inkTertiary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
    }
}

// MARK: - Case editor

struct SymptomCaseEditorView: View {
    let pet: Pet
    var symptomCase: SymptomCase?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var area: BodyArea?
    @State private var startDate = Date.now
    @State private var notes = ""
    @State private var dailyReminder = true

    var body: some View {
        Form {
            Section {
                TextField("What are you noticing? (e.g. Red spot on belly)", text: $title, axis: .vertical)
                    .font(.headline)
            }
            Section("Where") {
                FlowLayout(spacing: 8) {
                    ForEach(BodyArea.allCases) { item in
                        ChoiceChip(title: item.title, isSelected: area == item) { area = item }
                    }
                }
                .padding(.vertical, 4)
            }
            Section {
                DatePicker("First noticed", selection: $startDate, in: ...Date.now, displayedComponents: .date)
                Toggle("Daily photo reminder", isOn: $dailyReminder)
                TextField("Notes", text: $notes, axis: .vertical)
            }
            if let symptomCase {
                Section {
                    Button("Delete diary", role: .destructive) {
                        NotificationManager.shared.cancel(symptomCase)
                        context.delete(symptomCase)
                        try? context.save()
                        dismiss()
                    }
                }
            }
        }
        .formCanvas()
        .navigationTitle(symptomCase == nil ? Text("New symptom diary") : Text("Edit diary"))
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
            guard let symptomCase else { return }
            title = symptomCase.title
            area = BodyArea.allCases.first { String(localized: $0.title) == symptomCase.bodyArea }
            startDate = symptomCase.startDate
            notes = symptomCase.notes
        }
    }

    private func save() {
        let target = symptomCase ?? SymptomCase(title: title)
        target.title = title.trimmingCharacters(in: .whitespaces)
        target.bodyArea = area.map { String(localized: $0.title) } ?? ""
        target.startDate = startDate
        target.notes = notes
        if symptomCase == nil {
            target.pet = pet
            context.insert(target)
        }
        try? context.save()
        Task {
            if dailyReminder {
                await NotificationManager.shared.requestAuthorization()
                NotificationManager.shared.schedule(target, petName: pet.name)
            } else {
                NotificationManager.shared.cancel(target)
            }
        }
        dismiss()
    }
}

// MARK: - Case detail / timeline

struct SymptomCaseDetailView: View {
    @Bindable var symptomCase: SymptomCase
    @Environment(\.modelContext) private var context
    @Environment(StoreManager.self) private var store
    @State private var showEntryEditor = false
    @State private var showCaseEditor = false
    @State private var exported: ExportedFile?
    @State private var enlarged: SymptomEntry?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(LocalizedStringKey(symptomCase.bodyArea.isEmpty ? "Symptom diary" : symptomCase.bodyArea))
                    Text(symptomCase.title)
                        .font(.display(30))
                        .foregroundStyle(Theme.ink)
                    HStack(spacing: 10) {
                        Text("Since \(symptomCase.startDate.formatted(date: .abbreviated, time: .omitted))")
                        Text("· Day \(symptomCase.dayCount)")
                        if let trend = symptomCase.severityTrend { TrendLabel(trend: trend) }
                    }
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
                }

                if let first = symptomCase.firstEntry, let last = symptomCase.latestEntry, first.id != last.id {
                    comparison(first: first, last: last)
                }

                HStack(spacing: 10) {
                    if !symptomCase.isResolved {
                        Button { showEntryEditor = true } label: {
                            Label(hasEntryToday ? LocalizedStringKey("Add another photo") : LocalizedStringKey("Add today's photo"), systemImage: "camera.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle(tint: Theme.accent, foreground: .white))
                    }
                    Button {
                        store.requirePremium(.symptomDiary) { exportReport() }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.headline)
                            .foregroundStyle(Theme.ink)
                            .frame(width: 54, height: 54)
                            .background(Theme.surfaceMuted, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                    }
                    .accessibilityLabel(Text("Share report"))
                }

                SectionHeader(title: "Timeline")
                if symptomCase.sortedEntries.isEmpty {
                    EmptyStateView(symbol: "camera", title: "No entries yet",
                                   message: "Add the first photo so you have a baseline to compare against.")
                        .card()
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(symptomCase.sortedEntries.reversed().enumerated()), id: \.element.id) { index, entry in
                            timelineRow(entry, isLast: index == symptomCase.sortedEntries.count - 1)
                        }
                    }
                }

                if !symptomCase.notes.isEmpty {
                    InfoRow(symbol: "note.text", title: "Notes", value: symptomCase.notes).card()
                }

                Button {
                    withAnimation {
                        symptomCase.isResolved.toggle()
                        symptomCase.resolvedDate = symptomCase.isResolved ? .now : nil
                        try? context.save()
                    }
                    if symptomCase.isResolved {
                        NotificationManager.shared.cancel(symptomCase)
                    } else if let petName = symptomCase.pet?.name {
                        NotificationManager.shared.schedule(symptomCase, petName: petName)
                    }
                } label: {
                    Label(symptomCase.isResolved ? LocalizedStringKey("Reopen") : LocalizedStringKey("Mark as resolved"),
                          systemImage: symptomCase.isResolved ? "arrow.uturn.backward" : "checkmark.seal")
                }
                .buttonStyle(SoftButtonStyle(tint: Theme.sage))
                .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
        .tabBarSafeArea()
        .background(Theme.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Edit") { showCaseEditor = true } }
        .sheet(isPresented: $showEntryEditor) {
            NavigationStack { SymptomEntryEditorView(symptomCase: symptomCase) }
        }
        .sheet(isPresented: $showCaseEditor) {
            if let pet = symptomCase.pet {
                NavigationStack { SymptomCaseEditorView(pet: pet, symptomCase: symptomCase) }
            }
        }
        .sheet(item: $exported) { file in
            ActivityView(items: [file.url]).presentationDetents([.medium, .large])
        }
        .fullScreenCover(item: $enlarged) { entry in
            PhotoViewer(entry: entry) { enlarged = nil }
        }
    }

    private var hasEntryToday: Bool {
        symptomCase.sortedEntries.contains { Calendar.current.isDateInToday($0.date) }
    }

    private func comparison(first: SymptomEntry, last: SymptomEntry) -> some View {
        HStack(spacing: 10) {
            comparisonTile(first, label: "First")
            comparisonTile(last, label: "Latest")
        }
    }

    private func comparisonTile(_ entry: SymptomEntry, label: LocalizedStringKey) -> some View {
        Button { enlarged = entry } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    GeometryReader { proxy in
                        SymptomThumbnail(data: entry.photoData, size: proxy.size.width)
                    }
                    .aspectRatio(1, contentMode: .fit)
                    Text(label)
                        .font(.caption2.weight(.bold))
                        .textCase(.uppercase)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(8)
                }
                Text(entry.date, format: .dateTime.day().month(.abbreviated).hour().minute())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                SeverityDots(value: entry.severity)
            }
        }
        .buttonStyle(PressableStyle())
        .frame(maxWidth: .infinity)
    }

    private func timelineRow(_ entry: SymptomEntry, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Circle()
                    .fill(SeverityScale.color(entry.severity))
                    .frame(width: 12, height: 12)
                    .padding(.top, 6)
                if !isLast {
                    Rectangle().fill(Theme.hairline).frame(width: 1.5).frame(maxHeight: .infinity)
                }
            }
            .frame(width: 12)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(entry.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text(SeverityScale.title(entry.severity))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SeverityScale.color(entry.severity))
                }
                if entry.photoData != nil {
                    Button { enlarged = entry } label: {
                        GeometryReader { proxy in
                            SymptomThumbnail(data: entry.photoData, size: proxy.size.width)
                        }
                        .aspectRatio(4 / 3, contentMode: .fit)
                    }
                    .buttonStyle(PressableStyle())
                }
                if !entry.note.isEmpty {
                    Text(entry.note)
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
            .padding(.bottom, 20)
            .contextMenu {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    context.delete(entry)
                    try? context.save()
                }
            }
        }
    }

    @MainActor
    private func exportReport() {
        guard let pet = symptomCase.pet else { return }
        let name = String(localized: "\(pet.name)-\(symptomCase.title)-Symptom-Report")
        if let url = try? PDFRenderer.render(SymptomReportDocument(symptomCase: symptomCase, pet: pet), fileName: name) {
            exported = ExportedFile(url: url)
        }
    }
}

struct SeverityDots: View {
    let value: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { index in
                Capsule()
                    .fill(index <= value ? SeverityScale.color(value) : Theme.surfaceMuted)
                    .frame(width: 14, height: 5)
            }
        }
    }
}

struct PhotoViewer: View {
    let entry: SymptomEntry
    var onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if let data = entry.photoData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit()
            }
            VStack(alignment: .leading) {
                Spacer()
                Text(entry.date.formatted(date: .complete, time: .shortened))
                    .font(.subheadline.weight(.semibold))
                if !entry.note.isEmpty { Text(entry.note).font(.subheadline) }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.15), in: Circle())
            }
            .padding(20)
            .accessibilityLabel(Text("Close"))
        }
    }
}

// MARK: - Entry editor

struct SymptomEntryEditorView: View {
    let symptomCase: SymptomCase

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var photoData: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var severity = 2
    @State private var note = ""
    @State private var date = Date.now

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    if let photoData, let image = UIImage(data: photoData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 280)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                    } else if let previous = symptomCase.latestEntry?.photoData, let image = UIImage(data: previous) {
                        // Show the previous photo faded so the owner can match angle and distance.
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .opacity(0.35)
                            .overlay {
                                Text("Try to match the previous angle")
                                    .font(.caption.weight(.semibold))
                                    .padding(8)
                                    .background(.ultraThinMaterial, in: Capsule())
                            }
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                    }
                    HStack(spacing: 10) {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            Button { showCamera = true } label: {
                                Label("Camera", systemImage: "camera.fill").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(SoftButtonStyle(tint: Theme.accent))
                        }
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label("Photos", systemImage: "photo").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SoftButtonStyle(tint: Theme.sky))
                    }
                }
                .listRowBackground(Color.clear)
            }

            Section("How does it look?") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(SeverityScale.title(severity))
                            .font(.headline)
                            .foregroundStyle(SeverityScale.color(severity))
                        Spacer()
                        SeverityDots(value: severity)
                    }
                    Slider(value: Binding(get: { Double(severity) }, set: { severity = Int($0.rounded()) }), in: 1...5, step: 1)
                        .tint(SeverityScale.color(severity))
                }
                DatePicker("Date & time", selection: $date, in: ...Date.now)
                TextField("Notes (itching, size, behaviour…)", text: $note, axis: .vertical)
            }
        }
        .formCanvas()
        .navigationTitle("New entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .fontWeight(.semibold)
                    .disabled(photoData == nil && note.isEmpty)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                showCamera = false
                guard let image else { return }
                photoData = ImageResizer.jpegData(from: image, maxDimension: 1600)
                date = .now
            }
            .ignoresSafeArea()
        }
        .onChange(of: photoItem) { _, item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self) else { return }
                photoData = ImageResizer.jpegData(from: data, maxDimension: 1600)
            }
        }
        .onAppear {
            if let last = symptomCase.latestEntry { severity = last.severity }
        }
    }

    private func save() {
        let entry = SymptomEntry(date: date, severity: severity, note: note, photoData: photoData)
        entry.symptomCase = symptomCase
        context.insert(entry)
        try? context.save()
        dismiss()
    }
}

/// Simple camera capture with UIImagePickerController.
struct CameraPicker: UIViewControllerRepresentable {
    /// Called with the photo, or `nil` when the user cancels. The presenter dismisses the camera.
    var onCapture: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.onCapture(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCapture(nil)
        }
    }
}

// MARK: - Today nudge

struct SymptomWatchCard: View {
    let pet: Pet
    @State private var addingTo: SymptomCase?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow("Watching")
            ForEach(pet.openSymptomCases) { symptomCase in
                HStack(spacing: 12) {
                    NavigationLink(value: symptomCase) {
                        HStack(spacing: 12) {
                            SymptomThumbnail(data: symptomCase.latestEntry?.photoData, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(symptomCase.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                                    .lineLimit(1)
                                Text("Day \(symptomCase.dayCount)")
                                    .font(.caption)
                                    .foregroundStyle(Theme.inkSecondary)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)
                    if !symptomCase.sortedEntries.contains(where: { Calendar.current.isDateInToday($0.date) }) {
                        Button { addingTo = symptomCase } label: {
                            Label("Today's photo", systemImage: "camera.fill")
                                .labelStyle(.iconOnly)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                                .frame(width: 38, height: 38)
                                .background(Theme.accent.opacity(0.13), in: Circle())
                        }
                        .buttonStyle(.plain)
                    } else {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.sage)
                    }
                }
            }
        }
        .card()
        .sheet(item: $addingTo) { symptomCase in
            NavigationStack { SymptomEntryEditorView(symptomCase: symptomCase) }
        }
    }
}

// MARK: - PDF report

struct SymptomReportDocument: View {
    let symptomCase: SymptomCase
    let pet: Pet

    private let ink = Color(hex: 0x17201C)
    private let muted = Color(hex: 0x5D6962)
    private let accent = Color(hex: 0xCF5F3B)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SYMPTOM REPORT")
                    .font(.system(size: 9, weight: .bold)).tracking(2).foregroundStyle(accent)
                Text(symptomCase.title)
                    .font(.system(size: 26, weight: .semibold, design: .serif)).foregroundStyle(ink)
                Text("\(pet.name) · \(symptomCase.bodyArea) · \(String(localized: "Since \(symptomCase.startDate.formatted(date: .long, time: .omitted))"))")
                    .font(.system(size: 11)).foregroundStyle(muted)
            }
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) { Rectangle().fill(ink).frame(height: 1.5) }

            if !symptomCase.notes.isEmpty {
                Text(symptomCase.notes).font(.system(size: 11)).foregroundStyle(ink)
            }

            ForEach(symptomCase.sortedEntries) { entry in
                HStack(alignment: .top, spacing: 14) {
                    if let data = entry.photoData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 170, height: 128)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.date.formatted(date: .complete, time: .shortened))
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(ink)
                        Text(SeverityScale.title(entry.severity))
                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(SeverityScale.color(entry.severity))
                        if !entry.note.isEmpty {
                            Text(entry.note).font(.system(size: 10)).foregroundStyle(ink)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 6)
            }

            Text("Generated with PetTrack · \(Date.now.formatted(date: .long, time: .shortened))")
                .font(.system(size: 8)).foregroundStyle(muted)
        }
        .padding(36)
        .frame(width: 595, alignment: .topLeading)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }
}
