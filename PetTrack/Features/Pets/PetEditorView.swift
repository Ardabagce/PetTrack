import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct PetEditorView: View {
    let pet: Pet?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allPets: [Pet]
    @AppStorage("selectedPetID") private var selectedPetID = ""
    @AppStorage(WeightUnitPreference.storageKey) private var weightUnitRaw = WeightUnitPreference.automatic.rawValue

    @State private var name = ""
    @State private var species: Species = .dog
    @State private var breed = ""
    @State private var sex: PetSex = .unknown
    @State private var hasBirthDate = false
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .now
    @State private var isNeutered = false
    @State private var photoData: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var microchipID = ""
    @State private var bloodType = ""
    @State private var allergies = ""
    @State private var conditions = ""
    @State private var emergencyNotes = ""
    @State private var vetClinic = ""
    @State private var vetName = ""
    @State private var vetPhone = ""
    @State private var vetEmail = ""
    @State private var insuranceProvider = ""
    @State private var insurancePolicy = ""
    @State private var targetWeight = ""
    @State private var confirmDelete = false

    private var unit: UnitMass { (WeightUnitPreference(rawValue: weightUnitRaw) ?? .automatic).unit }
    private var isNew: Bool { pet == nil }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 14) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        ZStack(alignment: .bottomTrailing) {
                            Group {
                                if let photoData, let image = UIImage(data: photoData) {
                                    Image(uiImage: image).resizable().scaledToFill()
                                } else {
                                    ZStack {
                                        Theme.surfaceMuted
                                        Image(systemName: species.symbol)
                                            .font(.system(size: 38, weight: .semibold))
                                            .foregroundStyle(Theme.inkTertiary)
                                    }
                                }
                            }
                            .frame(width: 112, height: 112)
                            .clipShape(Circle())

                            Image(systemName: "camera.fill")
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(Theme.cream)
                                .frame(width: 34, height: 34)
                                .background(Theme.ink, in: Circle())
                                .overlay(Circle().strokeBorder(Theme.canvas, lineWidth: 3))
                        }
                    }
                    .buttonStyle(.plain)

                    TextField("Name", text: $name)
                        .font(.display(26))
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.words)

                    FlowLayout(spacing: 8) {
                        ForEach(Species.allCases) { item in
                            ChoiceChip(title: item.title, symbol: item.symbol, isSelected: species == item) { species = item }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section("Basics") {
                TextField("Breed", text: $breed)
                Picker("Sex", selection: $sex) {
                    ForEach(PetSex.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Spayed / neutered", isOn: $isNeutered)
                Toggle("Birthday known", isOn: $hasBirthDate.animation())
                if hasBirthDate {
                    DatePicker("Birthday", selection: $birthDate, in: ...Date.now, displayedComponents: .date)
                }
                HStack {
                    Text("Target weight")
                    Spacer()
                    TextField("Optional", text: $targetWeight)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                    Text(Formatting.unitSymbol(unit)).foregroundStyle(Theme.inkSecondary)
                }
            }

            Section {
                TextField("Microchip number", text: $microchipID)
                    .keyboardType(.numbersAndPunctuation)
                TextField("Blood type", text: $bloodType)
                TextField("Allergies", text: $allergies, axis: .vertical)
                TextField("Chronic conditions", text: $conditions, axis: .vertical)
                TextField("Emergency notes", text: $emergencyNotes, axis: .vertical)
            } header: {
                Text("Emergency information")
            } footer: {
                Text("Shown on the emergency card and included in the health passport.")
            }

            Section("Veterinarian") {
                TextField("Clinic", text: $vetClinic)
                TextField("Veterinarian", text: $vetName)
                TextField("Phone", text: $vetPhone).keyboardType(.phonePad)
                TextField("Email", text: $vetEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("Insurance") {
                TextField("Provider", text: $insuranceProvider)
                TextField("Policy number", text: $insurancePolicy)
            }

            if !isNew {
                Section {
                    Button("Delete pet", role: .destructive) { confirmDelete = true }
                }
            }
        }
        .formCanvas()
        .navigationTitle(isNew ? Text("New pet") : Text("Edit pet"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .confirmationDialog("Delete pet?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete all records", role: .destructive) { deletePet() }
        } message: {
            Text("This permanently removes the pet and all of its health records.")
        }
        .onChange(of: photoItem) { _, item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self) else { return }
                photoData = ImageResizer.jpegData(from: data, maxDimension: 900)
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard let pet else { return }
        name = pet.name
        species = pet.species
        breed = pet.breed
        sex = pet.sex
        if let date = pet.birthDate {
            hasBirthDate = true
            birthDate = date
        }
        isNeutered = pet.isNeutered
        photoData = pet.photoData
        microchipID = pet.microchipID
        bloodType = pet.bloodType
        allergies = pet.allergies
        conditions = pet.conditions
        emergencyNotes = pet.emergencyNotes
        vetClinic = pet.vetClinic
        vetName = pet.vetName
        vetPhone = pet.vetPhone
        vetEmail = pet.vetEmail
        insuranceProvider = pet.insuranceProvider
        insurancePolicy = pet.insurancePolicy
        if let kg = pet.targetWeightKg {
            targetWeight = Formatting.decimalString(Formatting.weightValue(kg, unit: unit))
        }
    }

    private func save() {
        let target = pet ?? Pet(name: name, species: species)
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.species = species
        target.breed = breed
        target.sex = sex
        target.birthDate = hasBirthDate ? birthDate : nil
        target.isNeutered = isNeutered
        target.photoData = photoData
        target.microchipID = microchipID
        target.bloodType = bloodType
        target.allergies = allergies
        target.conditions = conditions
        target.emergencyNotes = emergencyNotes
        target.vetClinic = vetClinic
        target.vetName = vetName
        target.vetPhone = vetPhone
        target.vetEmail = vetEmail
        target.insuranceProvider = insuranceProvider
        target.insurancePolicy = insurancePolicy
        target.targetWeightKg = Formatting.parseDecimal(targetWeight).map { Formatting.kilograms(from: $0, unit: unit) }

        if isNew {
            target.colorIndex = allPets.count
            context.insert(target)
            seedDefaultSchedule(for: target)
            selectedPetID = target.id.uuidString
        }
        try? context.save()

        Task {
            await NotificationManager.shared.requestAuthorization()
            NotificationManager.shared.rescheduleAll(for: target)
        }
        dismiss()
    }

    /// New dogs and cats start with a sensible breakfast / water / dinner routine the user can adjust.
    private func seedDefaultSchedule(for pet: Pet) {
        guard pet.species == .dog || pet.species == .cat else { return }
        let slots: [(String, FeedingKind, Int)] = [
            (String(localized: "Breakfast"), .meal, 8),
            (String(localized: "Fresh water"), .water, 9),
            (String(localized: "Dinner"), .meal, 18),
        ]
        for (label, kind, hour) in slots {
            let slot = FeedingSchedule(label: label, kind: kind, hour: hour, minute: 0)
            slot.pet = pet
            context.insert(slot)
        }
    }

    private func deletePet() {
        guard let pet else { return }
        NotificationManager.shared.cancelAll(for: pet)
        context.delete(pet)
        try? context.save()
        selectedPetID = ""
        dismiss()
    }
}

enum ImageResizer {
    static func jpegData(from data: Data, maxDimension: CGFloat, quality: CGFloat = 0.82) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return jpegData(from: image, maxDimension: maxDimension, quality: quality)
    }

    static func jpegData(from image: UIImage, maxDimension: CGFloat, quality: CGFloat = 0.82) -> Data? {
        let largest = max(image.size.width, image.size.height)
        let scale = largest > maxDimension ? maxDimension / largest : 1
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
