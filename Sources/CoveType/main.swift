import AppKit
import ApplicationServices
@preconcurrency import AVFoundation
import Combine
import Darwin
import Foundation
import QuartzCore
import SwiftUI
@preconcurrency import Translation

// MARK: - Localization Helper

/// Returns `zh` when the system's first preferred language is Chinese, otherwise `en`.
func L(_ en: String, _ zh: String) -> String {
    Locale.preferredLanguages.first.map { $0.hasPrefix("zh") } == true ? zh : en
}

// MARK: - Hotkey Configuration

enum HotkeyModifier: String, Codable, CaseIterable {
    case leftControl  = "LeftControl"
    case rightControl = "RightControl"
    case leftOption   = "LeftOption"
    case rightOption  = "RightOption"
    case leftCommand  = "LeftCommand"
    case rightCommand = "RightCommand"
    case leftShift    = "LeftShift"
    case rightShift   = "RightShift"

    var symbol: String {
        switch self {
        case .leftControl,  .rightControl: "⌃"
        case .leftOption,   .rightOption:  "⌥"
        case .leftCommand,  .rightCommand: "⌘"
        case .leftShift,    .rightShift:   "⇧"
        }
    }

    var label: String {
        switch self {
        case .leftControl:  L("⌃ Left Control",  "⌃ 左 Control")
        case .rightControl: L("⌃ Right Control", "⌃ 右 Control")
        case .leftOption:   L("⌥ Left Option",   "⌥ 左 Option")
        case .rightOption:  L("⌥ Right Option",  "⌥ 右 Option")
        case .leftCommand:  L("⌘ Left Command",  "⌘ 左 Command")
        case .rightCommand: L("⌘ Right Command", "⌘ 右 Command")
        case .leftShift:    L("⇧ Left Shift",    "⇧ 左 Shift")
        case .rightShift:   L("⇧ Right Shift",   "⇧ 右 Shift")
        }
    }

    var flag: NSEvent.ModifierFlags {
        switch self {
        case .leftControl,  .rightControl: .control
        case .leftOption,   .rightOption:  .option
        case .leftCommand,  .rightCommand: .command
        case .leftShift,    .rightShift:   .shift
        }
    }

    var keyCode: UInt16 {
        switch self {
        case .leftControl:  59
        case .rightControl: 62
        case .leftOption:   58
        case .rightOption:  61
        case .leftCommand:  55
        case .rightCommand: 54
        case .leftShift:    56
        case .rightShift:   60
        }
    }

}

enum TriggerMode: String, Codable, CaseIterable {
    case holdToTalk = "HoldToTalk"
    case singleTap = "SingleTap"
    case doubleTap = "DoubleTap"

    var label: String {
        switch self {
        case .holdToTalk: L("Hold to Talk", "按住说话")
        case .singleTap: L("1× Single Tap", "1× 单击")
        case .doubleTap: L("2× Double Tap", "2× 双击")
        }
    }
}

struct CustomShortcutBinding: Codable, Equatable {
    let keyCode: UInt16
    let modifierFlagsRaw: UInt
    let modifierOnly: Bool
    let displayName: String

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlagsRaw)
            .intersection(.deviceIndependentFlagsMask)
    }
}

enum PolishMode: String, Codable, CaseIterable {
    case off = "Off"
    case light = "Light"
    case formal = "Formal"
    case concise = "Concise"

    var label: String {
        switch self {
        case .off: L("Off (Raw Transcript)", "关闭（原始转录）")
        case .light: L("Light · Recommended", "轻度 · 推荐")
        case .formal: L("Formal", "正式")
        case .concise: L("Concise", "精简")
        }
    }
}

enum TranslationTarget: String, Codable, CaseIterable {
    case off = "Off"
    case english = "English"
    case simplifiedChinese = "Simplified Chinese"
    case traditionalChinese = "Traditional Chinese"
    case japanese = "Japanese"
    case korean = "Korean"
    case french = "French"
    case german = "German"
    case spanish = "Spanish"
    case portuguese = "Portuguese"
    case russian = "Russian"
    case arabic = "Arabic"
    case italian = "Italian"
    case hindi = "Hindi"
    case thai = "Thai"
    case vietnamese = "Vietnamese"

    var label: String {
        switch self {
        case .off: L("Off · Keep original language", "关闭 · 保持原语言")
        case .english: L("English", "英语")
        case .simplifiedChinese: L("Simplified Chinese", "简体中文")
        case .traditionalChinese: L("Traditional Chinese", "繁体中文")
        case .japanese: L("Japanese", "日语")
        case .korean: L("Korean", "韩语")
        case .french: L("French", "法语")
        case .german: L("German", "德语")
        case .spanish: L("Spanish", "西班牙语")
        case .portuguese: L("Portuguese", "葡萄牙语")
        case .russian: L("Russian", "俄语")
        case .arabic: L("Arabic", "阿拉伯语")
        case .italian: L("Italian", "意大利语")
        case .hindi: L("Hindi", "印地语")
        case .thai: L("Thai", "泰语")
        case .vietnamese: L("Vietnamese", "越南语")
        }
    }

    var localeIdentifier: String? {
        switch self {
        case .off: nil
        case .english: "en"
        case .simplifiedChinese: "zh-Hans"
        case .traditionalChinese: "zh-Hant"
        case .japanese: "ja"
        case .korean: "ko"
        case .french: "fr"
        case .german: "de"
        case .spanish: "es"
        case .portuguese: "pt"
        case .russian: "ru"
        case .arabic: "ar"
        case .italian: "it"
        case .hindi: "hi"
        case .thai: "th"
        case .vietnamese: "vi"
        }
    }
}

enum MicrophoneSelection: Equatable {
    case automatic
    case specific(String)

    init(storedValue: String?) {
        if let storedValue, !storedValue.isEmpty {
            self = .specific(storedValue)
        } else {
            self = .automatic
        }
    }

    var uniqueID: String? {
        switch self {
        case .automatic: nil
        case .specific(let uniqueID): uniqueID
        }
    }
}

struct MicrophoneOption: Equatable {
    let uniqueID: String
    let localizedName: String
}

extension UserDefaults {
    private static let modifierKey   = "ai.covetype.app.hotkeyModifier"
    private static let triggerKey    = "ai.covetype.app.triggerMode"
    private static let microphoneKey = "ai.covetype.app.microphone"
    private static let polishModeKey = "ai.covetype.app.polishMode"
    private static let translationTargetKey = "ai.covetype.app.translationTarget"
    private static let customShortcutKey = "ai.covetype.app.customShortcut"
    private static let shortcutHoldDurationKey = "ai.covetype.app.shortcutHoldDuration"

    var hotkeyModifier: HotkeyModifier {
        get {
            guard let raw = string(forKey: Self.modifierKey),
                  let v = HotkeyModifier(rawValue: raw) else { return .leftControl }
            return v
        }
        set { set(newValue.rawValue, forKey: Self.modifierKey) }
    }

    var triggerMode: TriggerMode {
        get {
            guard let raw = string(forKey: Self.triggerKey),
                  let v = TriggerMode(rawValue: raw) else { return .holdToTalk }
            return v
        }
        set { set(newValue.rawValue, forKey: Self.triggerKey) }
    }

    var microphoneSelection: MicrophoneSelection {
        get { MicrophoneSelection(storedValue: string(forKey: Self.microphoneKey)) }
        set {
            if let storedValue = newValue.uniqueID {
                set(storedValue, forKey: Self.microphoneKey)
            } else {
                removeObject(forKey: Self.microphoneKey)
            }
        }
    }

    var polishMode: PolishMode {
        get {
            guard let raw = string(forKey: Self.polishModeKey),
                  let value = PolishMode(rawValue: raw) else { return .light }
            return value
        }
        set { set(newValue.rawValue, forKey: Self.polishModeKey) }
    }

    var translationTarget: TranslationTarget {
        get {
            guard let raw = string(forKey: Self.translationTargetKey),
                  let value = TranslationTarget(rawValue: raw) else { return .off }
            return value
        }
        set { set(newValue.rawValue, forKey: Self.translationTargetKey) }
    }

    var customShortcutBinding: CustomShortcutBinding? {
        get {
            guard let data = data(forKey: Self.customShortcutKey) else { return nil }
            return try? JSONDecoder().decode(CustomShortcutBinding.self, from: data)
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                set(data, forKey: Self.customShortcutKey)
            } else {
                removeObject(forKey: Self.customShortcutKey)
            }
        }
    }

    var shortcutHoldDuration: TimeInterval {
        get {
            guard object(forKey: Self.shortcutHoldDurationKey) != nil else { return 0.32 }
            return min(max(double(forKey: Self.shortcutHoldDurationKey), 0.10), 1.50)
        }
        set { set(min(max(newValue, 0.10), 1.50), forKey: Self.shortcutHoldDurationKey) }
    }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension Notification.Name {
    static let hotkeyConfigChanged = Notification.Name("ai.covetype.app.hotkeyConfigChanged")
}

// MARK: - On-device System Translation

@MainActor
final class SystemTranslationBridge: ObservableObject {
    struct Request: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let targetLocaleIdentifier: String
    }

    @Published fileprivate var request: Request?
    private var continuation: CheckedContinuation<String, Error>?

    func translate(text: String, targetLocaleIdentifier: String) async throws -> String {
        guard #available(macOS 15.0, *) else {
            throw CoveTypeError.translationUnavailable(
                L("On-device translation requires macOS 15 or later", "设备端翻译需要 macOS 15 或更高版本")
            )
        }

        cancel()
        let newRequest = Request(text: text, targetLocaleIdentifier: targetLocaleIdentifier)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                request = newRequest
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancel(requestID: newRequest.id)
            }
        }
    }

    func cancel() {
        guard let request else { return }
        cancel(requestID: request.id)
    }

    private func cancel(requestID: UUID) {
        complete(requestID: requestID, result: .failure(CancellationError()))
    }

    fileprivate func complete(requestID: UUID, result: Result<String, Error>) {
        guard request?.id == requestID else { return }
        let pendingContinuation = continuation
        continuation = nil
        request = nil
        pendingContinuation?.resume(with: result)
    }
}


@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private var statusItemController: StatusItemController?
    private var hotkeyMonitor: HotkeyMonitor?
    private var overlayController: OverlayPanelController?
    private var permissionsGranted = false
    private var pollTimer: Timer?
    private let updateService = UpdateService()
    private let telemetryService = TelemetryService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AudioRecorder.removeAbandonedTemporaryRecordings()

        overlayController = OverlayPanelController(appState: appState)
        statusItemController = StatusItemController(appState: appState)
        hotkeyMonitor = HotkeyMonitor(
            onToggle: { [weak self] in self?.handleToggle() },
            onPress: { [weak self] in self?.handleHotkeyPress() },
            onRelease: { [weak self] in self?.handleHotkeyRelease() }
        )

        if CommandLine.arguments.contains("--open-shortcut-settings") {
            DispatchQueue.main.async { [weak self] in
                self?.statusItemController?.showShortcutSettings()
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(restartHotkeyMonitor),
            name: .hotkeyConfigChanged,
            object: nil
        )

        appState.onToggleRequest = { [weak self] in
            self?.handleToggle()
        }

        appState.onOverlayRequest = { [weak self] visible in
            if visible {
                self?.overlayController?.show()
            } else {
                self?.overlayController?.hide()
            }
        }

        appState.onPermissionOpen = { [weak self] kind in
            self?.openPermissionSettings(for: kind)
        }

        appState.onCancel = { [weak self] in
            self?.cancelFlow()
        }

        appState.onConfirm = { [weak self] in
            self?.appState.confirmInsert()
        }

        appState.onUpdateRequest = { [weak self] in
            self?.performUpdate()
        }

        // First-launch onboarding: request the two privacy permissions and keep
        // the in-app guide visible until macOS reports that both are enabled.
        let missingPermissions = PermissionManager.missingPermissions(
            requestMicrophoneIfNeeded: true,
            requestAccessibilityIfNeeded: true
        )
        permissionsGranted = missingPermissions.isEmpty
        PermissionManager.writeStatusSnapshot()
        if missingPermissions.isEmpty == false {
            appState.showPermissions(missingPermissions)
        }

        // Auto-poll permissions and update the onboarding panel immediately.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollStatus()
            }
        }

        hotkeyMonitor?.start()

        // Silent update check on launch
        Task {
            if let release = await updateService.checkForUpdate() {
                statusItemController?.setUpdateAvailable(release.version)
            }
        }

        // Anonymous usage statistics are independent from speech processing.
        // The service records the attempt before making one small HTTPS request,
        // which prevents retries from exceeding once in any 24-hour period.
        Task {
            try? await Task.sleep(for: .seconds(3))
            await telemetryService.sendHeartbeatIfNeeded()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        pollTimer?.invalidate()
        hotkeyMonitor?.stop()
        appState.shutdownLocalAI()
    }

    private func pollStatus() {
        PermissionManager.writeStatusSnapshot()
        switch appState.phase {
        case .permissions:
            let missing = PermissionManager.missingPermissions(requestMicrophoneIfNeeded: false)
            if missing.isEmpty {
                let hotkeyNeedsRestart = !permissionsGranted
                permissionsGranted = true
                appState.hidePermissions()
                // Recreate the global keyboard monitors as soon as Accessibility
                // permission arrives.
                if hotkeyNeedsRestart {
                    restartHotkeyMonitor()
                }
            } else {
                appState.showPermissions(missing)
            }
        case .missingColi:
            if ColiASRService.isInstalled {
                appState.hideColiGuidance()
            } else if ColiASRService.isNpmAvailable {
                // npm became available (user installed Node), trigger auto-install
                appState.autoInstallColi()
            }
        default:
            break
        }
    }

    private func handleToggle() {
        switch appState.phase {
        case .idle:
            startRecording()
        case .recording:
            stopRecording()
        case .done:
            appState.confirmInsert()
        case .transcribing, .error:
            appState.cancel()
        case .permissions, .missingColi, .installingColi, .updating:
            break
        }
    }

    private func handleHotkeyPress() {
        guard case .idle = appState.phase else { return }
        startRecording()
    }

    private func handleHotkeyRelease() {
        guard case .recording = appState.phase else { return }
        stopRecording()
    }

    @objc private func restartHotkeyMonitor() {
        hotkeyMonitor?.stop()
        hotkeyMonitor = HotkeyMonitor(
            onToggle: { [weak self] in self?.handleToggle() },
            onPress: { [weak self] in self?.handleHotkeyPress() },
            onRelease: { [weak self] in self?.handleHotkeyRelease() }
        )
        hotkeyMonitor?.start()
    }

    private func startRecording() {
        // Only check permissions if not previously granted this session
        if !permissionsGranted {
            let missing = PermissionManager.missingPermissions(requestMicrophoneIfNeeded: true, requestAccessibilityIfNeeded: true)
            if !missing.isEmpty {
                appState.showPermissions(missing)
                return
            }
            permissionsGranted = true
        }

        do {
            try appState.startRecording()
        } catch {
            appState.showError(error.localizedDescription)
        }
    }

    private func stopRecording() {
        Task { @MainActor in
            do {
                try await appState.stopRecording()
                await appState.transcribeAndInsert()
            } catch is CancellationError {
                // User canceled; keep app in reset state
            } catch {
                appState.showError(error.localizedDescription)
            }
        }
    }

    private func cancelFlow() {
        appState.cancel()
    }

    private func openPermissionSettings(for kind: PermissionKind) {
        PermissionManager.openPrivacySettings(for: [kind])
    }

    private func performUpdate() {
        Task {
            appState.phase = .updating(L("Checking for updates...", "检查更新..."))
            appState.onOverlayRequest?(true)

            switch await updateService.checkForUpdateDetailed() {
            case .upToDate:
                appState.phase = .updating(L("Already up to date", "已是最新版本"))
                try? await Task.sleep(for: .seconds(2))
                appState.phase = .idle
                appState.onOverlayRequest?(false)

            case .channelNotConfigured:
                appState.phase = .updating(L(
                    "Custom update channel is not published yet",
                    "定制版更新通道尚未发布"
                ))
                try? await Task.sleep(for: .seconds(2.5))
                appState.phase = .idle
                appState.onOverlayRequest?(false)

            case .failed:
                appState.showError(L("Could not check the custom update channel", "无法检查定制版更新通道"))

            case .updateAvailable(let release):
                appState.phase = .updating(L("v\(release.version) available", "v\(release.version) 可更新"))
                appState.onOverlayRequest?(true)
                try? await Task.sleep(for: .seconds(1.5))
                appState.phase = .idle
                appState.onOverlayRequest?(false)
                NSWorkspace.shared.open(release.releasePageURL)
            }
        }
    }
}

// MARK: - Model

enum PermissionKind: CaseIterable, Hashable {
    case microphone
    case accessibility

    var title: String {
        switch self {
        case .microphone: L("Microphone", "麦克风")
        case .accessibility: L("Accessibility", "辅助功能")
        }
    }

    var explanation: String {
        switch self {
        case .microphone: L("Required to capture your voice", "用于捕获语音")
        case .accessibility: L("Required to type text into apps", "用于向应用输入文字")
        }
    }

    var icon: String {
        switch self {
        case .microphone: "mic.fill"
        case .accessibility: "hand.raised.fill"
        }
    }
}

enum AppPhase: Equatable {
    case idle
    case recording
    case transcribing(String? = nil)
    case done(String)        // transcription result, waiting for user confirm
    case permissions(Set<PermissionKind>)
    case missingColi
    case installingColi(String) // progress message
    case updating(String)    // progress message
    case error(String)

    var subtitle: String {
        switch self {
        case .idle:
            return L("Hold Fn, Option, or Control to talk", "按住 Fn、Option 或 Control 说话")
        case .recording:
            return ""
        case .transcribing(let message):
            let trimmed = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? L("Transcribing...", "转录中...") : trimmed
        case .done(let text):
            return text
        case .permissions, .missingColi, .installingColi:
            return ""
        case .updating(let message):
            return message
        case .error(let message):
            return message
        }
    }
}

// MARK: - App State

@MainActor
final class AppState: ObservableObject {
    @Published var phase: AppPhase = .idle
    var transcript = ""

    var onOverlayRequest: ((Bool) -> Void)?
    var onPermissionOpen: ((PermissionKind) -> Void)?
    var onCancel: (() -> Void)?
    var onConfirm: (() -> Void)?
    var onToggleRequest: (() -> Void)?
    var onUpdateRequest: (() -> Void)?

    private let recorder = AudioRecorder()
    private let localAIService = LocalAIService()
    let systemTranslation = SystemTranslationBridge()
    private var currentRecordingURL: URL?
    private var previousApp: NSRunningApplication?
    private var recordingTimer: Timer?
    private var localAIKeepAliveTimer: Timer?
    @Published var recordingElapsedSeconds: Int = 0
    @Published var microphoneLevel: Double = 0

    var recordingElapsedStr: String {
        let m = recordingElapsedSeconds / 60
        let s = recordingElapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    func startRecording() throws {
        transcript = ""
        microphoneLevel = 0
        previousApp = NSWorkspace.shared.frontmostApplication
        let microphone = try MicrophoneManager.resolvedDevice(for: UserDefaults.standard.microphoneSelection)
        currentRecordingURL = try recorder.start(using: microphone) { [weak self] level in
            Task { @MainActor in
                self?.microphoneLevel = Double(level)
            }
        }
        beginLocalAIPrewarmIfNeeded()
        recordingElapsedSeconds = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.recordingElapsedSeconds += 1 }
        }
        phase = .recording
        onOverlayRequest?(true)
    }

    func stopRecording() async throws {
        localAIKeepAliveTimer?.invalidate()
        localAIKeepAliveTimer = nil
        recordingTimer?.invalidate()
        recordingTimer = nil
        transcript = ""
        phase = .transcribing(nil)
        onOverlayRequest?(true)

        let url = try await recorder.stop()
        currentRecordingURL = url
    }

    func cancel() {
        let targetApp = previousApp
        let shouldCancelLocalAI: Bool
        if case .recording = phase {
            shouldCancelLocalAI = true
        } else if case .transcribing = phase {
            shouldCancelLocalAI = true
        } else {
            shouldCancelLocalAI = false
        }
        recordingTimer?.invalidate()
        recordingTimer = nil
        localAIKeepAliveTimer?.invalidate()
        localAIKeepAliveTimer = nil
        recorder.cancel()
        if shouldCancelLocalAI {
            localAIService.cancelCurrentRequest()
        }
        systemTranslation.cancel()
        if let currentRecordingURL {
            try? FileManager.default.removeItem(at: currentRecordingURL)
        }
        currentRecordingURL = nil
        transcript = ""
        microphoneLevel = 0
        previousApp = nil
        phase = .idle
        onOverlayRequest?(false)
        if let targetApp {
            targetApp.activate()
        }
    }

    func showPermissions(_ missing: Set<PermissionKind>) {
        phase = .permissions(missing)
        onOverlayRequest?(true)
    }

    func hidePermissions() {
        phase = .idle
        onOverlayRequest?(false)
    }

    func showMissingColi() {
        // If npm is available, auto-install coli instead of showing manual guidance
        if ColiASRService.isNpmAvailable {
            autoInstallColi()
        } else {
            phase = .missingColi
            onOverlayRequest?(true)
        }
    }

    func autoInstallColi() {
        phase = .installingColi(L("Installing coli...", "安装中..."))
        onOverlayRequest?(true)

        Task {
            do {
                try await ColiASRService.installColi { [weak self] message in
                    self?.phase = .installingColi(message)
                }
                // Verify installation
                if ColiASRService.isInstalled {
                    phase = .installingColi(
                        L(
                            "Coli installed. The first transcription will download the speech model.",
                            "Coli 已安装。首次转录时会下载语音模型。"
                        )
                    )
                    try? await Task.sleep(for: .seconds(1.5))
                    phase = .idle
                    onOverlayRequest?(false)
                } else {
                    // Fallback to manual guidance
                    phase = .missingColi
                }
            } catch {
                showError("Install failed: \(error.localizedDescription)")
            }
        }
    }

    func hideColiGuidance() {
        if case .missingColi = phase {
            phase = .idle
            onOverlayRequest?(false)
        }
    }

    func showError(_ message: String) {
        removeCurrentRecordingFile()
        phase = .error(message)
        onOverlayRequest?(true)
    }

    func transcribeAndInsert() async {
        guard let url = currentRecordingURL else {
            showError("No recording")
            return
        }

        transcript = ""
        phase = .transcribing(L("Preparing local AI...", "正在准备本地 AI..."))

        do {
            transcript = try await makeFinalTranscript(fileURL: url)

            // Show result briefly, then auto-insert
            phase = .done(transcript)
            onOverlayRequest?(true)
            confirmInsert()
        } catch is CancellationError {
            // User canceled the current transcription with Esc.
        } catch CoveTypeError.coliNotInstalled {
            showMissingColi()
        } catch {
            showError(error.localizedDescription)
        }
    }

    func confirmInsert() {
        guard !transcript.isEmpty else {
            cancel()
            return
        }

        let text = transcript
        let targetApp = previousApp

        // Copy to clipboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        // Hide overlay
        onOverlayRequest?(false)

        // Activate previous app, then Cmd+V
        if let targetApp {
            targetApp.activate()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            let source = CGEventSource(stateID: .hidSystemState)
            let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
            let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            vDown?.flags = .maskCommand
            vUp?.flags = .maskCommand
            vDown?.post(tap: .cghidEventTap)
            vUp?.post(tap: .cghidEventTap)

            self?.resetState()
        }
    }

    private func resetState() {
        localAIKeepAliveTimer?.invalidate()
        localAIKeepAliveTimer = nil
        if let currentRecordingURL {
            try? FileManager.default.removeItem(at: currentRecordingURL)
        }
        currentRecordingURL = nil
        previousApp = nil
        transcript = ""
        microphoneLevel = 0
        phase = .idle
        onOverlayRequest?(false)
    }

    private func beginLocalAIPrewarmIfNeeded() {
        let loadASR = true
        let translationIsOff = UserDefaults.standard.translationTarget == .off
        let loadPolisher = translationIsOff && UserDefaults.standard.polishMode != .off
        guard loadASR || loadPolisher else { return }

        Task { [localAIService] in
            await localAIService.prewarm(loadASR: loadASR, loadPolisher: loadPolisher)
        }

        localAIKeepAliveTimer?.invalidate()
        localAIKeepAliveTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { [localAIService = self.localAIService] in
                await localAIService.keepAlive()
            }
        }
    }

    func shutdownLocalAI() {
        recorder.cancel()
        removeCurrentRecordingFile()
        systemTranslation.cancel()
        localAIService.shutdown()
    }

    private func removeCurrentRecordingFile() {
        if let currentRecordingURL {
            try? FileManager.default.removeItem(at: currentRecordingURL)
        }
        currentRecordingURL = nil
    }

    func releaseLocalAIMemory() async {
        await localAIService.releaseMemory()
    }

    private func makeFinalTranscript(fileURL: URL) async throws -> String {
        phase = .transcribing(L("Qwen3-ASR is recognizing locally...", "Qwen3-ASR 本地识别中..."))
        let rawText = try await localAIService.transcribe(fileURL: fileURL)

        let normalized = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else {
            throw CoveTypeError.emptyTranscript
        }

        let translationTarget = UserDefaults.standard.translationTarget
        if let targetLocaleIdentifier = translationTarget.localeIdentifier {
            phase = .transcribing(
                L(
                    "Translating on device to \(translationTarget.label)...",
                    "正在设备端翻译为\(translationTarget.label)..."
                )
            )
            return try await systemTranslation.translate(
                text: normalized,
                targetLocaleIdentifier: targetLocaleIdentifier
            )
        }

        let polishMode = UserDefaults.standard.polishMode
        guard polishMode != .off else { return normalized }

        phase = .transcribing(L("Qwen3.5 is polishing locally...", "Qwen3.5 本地润色中..."))
        do {
            return try await localAIService.polish(text: normalized, mode: polishMode)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // A rejected/failed rewrite must never block dictation. The worker
            // validates numbers, URLs and output length before it returns text.
            return normalized
        }
    }

    func transcribeFile(_ url: URL) async {
        previousApp = NSWorkspace.shared.frontmostApplication
        transcript = ""
        phase = .transcribing(L("Preparing local AI...", "正在准备本地 AI..."))
        onOverlayRequest?(true)

        do {
            transcript = try await makeFinalTranscript(fileURL: url)

            phase = .done(transcript)
            onOverlayRequest?(true)
            // Copy to clipboard (don't paste into another app)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(transcript, forType: .string)
            try? await Task.sleep(for: .seconds(2))
            resetState()
        } catch is CancellationError {
            // User canceled the current transcription with Esc.
        } catch CoveTypeError.coliNotInstalled {
            showMissingColi()
        } catch {
            showError(error.localizedDescription)
        }
    }
}

// MARK: - Errors

enum CoveTypeError: LocalizedError {
    case noRecording
    case emptyTranscript
    case coliNotInstalled
    case npmNotFound
    case coliInstallFailed(String)
    case transcriptionFailed(String)
    case localAIUnavailable(String)
    case localAIProtocolError(String)
    case translationUnavailable(String)
    case noMicrophoneAvailable
    case selectedMicrophoneUnavailable
    case couldNotUseMicrophone(String)
    case couldNotStartRecording

    var errorDescription: String? {
        switch self {
        case .noRecording: "No recording"
        case .emptyTranscript: "No speech detected"
        case .coliNotInstalled: "CoveType needs the local Coli engine. Install it with: npm install -g @marswave/coli"
        case .npmNotFound: "Node.js is required. Install it from https://nodejs.org"
        case .coliInstallFailed(let message): "Coli install failed: \(message)"
        case .transcriptionFailed(let message): message
        case .localAIUnavailable(let message): L("Local AI unavailable: \(message)", "本地 AI 不可用：\(message)")
        case .localAIProtocolError(let message): L("Local AI error: \(message)", "本地 AI 错误：\(message)")
        case .translationUnavailable(let message): L("Translation unavailable: \(message)", "翻译不可用：\(message)")
        case .noMicrophoneAvailable: L("No microphone available", "没有可用的麦克风")
        case .selectedMicrophoneUnavailable: L("The selected microphone is unavailable", "所选麦克风当前不可用")
        case .couldNotUseMicrophone(let name): L("Could not use microphone: \(name)", "无法使用麦克风：\(name)")
        case .couldNotStartRecording: L("Could not start recording", "无法开始录音")
        }
    }
}

// MARK: - Permission Manager

enum PermissionManager {
    private static var statusFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/CoveType", isDirectory: true)
            .appendingPathComponent("permission-status.json")
    }

    static func commandLineStatusJSON() -> (json: String, ready: Bool) {
        let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let microphoneLabel: String
        switch microphoneStatus {
        case .authorized: microphoneLabel = "authorized"
        case .denied: microphoneLabel = "denied"
        case .restricted: microphoneLabel = "restricted"
        case .notDetermined: microphoneLabel = "not_determined"
        @unknown default: microphoneLabel = "unknown"
        }

        let accessibility = AXIsProcessTrusted()
        let microphone = microphoneStatus == .authorized
        let ready = accessibility && microphone
        let payload: [String: Any] = [
            "accessibility": accessibility,
            "microphone": microphoneLabel,
            "microphone_authorized": microphone,
            "ready": ready
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return ("{\"ready\":false}", false)
        }
        return (json, ready)
    }

    static func writeStatusSnapshot() {
        let status = commandLineStatusJSON()
        let directory = statusFileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data(status.json.utf8).write(to: statusFileURL, options: .atomic)
        } catch {
            // Permission display remains functional even if the diagnostic
            // snapshot cannot be written.
        }
    }

    static func cachedOrCurrentStatusJSON() -> (json: String, ready: Bool) {
        if let values = try? statusFileURL.resourceValues(forKeys: [.contentModificationDateKey]),
           let modified = values.contentModificationDate,
           Date().timeIntervalSince(modified) < 5,
           let data = try? Data(contentsOf: statusFileURL),
           let json = String(data: data, encoding: .utf8) {
            return (json, json.contains("\"ready\":true"))
        }
        return commandLineStatusJSON()
    }

    static func missingPermissions(requestMicrophoneIfNeeded: Bool, requestAccessibilityIfNeeded: Bool = false) -> Set<PermissionKind> {
        var missing = Set<PermissionKind>()

        switch microphoneStatus(requestIfNeeded: requestMicrophoneIfNeeded) {
        case .authorized:
            break
        default:
            missing.insert(.microphone)
        }

        if !accessibilityStatus(requestIfNeeded: requestAccessibilityIfNeeded) {
            missing.insert(.accessibility)
        }

        return missing
    }

    static func microphoneStatus(requestIfNeeded: Bool) -> AVAuthorizationStatus {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .notDetermined, requestIfNeeded {
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
        }
        return status
    }

    static func accessibilityStatus(requestIfNeeded: Bool) -> Bool {
        guard requestIfNeeded else {
            return AXIsProcessTrusted()
        }
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openPrivacySettings(for permissions: Set<PermissionKind>) {
        let urlString: String
        if permissions.contains(.accessibility) {
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        } else if permissions.contains(.microphone) {
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        } else {
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy"
        }

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Microphone Manager

enum MicrophoneManager {
    private static let deviceTypes: [AVCaptureDevice.DeviceType] = [.microphone, .external]

    static func availableMicrophones() -> [MicrophoneOption] {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .audio,
            position: .unspecified
        )

        var seen = Set<String>()
        return session.devices
            .filter { seen.insert($0.uniqueID).inserted }
            .sorted { lhs, rhs in
                lhs.localizedName.localizedStandardCompare(rhs.localizedName) == .orderedAscending
            }
            .map { device in
                MicrophoneOption(uniqueID: device.uniqueID, localizedName: device.localizedName)
            }
    }

    static func resolvedDevice(for selection: MicrophoneSelection) throws -> AVCaptureDevice {
        switch selection {
        case .automatic:
            if let device = AVCaptureDevice.default(for: .audio) {
                return device
            }
            guard let fallback = availableMicrophones().first.flatMap({ AVCaptureDevice(uniqueID: $0.uniqueID) }) else {
                throw CoveTypeError.noMicrophoneAvailable
            }
            return fallback

        case .specific(let uniqueID):
            guard let device = AVCaptureDevice(uniqueID: uniqueID) else {
                throw CoveTypeError.selectedMicrophoneUnavailable
            }
            return device
        }
    }
}

// MARK: - Audio Recorder

@MainActor
final class AudioRecorder: NSObject, AVCaptureFileOutputRecordingDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    private final class RecordingContext: @unchecked Sendable {
        let session: AVCaptureSession
        let output: AVCaptureAudioFileOutput
        let dataOutput: AVCaptureAudioDataOutput?
        let recordingURL: URL
        let levelHandler: (@Sendable (Float) -> Void)?
        let audioDataQueue = DispatchQueue(label: "ai.covetype.app.recorder.audio-data")
        var stopContinuation: CheckedContinuation<URL, Error>?
        var discardRecordingOnFinish = false
        var lastLevelEmissionTime: TimeInterval = 0

        init(
            session: AVCaptureSession,
            output: AVCaptureAudioFileOutput,
            dataOutput: AVCaptureAudioDataOutput?,
            recordingURL: URL,
            levelHandler: (@Sendable (Float) -> Void)?
        ) {
            self.session = session
            self.output = output
            self.dataOutput = dataOutput
            self.recordingURL = recordingURL
            self.levelHandler = levelHandler
        }
    }

    private var activeContexts: [ObjectIdentifier: RecordingContext] = [:]
    private var currentRecordingID: ObjectIdentifier?
    /// Lock-protected map for audio data delegate callbacks (called on background queue).
    private let audioContextLock = NSLock()
    private nonisolated(unsafe) var audioDataContexts: [ObjectIdentifier: RecordingContext] = [:]

    static func removeAbandonedTemporaryRecordings(
        in directory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("CoveType", isDirectory: true)
    ) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }
        for file in files where ["m4a", "wav"].contains(file.pathExtension.lowercased()) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    static func runAudioPipelineSelfTest() -> Bool {
        guard AVCaptureAudioFileOutput.availableOutputFileTypes().contains(.wav) else { return false }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CoveTypeAudioSelfTest-\(UUID().uuidString)", isDirectory: true)
        let abandonedM4A = directory.appendingPathComponent("abandoned.m4a")
        let abandonedWAV = directory.appendingPathComponent("abandoned.wav")
        let unrelatedFile = directory.appendingPathComponent("keep.txt")
        defer { try? FileManager.default.removeItem(at: directory) }

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data("test".utf8).write(to: abandonedM4A)
            try Data("test".utf8).write(to: abandonedWAV)
            try Data("keep".utf8).write(to: unrelatedFile)
            removeAbandonedTemporaryRecordings(in: directory)
            return FileManager.default.fileExists(atPath: abandonedM4A.path) == false
                && FileManager.default.fileExists(atPath: abandonedWAV.path) == false
                && FileManager.default.fileExists(atPath: unrelatedFile.path)
        } catch {
            return false
        }
    }

    func start(
        using microphone: AVCaptureDevice,
        levelHandler: (@Sendable (Float) -> Void)? = nil
    ) throws -> URL {
        guard currentRecordingID == nil else {
            throw CoveTypeError.couldNotStartRecording
        }

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("CoveType", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // WAV is decoded directly by mlx-audio's bundled miniaudio path. Using
        // M4A here would require an external ffmpeg binary, which Finder and
        // login-item launches cannot reliably discover in the user's shell PATH.
        let url = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("wav")
        let session = AVCaptureSession()
        let output = AVCaptureAudioFileOutput()
        let dataOutput: AVCaptureAudioDataOutput? = levelHandler == nil ? nil : AVCaptureAudioDataOutput()

        do {
            session.beginConfiguration()
            defer { session.commitConfiguration() }

            let input = try AVCaptureDeviceInput(device: microphone)
            guard session.canAddInput(input) else {
                throw CoveTypeError.couldNotUseMicrophone(microphone.localizedName)
            }
            session.addInput(input)

            guard session.canAddOutput(output) else {
                throw CoveTypeError.couldNotStartRecording
            }
            session.addOutput(output)

            if let dataOutput {
                guard session.canAddOutput(dataOutput) else {
                    throw CoveTypeError.couldNotStartRecording
                }
                session.addOutput(dataOutput)
            }
        }

        let context = RecordingContext(
            session: session,
            output: output,
            dataOutput: dataOutput,
            recordingURL: url,
            levelHandler: levelHandler
        )
        if let dataOutput {
            dataOutput.audioSettings = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsNonInterleaved: false,
                AVLinearPCMIsBigEndianKey: false
            ]
            dataOutput.setSampleBufferDelegate(self, queue: context.audioDataQueue)
        }

        let contextID = ObjectIdentifier(output)
        activeContexts[contextID] = context
        currentRecordingID = contextID

        if let dataOutput {
            let dataOutputID = ObjectIdentifier(dataOutput)
            audioContextLock.lock()
            audioDataContexts[dataOutputID] = context
            audioContextLock.unlock()
        }

        session.startRunning()

        // Wait for AVCaptureSession to stabilize audio format before recording.
        // Without this, the AAC encoder may initialize with 0 Hz sample rate when
        // the session is still negotiating the hardware format (especially during
        // device switching or with external mics), producing empty recordings.
        // See: https://github.com/marswaveai/TypeNo/issues/43
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < 1.0 {
            if let connection = output.connections.first,
               let _ = connection.audioChannels.first,
               connection.isActive {
                break
            }
            Thread.sleep(forTimeInterval: 0.01)
        }

        output.startRecording(to: url, outputFileType: .wav, recordingDelegate: self)
        return url
    }

    func stop() async throws -> URL {
        guard let contextID = currentRecordingID,
              let context = activeContexts[contextID] else {
            throw CoveTypeError.noRecording
        }
        guard context.output.isRecording else {
            tearDownCapturePipeline(for: context)
            activeContexts.removeValue(forKey: contextID)
            currentRecordingID = nil
            return context.recordingURL
        }

        return try await withCheckedThrowingContinuation { continuation in
            context.stopContinuation = continuation
            context.output.stopRecording()
        }
    }

    func cancel() {
        guard let contextID = currentRecordingID,
              let context = activeContexts[contextID] else {
            return
        }

        currentRecordingID = nil
        finishStop(for: contextID, with: .failure(CancellationError()))

        let wasRecording = context.output.isRecording
        context.discardRecordingOnFinish = true
        context.output.stopRecording()
        if !wasRecording {
            tearDownCapturePipeline(for: context)
            try? FileManager.default.removeItem(at: context.recordingURL)
            activeContexts.removeValue(forKey: contextID)
        }
    }

    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {}

    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: (any Error)?) {
        let contextID = ObjectIdentifier(output)
        Task { @MainActor in
            guard let context = activeContexts[contextID] else { return }

            defer {
                if context.discardRecordingOnFinish, let outputURL = outputFileURL as URL? {
                    try? FileManager.default.removeItem(at: outputURL)
                }
                tearDownCapturePipeline(for: context)
                activeContexts.removeValue(forKey: contextID)
                if currentRecordingID == contextID {
                    currentRecordingID = nil
                }
            }

            if let error {
                finishStop(for: contextID, with: .failure(error))
            } else {
                finishStop(for: contextID, with: .success(context.recordingURL))
            }
        }
    }

    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        audioContextLock.lock()
        let context = audioDataContexts[ObjectIdentifier(output)]
        audioContextLock.unlock()
        if context == nil {
            return
        }
        guard let context, let levelHandler = context.levelHandler else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - context.lastLevelEmissionTime >= 1.0 / 24.0 else { return }
        context.lastLevelEmissionTime = now
        guard let level = Self.normalizedAudioLevel(from: sampleBuffer) else { return }
        levelHandler(level)
    }

    private func tearDownCapturePipeline(for context: RecordingContext) {
        if let dataOutput = context.dataOutput {
            let dataOutputID = ObjectIdentifier(dataOutput)
            audioContextLock.lock()
            audioDataContexts.removeValue(forKey: dataOutputID)
            audioContextLock.unlock()
            dataOutput.setSampleBufferDelegate(nil, queue: nil)
        }
        if context.session.isRunning {
            context.session.stopRunning()
        }
        context.session.inputs.forEach { context.session.removeInput($0) }
        context.session.outputs.forEach { context.session.removeOutput($0) }
    }

    private func finishStop(for contextID: ObjectIdentifier, with result: Result<URL, Error>) {
        guard let context = activeContexts[contextID],
              let stopContinuation = context.stopContinuation else { return }
        context.stopContinuation = nil
        switch result {
        case .success(let url): stopContinuation.resume(returning: url)
        case .failure(let err): stopContinuation.resume(throwing: err)
        }
    }

    private nonisolated static func normalizedAudioLevel(from sampleBuffer: CMSampleBuffer) -> Float? {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return nil }
        let byteCount = CMBlockBufferGetDataLength(blockBuffer)
        guard byteCount >= MemoryLayout<Float>.size else { return nil }

        var samples = [Float](repeating: 0, count: byteCount / MemoryLayout<Float>.size)
        let status = samples.withUnsafeMutableBytes { bytes in
            CMBlockBufferCopyDataBytes(
                blockBuffer,
                atOffset: 0,
                dataLength: min(byteCount, bytes.count),
                destination: bytes.baseAddress!
            )
        }
        guard status == kCMBlockBufferNoErr, samples.isEmpty == false else { return nil }

        var squareSum: Float = 0
        for sample in samples {
            let clamped = min(max(sample, -1), 1)
            squareSum += clamped * clamped
        }
        let rms = sqrt(squareSum / Float(samples.count))
        let decibels = 20 * log10(max(rms, 0.000_001))
        // -52 dB is near silence; -7 dB and above maps to a full waveform.
        return min(max((decibels + 52) / 45, 0), 1)
    }
}

// MARK: - Persistent Local AI Service

private struct LocalAIRequest: Encodable, Sendable {
    let id: String
    let action: String
    var audioPath: String?
    var language: String?
    var text: String?
    var mode: String?
    var loadASR: Bool?
    var loadPolisher: Bool?

    enum CodingKeys: String, CodingKey {
        case id, action, language, text, mode
        case audioPath = "audio_path"
        case loadASR = "load_asr"
        case loadPolisher = "load_polisher"
    }
}

private struct LocalAIResponse: Decodable, Sendable {
    let id: String?
    let ok: Bool?
    let ready: Bool?
    let text: String?
    let error: String?
}

final class LocalAIService: @unchecked Sendable {
    private let ioQueue = DispatchQueue(label: "ai.covetype.app.local-ai")
    private let stateLock = NSLock()
    private var process: Process?
    private var stdinHandle: FileHandle?
    private var stdoutHandle: FileHandle?
    private var stderrHandle: FileHandle?
    private var stdoutBuffer = Data()
    private var currentRequestWasCancelled = false

    func prewarm(loadASR: Bool, loadPolisher: Bool) async {
        guard loadASR || loadPolisher else { return }
        _ = try? await request(
            LocalAIRequest(
                id: UUID().uuidString,
                action: "prewarm",
                loadASR: loadASR,
                loadPolisher: loadPolisher
            )
        )
    }

    func keepAlive() async {
        _ = try? await request(LocalAIRequest(id: UUID().uuidString, action: "health"))
    }

    func transcribe(fileURL: URL) async throws -> String {
        let response = try await request(
            LocalAIRequest(
                id: UUID().uuidString,
                action: "transcribe",
                audioPath: fileURL.path
            )
        )
        guard let text = response.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              text.isEmpty == false else {
            throw CoveTypeError.localAIProtocolError(L("Empty Qwen3-ASR result", "Qwen3-ASR 返回空结果"))
        }
        return text
    }

    func polish(text: String, mode: PolishMode) async throws -> String {
        let response = try await request(
            LocalAIRequest(
                id: UUID().uuidString,
                action: "polish",
                text: text,
                mode: mode.rawValue.lowercased()
            )
        )
        guard let polished = response.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              polished.isEmpty == false else {
            throw CoveTypeError.localAIProtocolError(L("Empty Qwen3.5 result", "Qwen3.5 返回空结果"))
        }
        return polished
    }

    func releaseMemory() async {
        _ = try? await request(LocalAIRequest(id: UUID().uuidString, action: "release"))
    }

    func cancelCurrentRequest() {
        stateLock.lock()
        currentRequestWasCancelled = true
        let activeProcess = process
        stateLock.unlock()
        if let activeProcess, activeProcess.isRunning {
            activeProcess.terminate()
        }
    }

    func shutdown() {
        stateLock.lock()
        let activeProcess = process
        process = nil
        stateLock.unlock()
        if let activeProcess, activeProcess.isRunning {
            activeProcess.terminate()
        }
    }

    private func request(_ request: LocalAIRequest) async throws -> LocalAIResponse {
        try Task.checkCancellation()
        let encoded = try JSONEncoder().encode(request)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                ioQueue.async { [weak self] in
                    guard let self else {
                        continuation.resume(throwing: CancellationError())
                        return
                    }
                    do {
                        self.markRequestStarted()
                        try self.ensureProcess()
                        guard let stdinHandle = self.stdinHandle,
                              let stdoutHandle = self.stdoutHandle else {
                            throw CoveTypeError.localAIProtocolError("Worker pipe unavailable")
                        }
                        var line = encoded
                        line.append(0x0A)
                        try stdinHandle.write(contentsOf: line)

                        let responseData = try self.readLine(from: stdoutHandle)
                        let response = try JSONDecoder().decode(LocalAIResponse.self, from: responseData)
                        guard response.id == request.id else {
                            throw CoveTypeError.localAIProtocolError("Mismatched worker response")
                        }
                        guard response.ok == true else {
                            throw CoveTypeError.localAIProtocolError(response.error ?? "Unknown worker error")
                        }
                        self.clearCancellationFlag()
                        continuation.resume(returning: response)
                    } catch {
                        let wasCancelled = self.consumeCancellationFlag()
                        self.discardProcess()
                        continuation.resume(throwing: wasCancelled ? CancellationError() : error)
                    }
                }
            }
        } onCancel: { [weak self] in
            self?.cancelCurrentRequest()
        }
    }

    private func ensureProcess() throws {
        if let process, process.isRunning, stdinHandle != nil, stdoutHandle != nil {
            return
        }
        discardProcess()

        let home = FileManager.default.homeDirectoryForCurrentUser
        let pythonURL = home
            .appendingPathComponent("Library/Application Support/CoveType/mlx-runtime/bin/python")
        guard FileManager.default.isExecutableFile(atPath: pythonURL.path) else {
            throw CoveTypeError.localAIUnavailable(L("MLX runtime is missing", "缺少 MLX 运行环境"))
        }

        let bundledWorker = Bundle.main.url(forResource: "covetype_local_ai_worker", withExtension: "py")
        let sourceWorker = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources/covetype_local_ai_worker.py")
        let workerURL = bundledWorker ?? sourceWorker
        guard FileManager.default.fileExists(atPath: workerURL.path) else {
            throw CoveTypeError.localAIUnavailable(L("Local AI worker is missing", "缺少本地 AI 工作程序"))
        }

        let newProcess = Process()
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        newProcess.executableURL = pythonURL
        newProcess.arguments = [workerURL.path]
        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONUNBUFFERED"] = "1"
        environment["TOKENIZERS_PARALLELISM"] = "false"
        newProcess.environment = environment
        newProcess.standardInput = stdinPipe
        newProcess.standardOutput = stdoutPipe
        newProcess.standardError = stderrPipe

        let newStderrHandle = stderrPipe.fileHandleForReading
        newStderrHandle.readabilityHandler = { handle in
            _ = handle.availableData
        }

        do {
            try newProcess.run()
        } catch {
            newStderrHandle.readabilityHandler = nil
            throw CoveTypeError.localAIUnavailable(error.localizedDescription)
        }

        process = newProcess
        stdinHandle = stdinPipe.fileHandleForWriting
        stdoutHandle = stdoutPipe.fileHandleForReading
        stderrHandle = newStderrHandle
        stdoutBuffer.removeAll(keepingCapacity: true)
        stateLock.lock()
        process = newProcess
        stateLock.unlock()

        guard let stdoutHandle else {
            throw CoveTypeError.localAIProtocolError("Worker stdout unavailable")
        }
        let readyData = try readLine(from: stdoutHandle)
        let ready = try JSONDecoder().decode(LocalAIResponse.self, from: readyData)
        guard ready.ready == true else {
            throw CoveTypeError.localAIProtocolError("Worker did not become ready")
        }
    }

    private func readLine(from handle: FileHandle) throws -> Data {
        while true {
            if let newline = stdoutBuffer.firstIndex(of: 0x0A) {
                let line = Data(stdoutBuffer[..<newline])
                stdoutBuffer.removeSubrange(...newline)
                return line
            }
            var bytes = [UInt8](repeating: 0, count: 4096)
            let byteCount = Darwin.read(handle.fileDescriptor, &bytes, bytes.count)
            if byteCount < 0 && errno == EINTR {
                continue
            }
            guard byteCount > 0 else {
                throw CoveTypeError.localAIProtocolError("Local AI worker stopped unexpectedly")
            }
            stdoutBuffer.append(contentsOf: bytes.prefix(byteCount))
            if stdoutBuffer.count > 8 * 1024 * 1024 {
                throw CoveTypeError.localAIProtocolError("Local AI response is too large")
            }
        }
    }

    private func discardProcess() {
        stderrHandle?.readabilityHandler = nil
        let oldProcess = process
        stdinHandle = nil
        stdoutHandle = nil
        stderrHandle = nil
        stdoutBuffer.removeAll(keepingCapacity: true)
        stateLock.lock()
        process = nil
        stateLock.unlock()
        if let oldProcess, oldProcess.isRunning {
            oldProcess.terminate()
        }
    }

    private func markRequestStarted() {
        stateLock.lock()
        currentRequestWasCancelled = false
        stateLock.unlock()
    }

    private func clearCancellationFlag() {
        stateLock.lock()
        currentRequestWasCancelled = false
        stateLock.unlock()
    }

    private func consumeCancellationFlag() -> Bool {
        stateLock.lock()
        let result = currentRequestWasCancelled
        currentRequestWasCancelled = false
        stateLock.unlock()
        return result
    }
}

// MARK: - ASR Service

/// Thread-safe mutable data buffer for pipe reading.
private final class LockedData: @unchecked Sendable {
    private var data = Data()
    private let lock = NSLock()
    func append(_ chunk: Data) { lock.lock(); data.append(chunk); lock.unlock() }
    func read() -> Data { lock.lock(); defer { lock.unlock() }; return data }
}

final class ColiASRService: @unchecked Sendable {
    static var isInstalled: Bool {
        findColiPath() != nil
    }

    static var isNpmAvailable: Bool {
        findNpmPath() != nil
    }

    private struct PreviewState {
        var process: Process
        var stdin: FileHandle
        var lineBuffer = ""
        var wasCancelled = false
    }

    /// Auto-install coli via npm. Reports progress via callback.
    static func installColi(onProgress: @MainActor @Sendable @escaping (String) -> Void) async throws {
        guard let npmPath = findNpmPath() else {
            throw CoveTypeError.npmNotFound
        }

        await onProgress("Installing coli...")

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: npmPath)
                    process.arguments = ["install", "-g", "@marswave/coli"]

                    // Set up PATH so npm can find node
                    let npmDir = (npmPath as NSString).deletingLastPathComponent
                    let env = ProcessInfo.processInfo.environment
                    let home = env["HOME"] ?? ""
                    let extraPaths = [
                        npmDir,
                        "/opt/homebrew/bin",
                        "/usr/local/bin",
                        home + "/.nvm/current/bin",
                        home + "/.volta/bin",
                        home + "/.local/share/fnm/aliases/default/bin"
                    ]
                    var processEnv = env
                    let existingPath = env["PATH"] ?? "/usr/bin:/bin"
                    processEnv["PATH"] = (extraPaths + [existingPath]).joined(separator: ":")
                    process.environment = processEnv

                    let stdout = Pipe()
                    let stderr = Pipe()
                    process.standardOutput = stdout
                    process.standardError = stderr

                    // Read pipe data asynchronously to avoid deadlock
                    let stderrBuf = LockedData()
                    let stderrHandle = stderr.fileHandleForReading

                    stderrHandle.readabilityHandler = { handle in
                        let data = handle.availableData
                        if !data.isEmpty { stderrBuf.append(data) }
                    }

                    try process.run()

                    // 120-second timeout for install
                    let timeoutItem = DispatchWorkItem {
                        if process.isRunning { process.terminate() }
                    }
                    DispatchQueue.global().asyncAfter(deadline: .now() + 120, execute: timeoutItem)

                    process.waitUntilExit()
                    timeoutItem.cancel()

                    stderrHandle.readabilityHandler = nil

                    guard process.terminationStatus == 0 else {
                        let errorOutput = String(data: stderrBuf.read(), encoding: .utf8) ?? ""
                        let msg = errorOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                        throw CoveTypeError.coliInstallFailed(msg.isEmpty ? "npm install failed" : msg)
                    }

                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private var currentProcess: Process?
    private let processLock = NSLock()
    private var currentProcessWasCancelled = false
    private var previewState: PreviewState?

    func cancelCurrentProcess() {
        processLock.lock()
        let proc = currentProcess
        let previewProcess = previewState?.process
        if proc != nil {
            currentProcessWasCancelled = true
        }
        if previewState != nil {
            previewState?.wasCancelled = true
        }
        currentProcess = nil
        previewState = nil
        processLock.unlock()
        if let proc, proc.isRunning {
            proc.terminate()
        }
        if let previewProcess, previewProcess.isRunning {
            previewProcess.terminate()
        }
    }

    func startPreviewStream(onPreviewText: @MainActor @escaping @Sendable (String) -> Void) {
        processLock.lock()
        defer { processLock.unlock() }
        guard previewState == nil else { return }
        guard let coliPath = Self.findColiPath() else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: coliPath)
        process.arguments = ["asr-stream", "--json", "--asr-interval-ms", "1000"]
        process.environment = Self.makeColiEnvironment(coliPath: coliPath)

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        let stdoutHandle = stdout.fileHandleForReading
        stdoutHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard data.isEmpty == false else { return }
            self?.handlePreviewStdoutData(data, onPreviewText: onPreviewText)
        }

        let stderrHandle = stderr.fileHandleForReading
        stderrHandle.readabilityHandler = { handle in
            _ = handle.availableData
        }

        do {
            try process.run()
            previewState = PreviewState(process: process, stdin: stdin.fileHandleForWriting)
        } catch {
            stdoutHandle.readabilityHandler = nil
            stderrHandle.readabilityHandler = nil
        }
    }

    func sendPreviewAudio(_ data: Data, isFinal: Bool) {
        processLock.lock()
        guard let state = previewState else {
            processLock.unlock()
            return
        }
        let stdin = state.stdin
        processLock.unlock()

        if isFinal {
            try? stdin.close()
            return
        }

        guard data.isEmpty == false else { return }
        try? stdin.write(contentsOf: data)
    }

    func finishPreviewStream() {
        processLock.lock()
        guard let state = previewState else {
            processLock.unlock()
            return
        }
        previewState = nil
        processLock.unlock()
        try? state.stdin.close()
        // Wait briefly then terminate if still running
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            if state.process.isRunning {
                state.process.terminate()
            }
        }
    }

    func transcribe(fileURL: URL) async throws -> String {
        guard let coliPath = Self.findColiPath() else {
            throw CoveTypeError.coliNotInstalled
        }
        if let modelIssue = Self.detectIncompleteModelDownload() {
            throw CoveTypeError.transcriptionFailed(modelIssue)
        }

        // Retry once on failure (handles transient issues like ffmpeg not found)
        var lastError: Error?
        for attempt in 0..<2 {
            do {
                return try await runTranscription(fileURL: fileURL, coliPath: coliPath)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
                if attempt == 0 {
                    // Brief delay before retry
                    try? await Task.sleep(for: .milliseconds(500))
                }
            }
        }
        throw lastError!
    }

    private func runTranscription(fileURL: URL, coliPath: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                do {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: coliPath)
                    process.arguments = ["asr", fileURL.path]

                    // Inherit a proper PATH so node/bun can be found
                    let env = Self.makeColiEnvironment(coliPath: coliPath)

                    process.environment = env

                    let stdout = Pipe()
                    let stderr = Pipe()
                    process.standardOutput = stdout
                    process.standardError = stderr

                    // Read pipe data asynchronously to avoid deadlock when buffer fills up
                    let stdoutBuf = LockedData()
                    let stderrBuf = LockedData()
                    let stdoutHandle = stdout.fileHandleForReading
                    let stderrHandle = stderr.fileHandleForReading

                    stdoutHandle.readabilityHandler = { handle in
                        let data = handle.availableData
                        guard data.isEmpty == false else { return }
                        stdoutBuf.append(data)
                    }
                    stderrHandle.readabilityHandler = { handle in
                        let data = handle.availableData
                        if !data.isEmpty { stderrBuf.append(data) }
                    }

                    self?.processLock.lock()
                    self?.currentProcessWasCancelled = false
                    self?.currentProcess = process
                    self?.processLock.unlock()

                    try process.run()

                    // Dynamic timeout: 2x audio duration, minimum 120s (covers model download on first run)
                    var audioTimeout: TimeInterval = 120
                    if let audioFile = try? AVAudioFile(forReading: fileURL) {
                        let durationSeconds = Double(audioFile.length) / audioFile.processingFormat.sampleRate
                        audioTimeout = max(120, durationSeconds * 2.0)
                    }
                    let timeoutItem = DispatchWorkItem {
                        if process.isRunning {
                            process.terminate()
                        }
                    }
                    DispatchQueue.global().asyncAfter(deadline: .now() + audioTimeout, execute: timeoutItem)

                    process.waitUntilExit()
                    timeoutItem.cancel()

                    // Stop reading handlers
                    stdoutHandle.readabilityHandler = nil
                    stderrHandle.readabilityHandler = nil

                    self?.processLock.lock()
                    let wasCancelled = self?.currentProcessWasCancelled ?? false
                    self?.currentProcessWasCancelled = false
                    self?.currentProcess = nil
                    self?.processLock.unlock()

                    guard process.terminationReason != .uncaughtSignal else {
                        if wasCancelled {
                            throw CancellationError()
                        }
                        let diagnostics = Self.timeoutDiagnostics(
                            stdout: String(data: stdoutBuf.read(), encoding: .utf8) ?? "",
                            stderr: String(data: stderrBuf.read(), encoding: .utf8) ?? ""
                        )
                        throw CoveTypeError.transcriptionFailed(diagnostics)
                    }

                    let output = String(data: stdoutBuf.read(), encoding: .utf8) ?? ""
                    let errorOutput = String(data: stderrBuf.read(), encoding: .utf8) ?? ""

                    guard process.terminationStatus == 0 else {
                        let msg = errorOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                        throw CoveTypeError.transcriptionFailed(Self.diagnoseColiError(msg))
                    }

                    continuation.resume(returning: output.trimmingCharacters(in: .whitespacesAndNewlines))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Returns the macOS system HTTPS proxy as an "http://host:port" string, or nil if none is set.
    static func systemHTTPSProxyURL() -> String? {
        guard let proxySettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] else {
            return nil
        }
        // Check HTTPS proxy first, fall back to HTTP proxy
        if let httpsEnabled = proxySettings[kCFNetworkProxiesHTTPSEnable as String] as? Int, httpsEnabled == 1,
           let host = proxySettings[kCFNetworkProxiesHTTPSProxy as String] as? String,
           let port = proxySettings[kCFNetworkProxiesHTTPSPort as String] as? Int, !host.isEmpty {
            return "http://\(host):\(port)"
        }
        if let httpEnabled = proxySettings[kCFNetworkProxiesHTTPEnable as String] as? Int, httpEnabled == 1,
           let host = proxySettings[kCFNetworkProxiesHTTPProxy as String] as? String,
           let port = proxySettings[kCFNetworkProxiesHTTPPort as String] as? Int, !host.isEmpty {
            return "http://\(host):\(port)"
        }
        return nil
    }

    private func handlePreviewStdoutData(_ data: Data, onPreviewText: @MainActor @escaping @Sendable (String) -> Void) {
        guard let chunk = String(data: data, encoding: .utf8), chunk.isEmpty == false else { return }

        processLock.lock()
        guard var state = previewState else {
            processLock.unlock()
            return
        }
        state.lineBuffer += chunk

        while let newlineRange = state.lineBuffer.range(of: "\n") {
            let line = String(state.lineBuffer[..<newlineRange.lowerBound])
            state.lineBuffer.removeSubrange(..<newlineRange.upperBound)
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { continue }
            if let previewText = Self.extractPreviewText(from: trimmed) {
                Task { @MainActor in
                    onPreviewText(previewText)
                }
            }
        }

        previewState = state
        processLock.unlock()
    }

    private static func extractPreviewText(from line: String) -> String? {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return line.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return extractPreviewText(fromJSONObject: json) ?? line.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractPreviewText(fromJSONObject json: Any) -> String? {
        if let string = json as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        if let array = json as? [Any] {
            for item in array.reversed() {
                if let text = extractPreviewText(fromJSONObject: item) {
                    return text
                }
            }
            return nil
        }

        guard let dict = json as? [String: Any] else { return nil }

        let candidateKeys = ["text", "result", "sentence", "transcript", "partial", "output"]
        for key in candidateKeys {
            if let value = dict[key], let text = extractPreviewText(fromJSONObject: value) {
                return text
            }
        }

        if let segments = dict["segments"] as? [Any] {
            let joined = segments.compactMap { extractPreviewText(fromJSONObject: $0) }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            return joined.isEmpty ? nil : joined
        }

        for value in dict.values {
            if let text = extractPreviewText(fromJSONObject: value) {
                return text
            }
        }

        return nil
    }

    /// Cached login shell PATH resolved once on first use. GUI apps don't inherit
    /// the user's terminal PATH, so we spawn a login shell to get the full PATH.
    private static let resolvedShellPath: String? = {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        // Use login + interactive so .zshrc / .bashrc init scripts (nvm, homebrew, etc.) run
        process.arguments = ["-l", "-i", "-c", "echo $PATH"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }()

    private static func makeColiEnvironment(coliPath: String) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let home = env["HOME"] ?? ""
        let coliDir = (coliPath as NSString).deletingLastPathComponent
        let extraPaths = [
            coliDir,
            "/opt/homebrew/bin",
            "/usr/local/bin",
            home + "/.bun/bin",
            home + "/.npm-global/bin",
            "/opt/homebrew/opt/node/bin"
        ]
        // Prefer: explicit extra paths → resolved shell PATH → existing process PATH
        let shellPath = resolvedShellPath ?? ""
        let existingPath = env["PATH"] ?? "/usr/bin:/bin"
        let allPaths = extraPaths + (shellPath.isEmpty ? [existingPath] : [shellPath, existingPath])
        env["PATH"] = allPaths.joined(separator: ":")
        env["NO_UPDATE_NOTIFIER"] = "1"
        env["npm_config_update_notifier"] = "false"

        if env["HTTP_PROXY"] == nil && env["HTTPS_PROXY"] == nil && env["http_proxy"] == nil {
            if let proxyURL = systemHTTPSProxyURL() {
                env["HTTPS_PROXY"] = proxyURL
                env["HTTP_PROXY"] = proxyURL
                env["https_proxy"] = proxyURL
                env["http_proxy"] = proxyURL
            }
        }

        return env
    }

    private static func detectIncompleteModelDownload() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let modelsDir = home.appendingPathComponent(".coli/models", isDirectory: true)
        let modelDirName = "sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17"
        let senseVoiceDir = modelsDir.appendingPathComponent(modelDirName, isDirectory: true)
        let senseVoiceCheckFile = senseVoiceDir.appendingPathComponent("model.int8.onnx")
        let senseVoiceArchive = modelsDir.appendingPathComponent("\(modelDirName).tar.bz2")

        let fm = FileManager.default
        let archiveExists = fm.fileExists(atPath: senseVoiceArchive.path)
        let dirExists = fm.fileExists(atPath: senseVoiceDir.path)
        let modelExists = fm.fileExists(atPath: senseVoiceCheckFile.path)

        // Model is fully extracted — everything is fine.
        if modelExists { return nil }

        // Archive downloaded but neither extracted dir nor model exists.
        // Extraction likely failed (disk space, permissions, corrupt download).
        if archiveExists && !dirExists {
            return """
                Coli model extraction failed. The archive downloaded but could not be extracted. \
                Try clearing the models cache: rm -rf ~/.coli/models/\
                Then run: coli asr --help (to trigger a fresh model download). \
                If GitHub is inaccessible in your network, enable TUN mode in your proxy.
                """
                .replacingOccurrences(of: "\n                ", with: " ")
        }

        // Archive exists, dir exists, but model file is missing.
        // Partial extraction — directory created but model.int8.onnx not written.
        if archiveExists && dirExists && !modelExists {
            return """
                Coli model is partially extracted. Try clearing the models cache: \
                rm -rf ~/.coli/models/\
                Then run: coli asr --help (to trigger a fresh model download).
                """
                .replacingOccurrences(of: "\n                ", with: " ")
        }

        // No archive and no model. First-run model download hasn't happened yet
        // (or was fully cleaned). Let coli handle it — not an error state.
        return nil
    }

    /// Returns a user-friendly error message for common coli failure modes.
    private static func diagnoseColiError(_ stderr: String) -> String {
        if stderr.isEmpty { return "coli failed" }
        let lower = stderr.lowercased()
        if lower.contains("env: node") || lower.contains("env:node") || (lower.contains("no such file") && lower.contains("node")) {
            return "Node.js not found. Make sure Node.js is installed (nodejs.org) and restart CoveType."
        }
        if lower.contains("ffmpeg") && (lower.contains("not found") || lower.contains("no such file") || lower.contains("command not found")) {
            return "ffmpeg is required but not installed. Run: brew install ffmpeg"
        }
        if lower.contains("sherpa-onnx-node") || lower.contains("could not find sherpa") {
            return "Node.js version incompatibility with native addon. Try: npm install -g @marswave/coli --build-from-source"
        }
        return stderr
    }

    private static func timeoutDiagnostics(stdout: String, stderr: String) -> String {
        let combined = [stdout, stderr]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        if combined.isEmpty {
            return "Transcription timed out. Coli downloads its first model on first use into ~/.coli/models. If GitHub is blocked, enable TUN/Enhanced proxy mode and try again."
        }

        let lower = combined.lowercased()
        if lower.contains("ffmpeg") && (lower.contains("not found") || lower.contains("no such file") || lower.contains("command not found")) {
            return "Transcription failed: ffmpeg is required but not installed. Run: brew install ffmpeg"
        }

        let condensed = combined
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .suffix(6)
            .joined(separator: " | ")

        return "Transcription timed out. Coli output: \(condensed)"
    }

    static func findNpmPath() -> String? {
        let env = ProcessInfo.processInfo.environment
        let home = env["HOME"] ?? ""

        if let pathInEnv = executableInPath(named: "npm", path: env["PATH"]) {
            return pathInEnv
        }

        let candidates = [
            "/opt/homebrew/bin/npm",
            "/usr/local/bin/npm",
            home + "/.nvm/current/bin/npm",
            home + "/.volta/bin/npm",
            home + "/.local/share/fnm/aliases/default/bin/npm",
            home + "/.bun/bin/npm"
        ]

        if let found = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return found
        }

        return resolveViaShell("npm")
    }

    private static func findColiPath() -> String? {
        let env = ProcessInfo.processInfo.environment
        let home = env["HOME"] ?? ""

        // Check current environment PATH first
        if let pathInEnv = executableInPath(named: "coli", path: env["PATH"]) {
            return pathInEnv
        }

        let candidates = [
            home + "/.local/bin/coli",
            "/opt/homebrew/bin/coli",
            "/usr/local/bin/coli",
            home + "/.npm-global/bin/coli",
            home + "/.bun/bin/coli",
            home + "/.volta/bin/coli",
            home + "/.nvm/current/bin/coli",
            "/opt/homebrew/opt/node/bin/coli"
        ]

        if let found = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return found
        }

        // Check fnm/nvm managed Node installs
        let managedRoots: [(root: String, rel: String)] = [
            (home + "/.local/share/fnm/node-versions", "installation/bin/coli"),
            (home + "/.nvm/versions/node", "bin/coli")
        ]
        for managed in managedRoots {
            if let path = newestManagedBinary(under: managed.root, relativePath: managed.rel) {
                return path
            }
        }

        // Use npm to find global bin directory (works even when coli is in a custom prefix)
        if let npmGlobalBin = resolveNpmGlobalBin(), !npmGlobalBin.isEmpty {
            let coliViaNpm = npmGlobalBin + "/coli"
            if FileManager.default.isExecutableFile(atPath: coliViaNpm) {
                return coliViaNpm
            }
        }

        // Check the cached login shell PATH (resolves nvm/fnm/volta without spawning a new shell each time)
        if let shellPath = resolvedShellPath, let found = executableInPath(named: "coli", path: shellPath) {
            return found
        }

        // Final fallback: spawn a login shell to resolve coli
        return resolveViaShell("coli")
    }

    private static func executableInPath(named name: String, path: String?) -> String? {
        guard let path else { return nil }
        for dir in path.split(separator: ":") {
            let full = String(dir) + "/\(name)"
            if FileManager.default.isExecutableFile(atPath: full) { return full }
        }
        return nil
    }

    private static func newestManagedBinary(under rootPath: String, relativePath: String) -> String? {
        let fm = FileManager.default
        let rootURL = URL(fileURLWithPath: rootPath, isDirectory: true)
        guard let entries = try? fm.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        let sorted = entries
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted {
                let d1 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let d2 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return d1 != d2 ? d1 > d2 : $0.lastPathComponent > $1.lastPathComponent
            }

        for dir in sorted {
            let path = dir.path + "/" + relativePath
            if fm.isExecutableFile(atPath: path) { return path }
        }
        return nil
    }

    private static func resolveViaShell(_ command: String) -> String? {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        // Use -i (interactive) so nvm/fnm/volta init scripts in .zshrc are loaded
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-l", "-i", "-c", "command -v \(command)"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard let path, !path.isEmpty,
                  FileManager.default.isExecutableFile(atPath: path) else {
                return nil
            }
            return path
        } catch {
            return nil
        }
    }

    /// Resolve the npm global bin directory by asking npm itself via a login shell.
    private static func resolveNpmGlobalBin() -> String? {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-l", "-i", "-c", "npm bin -g 2>/dev/null || npm prefix -g 2>/dev/null"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            // npm bin -g returns the bin path directly
            // npm prefix -g returns the prefix, bin is prefix/bin
            if output.hasSuffix("/bin") {
                return output
            } else if !output.isEmpty {
                return output + "/bin"
            }
            return nil
        } catch {
            return nil
        }
    }
}

// MARK: - Hotkey Monitor

@MainActor
final class KeyboardDiagnosticSession {
    private var monitors: [Any] = []
    private var outputHandle: FileHandle?
    private let duration: TimeInterval

    init(duration: TimeInterval) {
        self.duration = min(max(duration, 5), 30)
    }

    func start() {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/CoveType", isDirectory: true)
        let outputURL = directory.appendingPathComponent("keyboard-diagnostic.jsonl")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: outputURL)
        FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        outputHandle = try? FileHandle(forWritingTo: outputURL)
        write([
            "event": "start",
            "accessibility": AXIsProcessTrusted(),
            "duration_seconds": duration
        ])

        if let flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            Task { @MainActor in self?.record(event) }
        }) {
            monitors.append(flagsMonitor)
        }
        if let keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp], handler: { [weak self] event in
            Task { @MainActor in self?.record(event) }
        }) {
            monitors.append(keyMonitor)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.finish()
        }
    }

    private func record(_ event: NSEvent) {
        let eventName: String
        switch event.type {
        case .flagsChanged: eventName = "flagsChanged"
        case .keyDown: eventName = "keyDown"
        case .keyUp: eventName = "keyUp"
        default: return
        }
        write([
            "event": eventName,
            "key_code": Int(event.keyCode),
            "flags": event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
                .rawValue,
            "timestamp": event.timestamp
        ])
    }

    private func write(_ payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) else { return }
        outputHandle?.write(data)
        outputHandle?.write(Data([0x0A]))
    }

    private func finish() {
        write(["event": "finish"])
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
        try? outputHandle?.close()
        outputHandle = nil
        exit(EXIT_SUCCESS)
    }
}

@MainActor
final class HotkeyMonitor {
    private enum HoldKey: Equatable {
        case function
        case leftOption
        case rightOption
        case leftControl
        case rightControl
        case custom
    }

    private static let functionKeyCode: UInt16 = 63
    private static let leftOptionKeyCode: UInt16 = 58
    private static let rightOptionKeyCode: UInt16 = 61
    private static let leftControlKeyCode: UInt16 = 59
    private static let rightControlKeyCode: UInt16 = 62
    private static let spaceKeyCode: UInt16 = 49
    private static let standardHoldDelay: TimeInterval = 0.18
    private static let controlHoldDelay: TimeInterval = 0.32

    private let onToggle: () -> Void
    private let onPress: () -> Void
    private let onRelease: () -> Void
    private let customBinding: CustomShortcutBinding?
    private let customHoldDuration: TimeInterval
    private var flagsMonitor: Any?
    private var keyMonitor: Any?
    private var localFlagsMonitor: Any?
    private var localKeyMonitor: Any?
    private var functionIsDown = false
    private var leftOptionIsDown = false
    private var rightOptionIsDown = false
    private var leftControlIsDown = false
    private var rightControlIsDown = false
    private var customPrimaryIsDown = false
    private var pendingHoldKey: HoldKey?
    private var activeHoldKey: HoldKey?
    private var pendingHoldWorkItem: DispatchWorkItem?

    init(
        onToggle: @escaping () -> Void,
        onPress: @escaping () -> Void,
        onRelease: @escaping () -> Void,
        customBinding: CustomShortcutBinding? = nil,
        holdDuration: TimeInterval? = nil,
        loadStoredShortcut: Bool = true
    ) {
        self.onToggle = onToggle
        self.onPress = onPress
        self.onRelease = onRelease
        self.customBinding = loadStoredShortcut
            ? UserDefaults.standard.customShortcutBinding
            : customBinding
        self.customHoldDuration = min(
            max(
                holdDuration ?? (loadStoredShortcut
                    ? UserDefaults.standard.shortcutHoldDuration
                    : Self.controlHoldDelay),
                0.10
            ),
            1.50
        )
    }

    static func runSelfTest() async -> Bool {
        var events: [String] = []
        let monitor = HotkeyMonitor(
            onToggle: { events.append("toggle") },
            onPress: { events.append("press") },
            onRelease: { events.append("release") },
            holdDuration: Self.standardHoldDelay,
            loadStoredShortcut: false
        )

        func keyEvent(
            type: NSEvent.EventType,
            keyCode: UInt16,
            flags: NSEvent.ModifierFlags,
            characters: String = ""
        ) -> NSEvent {
            NSEvent.keyEvent(
                with: type,
                location: .zero,
                modifierFlags: flags,
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: 0,
                context: nil,
                characters: characters,
                charactersIgnoringModifiers: characters,
                isARepeat: false,
                keyCode: keyCode
            )!
        }

        // Standalone Fn: press after grace period, release to stop.
        monitor.handleFlagsChanged(keyEvent(type: .flagsChanged, keyCode: functionKeyCode, flags: .function))
        try? await Task.sleep(for: .milliseconds(230))
        monitor.handleFlagsChanged(keyEvent(type: .flagsChanged, keyCode: functionKeyCode, flags: []))

        // Standalone Right Option follows the same push-to-talk behavior.
        monitor.handleFlagsChanged(keyEvent(type: .flagsChanged, keyCode: rightOptionKeyCode, flags: .option))
        try? await Task.sleep(for: .milliseconds(230))
        monitor.handleFlagsChanged(keyEvent(type: .flagsChanged, keyCode: rightOptionKeyCode, flags: []))

        // Generic PC keyboards often report their right Control as macOS left
        // Control. It must still support hold-to-talk.
        monitor.handleFlagsChanged(keyEvent(type: .flagsChanged, keyCode: leftControlKeyCode, flags: .control))
        try? await Task.sleep(for: .milliseconds(370))
        monitor.handleFlagsChanged(keyEvent(type: .flagsChanged, keyCode: leftControlKeyCode, flags: []))

        // Fn+Space must toggle hands-free without starting a hold recording.
        monitor.handleFlagsChanged(keyEvent(type: .flagsChanged, keyCode: functionKeyCode, flags: .function))
        try? await Task.sleep(for: .milliseconds(40))
        monitor.handleKeyEvent(keyEvent(type: .keyDown, keyCode: spaceKeyCode, flags: .function, characters: " "))
        monitor.handleFlagsChanged(keyEvent(type: .flagsChanged, keyCode: functionKeyCode, flags: []))
        try? await Task.sleep(for: .milliseconds(230))

        // Fn used in a normal chord must not start dictation.
        monitor.handleFlagsChanged(keyEvent(type: .flagsChanged, keyCode: functionKeyCode, flags: .function))
        try? await Task.sleep(for: .milliseconds(40))
        monitor.handleKeyEvent(keyEvent(type: .keyDown, keyCode: 8, flags: .function, characters: "c"))
        monitor.handleFlagsChanged(keyEvent(type: .flagsChanged, keyCode: functionKeyCode, flags: []))
        try? await Task.sleep(for: .milliseconds(230))

        // Ctrl+C must remain a normal coding shortcut on external keyboards.
        monitor.handleFlagsChanged(keyEvent(type: .flagsChanged, keyCode: leftControlKeyCode, flags: .control))
        try? await Task.sleep(for: .milliseconds(40))
        monitor.handleKeyEvent(keyEvent(type: .keyDown, keyCode: 8, flags: .control, characters: "c"))
        monitor.handleFlagsChanged(keyEvent(type: .flagsChanged, keyCode: leftControlKeyCode, flags: []))
        try? await Task.sleep(for: .milliseconds(370))

        let expected = ["press", "release", "press", "release", "press", "release", "toggle"]
        var customEvents: [String] = []
        let customBinding = CustomShortcutBinding(
            keyCode: 40,
            modifierFlagsRaw: NSEvent.ModifierFlags.control.rawValue,
            modifierOnly: false,
            displayName: "⌃K"
        )
        let customMonitor = HotkeyMonitor(
            onToggle: { customEvents.append("toggle") },
            onPress: { customEvents.append("press") },
            onRelease: { customEvents.append("release") },
            customBinding: customBinding,
            holdDuration: 0.10,
            loadStoredShortcut: false
        )
        customMonitor.handleKeyEvent(
            keyEvent(type: .keyDown, keyCode: 40, flags: .control, characters: "k")
        )
        try? await Task.sleep(for: .milliseconds(140))
        customMonitor.handleKeyEvent(
            keyEvent(type: .keyUp, keyCode: 40, flags: .control, characters: "k")
        )

        let customExpected = ["press", "release"]
        let passed = events == expected && customEvents == customExpected
        print("HOTKEY_SELF_TEST_EVENTS=\(events.joined(separator: ","))")
        print("CUSTOM_HOTKEY_SELF_TEST_EVENTS=\(customEvents.joined(separator: ","))")
        print("HOTKEY_SELF_TEST_RESULT=\(passed ? "PASS" : "FAIL")")
        return passed
    }

    func stop() {
        cancelPendingHold()
        if activeHoldKey != nil {
            onRelease()
        }
        activeHoldKey = nil
        functionIsDown = false
        leftOptionIsDown = false
        rightOptionIsDown = false
        leftControlIsDown = false
        rightControlIsDown = false
        customPrimaryIsDown = false

        [flagsMonitor, keyMonitor, localFlagsMonitor, localKeyMonitor]
            .compactMap { $0 }
            .forEach { NSEvent.removeMonitor($0) }
        flagsMonitor = nil
        keyMonitor = nil
        localFlagsMonitor = nil
        localKeyMonitor = nil
    }

    func start() {
        stop()

        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in self?.handleFlagsChanged(event) }
        }
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            Task { @MainActor in self?.handleKeyEvent(event) }
        }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        if let customBinding {
            handleCustomFlagsChanged(event, binding: customBinding)
            return
        }

        switch event.keyCode {
        case Self.functionKeyCode:
            functionIsDown = event.modifierFlags.contains(.function)
            if functionIsDown {
                armHold(for: .function, flags: event.modifierFlags)
            } else {
                releaseHold(for: .function)
            }

        case Self.leftOptionKeyCode:
            leftOptionIsDown = event.modifierFlags.contains(.option)
            if leftOptionIsDown {
                armHold(for: .leftOption, flags: event.modifierFlags)
            } else {
                releaseHold(for: .leftOption)
            }

        case Self.rightOptionKeyCode:
            rightOptionIsDown = event.modifierFlags.contains(.option)
            if rightOptionIsDown {
                armHold(for: .rightOption, flags: event.modifierFlags)
            } else {
                releaseHold(for: .rightOption)
            }

        case Self.leftControlKeyCode:
            leftControlIsDown = event.modifierFlags.contains(.control)
            if leftControlIsDown {
                armHold(for: .leftControl, flags: event.modifierFlags)
            } else {
                releaseHold(for: .leftControl)
            }

        case Self.rightControlKeyCode:
            rightControlIsDown = event.modifierFlags.contains(.control)
            if rightControlIsDown {
                armHold(for: .rightControl, flags: event.modifierFlags)
            } else {
                releaseHold(for: .rightControl)
            }

        default:
            // A second modifier means the user is entering a normal shortcut.
            cancelPendingHold()
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        if let customBinding {
            handleCustomKeyEvent(event, binding: customBinding)
            return
        }

        guard event.type == .keyDown, !event.isARepeat else { return }

        // Fn+Space is the hands-free toggle. Press it before the 180 ms
        // standalone-Fn grace period expires.
        if event.keyCode == Self.spaceKeyCode,
           functionIsDown,
           activeHoldKey == nil,
           hasOnlyFunctionModifier(event.modifierFlags) {
            cancelPendingHold()
            onToggle()
            return
        }

        // Any ordinary key means Fn/Right Option is being used as a modifier,
        // not as dictation. If recording already started, stop it immediately
        // and allow the user's original shortcut to continue normally.
        cancelPendingHold()
        if activeHoldKey != nil {
            finishActiveHold()
        }
    }

    private func handleCustomFlagsChanged(_ event: NSEvent, binding: CustomShortcutBinding) {
        let currentFlags = relevantModifiers(in: event.modifierFlags)
        let expectedFlags = relevantModifiers(in: binding.modifierFlags)

        if binding.modifierOnly {
            if event.keyCode == binding.keyCode, currentFlags == expectedFlags, !expectedFlags.isEmpty {
                customPrimaryIsDown = true
                armHold(for: .custom, flags: event.modifierFlags)
            } else if customPrimaryIsDown, currentFlags != expectedFlags {
                customPrimaryIsDown = false
                releaseHold(for: .custom)
            } else if pendingHoldKey == .custom, currentFlags != expectedFlags {
                cancelPendingHold()
            }
            return
        }

        // For a key+modifier binding, releasing or adding a modifier while the
        // primary key is held ends the push-to-talk gesture immediately.
        if customPrimaryIsDown, currentFlags != expectedFlags {
            customPrimaryIsDown = false
            releaseHold(for: .custom)
        }
    }

    private func handleCustomKeyEvent(_ event: NSEvent, binding: CustomShortcutBinding) {
        if binding.modifierOnly {
            guard event.type == .keyDown, !event.isARepeat else { return }
            // A modifier-only shortcut may become part of a normal chord such
            // as Control+C. Cancel before the configured hold time elapses.
            cancelPendingHold()
            if activeHoldKey == .custom {
                finishActiveHold()
            }
            return
        }

        if event.keyCode == binding.keyCode {
            switch event.type {
            case .keyDown where !event.isARepeat:
                guard relevantModifiers(in: event.modifierFlags)
                        == relevantModifiers(in: binding.modifierFlags) else {
                    return
                }
                customPrimaryIsDown = true
                armHold(for: .custom, flags: event.modifierFlags)
            case .keyUp:
                customPrimaryIsDown = false
                releaseHold(for: .custom)
            default:
                break
            }
            return
        }

        guard event.type == .keyDown, !event.isARepeat else { return }
        cancelPendingHold()
        if activeHoldKey == .custom {
            finishActiveHold()
        }
    }

    private func armHold(for key: HoldKey, flags: NSEvent.ModifierFlags) {
        guard pendingHoldKey == nil, activeHoldKey == nil else { return }
        guard hasOnlyExpectedModifier(key, flags: flags) else { return }

        pendingHoldKey = key
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  self.pendingHoldKey == key,
                  self.isKeyDown(key) else { return }
            self.pendingHoldKey = nil
            self.pendingHoldWorkItem = nil
            self.activeHoldKey = key
            self.onPress()
        }
        pendingHoldWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + customHoldDuration, execute: workItem)
    }

    private func releaseHold(for key: HoldKey) {
        if pendingHoldKey == key {
            cancelPendingHold()
        }
        if activeHoldKey == key {
            finishActiveHold()
        }
    }

    private func cancelPendingHold() {
        pendingHoldWorkItem?.cancel()
        pendingHoldWorkItem = nil
        pendingHoldKey = nil
    }

    private func finishActiveHold() {
        guard activeHoldKey != nil else { return }
        activeHoldKey = nil
        onRelease()
    }

    private func isKeyDown(_ key: HoldKey) -> Bool {
        switch key {
        case .function: functionIsDown
        case .leftOption: leftOptionIsDown
        case .rightOption: rightOptionIsDown
        case .leftControl: leftControlIsDown
        case .rightControl: rightControlIsDown
        case .custom: customPrimaryIsDown
        }
    }

    private func hasOnlyExpectedModifier(_ key: HoldKey, flags: NSEvent.ModifierFlags) -> Bool {
        let relevant: NSEvent.ModifierFlags = [.shift, .control, .option, .command, .function]
        let expected: NSEvent.ModifierFlags = switch key {
        case .function: .function
        case .leftOption, .rightOption: .option
        case .leftControl, .rightControl: .control
        case .custom: customBinding?.modifierFlags ?? []
        }
        return flags.intersection(relevant) == expected.intersection(relevant)
    }

    private func relevantModifiers(in flags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        let relevant: NSEvent.ModifierFlags = [.shift, .control, .option, .command, .function]
        return flags.intersection(relevant)
    }

    private func hasOnlyFunctionModifier(_ flags: NSEvent.ModifierFlags) -> Bool {
        let relevant: NSEvent.ModifierFlags = [.shift, .control, .option, .command, .function]
        return flags.intersection(relevant) == .function
    }
}

// MARK: - Shortcut Settings

enum ShortcutNameFormatter {
    private static let keyNames: [UInt16: String] = [
        36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Esc",
        71: "Clear", 76: "Enter", 117: "Forward Delete", 123: "←",
        124: "→", 125: "↓", 126: "↑", 122: "F1", 120: "F2",
        99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7",
        100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17",
        79: "F18", 80: "F19", 90: "F20", 110: "Menu"
    ]

    static func binding(from event: NSEvent, modifierOnly: Bool) -> CustomShortcutBinding {
        let flags = relevantModifiers(event.modifierFlags)
        let name: String
        if modifierOnly {
            name = modifierOnlyName(keyCode: event.keyCode, flags: flags)
        } else {
            let prefix = modifierSymbols(flags)
            let keyName = keyNames[event.keyCode]
                ?? event.charactersIgnoringModifiers?.uppercased()
                ?? L("Key \(event.keyCode)", "按键 \(event.keyCode)")
            name = prefix + keyName
        }
        return CustomShortcutBinding(
            keyCode: event.keyCode,
            modifierFlagsRaw: flags.rawValue,
            modifierOnly: modifierOnly,
            displayName: name
        )
    }

    static func flag(for keyCode: UInt16) -> NSEvent.ModifierFlags? {
        switch keyCode {
        case 55, 54: .command
        case 56, 60: .shift
        case 59, 62: .control
        case 58, 61: .option
        case 63: .function
        default: nil
        }
    }

    private static func modifierOnlyName(
        keyCode: UInt16,
        flags: NSEvent.ModifierFlags
    ) -> String {
        if flags.rawValue.nonzeroBitCount > 1 {
            return modifierSymbols(flags)
        }
        switch keyCode {
        case 55, 54: return "⌘ Command"
        case 56, 60: return "⇧ Shift"
        case 59, 62: return "⌃ Control"
        case 58, 61: return "⌥ Option"
        case 63: return "Fn"
        default: return modifierSymbols(flags)
        }
    }

    private static func modifierSymbols(_ flags: NSEvent.ModifierFlags) -> String {
        var result = ""
        if flags.contains(.control) { result += "⌃" }
        if flags.contains(.option) { result += "⌥" }
        if flags.contains(.shift) { result += "⇧" }
        if flags.contains(.command) { result += "⌘" }
        if flags.contains(.function) { result += "Fn+" }
        return result
    }

    private static func relevantModifiers(_ flags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        flags.intersection([.shift, .control, .option, .command, .function])
    }
}

@MainActor
final class ShortcutSettingsModel: ObservableObject {
    @Published var binding: CustomShortcutBinding?
    @Published var holdDuration: Double
    @Published var isCapturing = false

    var onRecord: (() -> Void)?
    var onCancelCapture: (() -> Void)?
    var onReset: (() -> Void)?
    var onDurationChanged: ((Double) -> Void)?
    var onDone: (() -> Void)?

    init() {
        binding = UserDefaults.standard.customShortcutBinding
        holdDuration = UserDefaults.standard.shortcutHoldDuration
    }

    var shortcutName: String {
        binding?.displayName ?? L("Automatic · Fn / Option / Control", "自动 · Fn / Option / Control")
    }

    var instruction: String {
        L(
            "Hold \(shortcutName) for \(String(format: "%.2f", holdDuration)) seconds to start recording. Release it to transcribe.",
            "按住 \(shortcutName) \(String(format: "%.2f", holdDuration)) 秒开始录音，松开后转录并输入。"
        )
    }
}

struct ShortcutSettingsView: View {
    @ObservedObject var model: ShortcutSettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "keyboard.badge.ellipsis")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("Push-to-Talk Shortcut", "按住说话快捷键"))
                        .font(.title2.weight(.semibold))
                    Text(L("Use the physical key that feels best on your keyboard.", "直接录制最适合你键盘的实体按键。"))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(L("Current shortcut", "当前快捷键"))
                    .font(.headline)
                HStack {
                    Text(model.isCapturing
                         ? L("Press a key or key combination…", "请按一个键或组合键…")
                         : model.shortcutName)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(model.isCapturing ? Color.accentColor : Color.primary)
                    Spacer()
                    Button(model.isCapturing ? L("Cancel", "取消") : L("Record Shortcut…", "录制快捷键…")) {
                        if model.isCapturing {
                            model.onCancelCapture?()
                        } else {
                            model.onRecord?()
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(model.isCapturing ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                )
                if model.isCapturing {
                    Text(L("Hold modifiers together, or press a normal key combination. Esc cancels.", "可同时按住多个修饰键，也可按普通组合键；Esc 取消。"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L("Hold before recording", "触发前按住时长"))
                        .font(.headline)
                    Spacer()
                    Text(String(format: "%.2f s", model.holdDuration))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $model.holdDuration, in: 0.10...1.50, step: 0.05)
                    .onChange(of: model.holdDuration) { _, newValue in
                        model.onDurationChanged?(newValue)
                    }
                Text(model.instruction)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Text(L(
                "Tip: a longer delay prevents shortcuts such as Control+C from starting dictation. Choose a key combination that is not already used by the current app.",
                "提示：较长的时长可避免 Control+C 等常用快捷键误启动录音；组合键请尽量避开当前软件已有的快捷键。"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)

            Divider()
            HStack {
                Button(L("Reset to Automatic", "恢复自动兼容模式")) {
                    model.onReset?()
                }
                Spacer()
                Button(L("Done", "完成")) {
                    model.onDone?()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 540)
    }
}

@MainActor
final class ShortcutSettingsController: NSObject, NSWindowDelegate {
    private let model = ShortcutSettingsModel()
    private var window: NSWindow?
    private var keyMonitor: Any?
    private var flagsMonitor: Any?
    private var pendingModifierBinding: CustomShortcutBinding?
    private let onConfigurationChanged: () -> Void

    init(onConfigurationChanged: @escaping () -> Void) {
        self.onConfigurationChanged = onConfigurationChanged
        super.init()
        model.onRecord = { [weak self] in self?.beginCapture() }
        model.onCancelCapture = { [weak self] in self?.endCapture() }
        model.onReset = { [weak self] in self?.resetToAutomatic() }
        model.onDurationChanged = { [weak self] duration in self?.saveDuration(duration) }
        model.onDone = { [weak self] in self?.window?.close() }
    }

    func show() {
        if window == nil {
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 540, height: 430),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            newWindow.title = L("CoveType Shortcut Settings", "CoveType 快捷键设置")
            newWindow.isReleasedWhenClosed = false
            newWindow.delegate = self
            newWindow.contentView = NSHostingView(rootView: ShortcutSettingsView(model: model))
            newWindow.center()
            window = newWindow
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        endCapture()
    }

    private func beginCapture() {
        endCapture()
        pendingModifierBinding = nil
        model.isCapturing = true

        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.captureModifierEvent(event)
            return nil
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.captureKeyEvent(event)
            return nil
        }
    }

    private func captureModifierEvent(_ event: NSEvent) {
        guard model.isCapturing,
              let changedFlag = ShortcutNameFormatter.flag(for: event.keyCode) else { return }

        if event.modifierFlags.contains(changedFlag) {
            pendingModifierBinding = ShortcutNameFormatter.binding(from: event, modifierOnly: true)
        } else if let pendingModifierBinding {
            save(binding: pendingModifierBinding)
        }
    }

    private func captureKeyEvent(_ event: NSEvent) {
        guard model.isCapturing, !event.isARepeat else { return }
        if event.keyCode == 53 {
            endCapture()
            return
        }
        save(binding: ShortcutNameFormatter.binding(from: event, modifierOnly: false))
    }

    private func save(binding: CustomShortcutBinding) {
        model.binding = binding
        UserDefaults.standard.customShortcutBinding = binding
        endCapture()
        configurationDidChange()
    }

    private func saveDuration(_ duration: Double) {
        UserDefaults.standard.shortcutHoldDuration = duration
        configurationDidChange()
    }

    private func resetToAutomatic() {
        endCapture()
        model.binding = nil
        model.holdDuration = 0.32
        UserDefaults.standard.customShortcutBinding = nil
        UserDefaults.standard.shortcutHoldDuration = 0.32
        configurationDidChange()
    }

    private func configurationDidChange() {
        NotificationCenter.default.post(name: .hotkeyConfigChanged, object: nil)
        onConfigurationChanged()
    }

    private func endCapture() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let flagsMonitor { NSEvent.removeMonitor(flagsMonitor) }
        keyMonitor = nil
        flagsMonitor = nil
        pendingModifierBinding = nil
        model.isCapturing = false
    }
}

// MARK: - Product Feedback

enum FeedbackCategory: String, CaseIterable, Identifiable {
    case bug
    case feature
    case recognition
    case translation
    case performance
    case privacy
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bug: L("Problem or Bug", "问题或故障")
        case .feature: L("Feature Request", "功能建议")
        case .recognition: L("Recognition Quality", "识别质量")
        case .translation: L("Translation", "翻译问题")
        case .performance: L("Performance", "性能问题")
        case .privacy: L("Privacy", "隐私问题")
        case .other: L("Other", "其他")
        }
    }

    var issueLabel: String {
        switch self {
        case .bug: "Bug"
        case .feature: "Feature Request"
        case .recognition: "Recognition Quality"
        case .translation: "Translation"
        case .performance: "Performance"
        case .privacy: "Privacy"
        case .other: "Other"
        }
    }
}

@MainActor
final class FeedbackModel: ObservableObject {
    @Published var category: FeedbackCategory = .feature
    @Published var subject = ""
    @Published var details = ""
    @Published var includeSystemInfo = true
    @Published var anonymousUsageStatisticsEnabled: Bool {
        didSet {
            UserDefaults.standard.anonymousUsageStatisticsEnabled = anonymousUsageStatisticsEnabled
        }
    }
    @Published var statusMessage = ""
    @Published var submissionConfigured = false

    var onCopy: (() -> Void)?
    var onSubmit: (() -> Void)?
    var onDone: (() -> Void)?

    init() {
        anonymousUsageStatisticsEnabled = UserDefaults.standard.anonymousUsageStatisticsEnabled
    }

    var canPrepare: Bool {
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct FeedbackView: View {
    @ObservedObject var model: FeedbackModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 27, weight: .medium))
                    .foregroundStyle(.tint)
                    .frame(width: 38)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("Help improve CoveType", "帮助改进 CoveType"))
                        .font(.title2.weight(.semibold))
                    Text(L(
                        "Report a problem or tell us what you would like changed.",
                        "报告使用问题，或者告诉我们你希望修改的功能。"
                    ))
                    .foregroundStyle(.secondary)
                }
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 12) {
                GridRow {
                    Text(L("Type", "类型"))
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.trailing)
                    Picker("", selection: $model.category) {
                        ForEach(FeedbackCategory.allCases) { category in
                            Text(category.label).tag(category)
                        }
                    }
                    .labelsHidden()
                }

                GridRow {
                    Text(L("Title", "标题"))
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.trailing)
                    TextField(
                        L("What should CoveType improve?", "你希望 CoveType 改进什么？"),
                        text: $model.subject
                    )
                    .textFieldStyle(.roundedBorder)
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(L("Details", "详细说明"))
                    .font(.headline)
                TextEditor(text: $model.details)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 150)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
                    )
                Text(L(
                    "Describe what happened, what you expected, and your suggested change.",
                    "请说明发生了什么、你的预期，以及建议如何修改。"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Toggle(
                L(
                    "Include CoveType version, macOS version, language, and processor architecture",
                    "附带 CoveType 版本、macOS 版本、系统语言和处理器架构"
                ),
                isOn: $model.includeSystemInfo
            )
            .toggleStyle(.checkbox)

            VStack(alignment: .leading, spacing: 5) {
                Toggle(
                    L(
                        "Send anonymous daily usage statistics",
                        "发送匿名每日使用统计"
                    ),
                    isOn: $model.anonymousUsageStatisticsEnabled
                )
                .toggleStyle(.checkbox)

                Text(L(
                    "At most once every 24 hours, CoveType sends a random installation ID, app version, macOS version, and processor architecture over HTTPS. The server derives only the country and does not store your IP. Audio, transcripts, and typed text are never included.",
                    "CoveType 每 24 小时最多通过 HTTPS 发送一次随机安装编号、应用版本、macOS 版本和处理器架构。服务器只判断国家且不保存 IP；绝不包含录音、转录结果或输入文字。"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)

                Link(
                    L("Read privacy details", "查看隐私说明"),
                    destination: URL(string: "https://covetype.com/#privacy")!
                )
                .font(.caption)
            }

            VStack(alignment: .leading, spacing: 5) {
                Label(
                    L(
                        "Do not include recordings, passwords, private text, or other sensitive information.",
                        "请勿填写录音、密码、私人文字或其他敏感信息。"
                    ),
                    systemImage: "hand.raised.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                if !model.submissionConfigured {
                    Label(
                        L(
                            "The CoveType feedback channel will be enabled after its public repository is published. Copy remains available now.",
                            "CoveType 公开仓库发布后才会启用在线提交；现在可以先复制反馈内容。"
                        ),
                        systemImage: "info.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }

            if !model.statusMessage.isEmpty {
                Text(model.statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Divider()

            HStack {
                Button(L("Copy Feedback", "复制反馈内容")) {
                    model.onCopy?()
                }
                .disabled(!model.canPrepare)

                Spacer()

                Button(L("Done", "完成")) {
                    model.onDone?()
                }

                Button(L("Review & Submit…", "检查并提交…")) {
                    model.onSubmit?()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canPrepare || !model.submissionConfigured)
            }
        }
        .padding(24)
        .frame(width: 620)
    }
}

@MainActor
final class FeedbackController: NSObject, NSWindowDelegate {
    private static let feedbackInfoKey = "CoveTypeFeedbackURL"

    private let model = FeedbackModel()
    private var window: NSWindow?

    override init() {
        super.init()
        model.submissionConfigured = Self.configuredFeedbackURL != nil
        model.onCopy = { [weak self] in self?.copyFeedback() }
        model.onSubmit = { [weak self] in self?.submitFeedback() }
        model.onDone = { [weak self] in self?.window?.close() }
    }

    func show() {
        if window == nil {
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 620, height: 710),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            newWindow.title = L("CoveType Feedback", "CoveType 使用反馈")
            newWindow.isReleasedWhenClosed = false
            newWindow.delegate = self
            newWindow.contentView = NSHostingView(rootView: FeedbackView(model: model))
            newWindow.center()
            window = newWindow
        }

        model.submissionConfigured = Self.configuredFeedbackURL != nil
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private static var configuredFeedbackURL: URL? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: feedbackInfoKey) as? String else {
            return nil
        }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              url.scheme?.lowercased() == "https" else {
            return nil
        }
        return url
    }

    private var feedbackTitle: String {
        let subject = model.subject.trimmingCharacters(in: .whitespacesAndNewlines)
        return "[CoveType][\(model.category.issueLabel)] \(String(subject.prefix(120)))"
    }

    private var feedbackBody: String {
        let details = model.details.trimmingCharacters(in: .whitespacesAndNewlines)
        var body = "### Feedback type\n\(model.category.issueLabel)\n\n### Details\n\(String(details.prefix(4_000)))"
        if model.includeSystemInfo {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
            let language = Locale.preferredLanguages.first ?? "Unknown"
            #if arch(arm64)
            let architecture = "arm64 (Apple silicon)"
            #elseif arch(x86_64)
            let architecture = "x86_64"
            #else
            let architecture = "Unknown"
            #endif
            body += """


            ### System information
            - CoveType: \(version)
            - macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
            - Language: \(language)
            - Architecture: \(architecture)
            """
        }
        return body
    }

    private func copyFeedback() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("\(feedbackTitle)\n\n\(feedbackBody)", forType: .string)
        model.statusMessage = L(
            "Feedback copied. You can paste it into an email or issue.",
            "反馈内容已复制，可以粘贴到邮件或问题单中。"
        )
    }

    private func submitFeedback() {
        guard let baseURL = Self.configuredFeedbackURL,
              var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            copyFeedback()
            model.statusMessage = L(
                "The online feedback channel is not configured yet. The feedback was copied instead.",
                "在线反馈地址尚未配置，已改为复制反馈内容。"
            )
            return
        }

        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "title", value: feedbackTitle))
        queryItems.append(URLQueryItem(name: "body", value: feedbackBody))
        components.queryItems = queryItems
        guard let destination = components.url else {
            model.statusMessage = L("Could not prepare the feedback link.", "无法生成反馈链接。")
            return
        }

        NSWorkspace.shared.open(destination)
        model.statusMessage = L(
            "The feedback draft opened in your browser. Review it before submitting.",
            "反馈草稿已在浏览器中打开，请检查后再提交。"
        )
    }
}

// MARK: - Menu Bar Breathing Lamp

@MainActor
final class StatusLampAnimator {
    private enum Style: Equatable {
        case idle
        case listening
        case processing
        case success
        case warning
        case updating
        case failure

        var palette: [NSColor] {
            switch self {
            case .idle:
                [
                    NSColor(srgbRed: 0.18, green: 0.92, blue: 0.91, alpha: 1),
                    NSColor(srgbRed: 0.31, green: 0.57, blue: 1.00, alpha: 1),
                    NSColor(srgbRed: 0.72, green: 0.43, blue: 1.00, alpha: 1)
                ]
            case .listening:
                [
                    NSColor(srgbRed: 1.00, green: 0.24, blue: 0.36, alpha: 1),
                    NSColor(srgbRed: 1.00, green: 0.50, blue: 0.22, alpha: 1),
                    NSColor(srgbRed: 1.00, green: 0.30, blue: 0.68, alpha: 1)
                ]
            case .processing:
                [
                    NSColor(srgbRed: 0.12, green: 0.82, blue: 1.00, alpha: 1),
                    NSColor(srgbRed: 0.22, green: 0.45, blue: 1.00, alpha: 1),
                    NSColor(srgbRed: 0.49, green: 0.33, blue: 1.00, alpha: 1)
                ]
            case .success:
                [
                    NSColor(srgbRed: 0.20, green: 0.94, blue: 0.58, alpha: 1),
                    NSColor(srgbRed: 0.08, green: 0.76, blue: 0.70, alpha: 1),
                    NSColor(srgbRed: 0.27, green: 0.58, blue: 1.00, alpha: 1)
                ]
            case .warning:
                [
                    NSColor(srgbRed: 1.00, green: 0.82, blue: 0.30, alpha: 1),
                    NSColor(srgbRed: 1.00, green: 0.47, blue: 0.20, alpha: 1),
                    NSColor(srgbRed: 1.00, green: 0.33, blue: 0.61, alpha: 1)
                ]
            case .updating:
                [
                    NSColor(srgbRed: 0.67, green: 0.42, blue: 1.00, alpha: 1),
                    NSColor(srgbRed: 0.31, green: 0.45, blue: 1.00, alpha: 1),
                    NSColor(srgbRed: 0.22, green: 0.83, blue: 1.00, alpha: 1)
                ]
            case .failure:
                [
                    NSColor(srgbRed: 1.00, green: 0.26, blue: 0.58, alpha: 1),
                    NSColor(srgbRed: 1.00, green: 0.24, blue: 0.34, alpha: 1),
                    NSColor(srgbRed: 1.00, green: 0.47, blue: 0.24, alpha: 1)
                ]
            }
        }

        var period: TimeInterval {
            switch self {
            case .listening: 0.86
            case .processing, .updating: 1.10
            case .success: 1.45
            case .warning, .failure: 1.20
            case .idle: 2.40
            }
        }
    }

    private weak var button: NSStatusBarButton?
    private let lampLayer = CALayer()
    private var style: Style?

    init(button: NSStatusBarButton?) {
        self.button = button
        button?.wantsLayer = true
        lampLayer.contentsGravity = .resizeAspect
        lampLayer.actions = ["contents": NSNull(), "bounds": NSNull(), "position": NSNull()]
        button?.layer?.addSublayer(lampLayer)
    }

    func setPhase(_ phase: AppPhase) {
        let nextStyle: Style = switch phase {
        case .idle: .idle
        case .recording: .listening
        case .transcribing: .processing
        case .done: .success
        case .permissions, .missingColi, .installingColi: .warning
        case .updating: .updating
        case .error: .failure
        }
        guard nextStyle != style || lampLayer.contents == nil else { return }
        style = nextStyle
        guard let button else { return }
        let image = Self.makeImage(style: nextStyle, progress: 0.88)
        var proposedRect = NSRect(origin: .zero, size: image.size)
        lampLayer.contents = image.cgImage(
            forProposedRect: &proposedRect,
            context: nil,
            hints: nil
        )
        lampLayer.contentsScale = button.window?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2
        let lampSize = NSSize(width: 22, height: 20)
        lampLayer.frame = NSRect(
            x: (button.bounds.width - lampSize.width) / 2,
            y: (button.bounds.height - lampSize.height) / 2,
            width: lampSize.width,
            height: lampSize.height
        )

        lampLayer.removeAnimation(forKey: "breathing")
        let breathing = CABasicAnimation(keyPath: "opacity")
        breathing.fromValue = 0.52
        breathing.toValue = 1.0
        breathing.duration = nextStyle.period / 2
        breathing.autoreverses = true
        breathing.repeatCount = .infinity
        breathing.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        breathing.isRemovedOnCompletion = false
        lampLayer.add(breathing, forKey: "breathing")
    }

    func updateLayout() {
        guard let button else { return }
        let lampSize = NSSize(width: 22, height: 20)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        lampLayer.frame = NSRect(
            x: (button.bounds.width - lampSize.width) / 2,
            y: (button.bounds.height - lampSize.height) / 2,
            width: lampSize.width,
            height: lampSize.height
        )
        CATransaction.commit()
    }

    private static func makeFrames(style: Style) -> [NSImage] {
        let frameCount = 30
        return (0..<frameCount).map { index in
            let progress = Double(index) / Double(frameCount)
            return makeImage(style: style, progress: progress)
        }
    }

    private static func makeImage(style: Style, progress: Double) -> NSImage {
        let size = NSSize(width: 22, height: 20)
        let breathe = (1 - cos(progress * 2 * .pi)) / 2
        let colors = style.palette
        let primary = colors[0]
        let middle = colors[1]
        let accent = colors[2]

        let image = NSImage(size: size, flipped: false) { _ in
            NSGraphicsContext.current?.shouldAntialias = true
            let center = NSPoint(x: size.width / 2, y: size.height / 2)

            // Soft outer halo. Its size and alpha change together so the lamp
            // visibly breathes without moving the menu-bar layout.
            let haloRadius = 9.15 + (0.55 * breathe)
            let haloGradient = NSGradient(colorsAndLocations:
                (primary.withAlphaComponent(0.24 + (0.13 * breathe)), 0.0),
                (middle.withAlphaComponent(0.14 + (0.09 * breathe)), 0.48),
                (accent.withAlphaComponent(0.0), 1.0)
            )
            haloGradient?.draw(
                fromCenter: center,
                radius: 0,
                toCenter: center,
                radius: haloRadius,
                options: [.drawsBeforeStartingLocation, .drawsAfterEndingLocation]
            )

            // Lamp glass ring.
            let glassRadius = 8.20 + (0.20 * breathe)
            let glassRect = NSRect(
                x: center.x - glassRadius,
                y: center.y - glassRadius,
                width: glassRadius * 2,
                height: glassRadius * 2
            )
            let glass = NSBezierPath(ovalIn: glassRect)
            let glassGradient = NSGradient(colors: [
                primary.withAlphaComponent(0.16 + (0.08 * breathe)),
                middle.withAlphaComponent(0.08 + (0.06 * breathe)),
                accent.withAlphaComponent(0.18 + (0.08 * breathe))
            ])
            glassGradient?.draw(in: glass, angle: -35)

            let ringWidth: CGFloat = 1.70
            let ring = NSBezierPath()
            ring.appendOval(in: glassRect)
            ring.appendOval(in: glassRect.insetBy(dx: ringWidth, dy: ringWidth))
            ring.windingRule = .evenOdd
            NSGraphicsContext.saveGraphicsState()
            ring.addClip()
            let ringGradient = NSGradient(colors: [primary, middle, accent, primary])
            ringGradient?.draw(in: glassRect, angle: 32)
            NSGraphicsContext.restoreGraphicsState()

            let gloss = NSBezierPath()
            gloss.appendArc(
                withCenter: center,
                radius: glassRadius - 0.85,
                startAngle: 52,
                endAngle: 142
            )
            gloss.lineWidth = 0.62
            NSColor.white.withAlphaComponent(0.42 + (0.22 * breathe)).setStroke()
            gloss.stroke()

            // Bright LED core.
            let coreRadius = 4.10 + (0.40 * breathe)
            let coreRect = NSRect(
                x: center.x - coreRadius,
                y: center.y - coreRadius,
                width: coreRadius * 2,
                height: coreRadius * 2
            )
            let core = NSBezierPath(ovalIn: coreRect)
            let coreGradient = NSGradient(colors: [
                primary.withAlphaComponent(0.98),
                middle.withAlphaComponent(0.96),
                accent.withAlphaComponent(0.92)
            ])
            coreGradient?.draw(in: core, angle: -42)

            let innerGlowRect = coreRect.insetBy(dx: 0.95, dy: 0.95)
            NSColor.white.withAlphaComponent(0.08 + (0.11 * breathe)).setFill()
            NSBezierPath(ovalIn: innerGlowRect).fill()

            let highlightRadius = 1.00
            let highlightRect = NSRect(
                x: center.x - 2.10,
                y: center.y + 1.05,
                width: highlightRadius * 2,
                height: highlightRadius * 2
            )
            NSColor.white.withAlphaComponent(0.48 + (0.30 * breathe)).setFill()
            NSBezierPath(ovalIn: highlightRect).fill()

            let sparkleRect = NSRect(
                x: center.x + 2.25,
                y: center.y - 2.65,
                width: 0.90,
                height: 0.90
            )
            accent.withAlphaComponent(0.78).setFill()
            NSBezierPath(ovalIn: sparkleRect).fill()
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = L("Local AI status lamp", "本地 AI 状态灯")
        return image
    }

    static func writePreviewStrip(to url: URL) -> Bool {
        let styles: [Style] = [.idle, .listening, .processing, .success, .warning, .updating, .failure]
        let tileSize = NSSize(width: 48, height: 48)
        let preview = NSImage(size: NSSize(width: tileSize.width * CGFloat(styles.count), height: tileSize.height))
        preview.lockFocus()
        NSColor.windowBackgroundColor.setFill()
        NSRect(origin: .zero, size: preview.size).fill()
        for (index, style) in styles.enumerated() {
            let icon = makeImage(style: style, progress: 0.72)
            let destination = NSRect(
                x: CGFloat(index) * tileSize.width + 6,
                y: 7.5,
                width: 36,
                height: 33
            )
            icon.draw(in: destination)
        }
        preview.unlockFocus()

        guard let tiffData = preview.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return false
        }
        do {
            try pngData.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Status Item

@MainActor
final class StatusItemController: NSObject {
    private enum MenuTag {
        static let record = 100
        static let update = 200
        static let microphone = 250
        static let hotkeyBase = 300
        static let triggerBase = 400
        static let polishBase = 600
        static let releaseMemory = 700
        static let translationBase = 800
        static let shortcutSettings = 900
        static let feedback = 950
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: 28)
    private var cancellable: AnyCancellable?
    private weak var appState: AppState?
    private var shortcutSettingsController: ShortcutSettingsController?
    private var feedbackController: FeedbackController?
    private var lampAnimator: StatusLampAnimator?

    init(appState: AppState) {
        self.appState = appState
        super.init()
        lampAnimator = StatusLampAnimator(button: statusItem.button)
        configureMenu()
        configureDragDrop()
        updateTitle(for: appState.phase)
        cancellable = appState.$phase.sink { [weak self] phase in
            self?.updateTitle(for: phase)
            self?.updateRecordMenuItem(for: phase)
        }
    }

    private func configureDragDrop() {
        guard let button = statusItem.button else { return }
        button.window?.registerForDraggedTypes([.fileURL])
        button.window?.delegate = self
    }

    private func configureMenu() {
        let menu = NSMenu()
        menu.delegate = self

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let aboutItem = NSMenuItem(title: "CoveType  v\(version)", action: nil, keyEquivalent: "")
        aboutItem.isEnabled = false
        menu.addItem(aboutItem)

        let localAIItem = NSMenuItem(
            title: L("Local AI · Qwen3-ASR + Qwen3.5-0.8B", "本地 AI · Qwen3-ASR + Qwen3.5-0.8B"),
            action: nil,
            keyEquivalent: ""
        )
        localAIItem.isEnabled = false
        menu.addItem(localAIItem)

        let translationEngineItem = NSMenuItem(
            title: L("Translation · Apple on-device", "翻译 · Apple 设备端模型"),
            action: nil,
            keyEquivalent: ""
        )
        translationEngineItem.isEnabled = false
        menu.addItem(translationEngineItem)

        menu.addItem(NSMenuItem.separator())

        let recordItem = NSMenuItem(
            title: L("Record · \(shortcutSummary)", "录音 · \(shortcutSummary)"),
            action: #selector(toggleRecording),
            keyEquivalent: ""
        )
        recordItem.target = self
        recordItem.tag = MenuTag.record
        menu.addItem(recordItem)

        let transcribeItem = NSMenuItem(title: L("Transcribe File to Clipboard...", "转录文件到剪贴板..."), action: #selector(transcribeFile), keyEquivalent: "")
        transcribeItem.target = self
        menu.addItem(transcribeItem)

        menu.addItem(NSMenuItem.separator())

        // Microphone sub-menu
        let microphoneItem = NSMenuItem(title: L("Microphone", "麦克风"), action: nil, keyEquivalent: "")
        microphoneItem.tag = MenuTag.microphone
        menu.setSubmenu(makeMicrophoneSubmenu(), for: microphoneItem)
        menu.addItem(microphoneItem)

        let asrItem = NSMenuItem(
            title: L(
                "Recognition · Auto-detect 30 languages",
                "识别语言 · 自动检测 30 种语言"
            ),
            action: nil,
            keyEquivalent: ""
        )
        asrItem.isEnabled = false
        menu.addItem(asrItem)

        let translationItem = NSMenuItem(title: L("Instant Translation", "即时翻译"), action: nil, keyEquivalent: "")
        let translationSubmenu = NSMenu()
        let translationHint = NSMenuItem(
            title: L("Language pack downloads on first use", "首次使用会下载对应语言包"),
            action: nil,
            keyEquivalent: ""
        )
        translationHint.isEnabled = false
        translationSubmenu.addItem(translationHint)
        translationSubmenu.addItem(NSMenuItem.separator())
        let currentTranslationTarget = UserDefaults.standard.translationTarget
        for (index, target) in TranslationTarget.allCases.enumerated() {
            let item = NSMenuItem(
                title: target.label,
                action: #selector(changeTranslationTarget(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = MenuTag.translationBase + index
            item.state = target == currentTranslationTarget ? .on : .off
            translationSubmenu.addItem(item)
        }
        menu.setSubmenu(translationSubmenu, for: translationItem)
        menu.addItem(translationItem)

        let polishItem = NSMenuItem(title: L("AI Polishing", "AI 润色"), action: nil, keyEquivalent: "")
        let polishSub = NSMenu()
        let polishHint = NSMenuItem(
            title: L("Used when translation is off", "关闭翻译时生效"),
            action: nil,
            keyEquivalent: ""
        )
        polishHint.isEnabled = false
        polishSub.addItem(polishHint)
        polishSub.addItem(NSMenuItem.separator())
        let currentPolish = UserDefaults.standard.polishMode
        for (index, mode) in PolishMode.allCases.enumerated() {
            let item = NSMenuItem(title: mode.label, action: #selector(changePolishMode(_:)), keyEquivalent: "")
            item.target = self
            item.tag = MenuTag.polishBase + index
            item.state = mode == currentPolish ? .on : .off
            polishSub.addItem(item)
        }
        menu.setSubmenu(polishSub, for: polishItem)
        menu.addItem(polishItem)

        let shortcutSettingsItem = NSMenuItem(
            title: L("Shortcut Settings…", "快捷键设置…"),
            action: #selector(openShortcutSettings),
            keyEquivalent: ""
        )
        shortcutSettingsItem.target = self
        shortcutSettingsItem.tag = MenuTag.shortcutSettings
        menu.addItem(shortcutSettingsItem)

        let shortcutsItem = NSMenuItem(title: L("Shortcut Status", "快捷键状态"), action: nil, keyEquivalent: "")
        let shortcutsSubmenu = NSMenu()
        let shortcutRows: [String]
        if UserDefaults.standard.customShortcutBinding != nil {
            shortcutRows = [
                L("Custom · \(shortcutSummary)", "自定义 · \(shortcutSummary)"),
                L("Hold \(holdDurationSummary) · Release to transcribe", "按住 \(holdDurationSummary) · 松开转录"),
                L("Esc · Cancel", "Esc · 取消")
            ]
        } else {
            shortcutRows = [
                L("Automatic · Fn / Option / Control", "自动 · Fn / Option / Control"),
                L("Hold \(holdDurationSummary) · Release to transcribe", "按住 \(holdDurationSummary) · 松开转录"),
                L("Fn + Space · Hands-free toggle", "Fn + 空格 · 免按住开关"),
                L("Esc · Cancel", "Esc · 取消")
            ]
        }
        for title in shortcutRows {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.isEnabled = false
            shortcutsSubmenu.addItem(item)
        }
        menu.setSubmenu(shortcutsSubmenu, for: shortcutsItem)
        menu.addItem(shortcutsItem)

        let releaseMemoryItem = NSMenuItem(
            title: L("Release Local AI Memory", "释放本地 AI 内存"),
            action: #selector(releaseLocalAIMemory),
            keyEquivalent: ""
        )
        releaseMemoryItem.tag = MenuTag.releaseMemory
        releaseMemoryItem.target = self
        menu.addItem(releaseMemoryItem)

        menu.addItem(NSMenuItem.separator())

        let updateItem = NSMenuItem(
            title: L("Custom Build Updates…", "定制版更新…"),
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        updateItem.target = self
        updateItem.tag = MenuTag.update
        menu.addItem(updateItem)

        let feedbackItem = NSMenuItem(
            title: L("Send Feedback…", "使用反馈…"),
            action: #selector(openFeedback),
            keyEquivalent: ""
        )
        feedbackItem.target = self
        feedbackItem.tag = MenuTag.feedback
        menu.addItem(feedbackItem)

        menu.addItem(NSMenuItem(title: L("Open Privacy Settings", "打开隐私设置"), action: #selector(openPrivacySettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: L("Quit CoveType", "退出 CoveType"), action: #selector(quit), keyEquivalent: "q"))

        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    private func makeMicrophoneSubmenu() -> NSMenu {
        let submenu = NSMenu()
        let selection = UserDefaults.standard.microphoneSelection

        let automaticItem = NSMenuItem(title: L("Automatic", "自动"), action: #selector(changeMicrophone(_:)), keyEquivalent: "")
        automaticItem.target = self
        automaticItem.state = selection == .automatic ? .on : .off
        submenu.addItem(automaticItem)

        let microphones = MicrophoneManager.availableMicrophones()
        if microphones.isEmpty {
            submenu.addItem(NSMenuItem.separator())
            let unavailableItem = NSMenuItem(title: L("No microphones found", "未找到麦克风"), action: nil, keyEquivalent: "")
            unavailableItem.isEnabled = false
            submenu.addItem(unavailableItem)
            return submenu
        }

        submenu.addItem(NSMenuItem.separator())

        for microphone in microphones {
            let item = NSMenuItem(title: microphone.localizedName, action: #selector(changeMicrophone(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = microphone.uniqueID
            item.state = selection.uniqueID == microphone.uniqueID ? .on : .off
            submenu.addItem(item)
        }

        if case .specific(let selectedID) = selection,
           microphones.contains(where: { $0.uniqueID == selectedID }) == false {
            submenu.addItem(NSMenuItem.separator())
            let unavailableItem = NSMenuItem(title: L("Selected microphone unavailable", "已选麦克风不可用"), action: nil, keyEquivalent: "")
            unavailableItem.isEnabled = false
            unavailableItem.state = .on
            submenu.addItem(unavailableItem)
        }

        return submenu
    }

    private func refreshMicrophoneSubmenu() {
        guard let menu = statusItem.menu,
              let microphoneItem = menu.item(withTag: MenuTag.microphone) else { return }
        menu.setSubmenu(makeMicrophoneSubmenu(), for: microphoneItem)
    }

    private func updateRecordMenuItem(for phase: AppPhase) {
        guard let item = statusItem.menu?.item(withTag: MenuTag.record) else { return }
        switch phase {
        case .recording:
            item.title = L("Stop Recording", "停止录音")
        default:
            item.title = L("Record · \(shortcutSummary)", "录音 · \(shortcutSummary)")
        }
    }

    private var shortcutSummary: String {
        UserDefaults.standard.customShortcutBinding?.displayName ?? "Fn / Option / Control"
    }

    private var holdDurationSummary: String {
        String(format: "%.2f s", UserDefaults.standard.shortcutHoldDuration)
    }

    private func updateTitle(for phase: AppPhase) {
        guard let button = statusItem.button else { return }
        lampAnimator?.setPhase(phase)
        button.title = ""
        button.image = nil
        button.imagePosition = .noImage
        lampAnimator?.updateLayout()
        button.toolTip = switch phase {
        case .idle: L("Ready · Local AI", "就绪 · 本地 AI")
        case .recording: L("Listening…", "正在聆听…")
        case .transcribing: L("Processing locally…", "正在本地处理…")
        case .done: L("Ready to insert", "等待输入")
        case .permissions: L("Permission required", "需要权限")
        case .missingColi, .installingColi: L("Local AI setup required", "需要配置本地 AI")
        case .updating: L("Checking custom updates…", "正在检查定制版更新…")
        case .error: L("CoveType needs attention", "CoveType 需要处理")
        }
    }

    @objc private func changeHotkey(_ sender: NSMenuItem) {
        let idx = sender.tag - MenuTag.hotkeyBase
        guard let mod = HotkeyModifier.allCases[safe: idx] else { return }
        UserDefaults.standard.hotkeyModifier = mod
        // Update checkmarks
        sender.menu?.items.forEach { $0.state = $0.tag == sender.tag ? .on : .off }
        // Refresh title + record item
        if let phase = appState?.phase {
            updateTitle(for: phase)
            updateRecordMenuItem(for: phase)
        }
        NotificationCenter.default.post(name: .hotkeyConfigChanged, object: nil)
    }

    @objc private func changeMicrophone(_ sender: NSMenuItem) {
        if let uniqueID = sender.representedObject as? String {
            UserDefaults.standard.microphoneSelection = .specific(uniqueID)
        } else {
            UserDefaults.standard.microphoneSelection = .automatic
        }
        refreshMicrophoneSubmenu()
    }

    @objc private func changeTriggerMode(_ sender: NSMenuItem) {
        let idx = sender.tag - MenuTag.triggerBase
        guard let mode = TriggerMode.allCases[safe: idx] else { return }
        UserDefaults.standard.triggerMode = mode
        sender.menu?.items.forEach { $0.state = $0.tag == sender.tag ? .on : .off }
        NotificationCenter.default.post(name: .hotkeyConfigChanged, object: nil)
    }

    @objc private func changePolishMode(_ sender: NSMenuItem) {
        let index = sender.tag - MenuTag.polishBase
        guard let mode = PolishMode.allCases[safe: index] else { return }
        UserDefaults.standard.polishMode = mode
        sender.menu?.items.forEach { $0.state = $0.tag == sender.tag ? .on : .off }
    }

    @objc private func changeTranslationTarget(_ sender: NSMenuItem) {
        let index = sender.tag - MenuTag.translationBase
        guard let target = TranslationTarget.allCases[safe: index] else { return }
        UserDefaults.standard.translationTarget = target
        sender.menu?.items.forEach { $0.state = $0.tag == sender.tag ? .on : .off }
    }

    @objc private func releaseLocalAIMemory() {
        Task { @MainActor [weak appState] in
            await appState?.releaseLocalAIMemory()
        }
    }

    @objc private func openPrivacySettings() {
        PermissionManager.openPrivacySettings(for: [])
    }

    @objc private func openShortcutSettings() {
        showShortcutSettings()
    }

    func showShortcutSettings() {
        if shortcutSettingsController == nil {
            shortcutSettingsController = ShortcutSettingsController { [weak self] in
                self?.configureMenu()
            }
        }
        shortcutSettingsController?.show()
    }

    @objc private func openFeedback() {
        if feedbackController == nil {
            feedbackController = FeedbackController()
        }
        feedbackController?.show()
    }

    @objc private func toggleRecording() {
        appState?.onToggleRequest?()
    }

    @objc private func checkForUpdates() {
        appState?.onUpdateRequest?()
    }

    func setUpdateAvailable(_ version: String) {
        guard let item = statusItem.menu?.item(withTag: MenuTag.update) else { return }
        item.title = L("Update Available (v\(version))", "有新版本 (v\(version))")
    }

    @objc private func transcribeFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            .init(filenameExtension: "m4a")!,
            .init(filenameExtension: "mp3")!,
            .init(filenameExtension: "wav")!,
            .init(filenameExtension: "aac")!
        ]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose an audio file — result will be copied to clipboard"

        if panel.runModal() == .OK, let url = panel.url {
            Task { @MainActor in
                await appState?.transcribeFile(url)
            }
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

extension StatusItemController: NSWindowDelegate, NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        refreshMicrophoneSubmenu()
    }

    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let items = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              let url = items.first,
              ["m4a", "mp3", "wav", "aac"].contains(url.pathExtension.lowercased()) else {
            return []
        }
        return .copy
    }

    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let items = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              let url = items.first else {
            return false
        }

        Task { @MainActor in
            await appState?.transcribeFile(url)
        }
        return true
    }
}

// MARK: - Overlay Panel

@MainActor
final class EscapeAwarePanel: NSPanel {
    var onEscape: (() -> Void)?
    var onReturn: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onEscape?()
            return
        }
        if event.keyCode == 36 || event.keyCode == 76 {  // Return or Enter
            onReturn?()
            return
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}

@MainActor
final class OverlayPanelController {
    private let hudPanel: NSPanel
    private let capturePanel: EscapeAwarePanel
    private let hudHostingView: NSHostingView<OverlayView>
    private let captureHostingView: NSHostingView<OverlayView>
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        hudHostingView = NSHostingView(
            rootView: OverlayView(appState: appState, hostsSystemTranslation: false)
        )
        captureHostingView = NSHostingView(
            rootView: OverlayView(appState: appState, hostsSystemTranslation: true)
        )

        hudPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        capturePanel = EscapeAwarePanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        configure(panel: hudPanel, contentView: hudHostingView)
        configure(panel: capturePanel, contentView: captureHostingView)
        capturePanel.onEscape = { [weak appState] in
            appState?.onCancel?()
        }
        capturePanel.onReturn = { [weak appState] in
            appState?.onConfirm?()
        }
    }

    func show() {
        let activePanel = panel(for: appState.phase)
        let activeHostingView = hostingView(for: appState.phase)
        let inactivePanel = inactivePanel(for: appState.phase)

        activeHostingView.invalidateIntrinsicContentSize()
        let idealSize = activeHostingView.fittingSize
        let width = max(idealSize.width, 240)
        let height = max(idealSize.height, 44)

        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let x: CGFloat
            let y: CGFloat

            if case .permissions = appState.phase {
                x = frame.maxX - width - 16
                y = frame.maxY - height - 16
            } else if case .missingColi = appState.phase {
                x = frame.maxX - width - 16
                y = frame.maxY - height - 16
            } else if case .installingColi = appState.phase {
                x = frame.maxX - width - 16
                y = frame.maxY - height - 16
            } else {
                // Recording/transcription bar: center bottom
                x = frame.midX - width / 2
                y = frame.minY + 48
            }

            let panelFrame = NSRect(x: x, y: y, width: width, height: height)
            activePanel.setFrame(panelFrame, display: true)
        } else {
            activePanel.setContentSize(NSSize(width: width, height: height))
        }

        if shouldCaptureKeyboard(for: appState.phase) {
            NSApp.activate(ignoringOtherApps: true)
            capturePanel.makeKeyAndOrderFront(nil)
            capturePanel.makeFirstResponder(capturePanel.contentView)
        } else {
            activePanel.orderFrontRegardless()
        }
        inactivePanel.orderOut(nil)
    }

    func hide() {
        hudPanel.orderOut(nil)
        capturePanel.orderOut(nil)
    }

    private func shouldCaptureKeyboard(for phase: AppPhase) -> Bool {
        switch phase {
        case .transcribing, .done:
            true
        default:
            false
        }
    }

    private func configure(panel: NSPanel, contentView: NSView) {
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.contentView = contentView
    }

    private func panel(for phase: AppPhase) -> NSPanel {
        shouldCaptureKeyboard(for: phase) ? capturePanel : hudPanel
    }

    private func hostingView(for phase: AppPhase) -> NSHostingView<OverlayView> {
        shouldCaptureKeyboard(for: phase) ? captureHostingView : hudHostingView
    }

    private func inactivePanel(for phase: AppPhase) -> NSPanel {
        shouldCaptureKeyboard(for: phase) ? hudPanel : capturePanel
    }
}

// MARK: - Overlay View

struct ListeningWaveform: View {
    let level: Double
    private let barWeights = [0.42, 0.68, 0.9, 1.0, 0.82, 0.62, 0.38]

    var body: some View {
        HStack(spacing: 9) {
            microphoneBadge
            waveformBars
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.cyan.opacity(0.25), .purple.opacity(0.14)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 0.75
                )
        )
    }

    private var microphoneBadge: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.cyan.opacity(0.95), .blue.opacity(0.9), .purple.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 28)
                .shadow(color: .cyan.opacity(0.35), radius: 8)

            Image(systemName: "mic.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private var waveformBars: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            HStack(spacing: 3) {
                ForEach(barWeights.indices, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(barGradient)
                        .frame(
                            width: 3.5,
                            height: barHeight(
                                at: index,
                                time: timeline.date.timeIntervalSinceReferenceDate
                            )
                        )
                        .shadow(color: .blue.opacity(0.25), radius: 3)
                }
            }
            .frame(width: 43, height: 28)
            .animation(.spring(response: 0.13, dampingFraction: 0.72), value: level)
        }
    }

    private var barGradient: LinearGradient {
        LinearGradient(
            colors: [.cyan, .blue.opacity(0.95), .purple.opacity(0.9)],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    private func barHeight(at index: Int, time: TimeInterval) -> Double {
        let idleMotion = 0.05 + 0.035 * (sin(time * 4.2 + Double(index) * 0.9) + 1)
        let energy = min(max(level, idleMotion), 1)
        return 4 + 22 * energy * barWeights[index]
    }
}

@available(macOS 15.0, *)
struct SystemTranslationHost: View {
    @ObservedObject var bridge: SystemTranslationBridge
    @State private var configuration: TranslationSession.Configuration?

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onChange(of: bridge.request?.id, initial: true) { _, _ in
                refreshConfiguration()
            }
            .translationTask(configuration) { session in
                guard let request = bridge.request else { return }
                do {
                    let response = try await session.translate(request.text)
                    bridge.complete(requestID: request.id, result: .success(response.targetText))
                } catch {
                    bridge.complete(requestID: request.id, result: .failure(error))
                }
            }
    }

    private func refreshConfiguration() {
        guard let request = bridge.request else {
            configuration = nil
            return
        }

        let target = Locale.Language(identifier: request.targetLocaleIdentifier)
        if configuration?.target == target, configuration?.source == nil {
            configuration?.invalidate()
        } else {
            configuration = TranslationSession.Configuration(source: nil, target: target)
        }
    }
}

struct OverlayView: View {
    @ObservedObject var appState: AppState
    let hostsSystemTranslation: Bool

    var body: some View {
        Group {
            switch appState.phase {
            case .permissions(let missing):
                permissionView(missing: missing)
            case .missingColi:
                missingColiView
            case .installingColi(let message):
                installingColiView(message: message)
            case .idle:
                EmptyView()
            default:
                compactView
            }
        }
        .fixedSize()
        .background {
            if hostsSystemTranslation {
                if #available(macOS 15.0, *) {
                    SystemTranslationHost(bridge: appState.systemTranslation)
                }
            }
        }
    }

    var compactView: some View {
        HStack(spacing: 8) {
            // Left indicator
            if case .recording = appState.phase {
                ListeningWaveform(level: appState.microphoneLevel)
            } else if case .transcribing = appState.phase {
                ProgressView()
                    .controlSize(.mini)
            } else if case .updating = appState.phase {
                ProgressView()
                    .controlSize(.mini)
            }

            // Recording intentionally has no transcript/subtitle. The waveform
            // reflects microphone energy without running a second ASR engine.
            Group {
                if case .done(let text) = appState.phase {
                    Text(text)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.head)
                } else if case .recording = appState.phase {
                    EmptyView()
                } else if case .error = appState.phase {
                    Text(appState.phase.subtitle)
                        .foregroundStyle(.red.opacity(0.9))
                        .font(.system(size: 12))
                        .lineLimit(8)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(appState.phase.subtitle)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
            .font(.system(size: 14))

            Spacer(minLength: 0)

            // Right side: timer or error dismiss
            if case .recording = appState.phase {
                Text(appState.recordingElapsedStr)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.68))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                    .fixedSize()
            }

            if case .error = appState.phase {
                Button {
                    appState.onCancel?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minWidth: compactMinimumWidth, maxWidth: 480)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.10, blue: 0.16),
                            Color(red: 0.12, green: 0.08, blue: 0.17)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.cyan.opacity(0.2), .purple.opacity(0.15), .white.opacity(0.05)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 0.75
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
    }

    private var compactMinimumWidth: CGFloat {
        if case .recording = appState.phase {
            return 250
        }
        return 360
    }

    func permissionView(missing: Set<PermissionKind>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(missing.sorted { $0.title < $1.title }), id: \.self) { kind in
                HStack(spacing: 12) {
                    Image(systemName: kind.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(kind.title)
                            .font(.system(size: 13, weight: .medium))
                        Text(kind.explanation)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(L("Open Settings", "打开设置")) {
                        appState.onPermissionOpen?(kind)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }

            HStack {
                Text(L("Checking automatically...", "自动检测中..."))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button(L("Cancel", "取消")) {
                    appState.onCancel?()
                }
                .buttonStyle(.borderless)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 380)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    var missingColiView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 16))
                    .foregroundStyle(.orange)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Node.js Required", "需要 Node.js"))
                        .font(.system(size: 13, weight: .medium))
                    Text(L("Install Node.js first, then CoveType will set up automatically.", "请先安装 Node.js，CoveType 将自动配置。"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                Text("https://nodejs.org")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 36)

                Button(action: {
                    if let url = URL(string: "https://nodejs.org") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 10))
                }
                .buttonStyle(.borderless)
                .help("Open nodejs.org")
            }

            HStack {
                Text(L("Checking automatically...", "自动检测中..."))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button(L("Cancel", "取消")) {
                    appState.onCancel?()
                }
                .buttonStyle(.borderless)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 400)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    func installingColiView(message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Setting up speech engine", "配置语音引擎"))
                        .font(.system(size: 13, weight: .medium))
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .padding(16)
        .frame(width: 400)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }
}

// MARK: - Update Service

final class UpdateService: @unchecked Sendable {
    private static let manifestInfoKey = "CoveTypeUpdateManifestURL"
    private static let channelInfoKey = "CoveTypeUpdateChannelIdentifier"

    struct ReleaseInfo {
        let version: String
        let releasePageURL: URL
    }

    enum CheckResult {
        case updateAvailable(ReleaseInfo)
        case upToDate
        case channelNotConfigured
        case failed
    }

    func checkForUpdate() async -> ReleaseInfo? {
        switch await checkForUpdateDetailed() {
        case .updateAvailable(let info): return info
        default: return nil
        }
    }

    func checkForUpdateDetailed(currentVersionOverride: String? = nil) async -> CheckResult {
        guard let manifestURL = Self.configuredManifestURL else {
            return .channelNotConfigured
        }

        do {
            var request = URLRequest(url: manifestURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 12
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("CoveType/\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0")", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return .failed
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return .failed
            }

            guard let channel = json["channel"] as? String,
                  channel == Self.channelIdentifier,
                  let bundleIdentifier = json["bundle_identifier"] as? String,
                  bundleIdentifier == Bundle.main.bundleIdentifier,
                  let remoteVersion = json["version"] as? String,
                  let releasePageString = json["release_page_url"] as? String,
                  let releasePageURL = URL(string: releasePageString),
                  releasePageURL.scheme == "https" else {
                return .failed
            }

            let currentVersion = currentVersionOverride
                ?? Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
                ?? "0"

            guard Self.isNewer(remote: remoteVersion, current: currentVersion) else {
                return .upToDate
            }

            return .updateAvailable(ReleaseInfo(version: remoteVersion, releasePageURL: releasePageURL))
        } catch {
            return .failed
        }
    }

    private static var configuredManifestURL: URL? {
        let environmentValue = ProcessInfo.processInfo.environment["COVETYPE_UPDATE_MANIFEST_URL"]
        let bundledValue = Bundle.main.object(forInfoDictionaryKey: manifestInfoKey) as? String
        guard let rawValue = [environmentValue, bundledValue]
            .compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }),
              let url = URL(string: rawValue),
              url.scheme == "https" else {
            return nil
        }
        return url
    }

    private static var channelIdentifier: String {
        if let bundledValue = Bundle.main.object(forInfoDictionaryKey: channelInfoKey) as? String {
            let trimmed = bundledValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return "covetype-local-ai-stable"
    }

    private static func isNewer(remote: String, current: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let c = current.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, c.count) {
            let rv = i < r.count ? r[i] : 0
            let cv = i < c.count ? c[i] : 0
            if rv > cv { return true }
            if rv < cv { return false }
        }
        return false
    }
}

// MARK: - Entry Point

if let diagnosticIndex = CommandLine.arguments.firstIndex(of: "--keyboard-diagnostic") {
    let requestedDuration = CommandLine.arguments[safe: diagnosticIndex + 1].flatMap(TimeInterval.init) ?? 15
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let diagnosticSession = KeyboardDiagnosticSession(duration: requestedDuration)
    diagnosticSession.start()
    app.run()
} else if CommandLine.arguments.contains("--permission-status") {
    let status = PermissionManager.cachedOrCurrentStatusJSON()
    print(status.json)
    exit(status.ready ? EXIT_SUCCESS : 2)
} else if CommandLine.arguments.contains("--hotkey-self-test") {
    Task { @MainActor in
        let passed = await HotkeyMonitor.runSelfTest()
        exit(passed ? EXIT_SUCCESS : EXIT_FAILURE)
    }
    RunLoop.main.run()
} else if CommandLine.arguments.contains("--update-channel-self-test") {
    Task {
        let currentVersionOverride = ProcessInfo.processInfo.environment["COVETYPE_UPDATE_TEST_CURRENT_VERSION"]
        let result = await UpdateService().checkForUpdateDetailed(
            currentVersionOverride: currentVersionOverride
        )
        let passed: Bool
        let detail: String
        switch result {
        case .upToDate:
            passed = true
            detail = "UP_TO_DATE"
        case .updateAvailable(let release):
            passed = true
            detail = "UPDATE_AVAILABLE version=\(release.version) url=\(release.releasePageURL.absoluteString)"
        case .channelNotConfigured:
            passed = false
            detail = "CHANNEL_NOT_CONFIGURED"
        case .failed:
            passed = false
            detail = "CHANNEL_CHECK_FAILED"
        }
        print("CUSTOM_UPDATE_CHANNEL_SELF_TEST_RESULT=\(passed ? "PASS" : "FAIL") \(detail)")
        exit(passed ? EXIT_SUCCESS : EXIT_FAILURE)
    }
    RunLoop.main.run()
} else if CommandLine.arguments.contains("--telemetry-self-test") {
    let passed = TelemetryService.runSelfTest()
    print("ANONYMOUS_USAGE_TELEMETRY_SELF_TEST_RESULT=\(passed ? "PASS" : "FAIL")")
    exit(passed ? EXIT_SUCCESS : EXIT_FAILURE)
} else if CommandLine.arguments.contains("--audio-pipeline-self-test") {
    let passed = AudioRecorder.runAudioPipelineSelfTest()
    print("AUDIO_PIPELINE_SELF_TEST_RESULT=\(passed ? "PASS" : "FAIL")")
    exit(passed ? EXIT_SUCCESS : EXIT_FAILURE)
} else if let previewIndex = CommandLine.arguments.firstIndex(of: "--render-status-lamp-preview"),
          let previewPath = CommandLine.arguments[safe: previewIndex + 1] {
    Task { @MainActor in
        let passed = StatusLampAnimator.writePreviewStrip(to: URL(fileURLWithPath: previewPath))
        print("STATUS_LAMP_PREVIEW_RESULT=\(passed ? "PASS" : "FAIL")")
        exit(passed ? EXIT_SUCCESS : EXIT_FAILURE)
    }
    RunLoop.main.run()
} else if let flagIndex = CommandLine.arguments.firstIndex(of: "--local-ai-self-test"),
   let audioPath = CommandLine.arguments[safe: flagIndex + 1] {
    let service = LocalAIService()
    Task.detached {
        do {
            await service.prewarm(loadASR: true, loadPolisher: true)
            let raw = try await service.transcribe(fileURL: URL(fileURLWithPath: audioPath))
            print("SELF_TEST_RAW=\(raw)")
            do {
                let polished = try await service.polish(text: raw, mode: .light)
                print("SELF_TEST_POLISHED=\(polished)")
            } catch {
                // Production dictation returns the validated ASR text when the
                // optional small polishing model rejects or over-rewrites it.
                print("SELF_TEST_POLISH_FALLBACK=PASS reason=\(error.localizedDescription)")
            }
            service.shutdown()
            exit(EXIT_SUCCESS)
        } catch {
            fputs("SELF_TEST_ERROR=\(error.localizedDescription)\n", stderr)
            service.shutdown()
            exit(EXIT_FAILURE)
        }
    }
    RunLoop.main.run()
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
