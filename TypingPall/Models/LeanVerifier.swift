import Foundation

#if os(macOS)
/// Verifies self-contained Lean 4 snippets by piping them to a local `lean --stdin` process.
enum LeanVerifier {
    enum VerificationResult: Equatable, Sendable {
        case passed
        case failed(diagnostics: String)
        case toolchainUnavailable
    }

    private static let candidatePaths = [
        "/opt/homebrew/bin/lean",
        "/usr/local/bin/lean",
        (NSHomeDirectory() as NSString).appendingPathComponent(".elan/bin/lean")
    ]

    static var isSandboxed: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["APP_SANDBOX_CONTAINER_ID"] != nil ||
            NSHomeDirectory().contains("/Library/Containers/")
    }

    /// Returns the first executable `lean` binary on PATH or standard install locations,
    /// or `nil` when running inside the macOS App Sandbox.
    static func resolveLeanExecutable(fileManager: FileManager = .default) -> String? {
        guard !isSandboxed else { return nil }
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            for dir in pathEnv.split(separator: ":") {
                let candidate = String(dir) + "/lean"
                if fileManager.isExecutableFile(atPath: candidate) {
                    return candidate
                }
            }
        }
        return candidatePaths.first { fileManager.isExecutableFile(atPath: $0) }
    }

    /// Maps process exit status and output streams to a `VerificationResult`.
    static func interpretOutput(status: Int32, stdout: String, stderr: String) -> VerificationResult {
        let combined = [stdout, stderr]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        if status == 0 && !combined.contains("declaration uses 'sorry'") {
            return .passed
        }
        return .failed(diagnostics: combined.isEmpty ? "lean exited with status \(status)" : combined)
    }

    /// Type-checks `source` using `lean --stdin` with a bounded timeout.
    static func verify(
        _ source: String,
        executablePath: String? = resolveLeanExecutable(),
        timeoutSeconds: TimeInterval = 5
    ) -> VerificationResult {
        guard !isSandboxed, let executablePath else { return .toolchainUnavailable }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["--stdin"]

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let done = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in done.signal() }

        do {
            try process.run()
        } catch {
            return .toolchainUnavailable
        }

        if let data = source.data(using: .utf8) {
            stdinPipe.fileHandleForWriting.write(data)
        }
        try? stdinPipe.fileHandleForWriting.close()

        var stdoutData = Data()
        var stderrData = Data()
        let ioGroup = DispatchGroup()
        ioGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            ioGroup.leave()
        }
        ioGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            ioGroup.leave()
        }

        if done.wait(timeout: .now() + timeoutSeconds) == .timedOut {
            process.terminate()
            return .failed(diagnostics: "Lean verification timed out after \(Int(timeoutSeconds))s")
        }
        _ = ioGroup.wait(timeout: .now() + 1)

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        return interpretOutput(status: process.terminationStatus, stdout: stdout, stderr: stderr)
    }
}
#endif
