import AppKit
import Foundation

enum Key {
    static let batteryFloorEnabled = "batteryFloorEnabled"
    static let batteryFloor = "batteryFloor"
    static let autoOffEnabled = "autoOffEnabled"
    static let autoOffHours = "autoOffHours"
    static let lockOnLidClose = "lockOnLidClose"
    static let thermalGuard = "thermalGuard"
}

@MainActor
final class ClamshellController: ObservableObject {
    static let shared = ClamshellController()

    @Published private(set) var isActive = false
    @Published private(set) var isSetUp = false
    @Published private(set) var lidClosed = false
    @Published private(set) var battery: BatteryStatus?
    @Published private(set) var remaining: TimeInterval?
    @Published private(set) var lastStopReason: String?
    @Published var errorMessage: String?

    private var endsAt: Date?
    private var watchdog: Process?
    private var timer: Timer?
    private var ticks = 0

    private let defaults = UserDefaults.standard

    private init() {
        defaults.register(defaults: [
            Key.batteryFloorEnabled: true, Key.batteryFloor: 20,
            Key.autoOffEnabled: true, Key.autoOffHours: 8,
            Key.lockOnLidClose: true, Key.thermalGuard: true,
        ])
        // A previous run may have crashed with sleep still disabled. Clearing it also tells us whether setup is done.
        isSetUp = Power.setSleepDisabled(false)
        lidClosed = Lid.isClosed()
        battery = Battery.read()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    // MARK: Actions

    func toggle() {
        isActive ? stop(reason: nil) : start()
    }

    func start() {
        errorMessage = nil
        guard isSetUp else { errorMessage = "Run the one-time setup first."; return }
        if let reason = batteryFloorViolation() {
            errorMessage = "Not starting: \(reason)."
            return
        }
        guard Power.setSleepDisabled(true) else {
            errorMessage = "Couldn't change the sleep setting."
            return
        }
        isActive = true
        lastStopReason = nil
        endsAt = defaults.bool(forKey: Key.autoOffEnabled)
            ? Date().addingTimeInterval(defaults.double(forKey: Key.autoOffHours) * 3600) : nil
        remaining = endsAt.map { $0.timeIntervalSinceNow }
        startWatchdog()
    }

    func stop(reason: String?) {
        stopWatchdog()
        if !Power.setSleepDisabled(false) {
            errorMessage = "Couldn't restore the sleep setting. Run: sudo pmset -a disablesleep 0"
        }
        isActive = false
        endsAt = nil
        remaining = nil
        lastStopReason = reason
    }

    func runSetup() {
        errorMessage = Setup.install()
        isSetUp = Power.setSleepDisabled(false)
        if !isSetUp && errorMessage == nil { errorMessage = "Setup didn't take effect." }
    }

    /// Called on quit and on termination signals.
    func shutdown() {
        guard isActive else { return }
        stop(reason: nil)
    }

    // MARK: Polling

    private func tick() {
        ticks += 1
        let closed = Lid.isClosed()
        let wasClosed = lidClosed
        if closed != lidClosed { lidClosed = closed }
        let status = Battery.read()
        if status != battery { battery = status }

        guard isActive else { return }

        if closed && !wasClosed && defaults.bool(forKey: Key.lockOnLidClose) {
            ScreenLock.lock()
        }
        if !closed && wasClosed {
            stop(reason: "Lid opened")
            return
        }
        if let reason = batteryFloorViolation() {
            stop(reason: "Stopped: \(reason)")
            return
        }
        if defaults.bool(forKey: Key.thermalGuard),
           ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue {
            stop(reason: "Stopped: Mac is running hot")
            return
        }
        if let endsAt {
            let left = endsAt.timeIntervalSinceNow
            if left <= 0 { stop(reason: "Auto-off timer finished"); return }
            remaining = left
        }
        // Something else (another tool, a reboot) may have reset the setting behind our back.
        if ticks % 10 == 0 && !Power.isSleepDisabled() {
            stop(reason: "Sleep setting was changed elsewhere")
        }
    }

    private func batteryFloorViolation() -> String? {
        guard defaults.bool(forKey: Key.batteryFloorEnabled), let battery, !battery.onACPower else { return nil }
        let floor = defaults.integer(forKey: Key.batteryFloor)
        return battery.percent <= floor ? "battery at \(battery.percent)%" : nil
    }

    // MARK: Watchdog

    /// A detached shell that restores normal sleep if this app dies without cleaning up (crash, force quit).
    private func startWatchdog() {
        stopWatchdog()
        let pid = ProcessInfo.processInfo.processIdentifier
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "while kill -0 \(pid) 2>/dev/null; do sleep 3; done; /usr/bin/sudo -n /usr/bin/pmset -a disablesleep 0"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        try? process.run()
        watchdog = process
    }

    private func stopWatchdog() {
        watchdog?.terminate()
        watchdog = nil
    }
}
