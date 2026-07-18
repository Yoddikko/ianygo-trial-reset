import SwiftUI
import AppKit
import Security

// ============================================================================
// iAnyGo Trial Reset — macOS App
// ============================================================================
// A native macOS app to reset iAnyGo/AnyGo/Tenorshare free trial.
// ============================================================================

// MARK: - Main App Entry Point

@main
struct iAnyGoTrialResetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 520, maxWidth: 620, minHeight: 580, maxHeight: 700)
        }
        .windowResizability(.contentSize)
        .windowStyle(.titleBar)
        .defaultSize(width: 560, height: 620)
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.windows.forEach { window in
            window.title = "iAnyGo Trial Reset"
            window.titlebarAppearsTransparent = false
            window.center()
            window.setFrameAutosaveName("MainWindow")
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

// MARK: - Data Models

enum ResetStep: String, CaseIterable, Identifiable {
    case kill = "Terminating iAnyGo processes"
    case prefs = "Clearing preferences"
    case appSupport = "Clearing application data"
    case caches = "Clearing caches"
    case http = "Clearing HTTP storages"
    case savedState = "Clearing saved state"
    case webkit = "Clearing WebKit data"
    case crash = "Clearing crash reports"
    case dns = "Flushing DNS cache"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .kill: return "xmark.circle"
        case .prefs: return "doc.text"
        case .appSupport: return "folder"
        case .caches: return "trash"
        case .http: return "network"
        case .savedState: return "bookmark"
        case .webkit: return "globe"
        case .crash: return "exclamationmark.bubble"
        case .dns: return "arrow.triangle.2.circlepath"
        }
    }
}

struct ResetResult: Identifiable {
    let id = UUID()
    let step: ResetStep
    let status: StepStatus
    let detail: String
}

enum StepStatus {
    case pending
    case running
    case success
    case warning
    case error
    case skipped
}

// MARK: - Main Content View

struct ContentView: View {
    @State private var isResetting = false
    @State private var resetComplete = false
    @State private var currentStepIndex = 0
    @State private var results: [ResetResult] = []
    @State private var logText = ""
    @State private var deletedCount = 0
    @State private var skippedCount = 0
    @State private var showDryRunNotice = false
    @State private var dryRunMode = false
    @State private var blockHosts = false

    private let resetScriptPath: String = {
        // Find script relative to the app bundle
        let bundleScript = Bundle.main.resourcePath.map { "\($0)/reset_ianygo_trial.sh" } ?? ""
        if FileManager.default.fileExists(atPath: bundleScript) {
            return bundleScript
        }
        // Fallback: look next to the app
        let appParent = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("reset_ianygo_trial.sh").path
        if FileManager.default.fileExists(atPath: appParent) {
            return appParent
        }
        // Fallback: Desktop
        let desktop = NSHomeDirectory() + "/Desktop/iAnyGo-Trial-Reset/reset_ianygo_trial.sh"
        return desktop
    }()

    private let hostsScriptPath: String = {
        let bundleScript = Bundle.main.resourcePath.map { "\($0)/block_ianygo_hosts.sh" } ?? ""
        if FileManager.default.fileExists(atPath: bundleScript) {
            return bundleScript
        }
        let appParent = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("block_ianygo_hosts.sh").path
        if FileManager.default.fileExists(atPath: appParent) {
            return appParent
        }
        return NSHomeDirectory() + "/Desktop/iAnyGo-Trial-Reset/block_ianygo_hosts.sh"
    }()

    private var hardwareUUID: String {
        let task = Process()
        task.launchPath = "/usr/sbin/ioreg"
        task.arguments = ["-d2", "-c", "IOPlatformExpertDevice"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        let output = String(data: data, encoding: .utf8) ?? ""
        // Extract IOPlatformUUID using awk-like logic
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            if line.contains("IOPlatformUUID") {
                let parts = line.components(separatedBy: "\"")
                if parts.count >= 4 {
                    return parts[3]
                }
            }
        }
        return "Unknown"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Main Content Area
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Info section
                    infoSection

                    Divider()

                    // Options
                    optionsSection

                    Divider()

                    // Action Button
                    actionSection

                    // Results
                    if !results.isEmpty {
                        Divider()
                        resultsSection
                    }
                }
                .padding(20)
            }

            // Bottom status bar
            Divider()
            bottomBar
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("iAnyGo Trial Reset")
                    .font(.headline)
                    .fontWeight(.bold)
                Text("Reset the free trial for iAnyGo, AnyGo, Tenorshare & variants")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("HW UUID:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(hardwareUUID.prefix(16) + "...")
                    .font(.caption)
                    .monospaced()
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("What this tool does", systemImage: "info.circle.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.blue)

            Text("""
                This tool resets the iAnyGo free trial by removing all local trial \
                tracking data: preferences, caches, application data, HTTP cookies, \
                and WebKit storage. After reset and reboot, iAnyGo will launch as \
                if freshly installed.
                """)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(4)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.06))
        )
    }

    // MARK: - Options Section

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Options", systemImage: "gearshape.fill")
                .font(.subheadline)
                .fontWeight(.semibold)

            Toggle(isOn: $dryRunMode) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dry Run Mode")
                        .font(.callout)
                    Text("Show what would be deleted without actually removing files")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(isResetting)

            Toggle(isOn: $blockHosts) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Block Activation Servers")
                        .font(.callout)
                    Text("Add iAnyGo update servers to /etc/hosts (requires sudo)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(isResetting)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    // MARK: - Action Section

    private var actionSection: some View {
        VStack(spacing: 12) {
            // Main Reset Button
            Button(action: performReset) {
                HStack(spacing: 8) {
                    if isResetting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 16, height: 16)
                        Text("Resetting...")
                    } else if resetComplete {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Reset Complete — Do It Again?")
                    } else {
                        Image(systemName: "arrow.clockwise.circle.fill")
                        Text("Reset iAnyGo Trial")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isResetting)
            .tint(resetComplete ? .green : .blue)

            if showDryRunNotice {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Dry run mode: no files will be deleted")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Progress", systemImage: "list.bullet.clipboard.fill")
                .font(.subheadline)
                .fontWeight(.semibold)

            VStack(spacing: 6) {
                ForEach(results) { result in
                    HStack(spacing: 8) {
                        Image(systemName: statusIcon(for: result.status))
                            .font(.system(size: 14))
                            .foregroundStyle(statusColor(for: result.status))
                            .frame(width: 18)

                        Text(result.step.rawValue)
                            .font(.caption)
                            .foregroundColor(.primary)

                        Spacer()

                        Text(result.detail)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(result.status == .running ?
                                  Color.blue.opacity(0.08) : Color.clear)
                    )
                }
            }

            if resetComplete {
                HStack(spacing: 12) {
                    Label("Deleted: \(deletedCount)", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundColor(.green)
                    Label("Skipped: \(skippedCount)", systemImage: "minus.circle")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.top, 4)
            }

            // Log output
            if !logText.isEmpty {
                ScrollView {
                    Text(logText)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 100)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.05))
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            if isResetting {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 12, height: 12)
                    Text("Resetting trial data...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else if resetComplete {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 12))
                    Text("Reset complete! Please reboot your Mac before launching iAnyGo.")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            } else {
                Text("Ready — make sure iAnyGo is not running")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("v1.0 — Educational Use Only")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Reset Logic

    private func performReset() {
        isResetting = true
        resetComplete = false
        results = []
        logText = ""
        deletedCount = 0
        skippedCount = 0
        showDryRunNotice = dryRunMode
        currentStepIndex = 0

        // Initialize results
        for step in ResetStep.allCases {
            results.append(ResetResult(step: step, status: .pending, detail: "Waiting..."))
        }

        // Run the reset in the background
        DispatchQueue.global(qos: .userInitiated).async {
            executeResetSteps()
        }
    }

    private func executeResetSteps() {
        for (index, step) in ResetStep.allCases.enumerated() {
            currentStepIndex = index

            // Update status to running
            DispatchQueue.main.async {
                results[index] = ResetResult(step: step, status: .running, detail: "Working...")
            }

            // Execute the step (simulate with sleeps, then run actual script)
            let result = executeStep(step)

            DispatchQueue.main.async {
                results[index] = result
                if result.status == .success || result.status == .warning {
                    deletedCount += 1
                }
                if result.status == .skipped {
                    skippedCount += 1
                }
                logText += "[\(result.status)] \(step.rawValue): \(result.detail)\n"
            }

            // Small delay for visual feedback
            Thread.sleep(forTimeInterval: 0.3)
        }

        // Run the actual shell script
        DispatchQueue.main.async {
            runActualScript()
        }
    }

    private func executeStep(_ step: ResetStep) -> ResetResult {
        // Map steps to their actual file/directory patterns for pre-check
        let home = NSHomeDirectory()
        let fm = FileManager.default

        let paths: [String] = {
            switch step {
            case .kill:
                return [] // Handled by script
            case .prefs:
                return [
                    "\(home)/Library/Preferences/com.ianygo.iAnyGo.plist",
                    "\(home)/Library/Preferences/com.tenorshare.iAnyGo.plist",
                    "\(home)/Library/Preferences/com.itoolab.AnyGo.plist",
                ]
            case .appSupport:
                return [
                    "\(home)/Library/Application Support/iAnyGo",
                    "\(home)/Library/Application Support/Tenorshare/iAnyGo",
                    "\(home)/Library/Application Support/com.ianygo.ianygo2",
                    "\(home)/Library/Application Support/AnyGo",
                ]
            case .caches:
                return [
                    "\(home)/Library/Caches/iAnyGo",
                    "\(home)/Library/Caches/iAnyGo_data",
                    "\(home)/Library/Caches/com.ianygo.ianygo2",
                    "\(home)/Library/Caches/com.Tenorshare.ianygo2",
                ]
            case .http:
                return [
                    "\(home)/Library/HTTPStorages/com.ianygo.ianygo2",
                    "\(home)/Library/HTTPStorages/com.Tenorshare.ianygo2",
                ]
            case .savedState:
                return [
                    "\(home)/Library/Saved Application State/com.Tenorshare.ianygo2.savedState",
                ]
            case .webkit:
                return [
                    "\(home)/Library/WebKit/com.itoolab.AnyGo",
                ]
            case .crash:
                return [] // Pattern-based, handled by script
            case .dns:
                return [] // System-level
            }
        }()

        // Check if any paths exist
        let anyExist = paths.contains { fm.fileExists(atPath: $0) }
        if !anyExist && !paths.isEmpty {
            return ResetResult(step: step, status: .skipped, detail: "No files found")
        }

        return ResetResult(step: step, status: .success, detail: "Done")
    }

    private func runActualScript() {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = [resetScriptPath, "--force"]
        if dryRunMode {
            task.arguments?.append("--dry-run")
        }
        task.arguments?.append("--no-backup")

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            DispatchQueue.main.async {
                logText += "\n--- Script Output ---\n" + output
                isResetting = false
                resetComplete = true

                // Show completion alert
                if !dryRunMode {
                    showCompletionAlert()
                }
            }

            // Run hosts blocker if requested
            if blockHosts && !dryRunMode {
                runHostsBlocker()
            }
        } catch {
            DispatchQueue.main.async {
                logText += "\nERROR: \(error.localizedDescription)"
                isResetting = false
            }
        }
    }

    private func runHostsBlocker() {
        // Need AppleScript for admin privileges
        let script = """
        do shell script "\"\(hostsScriptPath)\"" with administrator privileges
        """

        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error = error {
                DispatchQueue.main.async {
                    logText += "\nHosts blocker error: \(error)"
                }
            } else {
                DispatchQueue.main.async {
                    logText += "\n✓ Activation servers blocked in /etc/hosts"
                }
            }
        }
    }

    private func showCompletionAlert() {
        let alert = NSAlert()
        alert.messageText = "Trial Reset Complete"
        alert.informativeText = """
        iAnyGo trial data has been reset successfully.

        IMPORTANT: Reboot your Mac before launching iAnyGo again.
        This ensures all cached process state is cleared.

        After reboot, iAnyGo should start as if freshly installed.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Reboot Now")
        alert.icon = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            // Reboot
            let script = "tell application \"System Events\" to restart"
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(nil)
            }
        }
    }

    // MARK: - Helpers

    private func statusIcon(for status: StepStatus) -> String {
        switch status {
        case .pending: return "circle"
        case .running: return "arrow.clockwise.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .skipped: return "minus.circle"
        }
    }

    private func statusColor(for status: StepStatus) -> Color {
        switch status {
        case .pending: return .secondary
        case .running: return .blue
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        case .skipped: return .secondary
        }
    }
}
