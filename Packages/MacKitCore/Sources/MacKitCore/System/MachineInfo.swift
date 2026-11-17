import Foundation

/// Identifying details about this Mac, shown on the overview.
public struct MachineInfo: Hashable, Sendable {
    /// The marketing name, such as "MacBook Air".
    public var model: String
    /// The processor, such as "Apple M2".
    public var chip: String
    /// Installed memory, such as "16 GB".
    public var memory: String
    /// The macOS version, such as "27.2".
    public var systemVersion: String

    public init(model: String, chip: String, memory: String, systemVersion: String) {
        self.model = model
        self.chip = chip
        self.memory = memory
        self.systemVersion = systemVersion
    }

    /// Reads the details from `system_profiler`, falling back to what
    /// `ProcessInfo` knows if that fails.
    @concurrent
    public static func current(using commands: any CommandRunning) async -> MachineInfo {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let systemVersion = version.patchVersion == 0
            ? "\(version.majorVersion).\(version.minorVersion)"
            : "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        let memory = ByteCountFormatter.string(
            fromByteCount: Int64(ProcessInfo.processInfo.physicalMemory), countStyle: .memory
        )
        var info = MachineInfo(model: "Mac", chip: "", memory: memory, systemVersion: systemVersion)

        struct Report: Decodable {
            struct Hardware: Decodable {
                var machine_name: String?
                var chip_type: String?
                var cpu_type: String?
                var physical_memory: String?
            }
            var SPHardwareDataType: [Hardware]
        }

        let command = Command("/usr/sbin/system_profiler", "SPHardwareDataType", "-json")
        if let result = try? await commands.run(command), result.exitCode == 0,
           let report = try? JSONDecoder().decode(Report.self, from: Data(result.standardOutput.utf8)),
           let hardware = report.SPHardwareDataType.first {
            info.model = hardware.machine_name ?? info.model
            info.chip = hardware.chip_type ?? hardware.cpu_type ?? ""
            info.memory = hardware.physical_memory ?? info.memory
        }
        return info
    }
}
