import Foundation
import Virtualization

struct CommandLineFailure: Error, CustomStringConvertible {
    let description: String
    let exitCode: Int32
}

struct RunOptions {
    var kernelPath: String?
    var initrdPath: String?
    var machineIdentifierPath: String?
    var sharePath: String?
    var shareTag: String = "dsdata"
    var cpuCount: Int = 2
    var memoryMiB: UInt64 = 1024
    var commandLine: String = "console=hvc0 init=/init"
}

final class VMDelegate: NSObject, VZVirtualMachineDelegate {
    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        print("\nVM stopped")
        exit(0)
    }

    func virtualMachine(
        _ virtualMachine: VZVirtualMachine,
        didStopWithError error: Error
    ) {
        fputs("\nVM stopped with error: \(error)\n", stderr)
        exit(1)
    }
}

enum DSVZ {
    static let name = "dsvz"
    static let version = "0.1.0"

    static func main(_ arguments: [String]) throws {
        var args = Array(arguments.dropFirst())

        guard let command = args.first else {
            printHelp()
            return
        }

        args.removeFirst()

        switch command {
        case "help", "-h", "--help":
            try requireNoExtraArguments(args, command: command)
            printHelp()

        case "version", "-V", "--version":
            try requireNoExtraArguments(args, command: command)
            printVersion()

        case "run":
            let options = try parseRunOptions(args)
            try run(options)

        default:
            throw CommandLineFailure(
                description: "unknown command: \(command)",
                exitCode: 2
            )
        }
    }

    private static func requireNoExtraArguments(
        _ args: [String],
        command: String
    ) throws {
        guard args.isEmpty else {
            throw CommandLineFailure(
                description: "\(command) does not accept arguments",
                exitCode: 2
            )
        }
    }

    private static func parseRunOptions(_ args: [String]) throws -> RunOptions {
        var options = RunOptions()
        var index = 0

        func requireValue(for flag: String) throws -> String {
            guard index + 1 < args.count else {
                throw CommandLineFailure(
                    description: "missing value for \(flag)",
                    exitCode: 2
                )
            }

            index += 1
            return args[index]
        }

        while index < args.count {
            let arg = args[index]

            switch arg {
            case "--kernel":
                options.kernelPath = try requireValue(for: arg)

            case "--initrd":
                options.initrdPath = try requireValue(for: arg)

            case "--machine-id":
                options.machineIdentifierPath = try requireValue(for: arg)

            case "--share":
                options.sharePath = try requireValue(for: arg)

            case "--share-tag":
                options.shareTag = try requireValue(for: arg)

            case "--cpus":
                let value = try requireValue(for: arg)
                guard let cpus = Int(value), cpus > 0 else {
                    throw CommandLineFailure(
                        description: "invalid CPU count: \(value)",
                        exitCode: 2
                    )
                }
                options.cpuCount = cpus

            case "--memory":
                let value = try requireValue(for: arg)
                guard let memoryMiB = UInt64(value), memoryMiB > 0 else {
                    throw CommandLineFailure(
                        description: "invalid memory size: \(value)",
                        exitCode: 2
                    )
                }
                options.memoryMiB = memoryMiB

            case "--cmdline":
                options.commandLine = try requireValue(for: arg)

            case "-h", "--help":
                printRunHelp()
                exit(0)

            default:
                throw CommandLineFailure(
                    description: "unknown run option: \(arg)",
                    exitCode: 2
                )
            }

            index += 1
        }

        guard options.kernelPath != nil else {
            throw CommandLineFailure(
                description: "run requires --kernel <path>",
                exitCode: 2
            )
        }

        guard options.initrdPath != nil else {
            throw CommandLineFailure(
                description: "run requires --initrd <path>",
                exitCode: 2
            )
        }

        guard options.sharePath != nil else {
            throw CommandLineFailure(
                description: "run requires --share <directory>",
                exitCode: 2
            )
        }

        return options
    }

    private static func run(_ options: RunOptions) throws {
        let configuration = try makeVirtualMachineConfiguration(options)
        let virtualMachine = VZVirtualMachine(configuration: configuration)
        let delegate = VMDelegate()
        virtualMachine.delegate = delegate

        print("Starting Droidspaces VM")
        print("  kernel:  \(expandPath(options.kernelPath!))")
        print("  initrd:  \(expandPath(options.initrdPath!))")
        if let machineIdentifierPath = options.machineIdentifierPath {
            print("  machine: \(makeFileURL(machineIdentifierPath).path)")
        } else {
            print("  machine: <ephemeral>")
        }
        print("  share:   \(makeFileURL(options.sharePath!).path)")
        print("  tag:     \(options.shareTag)")
        print("  cpus:    \(options.cpuCount)")
        print("  memory:  \(options.memoryMiB) MiB")
        print("  network: \(networkDescription(for: configuration))")
        print("  cmdline: \(options.commandLine)")
        print("")

        virtualMachine.start { result in
            switch result {
            case .success:
                print("VM started")
            case .failure(let error):
                fputs("failed to start VM: \(error)\n", stderr)
                exit(1)
            }
        }

        withExtendedLifetime(delegate) {
            RunLoop.main.run()
        }
    }

    private static func makeVirtualMachineConfiguration(
        _ options: RunOptions
    ) throws -> VZVirtualMachineConfiguration {
        let configuration = VZVirtualMachineConfiguration()

        let platform = VZGenericPlatformConfiguration()
        platform.machineIdentifier = try makeMachineIdentifier(
            path: options.machineIdentifierPath
        )
        configuration.platform = platform
        configuration.cpuCount = options.cpuCount
        configuration.memorySize = options.memoryMiB * 1024 * 1024

        let bootLoader = VZLinuxBootLoader(
            kernelURL: makeFileURL(options.kernelPath!)
        )
        bootLoader.initialRamdiskURL = makeFileURL(options.initrdPath!)
        bootLoader.commandLine = options.commandLine
        configuration.bootLoader = bootLoader

        let serialPort = VZVirtioConsoleDeviceSerialPortConfiguration()
        serialPort.attachment = VZFileHandleSerialPortAttachment(
            fileHandleForReading: FileHandle.standardInput,
            fileHandleForWriting: FileHandle.standardOutput
        )
        configuration.serialPorts = [serialPort]

        configuration.entropyDevices = [
            VZVirtioEntropyDeviceConfiguration()
        ]

        configuration.networkDevices = [
            makeNATNetworkDevice()
        ]

        configuration.directorySharingDevices = [
            try makeDirectorySharingDevice(
                path: options.sharePath!,
                tag: options.shareTag
            )
        ]

        try configuration.validate()
        return configuration
    }

    private static func makeNATNetworkDevice()
        -> VZVirtioNetworkDeviceConfiguration {
        let device = VZVirtioNetworkDeviceConfiguration()
        device.attachment = VZNATNetworkDeviceAttachment()
        device.macAddress = VZMACAddress.randomLocallyAdministered()
        return device
    }

    private static func networkDescription(
        for configuration: VZVirtualMachineConfiguration
    ) -> String {
        guard let networkDevice = configuration.networkDevices.first else {
            return "unavailable"
        }

        return "macOS NAT (MAC \(networkDevice.macAddress.string))"
    }

    private static func makeDirectorySharingDevice(
        path: String,
        tag: String
    ) throws -> VZVirtioFileSystemDeviceConfiguration {
        do {
            try VZVirtioFileSystemDeviceConfiguration.validateTag(tag)
        } catch {
            throw CommandLineFailure(
                description: "invalid VirtIO-FS share tag: \(tag)",
                exitCode: 2
            )
        }

        let shareURL = makeFileURL(path)
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        if fileManager.fileExists(
            atPath: shareURL.path,
            isDirectory: &isDirectory
        ) {
            guard isDirectory.boolValue else {
                throw CommandLineFailure(
                    description: "share path is not a directory: \(shareURL.path)",
                    exitCode: 1
                )
            }
        } else {
            try fileManager.createDirectory(
                at: shareURL,
                withIntermediateDirectories: true
            )
        }

        let sharedDirectory = VZSharedDirectory(url: shareURL, readOnly: false)
        let share = VZSingleDirectoryShare(directory: sharedDirectory)
        let device = VZVirtioFileSystemDeviceConfiguration(tag: tag)
        device.share = share
        return device
    }

    private static func makeMachineIdentifier(
        path: String?
    ) throws -> VZGenericMachineIdentifier {
        guard let path else {
            return VZGenericMachineIdentifier()
        }

        let identifierURL = makeFileURL(path)
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: identifierURL.path) {
            let data = try Data(contentsOf: identifierURL)
            guard let identifier = VZGenericMachineIdentifier(
                dataRepresentation: data
            ) else {
                throw CommandLineFailure(
                    description: "invalid machine identifier: \(identifierURL.path)",
                    exitCode: 1
                )
            }
            return identifier
        }

        let directoryURL = identifierURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let identifier = VZGenericMachineIdentifier()
        try identifier.dataRepresentation.write(to: identifierURL, options: [.atomic])
        return identifier
    }

    private static func makeFileURL(_ path: String) -> URL {
        let expanded = expandPath(path)

        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded)
        }

        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(expanded)
    }

    private static func expandPath(_ path: String) -> String {
        if path == "~" {
            return FileManager.default.homeDirectoryForCurrentUser.path
        }

        if path.hasPrefix("~/") {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            return home + String(path.dropFirst())
        }

        return path
    }

    private static func printVersion() {
        print("\(name) \(version)")
    }

    private static func printHelp() {
        print("""
        \(name) - Droidspaces Virtualization.framework runner

        Usage:
          \(name) <command>

        Commands:
          help       Show this help message
          version    Show program version
          run        Boot a Droidspaces Linux kernel and initramfs

        Use '\(name) run --help' for VM launch options.
        """)
    }

    private static func printRunHelp() {
        print("""
        \(name) run - boot a Droidspaces Linux kernel and initramfs

        Usage:
          \(name) run --kernel <path> --initrd <path> --share <directory> [options]

        Options:
          --kernel <path>      Linux kernel image to boot
          --initrd <path>      Droidspaces initramfs image to load
          --machine-id <path>  Persistent generic machine identifier file
          --share <directory>  Writable host directory to expose to the guest
          --share-tag <tag>    VirtIO-FS tag for --share; default: dsdata
          --cpus <count>       Virtual CPU count; default: 2
          --memory <MiB>       Guest memory size in MiB; default: 1024
          --cmdline <string>   Linux kernel command line
          -h, --help           Show this help message

        Default kernel command line:
          console=hvc0 init=/init

        The shared directory is exposed through VirtIO-FS. The current
        Droidspaces initramfs mounts the default dsdata tag at /mnt/host.
        A VirtIO network device is attached through macOS NAT. The guest
        initramfs must bring the device up and configure it with DHCP.
        Persistent virtual disks and plist configuration will be added in later
        commits.
        """)
    }
}

do {
    try DSVZ.main(CommandLine.arguments)
} catch let error as CommandLineFailure {
    fputs("error: \(error.description)\n", stderr)
    fputs("try 'dsvz help'\n", stderr)
    exit(error.exitCode)
} catch {
    fputs("error: \(error)\n", stderr)
    exit(1)
}
