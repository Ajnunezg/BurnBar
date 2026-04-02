import BurnBarDaemon
import Foundation

@main
struct BurnBarCLIExecutable {
    static func main() {
        let runner = BurnBarCLIRunner(client: BurnBarCLISocketClient())
        do {
            let output = try runner.run(arguments: Array(CommandLine.arguments.dropFirst()))
            fputs(output + "\n", stdout)
            exit(EXIT_SUCCESS)
        } catch {
            fputs((error.localizedDescription.isEmpty ? String(describing: error) : error.localizedDescription) + "\n", stderr)
            exit(EXIT_FAILURE)
        }
    }
}
