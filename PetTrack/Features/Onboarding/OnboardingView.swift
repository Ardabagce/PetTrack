import SwiftUI

struct OnboardingView: View {
    @State private var showAddPet = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.forest, Theme.forestDeep], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            // Soft decorative orbs
            Circle()
                .fill(Theme.accent.opacity(0.35))
                .frame(width: 320)
                .blur(radius: 90)
                .offset(x: 140, y: -260)
            Circle()
                .fill(Theme.sage.opacity(0.35))
                .frame(width: 280)
                .blur(radius: 90)
                .offset(x: -150, y: 120)

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                HStack(spacing: -14) {
                    ForEach(Array(["dog.fill", "cat.fill", "hare.fill"].enumerated()), id: \.offset) { index, symbol in
                        Image(systemName: symbol)
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(Theme.cream)
                            .frame(width: 64, height: 64)
                            .background(Theme.petPalette[index].opacity(0.9), in: Circle())
                            .overlay(Circle().strokeBorder(Theme.forestDeep, lineWidth: 3))
                            .offset(y: appeared ? 0 : 20)
                            .opacity(appeared ? 1 : 0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(Double(index) * 0.08), value: appeared)
                    }
                }
                .padding(.bottom, 28)

                Eyebrow("PetTrack", color: Theme.cream.opacity(0.6))
                    .padding(.bottom, 10)
                Text("A health passport for the ones who can't keep their own.")
                    .font(.display(38))
                    .foregroundStyle(Theme.cream)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 16)
                Text("Vaccines, vet visits, weight, meals and bills – organised in one beautiful place and ready to share with your vet in one tap.")
                    .font(.body)
                    .foregroundStyle(Theme.cream.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 32)

                VStack(alignment: .leading, spacing: 14) {
                    feature("syringe.fill", "Vaccine schedule with smart reminders")
                    feature("fork.knife", "Meal & water times, food transitions")
                    feature("doc.text.viewfinder", "Scan vet reports into records")
                }
                .padding(.bottom, 36)

                Button { showAddPet = true } label: {
                    Text("Add your first pet")
                }
                .buttonStyle(PrimaryButtonStyle(tint: Theme.cream, foreground: Theme.forestDeep))
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 24)
        }
        .onAppear { appeared = true }
        .sheet(isPresented: $showAddPet) {
            NavigationStack { PetEditorView(pet: nil) }
        }
    }

    private func feature(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.forestDeep)
                .frame(width: 30, height: 30)
                .background(Theme.cream.opacity(0.9), in: Circle())
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.cream)
        }
    }
}
