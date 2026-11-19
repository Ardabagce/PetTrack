import Foundation

/// App Group shared by the iPhone app and the widget (see app.json → ios.entitlements).
let petTrackAppGroup = "group.com.pettrack.app"

/// Mirrors `buildSnapshot()` in src/lib/companion.ts.
struct PTSnapshot: Codable {
  var updatedAt: String?
  var selectedPetId: String?
  var labels: [String: String]
  var pets: [PTPet]

  static func decode(_ json: String) -> PTSnapshot? {
    try? JSONDecoder().decode(PTSnapshot.self, from: Data(json.utf8))
  }

  /// Latest snapshot written by the iPhone app into the App Group (iOS only).
  static func loadShared() -> PTSnapshot? {
    guard let json = UserDefaults(suiteName: petTrackAppGroup)?.string(forKey: "snapshot") else { return nil }
    return decode(json)
  }

  func text(_ key: String, _ fallback: String) -> String {
    labels[key] ?? fallback
  }

  var primaryPet: PTPet? {
    pets.first { $0.id == selectedPetId } ?? pets.first
  }

  func kindLabel(_ kind: String) -> String {
    switch kind {
    case "water": return text("water", "Water")
    case "treat": return text("treat", "Treat")
    default: return text("meal", "Meal")
    }
  }

  static let placeholder = PTSnapshot(
    updatedAt: nil, selectedPetId: "p", labels: [:],
    pets: [PTPet(id: "p", name: "Luna", species: "dog",
                 slots: [PTSlot(id: "a", label: "Breakfast", kind: "meal", hour: 7, minute: 30),
                         PTSlot(id: "b", label: "Dinner", kind: "meal", hour: 18, minute: 0)],
                 done: [], lastMeal: nil, lastWater: nil, vaccine: nil)])
}

struct PTSlot: Codable, Hashable, Identifiable {
  var id: String
  var label: String
  var kind: String
  var hour: Int
  var minute: Int
}

struct PTDone: Codable, Hashable {
  var slotId: String?
  var kind: String
  var date: String
}

struct PTEvent: Codable, Hashable {
  var date: String
  var by: String
}

struct PTVaccine: Codable, Hashable {
  var name: String
  var due: String
}

struct PTPet: Codable, Identifiable {
  var id: String
  var name: String
  var species: String
  var slots: [PTSlot]
  var done: [PTDone]
  var lastMeal: PTEvent?
  var lastWater: PTEvent?
  var vaccine: PTVaccine?

  func isDone(_ slot: PTSlot, on day: Date) -> Bool {
    done.contains { entry in
      guard entry.slotId == slot.id, let d = PTDate.parse(entry.date) else { return false }
      return Calendar.current.isDate(d, inSameDayAs: day)
    }
  }

  func time(of slot: PTSlot, on day: Date) -> Date {
    Calendar.current.date(bySettingHour: slot.hour, minute: slot.minute, second: 0, of: day) ?? day
  }

  /// First slot of the day that is not ticked off yet (it may already be due).
  func nextSlot(at now: Date) -> PTSlot? {
    slots.first { !isDone($0, on: now) }
  }

  func doneCount(on day: Date) -> Int {
    slots.filter { isDone($0, on: day) }.count
  }

  var symbol: String {
    switch species {
    case "cat": return "cat.fill"
    case "dog": return "dog.fill"
    case "bird": return "bird.fill"
    case "rabbit": return "hare.fill"
    default: return "pawprint.fill"
    }
  }
}

enum PTDate {
  private static let withFraction: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()
  private static let plain = ISO8601DateFormatter()
  private static let dayOnly: DateFormatter = {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f
  }()

  static func parse(_ s: String) -> Date? {
    withFraction.date(from: s) ?? plain.date(from: s) ?? dayOnly.date(from: String(s.prefix(10)))
  }

  static func iso(_ d: Date) -> String {
    withFraction.string(from: d)
  }
}
