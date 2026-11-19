import SwiftUI
import UIKit

struct PetAvatar: View {
    let pet: Pet
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let data = pet.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Theme.petColor(pet.colorIndex).opacity(0.18)
                    Image(systemName: pet.species.symbol)
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundStyle(Theme.petColor(pet.colorIndex))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

/// Horizontal pet selector shown at the top of the main tabs.
struct PetSwitcher: View {
    let pets: [Pet]
    @Binding var selectedID: String
    @Environment(StoreManager.self) private var store
    @State private var showAddPet = false

    private var effectiveID: String {
        pets.selected(id: selectedID)?.id.uuidString ?? ""
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(pets) { pet in
                    let isSelected = pet.id.uuidString == effectiveID
                    Button {
                        withAnimation(.snappy) { selectedID = pet.id.uuidString }
                    } label: {
                        HStack(spacing: 8) {
                            PetAvatar(pet: pet, size: 30)
                            if isSelected {
                                Text(pet.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                                    .padding(.trailing, 6)
                            }
                        }
                        .padding(4)
                        .background(isSelected ? Theme.surface : Color.clear, in: Capsule())
                        .overlay(Capsule().strokeBorder(isSelected ? Theme.hairline : Color.clear, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    if pets.count >= FreeTier.maxPets && !store.isPremium {
                        store.presentPaywall(.unlimitedPets)
                    } else {
                        showAddPet = true
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.inkSecondary)
                        .frame(width: 38, height: 38)
                        .background(Theme.surfaceMuted, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Add pet"))
            }
            .padding(.vertical, 2)
        }
        .guideTip(GuideTips.petSwitcher)
        .sheet(isPresented: $showAddPet) {
            NavigationStack { PetEditorView(pet: nil) }
        }
    }
}

extension Array where Element == Pet {
    func selected(id: String) -> Pet? {
        first { $0.id.uuidString == id } ?? first
    }
}
