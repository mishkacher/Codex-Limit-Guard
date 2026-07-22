import Foundation
import CodexLimitGuardCore

final class CodexAppServerClient {
    enum ConnectionState: Equatable {
        case stopped
        case connecting
        case connected
        case unavailable(String)
    }

    var onSnapshot: ((RateLimitSnapshot) -> Void)?
    var onState: ((ConnectionState) -> Void)?
    var onDiagnostic: ((String) -> Void)?

    private let queue = DispatchQueue(label: "dev.mishkacher.codex-limit-guard.app-server")
    private let parser = RateLimitParser()
    private let builder = JSONRPCBuilder()
    private var process: Process?
    private var input: FileHandle?
    private var outputBuffer = Data()
    private var pollTimer: DispatchSourceTimer?
    private var reconnectWorkItem: DispatchWorkItem?
    private var requestID = 10
    private var reconnectDelay: TimeInterval = 2
    private var pollingInterval: TimeInterval = 30
    private var shouldRun = false

    func start(pollingInterval: TimeInterval) {
        queue.async {
            self.pollingInterval = max(10, pollingInterval)
            self.shouldRun = true
            self.launch()
        }
    }

    func updatePollingInterval(_ value: TimeInterval) {
        queue.async {
            self.pollingInterval = max(10, value)
            if self.process?.isRunning == true { self.configurePolling() }
        }
    }

    func stop() {
        queue.async {
            self.shouldRun = false
            self.reconnectWorkItem?.cancel()
            self.pollTimer?.cancel()
            self.pollTimer = nil
            self.process?.terminate()
            self.process = nil
            self.input = nil
            self.emitState(.stopped)
        }
    }

    func refreshNow() {
        queue.async { self.requestRateLimits() }
    }

    private func launch() {
        guard shouldRun else { return }
        cleanupProcess()
        emitState(.connecting)

        guard let executable = Self.findCodexExecutable() else {
            emitState(.unavailable("Codex CLI was not found. Install Codex or set it in PATH."))
            scheduleReconnect()
            return
        }

        let process = Process()
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["app-server"]
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.environment = ProcessInfo.processInfo.environment

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.queue.async { self?.consume(data) }
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard let text = String(data: data, encoding: .utf8), !text.isEmpty else { return }
            self?.emitDiagnostic(text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        process.terminationHandler = { [weak self] _ in
            self?.queue.async {
                guard let self else { return }
                self.cleanupProcess()
                guard self.shouldRun else {
                    self.emitState(.stopped)
                    return
                }
                self.emitState(.unavailable("Codex app-server stopped unexpectedly."))
                self.scheduleReconnect()
            }
        }

        do {
            try process.run()
            self.process = process
            input = stdinPipe.fileHandleForWriting
            reconnectDelay = 2
            try send(builder.initialize())
            try send(builder.initialized())
            requestRateLimits()
            configurePolling()
            emitState(.connected)
        } catch {
            emitState(.unavailable(error.localizedDescription))
            cleanupProcess()
            scheduleReconnect()
        }
    }

    private func configurePolling() {
        pollTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + pollingInterval, repeating: pollingInterval, leeway: .seconds(2))
        timer.setEventHandler { [weak self] in self?.requestRateLimits() }
        timer.resume()
        pollTimer = timer
    }

    private func requestRateLimits() {
        guard process?.isRunning == true else { return }
        requestID += 1
        do { try send(builder.readRateLimits(id: requestID)) }
        catch { emitDiagnostic("Unable to request limits: \(error.localizedDescription)") }
    }

    private func send(_ object: [String: Any]) throws {
        guard let input else { throw ClientError.notConnected }
        try input.write(contentsOf: builder.encodedLine(object))
    }

    private func consume(_ data: Data) {
        outputBuffer.append(data)
        while let newline = outputBuffer.firstIndex(of: 0x0A) {
            let line = outputBuffer.prefix(upTo: newline)
            outputBuffer.removeSubrange(...newline)
            guard !line.isEmpty else { continue }
            do {
                if let snapshot = try parser.parse(data: Data(line)) {
                    DispatchQueue.main.async { [weak self] in self?.onSnapshot?(snapshot) }
                }
            } catch RateLimitParserError.noRateLimitWindows {
                // Initialization and unrelated responses can legitimately contain no windows.
            } catch {
                emitDiagnostic("Rate-limit response could not be parsed: \(error.localizedDescription)")
            }
        }
    }

    private func cleanupProcess() {
        pollTimer?.cancel()
        pollTimer = nil
        process?.terminationHandler = nil
        process?.standardOutput = nil
        process?.standardError = nil
        if process?.isRunning == true { process?.terminate() }
        process = nil
        input = nil
        outputBuffer.removeAll(keepingCapacity: true)
    }

    private func scheduleReconnect() {
        guard shouldRun else { return }
        reconnectWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.launch() }
        reconnectWorkItem = item
        queue.asyncAfter(deadline: .now() + reconnectDelay, execute: item)
        reconnectDelay = min(reconnectDelay * 2, 60)
    }

    private func emitState(_ state: ConnectionState) {
        DispatchQueue.main.async { [weak self] in self?.onState?(state) }
    }

    private func emitDiagnostic(_ text: String) {
        DispatchQueue.main.async { [weak self] in self?.onDiagnostic?(text) }
    }

    private static func findCodexExecutable() -> String? {
        let environmentPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let pathCandidates = environmentPath.split(separator: ":").map { String($0) + "/codex" }
        let fixed = [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            NSHomeDirectory() + "/.local/bin/codex"
        ]
        return (fixed + pathCandidates).first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}

private enum ClientError: LocalizedError {
    case notConnected
    var errorDescription: String? { "Codex app-server is not connected." }
}
