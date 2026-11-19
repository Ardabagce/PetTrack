import SwiftUI
import WidgetKit

struct PetEntry: TimelineEntry {
  let date: Date
  let snapshot: PTSnapshot?
}

struct PetProvider: TimelineProvider {
  func placeholder(in context: Context) -> PetEntry {
    PetEntry(date: .now, snapshot: .placeholder)
  }

  func getSnapshot(in context: Context, completion: @escaping (PetEntry) -> Void) {
    completion(PetEntry(date: .now, snapshot: PTSnapshot.loadShared() ?? (context.isPreview ? .placeholder : nil)))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<PetEntry>) -> Void) {
    let snapshot = PTSnapshot.loadShared()
    let now = Date()
    let calendar = Calendar.current
    // A new entry at every feeding time today, so "next" moves on even while the app is closed.
    var dates: [Date] = [now]
    if let pet = snapshot?.primaryPet {
      dates += pet.slots.map { pet.time(of: $0, on: now) }.filter { $0 > now }
    }
    let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
    dates.append(tomorrow)
    let entries = dates.sorted().map { PetEntry(date: $0, snapshot: snapshot) }
    completion(Timeline(entries: entries, policy: .after(tomorrow.addingTimeInterval(60))))
  }
}

// MARK: - Views

private struct TimeText: View {
  let hour: Int
  let minute: Int
  var body: some View {
    let date = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
    Text(date, style: .time)
  }
}

private struct LastEventLine: View {
  let title: String
  let event: PTEvent?
  let never: String
  var body: some View {
    if let event, let date = PTDate.parse(event.date) {
      HStack(spacing: 3) {
        Text(title)
        Text(date, style: .relative)
      }
      .lineLimit(1)
    } else {
      Text("\(title): \(never)").lineLimit(1)
    }
  }
}

private struct EmptyStateView: View {
  let text: String
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Image(systemName: "pawprint.fill").font(.title2).foregroundStyle(Color("$accent"))
      Text(text).font(.footnote.weight(.medium)).foregroundStyle(Color("ptInk"))
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct SmallView: View {
  let entry: PetEntry
  var body: some View {
    if let s = entry.snapshot, let pet = s.primaryPet {
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 5) {
          Image(systemName: pet.symbol).foregroundStyle(Color("$accent"))
          Text(pet.name).font(.caption.weight(.semibold)).foregroundStyle(Color("ptMuted")).lineLimit(1)
        }
        Spacer(minLength: 2)
        if let slot = pet.nextSlot(at: entry.date) {
          Text(s.text("next", "Next")).font(.caption2).foregroundStyle(Color("ptMuted"))
          Text(slot.label.isEmpty ? s.kindLabel(slot.kind) : slot.label)
            .font(.headline).foregroundStyle(Color("ptInk")).lineLimit(1)
          TimeText(hour: slot.hour, minute: slot.minute)
            .font(.system(.title2, design: .rounded).weight(.semibold)).foregroundStyle(Color("$accent"))
        } else {
          Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(Color("ptSage"))
          Text(pet.slots.isEmpty ? s.text("noSlots", "No feeding times yet") : s.text("allDone", "All done for today"))
            .font(.subheadline.weight(.semibold)).foregroundStyle(Color("ptInk")).lineLimit(2)
        }
        Spacer(minLength: 2)
        LastEventLine(title: s.text("lastMeal", "Last meal"), event: pet.lastMeal, never: s.text("never", "Not logged yet"))
          .font(.caption2).foregroundStyle(Color("ptMuted"))
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    } else {
      EmptyStateView(text: entry.snapshot?.text("noPets", "Open PetTrack to add your pet") ?? "Open PetTrack to add your pet")
    }
  }
}

struct MediumView: View {
  let entry: PetEntry
  var body: some View {
    if let s = entry.snapshot, let pet = s.primaryPet {
      HStack(alignment: .top, spacing: 14) {
        SmallView(entry: entry)
        VStack(alignment: .leading, spacing: 5) {
          Text(s.text("today", "Today")).font(.caption.weight(.semibold)).foregroundStyle(Color("ptMuted"))
          ForEach(pet.slots.prefix(4)) { slot in
            let done = pet.isDone(slot, on: entry.date)
            HStack(spacing: 6) {
              Image(systemName: done ? "checkmark.circle.fill" : (slot.kind == "water" ? "drop" : "circle"))
                .foregroundStyle(done ? Color("ptSage") : Color("ptMuted"))
              Text(slot.label.isEmpty ? s.kindLabel(slot.kind) : slot.label).lineLimit(1)
                .foregroundStyle(Color("ptInk"))
              Spacer(minLength: 2)
              TimeText(hour: slot.hour, minute: slot.minute).foregroundStyle(Color("ptMuted"))
            }
            .font(.caption)
          }
          if pet.slots.isEmpty {
            Text(s.text("noSlots", "No feeding times yet")).font(.caption).foregroundStyle(Color("ptMuted"))
          }
          Spacer(minLength: 0)
          if let v = pet.vaccine, let due = PTDate.parse(v.due) {
            HStack(spacing: 4) {
              Image(systemName: "syringe").foregroundStyle(Color("$accent"))
              Text(v.name).lineLimit(1)
              Text(due, style: .date)
            }
            .font(.caption2).foregroundStyle(Color("ptMuted")).lineLimit(1)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    } else {
      SmallView(entry: entry)
    }
  }
}

struct RectangularView: View {
  let entry: PetEntry
  var body: some View {
    if let s = entry.snapshot, let pet = s.primaryPet {
      VStack(alignment: .leading, spacing: 1) {
        HStack(spacing: 4) {
          Image(systemName: pet.symbol)
          Text(pet.name).font(.headline).lineLimit(1)
        }
        if let slot = pet.nextSlot(at: entry.date) {
          HStack(spacing: 4) {
            Text(slot.label.isEmpty ? s.kindLabel(slot.kind) : slot.label).lineLimit(1)
            TimeText(hour: slot.hour, minute: slot.minute)
          }
        } else {
          Text(s.text("allDone", "All done for today")).lineLimit(1)
        }
        LastEventLine(title: s.text("lastMeal", "Last meal"), event: pet.lastMeal, never: s.text("never", "Not logged yet"))
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    } else {
      Label("PetTrack", systemImage: "pawprint.fill")
    }
  }
}

struct CircularView: View {
  let entry: PetEntry
  var body: some View {
    let pet = entry.snapshot?.primaryPet
    let total = max(pet?.slots.count ?? 0, 1)
    let done = pet?.doneCount(on: entry.date) ?? 0
    Gauge(value: Double(done), in: 0...Double(total)) {
      Image(systemName: pet?.symbol ?? "pawprint.fill")
    } currentValueLabel: {
      Text("\(done)/\(pet?.slots.count ?? 0)")
    }
    .gaugeStyle(.accessoryCircularCapacity)
  }
}

struct InlineView: View {
  let entry: PetEntry
  var body: some View {
    if let s = entry.snapshot, let pet = s.primaryPet, let slot = pet.nextSlot(at: entry.date) {
      HStack(spacing: 3) {
        Image(systemName: pet.symbol)
        Text("\(pet.name) · \(slot.label.isEmpty ? s.kindLabel(slot.kind) : slot.label)")
        TimeText(hour: slot.hour, minute: slot.minute)
      }
    } else {
      Label(entry.snapshot?.text("allDone", "All done for today") ?? "PetTrack", systemImage: "pawprint.fill")
    }
  }
}

struct PetTrackWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: PetEntry

  var body: some View {
    Group {
      switch family {
      case .systemMedium: MediumView(entry: entry)
      case .accessoryRectangular: RectangularView(entry: entry)
      case .accessoryCircular: CircularView(entry: entry)
      case .accessoryInline: InlineView(entry: entry)
      default: SmallView(entry: entry)
      }
    }
    .containerBackground(for: .widget) { Color("$widgetBackground") }
    .widgetURL(URL(string: "pettrack://"))
  }
}

struct PetTrackWidget: Widget {
  let kind = "PetTrackWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: PetProvider()) { entry in
      PetTrackWidgetView(entry: entry)
    }
    .configurationDisplayName("PetTrack")
    .description("Next feeding, last meal and upcoming vaccine.")
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
  }
}

@main
struct PetTrackWidgetBundle: WidgetBundle {
  var body: some Widget {
    PetTrackWidget()
  }
}
