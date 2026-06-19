import Foundation

struct CommandLineFailure: Error, CustomStringConvertible {
    let description: String
    let exitCode: Int32
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

        Planned commands:
          run        Boot a Droidspaces Linux kernel and initramfs
          validate   Validate VM configuration and host paths

        This initial commit intentionally contains only the CLI skeleton.
        VM launch support will be added after the workspace and CI baseline
        are established.
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
