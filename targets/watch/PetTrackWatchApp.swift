import SwiftUI
import WatchConnectivity

@main
struct PetTrackWatchApp: App {
  @StateObject private var store = WatchStore()

  var body: some Scene {
    WindowGroup {
      ContentView().environmentObject(store)
    }
  }
}

/// Receives the summary from the iPhone (application context) and sends "done" taps back (transferUserInfo,
/// delivered even if the iPhone app is not running right now).
final class WatchStore: NSObject, ObservableObject, WCSessionDelegate {
  @Published var snapshot: PTSnapshot?
  private let cacheKey = "snapshot"

  override init() {
    super.init()
    if let json = UserDefaults.standard.string(forKey: cacheKey) {
      snapshot = PTSnapshot.decode(json)
    }
    if WCSession.isSupported() {
      WCSession.default.delegate = self
      WCSession.default.activate()
    }
  }

  private func apply(_ context: [String: Any]) {
    guard let json = context["snapshot"] as? String, let snap = PTSnapshot.decode(json) else { return }
    DispatchQueue.main.async {
      self.snapshot = snap
      UserDefaults.standard.set(json, forKey: self.cacheKey)
    }
  }

  func markDone(pet: PTPet, slot: PTSlot) {
    let now = Date()
    let payload: [String: Any] = ["petId": pet.id, "slotId": slot.id, "kind": slot.kind, "date": PTDate.iso(now)]
    guard let data = try? JSONSerialization.data(withJSONObject: payload),
          let action = String(data: data, encoding: .utf8) else { return }
    // Optimistic update so the tick shows immediately.
    if var snap = snapshot, let i = snap.pets.firstIndex(where: { $0.id == pet.id }) {
      snap.pets[i].done.append(PTDone(slotId: slot.id, kind: slot.kind, date: PTDate.iso(now)))
      if slot.kind == "meal" { snap.pets[i].lastMeal = PTEvent(date: PTDate.iso(now), by: "") }
      if slot.kind == "water" { snap.pets[i].lastWater = PTEvent(date: PTDate.iso(now), by: "") }
      snapshot = snap
    }
    guard WCSession.isSupported() else { return }
    WCSession.default.transferUserInfo(["action": action])
  }

  // MARK: WCSessionDelegate

  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    apply(session.receivedApplicationContext)
  }

  func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    apply(applicationContext)
  }
}

struct ContentView: View {
  @EnvironmentObject private var store: WatchStore

  var body: some View {
    if let snap = store.snapshot, !snap.pets.isEmpty {
      TabView {
        ForEach(snap.pets) { pet in
          PetPage(pet: pet, snapshot: snap)
        }
      }
      .tabViewStyle(.verticalPage)
    } else {
      VStack(spacing: 8) {
        Image(systemName: "pawprint.fill").font(.title).foregroundStyle(Color("$accent"))
        Text(store.snapshot?.text("noPets", "Open PetTrack to add your pet") ?? "Open PetTrack on your iPhone")
          .font(.footnote).multilineTextAlignment(.center)
      }
      .padding()
    }
  }
}

struct PetPage: View {
  @EnvironmentObject private var store: WatchStore
  let pet: PTPet
  let snapshot: PTSnapshot

  private func time(_ slot: PTSlot) -> Date {
    pet.time(of: slot, on: .now)
  }

  var body: some View {
    let now = Date()
    List {
      Section {
        if let slot = pet.nextSlot(at: now) {
          VStack(alignment: .leading, spacing: 4) {
            Text(snapshot.text("next", "Next")).font(.caption2).foregroundStyle(.secondary)
            Text(slot.label.isEmpty ? snapshot.kindLabel(slot.kind) : slot.label).font(.headline)
            Text(time(slot), style: .time).font(.title3.weight(.semibold)).foregroundStyle(Color("$accent"))
            Button {
              store.markDone(pet: pet, slot: slot)
            } label: {
              Label(snapshot.text("markDone", "Mark done"), systemImage: "checkmark")
                .frame(maxWidth: .infinity)
            }
            .tint(Color("ptSage"))
            .padding(.top, 4)
          }
        } else {
          Label(pet.slots.isEmpty ? snapshot.text("noSlots", "No feeding times yet") : snapshot.text("allDone", "All done for today"),
                systemImage: "checkmark.circle.fill")
            .foregroundStyle(Color("ptSage"))
        }
      } header: {
        Label(pet.name, systemImage: pet.symbol)
      }

      if !pet.slots.isEmpty {
        Section(snapshot.text("today", "Today")) {
          ForEach(pet.slots) { slot in
            let done = pet.isDone(slot, on: now)
            Button {
              if !done { store.markDone(pet: pet, slot: slot) }
            } label: {
              HStack {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                  .foregroundStyle(done ? Color("ptSage") : .secondary)
                Text(slot.label.isEmpty ? snapshot.kindLabel(slot.kind) : slot.label).lineLimit(1)
                Spacer()
                Text(time(slot), style: .time).foregroundStyle(.secondary).font(.caption)
              }
            }
            .disabled(done)
          }
        }
      }

      Section {
        LastRow(title: snapshot.text("lastMeal", "Last meal"), event: pet.lastMeal, snapshot: snapshot, icon: "fork.knife")
        LastRow(title: snapshot.text("lastWater", "Last water"), event: pet.lastWater, snapshot: snapshot, icon: "drop.fill")
        if let v = pet.vaccine, let due = PTDate.parse(v.due) {
          VStack(alignment: .leading, spacing: 2) {
            Label(snapshot.text("vaccine", "Vaccine due"), systemImage: "syringe").font(.caption2).foregroundStyle(.secondary)
            Text(v.name).font(.footnote).lineLimit(2)
            Text(due, style: .date).font(.caption2).foregroundStyle(.secondary)
          }
        }
      }
    }
  }
}

struct LastRow: View {
  let title: String
  let event: PTEvent?
  let snapshot: PTSnapshot
  let icon: String

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Label(title, systemImage: icon).font(.caption2).foregroundStyle(.secondary)
      if let event, let date = PTDate.parse(event.date) {
        HStack(spacing: 3) {
          Text(date, style: .relative)
          if !event.by.isEmpty { Text("· \(event.by)").lineLimit(1) }
        }
        .font(.footnote)
      } else {
        Text(snapshot.text("never", "Not logged yet")).font(.footnote)
      }
    }
  }
}
