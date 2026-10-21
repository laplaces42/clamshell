import Foundation
import IOKit
import IOKit.ps

/// Runs a command and returns its exit status and stdout.
@discardableResult
func run(_ path: String, _ args: [String]) -> (status: Int32, output: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = args
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    do { try process.run() } catch { return (-1, "") }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return (process.terminationStatus, String(decoding: data, as: UTF8.self))
}

/// The one privileged operation: toggling `pmset disablesleep` through a scoped sudoers rule.
enum Power {
    static func setSleepDisabled(_ disabled: Bool) -> Bool {
        run("/usr/bin/sudo", ["-n", "/usr/bin/pmset", "-a", "disablesleep", disabled ? "1" : "0"]).status == 0
    }

    static func isSleepDisabled() -> Bool {
        run("/usr/bin/pmset", ["-g"]).output
            .split(separator: "\n")
            .contains { line in
                let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
                return parts.first == "SleepDisabled" && parts.last == "1"
            }
    }
}

enum Lid {
    static func isClosed() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        let value = IORegistryEntryCreateCFProperty(service, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0)
        return (value?.takeRetainedValue() as? Bool) ?? false
    }
}

struct BatteryStatus: Equatable {
    var percent: Int
    var onACPower: Bool
}

enum Battery {
    static func read() -> BatteryStatus? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  let percent = description[kIOPSCurrentCapacityKey] as? Int else { continue }
            let state = description[kIOPSPowerSourceStateKey] as? String
            return BatteryStatus(percent: percent, onACPower: state == kIOPSACPowerValue)
        }
        return nil
    }
}

enum ScreenLock {
    /// Locks the screen via the login framework, falling back to display sleep.
    static func lock() {
        typealias LockFunction = @convention(c) () -> Int32
        if let handle = dlopen("/System/Library/PrivateFrameworks/login.framework/login", RTLD_LAZY),
           let symbol = dlsym(handle, "SACLockScreenImmediate") {
            _ = unsafeBitCast(symbol, to: LockFunction.self)()
        } else {
            run("/usr/bin/pmset", ["displaysleepnow"])
        }
    }
}

/// One-time install of a sudoers rule that allows only the two `pmset disablesleep` commands.
enum Setup {
    static let sudoersPath = "/etc/sudoers.d/clamshelltoggle"

    static func install() -> String? {
        let user = NSUserName()
        guard user.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil else {
            return "Unsupported username: \(user)"
        }
        let rule = "\(user) ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1"
        let script = """
        set -e; T=$(mktemp); printf '%s\\n' '\(rule)' > "$T"; \
        /usr/sbin/visudo -cf "$T" >/dev/null; \
        /usr/bin/install -m 0440 -o root -g wheel "$T" \(sudoersPath); rm -f "$T"
        """
        let escaped = script.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        var error: NSDictionary?
        NSAppleScript(source: "do shell script \"\(escaped)\" with administrator privileges")?.executeAndReturnError(&error)
        return (error?[NSAppleScript.errorMessage] as? String)
    }
}
