import ServiceManagement
import SwiftUI

struct PopoverView: View {
    @ObservedObject var controller: ClamshellController

    @AppStorage(Key.batteryFloorEnabled) private var batteryFloorEnabled = true
    @AppStorage(Key.batteryFloor) private var batteryFloor = 20
    @AppStorage(Key.autoOffEnabled) private var autoOffEnabled = true
    @AppStorage(Key.autoOffHours) private var autoOffHours = 8
    @AppStorage(Key.lockOnLidClose) private var lockOnLidClose = true
    @AppStorage(Key.thermalGuard) private var thermalGuard = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if controller.isSetUp {
                Button(action: controller.toggle) {
                    Text(controller.isActive ? "Turn off clamshell mode" : "Turn on clamshell mode")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .tint(controller.isActive ? .orange : .accentColor)
            } else {
                setupBanner
            }

            if let message = controller.errorMessage {
                Text(message).font(.caption).foregroundStyle(.red)
            } else if let reason = controller.lastStopReason {
                Text(reason).font(.caption).foregroundStyle(.secondary)
            }

            Divider()
            status
            Divider()
            settings
            Divider()

            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        .padding(14)
        .frame(width: 280)
    }

    private var header: some View {
        HStack {
            Image(nsImage: LaptopIcon.image(closed: controller.isActive, size: 16))
            Text("Clamshell Mode").font(.headline)
            Spacer()
            Circle().fill(controller.isActive ? .green : .gray).frame(width: 8, height: 8)
        }
    }

    private var setupBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("One-time setup").font(.subheadline.bold())
            Text("Installs a sudoers rule allowing only `pmset -a disablesleep 0|1` without a password.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Set up…") { controller.runSetup() }
        }
        .padding(10)
        .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 4) {
            row("Lid", controller.lidClosed ? "Closed" : "Open")
            row("Power", powerText)
            if let remaining = controller.remaining {
                row("Auto-off in", format(remaining))
            }
        }
        .font(.callout)
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("Stop at battery ≤", isOn: $batteryFloorEnabled)
                Stepper("\(batteryFloor)%", value: $batteryFloor, in: 5...50, step: 5)
                    .disabled(!batteryFloorEnabled)
            }
            HStack {
                Toggle("Auto-off after", isOn: $autoOffEnabled)
                Stepper("\(autoOffHours) h", value: $autoOffHours, in: 1...24)
                    .disabled(!autoOffEnabled)
            }
            Toggle("Lock screen when lid closes", isOn: $lockOnLidClose)
            Toggle("Stop if Mac runs hot", isOn: $thermalGuard)
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { enabled in
                    do {
                        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
        }
        .font(.callout)
    }

    private var powerText: String {
        guard let battery = controller.battery else { return "AC" }
        return battery.onACPower ? "Plugged in (\(battery.percent)%)" : "Battery \(battery.percent)%"
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack { Text(label).foregroundStyle(.secondary); Spacer(); Text(value) }
    }

    private func format(_ interval: TimeInterval) -> String {
        let minutes = max(0, Int(interval / 60))
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}
