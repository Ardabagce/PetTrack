import ExpoModulesCore
import WatchConnectivity
import WidgetKit

private let appGroup = "group.com.pettrack.app"
private let snapshotKey = "snapshot"
private let watchActionsKey = "watchActions"

/// Bridges the JS app to the home-screen widget (App Group defaults) and the Watch app (WatchConnectivity).
public class PetTrackCompanionModule: Module {
  private let bridge = WatchBridge()

  public func definition() -> ModuleDefinition {
    Name("PetTrackCompanion")

    Events("onWatchAction")

    OnCreate {
      bridge.onAction = { [weak self] in
        self?.sendEvent("onWatchAction", [:])
      }
      bridge.activate()
    }

    /// Stores the JSON summary for the widget, reloads its timelines and forwards it to the Watch.
    Function("setSnapshot") { (json: String) in
      UserDefaults(suiteName: appGroup)?.set(json, forKey: snapshotKey)
      WidgetCenter.shared.reloadAllTimelines()
      self.bridge.push(json)
    }

    /// Returns (and clears) the actions tapped on the Watch, as a JSON array.
    Function("takeWatchActions") { () -> String in
      self.bridge.takeActions()
    }

    Function("isWatchAppInstalled") { () -> Bool in
      guard WCSession.isSupported() else { return false }
      let session = WCSession.default
      return session.activationState == .activated && session.isPaired && session.isWatchAppInstalled
    }
  }
}

final class WatchBridge: NSObject, WCSessionDelegate {
  var onAction: (() -> Void)?
  private var pending: String?
  private let lock = NSLock()

  func activate() {
    guard WCSession.isSupported() else { return }
    WCSession.default.delegate = self
    WCSession.default.activate()
  }

  func push(_ json: String) {
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    guard session.activationState == .activated else {
      pending = json
      return
    }
    guard session.isPaired, session.isWatchAppInstalled else { return }
    try? session.updateApplicationContext(["snapshot": json])
  }

  func takeActions() -> String {
    lock.lock(); defer { lock.unlock() }
    let defaults = UserDefaults(suiteName: appGroup)
    let list = defaults?.stringArray(forKey: watchActionsKey) ?? []
    defaults?.removeObject(forKey: watchActionsKey)
    return "[" + list.joined(separator: ",") + "]"
  }

  private func store(_ info: [String: Any]) {
    guard let action = info["action"] as? String else { return }
    lock.lock()
    let defaults = UserDefaults(suiteName: appGroup)
    var list = defaults?.stringArray(forKey: watchActionsKey) ?? []
    list.append(action)
    defaults?.set(list, forKey: watchActionsKey)
    lock.unlock()
    DispatchQueue.main.async { self.onAction?() }
  }

  // MARK: WCSessionDelegate

  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    if activationState == .activated, let json = pending {
      pending = nil
      push(json)
    }
  }

  func sessionDidBecomeInactive(_ session: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }

  func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
    store(userInfo)
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    store(message)
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
    store(message)
    replyHandler(["ok": true])
  }
}
