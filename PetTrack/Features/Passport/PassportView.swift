import SwiftData
import SwiftUI
import UIKit

struct ExportedFile: Identifiable {
    let id = UUID()
    let url: URL
}

struct PassportView: View {
    @Environment(StoreManager.self) private var store
    @Environment(\.openURL) private var openURL
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @AppStorage("selectedPetID") private var selectedPetID = ""
    @State private var showEditor = false
    @State private var showSettings = false
    @State private var exported: ExportedFile?
    @State private var exportError: String?

    private var pet: Pet? { pets.selected(id: selectedPetID) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("Passport")
                            .font(.display(34))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                                .frame(width: 42, height: 42)
                                .background(Theme.surface, in: Circle())
                                .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 0.5))
                        }
                        .accessibilityLabel(Text("Settings"))
                    }
                    .padding(.top, 16)

                    PetSwitcher(pets: pets, selectedID: $selectedPetID)

                    if let pet {
                        PassportIDCard(pet: pet) { showEditor = true }
                        shareCard(pet)
                        EmergencyCard(pet: pet)
                        TravelCard(pet: pet)
                        vetCard(pet)
                        if !pet.insuranceProvider.isEmpty || !pet.insurancePolicy.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Eyebrow("Insurance")
                                InfoRow(symbol: "shield.lefthalf.filled", title: "Provider", value: pet.insuranceProvider)
                                InfoRow(symbol: "number", title: "Policy number", value: pet.insurancePolicy)
                            }
                            .card()
                        }
                        NavigationLink {
                            ScrollView {
                                PassportDocumentView(pet: pet)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
                                    .padding()
                            }
                            .background(Theme.surfaceMuted.ignoresSafeArea())
                            .navigationTitle("Preview")
                            .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            HStack {
                                Label("Preview passport", systemImage: "doc.richtext")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Theme.inkTertiary)
                            }
                            .card(padding: 16)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
            .tabBarSafeArea()
            .background(Theme.canvas.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showEditor) {
                if let pet { NavigationStack { PetEditorView(pet: pet) } }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .navigationDestination(for: TravelPlan.self) { plan in
                TravelPlanDetailView(plan: plan)
            }
            .sheet(item: $exported) { file in
                ActivityView(items: [file.url])
                    .presentationDetents([.medium, .large])
            }
            .alert("Couldn't create the PDF", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportError ?? "")
            }
        }
    }

    private func shareCard(_ pet: Pet) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Share with your vet")
                        .font(.display(20))
                        .foregroundStyle(Theme.ink)
                    Text("A complete PDF health passport: vaccines, visits, weight, medication and emergency details.")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                }
                Spacer()
                if !store.isPremium { PremiumBadge() }
            }
            HStack(spacing: 10) {
                Button {
                    store.requirePremium(.passportExport) { export(pet) }
                } label: {
                    Label("Share passport", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PrimaryButtonStyle(tint: Theme.accent, foreground: .white))
                .guideTip(GuideTips.sharePassport)

                if let url = URL(string: "tel:\(pet.vetPhone.filter { $0.isNumber || $0 == "+" })"), !pet.vetPhone.isEmpty {
                    Button { openURL(url) } label: {
                        Image(systemName: "phone.fill")
                            .font(.headline)
                            .foregroundStyle(Theme.sage)
                            .frame(width: 54, height: 54)
                            .background(Theme.sage.opacity(0.14), in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                    }
                    .accessibilityLabel(Text("Call vet"))
                }
            }
        }
        .card()
    }

    private func vetCard(_ pet: Pet) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow("Veterinarian")
            InfoRow(symbol: "cross.case.fill", title: "Clinic", value: pet.vetClinic, tint: Theme.accent)
            InfoRow(symbol: "person.fill", title: "Veterinarian", value: pet.vetName, tint: Theme.accent)
            InfoRow(symbol: "phone.fill", title: "Phone", value: pet.vetPhone, tint: Theme.accent)
            InfoRow(symbol: "envelope.fill", title: "Email", value: pet.vetEmail, tint: Theme.accent)
        }
        .card()
    }

    @MainActor
    private func export(_ pet: Pet) {
        do {
            exported = ExportedFile(url: try PassportExporter.makePDF(for: pet))
        } catch {
            exportError = error.localizedDescription
        }
    }
}

// MARK: - ID card

struct PassportIDCard: View {
    let pet: Pet
    var onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("HEALTH PASSPORT")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Theme.cream.opacity(0.6))
                    Text(pet.name)
                        .font(.display(32))
                        .foregroundStyle(Theme.cream)
                }
                Spacer()
                Button(action: onEdit) {
                    Text("Edit")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.cream)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.cream.opacity(0.14), in: Capsule())
                }
            }
            HStack(alignment: .bottom, spacing: 16) {
                PetAvatar(pet: pet, size: 84)
                    .overlay(Circle().strokeBorder(Theme.cream.opacity(0.3), lineWidth: 2))
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow {
                        field("Species", String(localized: pet.species.title))
                        field("Sex", String(localized: pet.sex.title))
                    }
                    GridRow {
                        field("Born", pet.birthDate?.formatted(date: .abbreviated, time: .omitted) ?? "—")
                        field("Breed", pet.breed.isEmpty ? "—" : pet.breed)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("MICROCHIP")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Theme.cream.opacity(0.5))
                Text(pet.microchipID.isEmpty ? "—" : pet.microchipID)
                    .font(.system(size: 17, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.cream)
            }
        }
        .padding(22)
        .background {
            ZStack {
                LinearGradient(colors: [Theme.forest, Theme.forestDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
                // Guilloché-style rings, like on a printed passport.
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .strokeBorder(Theme.cream.opacity(0.05), lineWidth: 1)
                        .frame(width: 140 + CGFloat(index) * 44)
                        .offset(x: 150, y: -60)
                }
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 120))
                    .foregroundStyle(Theme.cream.opacity(0.05))
                    .offset(x: 120, y: 60)
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card + 4, style: .continuous))
        }
        .shadow(color: Theme.forestDeep.opacity(0.25), radius: 18, x: 0, y: 10)
    }

    private func field(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Theme.cream.opacity(0.5))
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.cream)
                .lineLimit(1)
        }
    }
}

// MARK: - Emergency

struct EmergencyCard: View {
    let pet: Pet

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "staroflife.fill")
                    .foregroundStyle(Theme.danger)
                Text("Emergency card")
                    .font(.display(20))
                    .foregroundStyle(Theme.ink)
            }
            InfoRow(symbol: "allergens", title: "Allergies", value: pet.allergies, tint: Theme.danger)
            InfoRow(symbol: "heart.text.square", title: "Conditions", value: pet.conditions, tint: Theme.danger)
            InfoRow(symbol: "pills.fill", title: "Current medication",
                    value: pet.activeMedications.map { [$0.name, $0.dosage].filter { !$0.isEmpty }.joined(separator: " ") }.joined(separator: ", "),
                    tint: Theme.danger)
            if !pet.bloodType.isEmpty {
                InfoRow(symbol: "drop.fill", title: "Blood type", value: pet.bloodType, tint: Theme.danger)
            }
            if !pet.emergencyNotes.isEmpty {
                InfoRow(symbol: "exclamationmark.bubble.fill", title: "Notes", value: pet.emergencyNotes, tint: Theme.danger)
            }
        }
        .card(background: Theme.surface)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.danger)
                .frame(width: 4)
                .padding(.vertical, 22)
        }
    }
}

/// UIKit share sheet (AirDrop, Mail, Messages, Files, print …).
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
