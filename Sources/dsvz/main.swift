import Foundation
import Virtualization

struct CommandLineFailure: Error, CustomStringConvertible {
    let description: String
    let exitCode: Int32
}

struct RunOptions {
    var kernelPath: String?
    var initrdPath: String?
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
        print("  cpus:    \(options.cpuCount)")
        print("  memory:  \(options.memoryMiB) MiB")
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

        configuration.platform = VZGenericPlatformConfiguration()
        configuration.cpuCount = options.cpuCount
        configuration.memorySize = options.memoryMiB * 1024 * 1024

        let bootLoader = VZLinuxBootLoader(
            kernelURL: URL(fileURLWithPath: expandPath(options.kernelPath!))
        )
        bootLoader.initialRamdiskURL = URL(
            fileURLWithPath: expandPath(options.initrdPath!)
        )
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

        try configuration.validate()
        return configuration
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
          \(name) run --kernel <path> --initrd <path> [options]

        Options:
          --kernel <path>      Linux kernel image to boot
          --initrd <path>      Droidspaces initramfs image to load
          --cpus <count>       Virtual CPU count; default: 2
          --memory <MiB>       Guest memory size in MiB; default: 1024
          --cmdline <string>   Linux kernel command line
          -h, --help           Show this help message

        Default kernel command line:
          console=hvc0 init=/init

        This command intentionally performs only direct kernel/initramfs boot.
        Directory sharing and networking will be added in later commits.
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
