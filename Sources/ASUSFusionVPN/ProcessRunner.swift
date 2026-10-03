import Darwin
import Foundation
import os

struct ProcessOutput: Sendable {
    let status: Int32
    let standardOutput: String
    let standardError: String
}

/// Runs a child process without blocking any thread while it executes.
///
/// Output is drained continuously so large responses cannot fill the pipe buffer,
/// the call is cancellable, and a hard timeout terminates (then kills) wedged processes.
enum ProcessRunner {
    private static let terminationGracePeriod: TimeInterval = 2

    static func run(
        executable: String,
        arguments: [String],
        environment: [String: String] = [:],
        timeout: TimeInterval
    ) async throws -> ProcessOutput {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
        process.standardInput = FileHandle.nullDevice

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let run = ProcessRun()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ProcessOutput, Error>) in
                guard run.attach(continuation) else { return }

                outputPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if data.isEmpty { handle.readabilityHandler = nil }
                    run.append(data, isError: false)
                }
                errorPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if data.isEmpty { handle.readabilityHandler = nil }
                    run.append(data, isError: true)
                }
                process.terminationHandler = { process in
                    run.exited(status: process.terminationStatus)
                }

                do {
                    try process.run()
                } catch {
                    outputPipe.fileHandleForReading.readabilityHandler = nil
                    errorPipe.fileHandleForReading.readabilityHandler = nil
                    run.fail(error)
                    return
                }
                run.process = process
                if run.isFinished {
                    // Cancelled while launching.
                    terminate(process)
                    return
                }

                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                    guard run.fail(ProcessTimeoutError(timeout: timeout)) else { return }
                    terminate(process)
                }
            }
        } onCancel: {
            if run.fail(CancellationError()), let process = run.process {
                terminate(process)
            }
        }
    }

    private static func terminate(_ process: Process) {
        guard process.isRunning else { return }
        process.terminate()
        let pid = process.processIdentifier
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + terminationGracePeriod) {
            if process.isRunning {
                kill(pid, SIGKILL)
            }
        }
    }
}

struct ProcessTimeoutError: LocalizedError, Sendable {
    let timeout: TimeInterval

    var errorDescription: String? {
        let formattedTimeout = timeout == floor(timeout)
            ? "\(Int(timeout))"
            : String(format: "%.1f", timeout)
        return "SSH command timed out after \(formattedTimeout) seconds."
    }
}

private final class ProcessRun: @unchecked Sendable {
    private struct State {
        var output = Data()
        var error = Data()
        var outputClosed = false
        var errorClosed = false
        var exitStatus: Int32?
        var continuation: CheckedContinuation<ProcessOutput, Error>?
        var earlyFailure: Error?
        var finished = false
    }

    private let state = OSAllocatedUnfairLock<State>(uncheckedState: State())
    private let processLock = OSAllocatedUnfairLock<Process?>(uncheckedState: nil)

    var process: Process? {
        get { processLock.withLockUnchecked { $0 } }
        set { processLock.withLockUnchecked { $0 = newValue } }
    }

    var isFinished: Bool {
        state.withLockUnchecked { $0.finished }
    }

    /// Attaches the continuation. Returns false (after resuming it) if the run was
    /// already failed, e.g. cancelled before the process could start.
    func attach(_ continuation: CheckedContinuation<ProcessOutput, Error>) -> Bool {
        let earlyFailure = state.withLockUnchecked { state -> Error? in
            if state.finished { return state.earlyFailure ?? CancellationError() }
            state.continuation = continuation
            return nil
        }
        if let earlyFailure {
            continuation.resume(throwing: earlyFailure)
            return false
        }
        return true
    }

    func append(_ data: Data, isError: Bool) {
        finishIfReady {
            if data.isEmpty {
                if isError { $0.errorClosed = true } else { $0.outputClosed = true }
            } else if isError {
                $0.error.append(data)
            } else {
                $0.output.append(data)
            }
        }
    }

    func exited(status: Int32) {
        finishIfReady { $0.exitStatus = status }
    }

    /// Resumes with `error` unless the run already finished. Returns whether it did.
    @discardableResult
    func fail(_ error: Error) -> Bool {
        let result = state.withLockUnchecked { state -> (Bool, CheckedContinuation<ProcessOutput, Error>?) in
            guard !state.finished else { return (false, nil) }
            state.finished = true
            state.earlyFailure = error
            defer { state.continuation = nil }
            return (true, state.continuation)
        }
        result.1?.resume(throwing: error)
        return result.0
    }

    private func finishIfReady(_ update: (inout State) -> Void) {
        let completion = state.withLockUnchecked { state -> (CheckedContinuation<ProcessOutput, Error>, ProcessOutput)? in
            update(&state)
            guard
                !state.finished,
                let continuation = state.continuation,
                let exitStatus = state.exitStatus,
                state.outputClosed,
                state.errorClosed
            else {
                return nil
            }
            state.finished = true
            state.continuation = nil
            return (continuation, ProcessOutput(
                status: exitStatus,
                standardOutput: String(decoding: state.output, as: UTF8.self),
                standardError: String(decoding: state.error, as: UTF8.self)
            ))
        }
        if let (continuation, output) = completion {
            continuation.resume(returning: output)
        }
    }
}
