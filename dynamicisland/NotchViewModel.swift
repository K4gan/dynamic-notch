//
//  NotchViewModel.swift
//  DynamicNotch
//
//  Created for Dynamic Notch utility app
//

import SwiftUI
import AppKit
import Combine
import SystemConfiguration
import OSLog
import UserNotifications
import CoreGraphics
import ApplicationServices
import Darwin

enum PomodoroMode: String, Codable {
    case work = "Work"
    case shortBreak = "Break"
    
    var displayTitle: String {
        switch self {
        case .work:
            return "Çalışma"
        case .shortBreak:
            return "Mola"
        }
    }
    
    var duration: Int {
        switch self {
        case .work:
            return 25 * 60
        case .shortBreak:
            return 5 * 60
        }
    }
    
    var accentColor: Color {
        switch self {
        case .work:
            return .purple
        case .shortBreak:
            return .green
        }
    }
}

struct ChatMessage: Identifiable, Equatable {
    enum Role: String, Codable {
        case user = "user"
        case assistant = "model"
    }
    
    let id = UUID()
    let role: Role
    let text: String
    var isError: Bool = false
}

struct ClipboardFileItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let addedAt = Date()
    
    var displayName: String {
        url.lastPathComponent
    }
}
class NotchViewModel: ObservableObject {
    @Published var isExpanded: Bool = false
    @Published var volume: Double = 0.5
    @Published var brightness: Double = 0.5
    
    
    // System Info
    @Published var cpuUsage: Double = 0.0
    @Published var ramUsage: Double = 0.0
    @Published var diskUsage: Double = 0.0
    @Published var gpuUsage: Double = 0.0
    @Published var networkSpeed: String = "0 MB/s"
    @Published var internetDownloadSpeed: String = "--"
    @Published var internetUploadSpeed: String = "--"
    
    // Clipboard Manager (Dil)
    @Published var clipboardItems: [String] = []
    @Published var hasFileInClipboard: Bool = false
    @Published var storedFiles: [ClipboardFileItem] = []
    
    // Pomodoro Timer
    @Published var pomodoroTimeRemaining: Int = 25 * 60 // 25 minutes in seconds
    @Published var isPomodoroRunning: Bool = false
    @Published var pomodoroMode: PomodoroMode = .work
    
    var pomodoroFormattedTime: String {
        let minutes = pomodoroTimeRemaining / 60
        let seconds = pomodoroTimeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var pomodoroProgress: Double {
        let total = max(1, pomodoroMode.duration)
        let consumed = total - min(total, pomodoroTimeRemaining)
        return Double(consumed) / Double(total)
    }
    
    // Speed Test
    @Published var isSpeedTestRunning: Bool = false
    @Published var downloadSpeed: String = "--"
    @Published var uploadSpeed: String = "--"
    @Published var speedTestError: String? = nil
    
    private var brightnessUpdateTimer: Timer?
    private var lastBrightnessValue: Double = 0.5
    private var systemBrightnessAtStart: Double = 0.5
    private var mouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var window: NotchWindow?
    private var cancellables = Set<AnyCancellable>()
    private var systemInfoTimer: Timer?
    private var pomodoroTimer: Timer?
    private var clipboardMonitor: Timer?
    private var speedTestTimer: Timer?
    private var previousCPULoad: host_cpu_load_info?
    private let systemInfoQueue = DispatchQueue(label: "app.dynamicisland.systemInfo", qos: .utility)
    private let geminiAPIKey = "AIzaSyCCzDmjBS3D0o2wlmP_JXRKHm72Jrt6Q6M"
    private let geminiModelCandidates = [
        "gemini-2.5-flash",
        "gemini-2.5-pro",
        "gemini-1.5-flash",
        "gemini-1.5-pro",
        "gemini-1.0-pro",
        "gemini-pro"
    ]
    private let maxChatHistory = 14
    
    // Track last update times for individual metrics
    private var lastCPUUpdate: Date = Date.distantPast
    private var lastRAMUpdate: Date = Date.distantPast
    private var lastDiskUpdate: Date = Date.distantPast
    private var lastGPUUpdate: Date = Date.distantPast
    
    // Settings - Individual refresh intervals
    @Published var cpuRefreshInterval: Double = 3.0 // seconds
    @Published var ramRefreshInterval: Double = 3.0 // seconds
    @Published var diskRefreshInterval: Double = 5.0 // seconds
    @Published var gpuRefreshInterval: Double = 3.0 // seconds
    @Published var internetSpeedRefreshInterval: Double = 30.0 // seconds (default 30s for speed test)
    @Published var clipboardRefreshInterval: Double = 5.0 // seconds
    
    // Legacy setting (for backward compatibility)
    @Published var refreshInterval: Double = 5.0 // seconds
    @Published var showSettings: Bool = false
    
    // AI Chat
    @Published var chatMessages: [ChatMessage] = [
        ChatMessage(role: .assistant, text: "Merhaba! Dynamic Notch üzerinden sana yardımcı olmaya hazırım. Bugün ne yapmak istersin?")
    ]
    @Published var chatInput: String = ""
    @Published var isChatLoading: Bool = false
    @Published var chatError: String?
    
    init() {
        // Request permissions on first launch
        requestAllPermissions()
        
        setupMouseTracking()
        setupVolumeControl()
        volume = getCurrentVolume()
        brightness = getCurrentBrightness()
        startSystemInfoUpdates()
        setupClipboardMonitoring()
    }
    
    // MARK: - Permissions
    func requestAllPermissions() {
        fputs("🔐 [Permissions] İzinler kontrol ediliyor...\n", stderr)
        fflush(stderr)
        
        // Check and request Accessibility permission (for screen recording, brightness control)
        checkAccessibilityPermission()
        
        // Check and request Screen Recording permission
        checkScreenRecordingPermission()
        
        // Note: Other permissions (like Full Disk Access) are requested automatically
        // when the user tries to use features that require them
    }
    
    private func checkAccessibilityPermission() {
        // Check if Accessibility permission is granted
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if accessEnabled {
            fputs("✅ [Permissions] Erişilebilirlik izni mevcut\n", stderr)
            fflush(stderr)
        } else {
            fputs("⚠️ [Permissions] Erişilebilirlik izni gerekli\n", stderr)
            fputs("📝 [Permissions] Sistem Tercihleri > Güvenlik > Erişilebilirlik'e gidin ve uygulamaya izin verin\n", stderr)
            fflush(stderr)
            
            // Show alert to user
            DispatchQueue.main.async {
                self.showPermissionAlert(
                    title: "Erişilebilirlik İzni Gerekli",
                    message: "Ekran kaydı ve parlaklık kontrolü için erişilebilirlik izni gereklidir.\n\nSistem Tercihleri > Güvenlik ve Gizlilik > Erişilebilirlik'e gidin ve bu uygulamaya izin verin.",
                    buttonTitle: "Sistem Tercihlerini Aç"
                ) {
                    // Open System Preferences to Accessibility
                    self.openSystemPreferences(to: "com.apple.preference.security?Privacy_Accessibility")
                }
            }
        }
    }
    
    private func checkScreenRecordingPermission() {
        // Check Screen Recording permission by trying to create a screen capture
        // Note: This will trigger the permission dialog if not granted
        let displayID = CGMainDisplayID()
        
        // Try to get display bounds (this requires Screen Recording permission)
        _ = CGDisplayBounds(displayID)
        
        // If we can't get bounds, permission might be needed
        // Note: This is a simple check, actual permission is requested when recording starts
        fputs("📹 [Permissions] Ekran kaydı izni kontrol edildi\n", stderr)
        fflush(stderr)
        
        // Show informational alert about Screen Recording permission
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Check if we need to show alert (only once)
            if !UserDefaults.standard.bool(forKey: "hasShownScreenRecordingAlert") {
                self.showPermissionAlert(
                    title: "Ekran Kaydı İzni",
                    message: "Ekran kaydı özelliğini kullanmak için ekran kaydı izni gereklidir.\n\nİlk kullanımda macOS izin isteyecektir.",
                    buttonTitle: "Tamam"
                ) {
                    UserDefaults.standard.set(true, forKey: "hasShownScreenRecordingAlert")
                }
            }
        }
    }
    
    private func showPermissionAlert(title: String, message: String, buttonTitle: String, action: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: buttonTitle)
        alert.addButton(withTitle: "İptal")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            action()
        }
    }
    
    private func openSystemPreferences(to pane: String) {
        // Open System Preferences to specific pane
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["x-apple.systempreferences:\(pane)"]
        
        do {
            try task.run()
            fputs("✅ [Permissions] Sistem Tercihleri açıldı\n", stderr)
            fflush(stderr)
        } catch {
            fputs("❌ [Permissions] Sistem Tercihleri açılamadı: \(error.localizedDescription)\n", stderr)
            fflush(stderr)
        }
    }
    
    func setWindow(_ window: NotchWindow) {
        self.window = window
    }
    
    // MARK: - Mouse Tracking
    private func setupMouseTracking() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handleMouseMove(event)
        }
        
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handleMouseMove(event)
            return event
        }
    }
    
    private func handleMouseMove(_ event: NSEvent) {
        guard let screen = NSScreen.main, let window = window else { return }
        
        let mouseLocation = NSEvent.mouseLocation
        let screenHeight = screen.frame.height
        let mouseY = mouseLocation.y
        let mouseX = mouseLocation.x
        
        let windowFrame = window.frame
        let isInsideWindow = mouseX >= windowFrame.minX && 
                            mouseX <= windowFrame.maxX &&
                            mouseY >= windowFrame.minY && 
                            mouseY <= windowFrame.maxY
        
        let notchWidth: CGFloat = 250
        let screenWidth = screen.frame.width
        let notchLeft = (screenWidth - notchWidth) / 2
        let notchRight = notchLeft + notchWidth
        
        let isInNotchArea = mouseY > (screenHeight - 40) && 
                           mouseX >= notchLeft && 
                           mouseX <= notchRight
        
        if isInNotchArea && !isExpanded {
            expand()
        } else if isExpanded && !isInsideWindow && !isInNotchArea {
            collapse()
        }
    }
    
    func handleMouseEnter() {
        expand()
    }
    
    func handleMouseExit() {
        if isExpanded {
            collapse()
        }
    }
    
    private func expand() {
        guard !isExpanded else { return }
        
        systemBrightnessAtStart = brightness
        lastBrightnessValue = brightness
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isExpanded = true
        }
        
        window?.setExpanded(true, animated: true)
        restartSystemInfoTimer()
        restartClipboardMonitor()
        restartSpeedTestTimer()
        updateSystemInfo()
    }
    
    private func collapse() {
        guard isExpanded else { return }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isExpanded = false
        }
        
        window?.setExpanded(false, animated: true)
        pauseSystemInfoTimer()
        clipboardMonitor?.invalidate()
        clipboardMonitor = nil
        speedTestTimer?.invalidate()
        speedTestTimer = nil
    }
    
    // MARK: - Volume & Brightness
    func setVolume(_ value: Double) {
        let clampedValue = max(0, min(1, value))
        volume = clampedValue
        
        let volumePercent = Int(clampedValue * 100)
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", "set volume output volume \(volumePercent)"]
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try task.run()
                task.waitUntilExit()
            } catch {
                print("Error setting volume: \(error)")
            }
        }
    }
    
    func setBrightness(_ value: Double, immediate: Bool = false) {
        let clampedValue = max(0, min(1, value))
        brightness = clampedValue
        
        brightnessUpdateTimer?.invalidate()
        
        if immediate {
            applyBrightnessChange(value: clampedValue)
        } else {
            brightnessUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                self?.applyBrightnessChange(value: clampedValue)
            }
        }
    }
    
    private func applyBrightnessChange(value: Double) {
        let currentSteps = Int((lastBrightnessValue * 16).rounded())
        let targetSteps = Int((value * 16).rounded())
        let stepsToMove = targetSteps - currentSteps
        
        lastBrightnessValue = value
        
        if abs(stepsToMove) == 0 {
            return
        }
        
        let task1 = Process()
        task1.launchPath = "/usr/local/bin/brightness"
        task1.arguments = ["\(value)"]
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try task1.run()
                task1.waitUntilExit()
                if task1.terminationStatus == 0 {
                    return
                }
            } catch {
                // Continue
            }
            
            let task2 = Process()
            task2.launchPath = "/usr/bin/osascript"
            
            let keyCode = stepsToMove > 0 ? 144 : 145
            let repeatCount = abs(stepsToMove)
            
            let script = """
            tell application "System Events"
                repeat \(repeatCount) times
                    key code \(keyCode)
                    delay 0.05
                end repeat
            end tell
            """
            
            task2.arguments = ["-e", script]
            
            do {
                try task2.run()
                task2.waitUntilExit()
            } catch {
                print("Error setting brightness: \(error)")
            }
        }
    }
    
    func getCurrentVolume() -> Double {
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", "output volume of (get volume settings)"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                if let volumeValue = Int(trimmed) {
                    return max(0, min(1, Double(volumeValue) / 100.0))
                }
            }
        } catch {
            print("Error getting volume: \(error)")
        }
        
        return 0.5
    }
    
    func getCurrentBrightness() -> Double {
        return brightness
    }
    
    // MARK: - System Info
    private func startSystemInfoUpdates() {
        updateSystemInfo()
        restartSystemInfoTimer()
    }
    
    private func pauseSystemInfoTimer() {
        systemInfoTimer?.invalidate()
        systemInfoTimer = nil
    }
    
    private func restartSystemInfoTimer() {
        pauseSystemInfoTimer()
        guard isExpanded else { return }
        let minInterval = min(cpuRefreshInterval, ramRefreshInterval, diskRefreshInterval, gpuRefreshInterval)
        systemInfoTimer = Timer.scheduledTimer(withTimeInterval: minInterval, repeats: true) { [weak self] _ in
            self?.updateSystemInfo()
        }
    }
    
    func updateRefreshInterval(_ interval: Double) {
        refreshInterval = max(1.0, min(60.0, interval)) // Between 1-60 seconds
        // Update all intervals to the same value for backward compatibility
        cpuRefreshInterval = interval
        ramRefreshInterval = interval
        diskRefreshInterval = interval
        gpuRefreshInterval = interval
        clipboardRefreshInterval = interval
        restartSystemInfoTimer()
        restartClipboardMonitor()
        restartSpeedTestTimer()
    }
    
    func updateCPURefreshInterval(_ interval: Double) {
        cpuRefreshInterval = max(1.0, min(60.0, interval))
        restartSystemInfoTimer()
    }
    
    func updateRAMRefreshInterval(_ interval: Double) {
        ramRefreshInterval = max(1.0, min(60.0, interval))
        restartSystemInfoTimer()
    }
    
    func updateDiskRefreshInterval(_ interval: Double) {
        diskRefreshInterval = max(1.0, min(60.0, interval))
        restartSystemInfoTimer()
    }
    
    func updateGPURefreshInterval(_ interval: Double) {
        gpuRefreshInterval = max(1.0, min(60.0, interval))
        restartSystemInfoTimer()
    }
    
    func updateInternetSpeedRefreshInterval(_ interval: Double) {
        internetSpeedRefreshInterval = max(10.0, min(300.0, interval)) // Between 10-300 seconds
        restartSpeedTestTimer()
    }
    
    func updateClipboardRefreshInterval(_ interval: Double) {
        clipboardRefreshInterval = max(1.0, min(60.0, interval))
        restartClipboardMonitor()
    }
    
    private func restartSpeedTestTimer() {
        speedTestTimer?.invalidate()
        guard isExpanded else {
            speedTestTimer = nil
            return
        }
        
        speedTestTimer = Timer.scheduledTimer(withTimeInterval: internetSpeedRefreshInterval, repeats: true) { [weak self] _ in
            self?.runNetworkQualityTestForContinuous()
        }
    }
    
    private func updateSystemInfo() {
        systemInfoQueue.async {
            let cpu = self.getCPUUsage()
            let ram = self.getRAMUsage()
            let disk = self.getDiskUsage()
            let gpu = self.getGPUUsage()
            let network = self.getNetworkSpeed()
            
            DispatchQueue.main.async {
                self.cpuUsage = cpu
                self.ramUsage = ram
                self.diskUsage = disk
                self.gpuUsage = gpu
                self.networkSpeed = network
            }
        }
    }
    
    private func getCPUUsage() -> Double {
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        var info = host_cpu_load_info()
        
        let result = withUnsafeMutablePointer(to: &info) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            return cpuUsage
        }
        
        defer { previousCPULoad = info }
        
        let user = Double(info.cpu_ticks.0)
        let system = Double(info.cpu_ticks.1)
        let idle = Double(info.cpu_ticks.2)
        let nice = Double(info.cpu_ticks.3)
        let total = user + system + idle + nice
        
        guard total > 0 else { return cpuUsage }
        
        if let previous = previousCPULoad {
            let userDiff = Double(info.cpu_ticks.0 - previous.cpu_ticks.0)
            let sysDiff = Double(info.cpu_ticks.1 - previous.cpu_ticks.1)
            let idleDiff = Double(info.cpu_ticks.2 - previous.cpu_ticks.2)
            let niceDiff = Double(info.cpu_ticks.3 - previous.cpu_ticks.3)
            let diffTotal = userDiff + sysDiff + idleDiff + niceDiff
            guard diffTotal > 0 else { return cpuUsage }
            
            let active = diffTotal - idleDiff
            return min(1.0, max(0.0, active / diffTotal))
        } else {
            let active = total - idle
            return min(1.0, max(0.0, active / total))
        }
    }
    
    private func getRAMUsage() -> Double {
        // Use vm_stat for reliable RAM usage (optimized parsing)
        let task = Process()
        task.launchPath = "/usr/bin/vm_stat"
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return 0.0 }
            
            let lines = output.components(separatedBy: "\n")
            var pagesFree = 0.0
            var pagesActive = 0.0
            var pagesInactive = 0.0
            var pagesWired = 0.0
            
            for line in lines {
                if line.contains("Pages free") {
                    if let value = extractPageValue(from: line) {
                        pagesFree = value
                    }
                } else if line.contains("Pages active") {
                    if let value = extractPageValue(from: line) {
                        pagesActive = value
                    }
                } else if line.contains("Pages inactive") {
                    if let value = extractPageValue(from: line) {
                        pagesInactive = value
                    }
                } else if line.contains("Pages wired") {
                    if let value = extractPageValue(from: line) {
                        pagesWired = value
                    }
                }
            }
            
            let totalUsed = pagesActive + pagesInactive + pagesWired
            let total = totalUsed + pagesFree
            
            if total > 0 {
                return totalUsed / total
            }
        } catch {
            print("Error getting RAM usage: \(error)")
        }
        
        return 0.0
    }
    
    private func extractPageValue(from line: String) -> Double? {
        let components = line.components(separatedBy: ":")
        guard components.count > 1 else { return nil }
        let valuePart = components[1].trimmingCharacters(in: .whitespaces)
        // Remove dots and extract number
        let numberPart = valuePart.components(separatedBy: ".").first ?? valuePart
        return Double(numberPart.replacingOccurrences(of: ",", with: ""))
    }
    
    private func getDiskUsage() -> Double {
        // Use df command to get disk usage
        let task = Process()
        task.launchPath = "/usr/bin/df"
        task.arguments = ["-k", "/"] // Use -k for kilobytes (more reliable parsing)
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: "\n")
                if lines.count > 1 {
                    // Parse df output: Filesystem 1024-blocks Used Available Capacity iused ifree %iused Mounted on
                    let components = lines[1].components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    
                    if components.count >= 4 {
                        // components[0] = Filesystem
                        // components[1] = Total blocks (1024-byte blocks)
                        // components[2] = Used blocks
                        // components[3] = Available blocks
                        
                        if let totalBlocks = Int64(components[1]),
                           let usedBlocks = Int64(components[2]) {
                            let usage = Double(usedBlocks) / Double(totalBlocks)
                            return min(1.0, max(0.0, usage))
                        }
                    }
                }
            }
        } catch {
            print("Error getting disk usage: \(error)")
        }
        
        // Fallback: Use FileManager
        return getDiskUsageViaFileManager()
    }
    
    private func getDiskUsageViaFileManager() -> Double {
        let fileManager = FileManager.default
        
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: "/")
            
            if let totalSize = attributes[.systemSize] as? NSNumber,
               let freeSize = attributes[.systemFreeSize] as? NSNumber {
                let total = totalSize.doubleValue
                let free = freeSize.doubleValue
                let used = total - free
                
                if total > 0 {
                    return used / total
                }
            }
        } catch {
            print("Error getting disk usage via FileManager: \(error)")
        }
        
        return 0.0
    }
    
    private func getGPUUsage() -> Double {
        // Estimate GPU usage by checking GPU-intensive processes
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-eo", "comm,%cpu"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return 0.15 }
            
            let lines = output.components(separatedBy: "\n")
            var totalCPU = 0.0
            var processCount = 0
            
            // GPU-intensive processes to monitor
            let gpuProcesses = ["WindowServer", "kernel_task"]
            
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { continue }
                
                for process in gpuProcesses {
                    if trimmed.contains(process) {
                        // Extract CPU percentage (format: "process_name 12.5")
                        let components = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                        if components.count >= 2 {
                            // Last component should be CPU percentage
                            if let cpuStr = components.last, let cpu = Double(cpuStr) {
                                totalCPU += cpu
                                processCount += 1
                            }
                        }
                    }
                }
            }
            
            // Calculate average and normalize (WindowServer typically uses 5-30% CPU when active)
            if processCount > 0 {
                let avgCPU = totalCPU / Double(processCount)
                // Normalize: 0-30% CPU maps to 0-1 GPU usage
                return min(1.0, max(0.0, avgCPU / 30.0))
            }
        } catch {
            print("Error estimating GPU usage: \(error)")
        }
        
        // Fallback: Return a reasonable default
        return 0.15
    }
    
    private func getNetworkSpeed() -> String {
        // Simplified network speed - would need proper monitoring
        return "0 MB/s"
    }
    
    // MARK: - AI Chat (Gemini)
    func sendChatMessage() {
        let trimmedInput = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }
        guard !isChatLoading else { return }
        
        let userMessage = ChatMessage(role: .user, text: trimmedInput)
        chatMessages.append(userMessage)
        chatInput = ""
        chatError = nil
        isChatLoading = true
        trimChatHistoryIfNeeded()
        
        performChatRequest(with: chatMessages)
    }
    
    private func performChatRequest(with messages: [ChatMessage], modelsToTry: [String]? = nil) {
        guard !geminiAPIKey.isEmpty else {
            handleChatFailure("API anahtarı bulunamadı.")
            return
        }
        
        var remainingModels = modelsToTry ?? geminiModelCandidates
        guard let currentModel = remainingModels.first else {
            handleChatFailure("Uygun Gemini modeli bulunamadı.")
            return
        }
        remainingModels.removeFirst()
        
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(currentModel):generateContent"
        guard let url = URL(string: urlString) else {
            handleChatFailure("Geçersiz istek adresi.")
            return
        }
        
        var recentMessages = Array(messages.suffix(maxChatHistory))
        
        // Gemini API requires the conversation to start with a user message.
        while let first = recentMessages.first, first.role == .assistant {
            recentMessages.removeFirst()
        }
        
        guard recentMessages.contains(where: { $0.role == .user }) else {
            handleChatFailure("En az bir kullanıcı mesajı gerekli.")
            return
        }
        
        let requestBody = GeminiRequest(
            contents: recentMessages.map { message in
                GeminiRequest.Content(
                    role: message.role.rawValue,
                    parts: [GeminiRequest.Part(text: message.text)]
                )
            }
        )
        
        guard let bodyData = try? JSONEncoder().encode(requestBody) else {
            handleChatFailure("İstek hazırlanamadı.")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue(geminiAPIKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = bodyData
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.handleChatFailure("Bağlantı hatası: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, (400...599).contains(httpResponse.statusCode) {
                let serverMessage = self.parseGeminiError(from: data)
                if let serverMessage = serverMessage, self.shouldTryNextModel(for: serverMessage) {
                    self.performChatRequest(with: messages, modelsToTry: remainingModels)
                    return
                }
                
                let message = serverMessage ?? "Sunucu hatası (kod \(httpResponse.statusCode))."
                self.handleChatFailure(message)
                return
            }
            
            guard let data = data else {
                self.handleChatFailure("Sunucudan veri alınamadı.")
                return
            }
            
            do {
                let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
                guard let candidate = decoded.candidates?.first,
                      let parts = candidate.content?.parts,
                      !parts.isEmpty else {
                    self.handleChatFailure("Anlamlı bir yanıt alınamadı.")
                    return
                }
                
                let combinedText = parts.compactMap { $0.text }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                
                guard !combinedText.isEmpty else {
                    self.handleChatFailure("Boş yanıt alındı.")
                    return
                }
                
                DispatchQueue.main.async {
                    let assistantMessage = ChatMessage(role: .assistant, text: combinedText)
                    self.chatMessages.append(assistantMessage)
                    self.trimChatHistoryIfNeeded()
                    self.isChatLoading = false
                }
            } catch {
                self.handleChatFailure("Yanıt çözümlenemedi: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    private func handleChatFailure(_ message: String) {
        DispatchQueue.main.async {
            self.chatError = message
            self.isChatLoading = false
            let errorMessage = ChatMessage(role: .assistant, text: message, isError: true)
            self.chatMessages.append(errorMessage)
            self.trimChatHistoryIfNeeded()
        }
    }
    
    private func trimChatHistoryIfNeeded() {
        if chatMessages.count > maxChatHistory {
            chatMessages = Array(chatMessages.suffix(maxChatHistory))
        }
    }
    
    private struct GeminiRequest: Codable {
        struct Content: Codable {
            let role: String
            let parts: [Part]
        }
        
        struct Part: Codable {
            let text: String
        }
        
        let contents: [Content]
    }
    
    private struct GeminiResponse: Codable {
        struct Candidate: Codable {
            let content: ResponseContent?
        }
        
        struct ResponseContent: Codable {
            let parts: [ResponsePart]?
        }
        
        struct ResponsePart: Codable {
            let text: String?
        }
        
        let candidates: [Candidate]?
    }
    
    private struct GeminiErrorResponse: Codable {
        struct ErrorInfo: Codable {
            let code: Int?
            let message: String?
            let status: String?
        }
        
        let error: ErrorInfo?
    }
    
    private func parseGeminiError(from data: Data?) -> String? {
        guard let data = data else { return nil }
        if let decoded = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data),
           let message = decoded.error?.message, !message.isEmpty {
            return message
        }
        
        if let raw = String(data: data, encoding: .utf8), !raw.isEmpty {
            return raw
        }
        return nil
    }
    
    private func shouldTryNextModel(for message: String) -> Bool {
        let lowercased = message.lowercased()
        let keywords = [
            "not found",
            "unsupported",
            "call listmodels",
            "unavailable for this api version"
        ]
        return keywords.contains(where: { lowercased.contains($0) })
    }
    
    // MARK: - Screen Recording
    func startScreenRecording() {
        fputs("🎥 [ScreenRecording] startScreenRecording() çağrıldı\n", stderr)
        fflush(stderr)
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Use AppleScript to simulate Cmd+Shift+5 key combination
            // This opens macOS's built-in screen recording tool
            // The tool will appear and user can click to start recording
            // Recordings are saved to Desktop by default
            
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            
            // Simple script: Just open the screen recording tool
            // User will manually click the record button
            let script = """
            tell application "System Events"
                -- Simulate Cmd+Shift+5 to open screen recording tool
                keystroke "5" using {command down, shift down}
            end tell
            """
            
            task.arguments = ["-e", script]
            
            // Set up environment
            var environment = ProcessInfo.processInfo.environment
            environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin"
            task.environment = environment
            
            do {
                fputs("🚀 [ScreenRecording] AppleScript çalıştırılıyor...\n", stderr)
                fflush(stderr)
                
                try task.run()
                
                // Don't wait for exit - let it run in background
                // The screen recording tool will open and user can interact with it
                
                fputs("✅ [ScreenRecording] Ekran kaydı aracı açıldı\n", stderr)
                fputs("💡 [ScreenRecording] Kullanıcı ekranda görünen kayıt butonuna tıklayarak kaydı başlatabilir\n", stderr)
                fflush(stderr)
                
            } catch {
                fputs("❌ [ScreenRecording] Hata: \(error.localizedDescription)\n", stderr)
                fflush(stderr)
                
                // Try alternative: Use CGEvent to send key event directly
                DispatchQueue.main.async {
                    self.sendScreenRecordingKeyEvent()
                }
            }
        }
    }
    
    private func sendScreenRecordingKeyEvent() {
        // Alternative method using CGEvent (requires accessibility permissions)
        fputs("🔄 [ScreenRecording] CGEvent yöntemi deneniyor...\n", stderr)
        fflush(stderr)
        
        // Create key down event for Cmd+Shift+5
        guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x17, keyDown: true) else {
            fputs("❌ [ScreenRecording] CGEvent oluşturulamadı\n", stderr)
            fflush(stderr)
            return
        }
        
        keyDownEvent.flags = [.maskCommand, .maskShift]
        keyDownEvent.post(tap: .cghidEventTap)
        
        // Create key up event
        guard let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x17, keyDown: false) else {
            return
        }
        keyUpEvent.flags = [.maskCommand, .maskShift]
        keyUpEvent.post(tap: .cghidEventTap)
        
        fputs("✅ [ScreenRecording] CGEvent gönderildi\n", stderr)
        fflush(stderr)
    }
    
    // MARK: - Clipboard Manager
    private func setupClipboardMonitoring() {
        restartClipboardMonitor()
    }
    
    private func restartClipboardMonitor() {
        clipboardMonitor?.invalidate()
        guard isExpanded else {
            clipboardMonitor = nil
            return
        }
        
        clipboardMonitor = Timer.scheduledTimer(withTimeInterval: clipboardRefreshInterval, repeats: true) { [weak self] _ in
            self?.updateClipboard()
        }
    }
    
    private func updateClipboard() {
        let pasteboard = NSPasteboard.general
        // Check for files
        if let types = pasteboard.types {
            hasFileInClipboard = types.contains(.fileURL) || types.contains(.tiff)
        } else {
            hasFileInClipboard = false
        }
        
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            // Only add if different from last item and not too long (prevent memory issues)
            if string.count < 500 && clipboardItems.first != string {
                clipboardItems.insert(string, at: 0)
                // Limit to 5 items to save memory
                if clipboardItems.count > 5 {
                    clipboardItems.removeLast()
                }
            }
        }
    }
    
    func handleFileDrop(url: URL) {
        let standardized = url.standardizedFileURL
        DispatchQueue.main.async {
            self.copyFileToSystemClipboard(standardized)
            self.appendStoredFile(url: standardized)
        }
    }
    
    func removeStoredFile(_ file: ClipboardFileItem) {
        storedFiles.removeAll { $0.id == file.id }
        if storedFiles.isEmpty {
            hasFileInClipboard = false
        }
    }
    
    func activateStoredFile(_ file: ClipboardFileItem) {
        copyFileToSystemClipboard(file.url)
    }
    
    func providerForStoredFile(_ file: ClipboardFileItem) -> NSItemProvider {
        return NSItemProvider(object: file.url as NSURL)
    }
    
    private func copyFileToSystemClipboard(_ url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([url as NSURL])
        hasFileInClipboard = true
    }
    
    private func appendStoredFile(url: URL) {
        if !storedFiles.contains(where: { $0.url == url }) {
            storedFiles.insert(ClipboardFileItem(url: url), at: 0)
        }
        
        if storedFiles.count > 5 {
            storedFiles.removeLast()
        }
    }
    
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    // MARK: - Speed Test
    // MARK: - Network Quality Test Result (Codable for JSON parsing)
    private struct NetworkQualityResult: Codable {
        let dl_throughput: Double? // Download throughput in bits per second
        let ul_throughput: Double? // Upload throughput in bits per second
        let dl_bytes_transferred: Int?
        let ul_bytes_transferred: Int?
        let dl_flows: Int?
        let ul_flows: Int?
        let dl_responsiveness: Double?
        let ul_responsiveness: Double?
        let base_rtt: Double?
        let end_date: String?
        let dl_metrics: Metrics?
        let ul_metrics: Metrics?
        
        struct Metrics: Codable {
            let bytesTransferred: Int?
            let duration: Double?
            let throughput: Double?
        }
    }
    
    // MARK: - Continuous Speed Test
    private func startContinuousSpeedTest() {
        restartSpeedTestTimer()
        // Run initial test
        runNetworkQualityTestForContinuous()
    }
    
    private func runNetworkQualityTestForContinuous() {
        // Don't show "Test..." state for continuous tests, just update silently
        runNetworkQualityTest(silent: true)
    }
    
    func startSpeedTest() {
        // Manual test trigger (for button click)
        fputs("🔵 [SpeedTest] startSpeedTest() çağrıldı (manuel)\n", stderr)
        fflush(stderr)
        
        // Reset error state
        speedTestError = nil
        
        // Start test
        isSpeedTestRunning = true
        downloadSpeed = "Test..."
        uploadSpeed = "Test..."
        
        fputs("✅ [SpeedTest] State güncellendi - isSpeedTestRunning: \(isSpeedTestRunning)\n", stderr)
        fflush(stderr)
        
        // Run network quality test using macOS built-in command
        runNetworkQualityTest(silent: false)
    }
    
    func stopSpeedTest() {
        isSpeedTestRunning = false
        downloadSpeed = "--"
        uploadSpeed = "--"
        speedTestError = nil
    }
    
    private func runNetworkQualityTest(silent: Bool = false) {
        // Use absolute path for networkQuality command
        let networkQualityPath = "/usr/bin/networkQuality"
        
        if !silent {
            fputs("🚀 [SpeedTest] runNetworkQualityTest() çağrıldı\n", stderr)
            fflush(stderr)
        }
        
        // Check if command exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: networkQualityPath) else {
            if !silent {
                fputs("❌ [SpeedTest] networkQuality komutu bulunamadı: \(networkQualityPath)\n", stderr)
                fflush(stderr)
            }
            DispatchQueue.main.async { [weak self] in
                self?.speedTestError = "networkQuality komutu bulunamadı"
                if !silent {
                    self?.isSpeedTestRunning = false
                    self?.downloadSpeed = "Hata"
                    self?.uploadSpeed = "Hata"
                } else {
                    self?.internetDownloadSpeed = "--"
                    self?.internetUploadSpeed = "--"
                }
            }
            return
        }
        
        if !silent {
            fputs("✅ [SpeedTest] networkQuality komutu bulundu\n", stderr)
            fflush(stderr)
        }
        
        // Run test in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                if !silent {
                    fputs("❌ [SpeedTest] self nil\n", stderr)
                    fflush(stderr)
                }
                return
            }
            
            if !silent {
                fputs("🚀 [SpeedTest] Background thread başladı\n", stderr)
                fflush(stderr)
            }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: networkQualityPath)
            process.arguments = ["-c"] // Computer-readable JSON format
            
            // Setup pipes for output and error
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            // Set environment variables (may help with permissions)
            var environment = ProcessInfo.processInfo.environment
            environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin"
            process.environment = environment
            
            // Setup file handles for reading
            let outputHandle = outputPipe.fileHandleForReading
            let errorHandle = errorPipe.fileHandleForReading
            
            do {
                if !silent {
                    fputs("🚀 [SpeedTest] Process başlatılıyor: \(networkQualityPath) -c\n", stderr)
                    fflush(stderr)
                }
                
                try process.run()
                
                fputs("✅ [SpeedTest] Process başlatıldı, PID: \(process.processIdentifier)\n", stderr)
                fflush(stderr)
                
                // Set timeout (networkQuality can take up to 30 seconds)
                let timeout: TimeInterval = 60.0
                let startTime = Date()
                
                // Wait with timeout check
                while process.isRunning {
                    if Date().timeIntervalSince(startTime) > timeout {
                        fputs("⏱️ [SpeedTest] Timeout - process'i sonlandırılıyor\n", stderr)
                        fflush(stderr)
                        process.terminate()
                        Thread.sleep(forTimeInterval: 2.0)
                        if process.isRunning {
                            process.terminate()
                        }
                        break
                    }
                    Thread.sleep(forTimeInterval: 0.1)
                }
                
                process.waitUntilExit()
                
                let exitCode = process.terminationStatus
                if !silent {
                    fputs("📊 [SpeedTest] Process tamamlandı, exit code: \(exitCode)\n", stderr)
                    fflush(stderr)
                }
                
                // Read output and error
                outputHandle.waitForDataInBackgroundAndNotify()
                errorHandle.waitForDataInBackgroundAndNotify()
                
                let outputData = outputHandle.readDataToEndOfFile()
                let errorData = errorHandle.readDataToEndOfFile()
                
                // Read output and error strings
                let outputString = String(data: outputData, encoding: .utf8) ?? ""
                let errorString = String(data: errorData, encoding: .utf8) ?? ""
                
                if !silent {
                    fputs("📊 [SpeedTest] Exit code: \(exitCode)\n", stderr)
                    fputs("📊 [SpeedTest] Output length: \(outputString.count) bytes\n", stderr)
                    if !errorString.isEmpty {
                        fputs("⚠️ [SpeedTest] Error output: \(errorString)\n", stderr)
                    }
                    fflush(stderr)
                }
                
                // Check if process succeeded
                guard exitCode == 0 else {
                    if !silent {
                        fputs("❌ [SpeedTest] Process başarısız: exit code \(exitCode), error: \(errorString)\n", stderr)
                        fflush(stderr)
                    }
                    DispatchQueue.main.async {
                        self.speedTestError = "Test başarısız (exit code: \(exitCode))"
                        if !silent {
                            self.isSpeedTestRunning = false
                            self.downloadSpeed = "Hata"
                            self.uploadSpeed = "Hata"
                        } else {
                            self.internetDownloadSpeed = "--"
                            self.internetUploadSpeed = "--"
                        }
                    }
                    return
                }
                
                // Parse JSON output
                guard !outputString.isEmpty else {
                    if !silent {
                        fputs("❌ [SpeedTest] Boş output alındı\n", stderr)
                        fflush(stderr)
                    }
                    DispatchQueue.main.async {
                        self.speedTestError = "Boş sonuç alındı"
                        if !silent {
                            self.isSpeedTestRunning = false
                            self.downloadSpeed = "Hata"
                            self.uploadSpeed = "Hata"
                        } else {
                            self.internetDownloadSpeed = "--"
                            self.internetUploadSpeed = "--"
                        }
                    }
                    return
                }
                
                if !silent {
                    fputs("📄 [SpeedTest] JSON parse ediliyor...\n", stderr)
                    fputs("📄 [SpeedTest] İlk 200 karakter: \(String(outputString.prefix(200)))\n", stderr)
                    fflush(stderr)
                }
                
                // Parse JSON
                let decoder = JSONDecoder()
                do {
                    // Try to decode the JSON
                    let result = try decoder.decode(NetworkQualityResult.self, from: outputData)
                    
                    if !silent {
                        fputs("✅ [SpeedTest] JSON parse başarılı\n", stderr)
                        fputs("📊 [SpeedTest] dl_throughput: \(result.dl_throughput ?? 0)\n", stderr)
                        fputs("📊 [SpeedTest] ul_throughput: \(result.ul_throughput ?? 0)\n", stderr)
                        fputs("📊 [SpeedTest] dl_bytes_transferred: \(result.dl_bytes_transferred ?? 0)\n", stderr)
                        fputs("📊 [SpeedTest] ul_bytes_transferred: \(result.ul_bytes_transferred ?? 0)\n", stderr)
                        fflush(stderr)
                    }
                    
                    // Convert bits per second to Mbps (divide by 1,000,000)
                    var downloadMbps: Double = 0.0
                    var uploadMbps: Double = 0.0
                    
                    // Try dl_throughput first (bits per second)
                    if let dlThroughput = result.dl_throughput, dlThroughput > 0 {
                        downloadMbps = dlThroughput / 1_000_000.0
                        if !silent {
                            fputs("📥 [SpeedTest] Download (dl_throughput): \(downloadMbps) Mbps\n", stderr)
                        }
                    } 
                    // Fallback to dl_metrics.throughput
                    else if let dlMetrics = result.dl_metrics, let throughput = dlMetrics.throughput, throughput > 0 {
                        downloadMbps = throughput / 1_000_000.0
                        if !silent {
                            fputs("📥 [SpeedTest] Download (dl_metrics): \(downloadMbps) Mbps\n", stderr)
                        }
                    }
                    // Fallback: calculate from bytes_transferred if we have duration
                    else if let dlBytes = result.dl_bytes_transferred, dlBytes > 0 {
                        // Estimate: assume test took ~10 seconds (typical networkQuality duration)
                        let estimatedDuration: Double = 10.0
                        let bitsPerSecond = Double(dlBytes * 8) / estimatedDuration
                        downloadMbps = bitsPerSecond / 1_000_000.0
                        if !silent {
                            fputs("📥 [SpeedTest] Download (estimated from bytes): \(downloadMbps) Mbps\n", stderr)
                        }
                    }
                    
                    // Try ul_throughput first (bits per second)
                    if let ulThroughput = result.ul_throughput, ulThroughput > 0 {
                        uploadMbps = ulThroughput / 1_000_000.0
                        if !silent {
                            fputs("📤 [SpeedTest] Upload (ul_throughput): \(uploadMbps) Mbps\n", stderr)
                        }
                    }
                    // Fallback to ul_metrics.throughput
                    else if let ulMetrics = result.ul_metrics, let throughput = ulMetrics.throughput, throughput > 0 {
                        uploadMbps = throughput / 1_000_000.0
                        if !silent {
                            fputs("📤 [SpeedTest] Upload (ul_metrics): \(uploadMbps) Mbps\n", stderr)
                        }
                    }
                    // Fallback: calculate from bytes_transferred
                    else if let ulBytes = result.ul_bytes_transferred, ulBytes > 0 {
                        let estimatedDuration: Double = 10.0
                        let bitsPerSecond = Double(ulBytes * 8) / estimatedDuration
                        uploadMbps = bitsPerSecond / 1_000_000.0
                        if !silent {
                            fputs("📤 [SpeedTest] Upload (estimated from bytes): \(uploadMbps) Mbps\n", stderr)
                        }
                    }
                    
                    if !silent {
                        fflush(stderr)
                    }
                    
                    // Update UI on main thread
                    DispatchQueue.main.async {
                        fputs("🔄 [SpeedTest] UI güncellemesi başlıyor - downloadMbps: \(downloadMbps), uploadMbps: \(uploadMbps)\n", stderr)
                        fflush(stderr)
                        
                        if downloadMbps > 0 {
                            self.downloadSpeed = String(format: "%.1f", downloadMbps)
                            fputs("✅ [SpeedTest] downloadSpeed güncellendi: \(self.downloadSpeed)\n", stderr)
                        } else {
                            self.downloadSpeed = "0.0"
                            fputs("⚠️ [SpeedTest] downloadSpeed 0, '0.0' olarak ayarlandı\n", stderr)
                        }
                        
                        if uploadMbps > 0 {
                            self.uploadSpeed = String(format: "%.1f", uploadMbps)
                            fputs("✅ [SpeedTest] uploadSpeed güncellendi: \(self.uploadSpeed)\n", stderr)
                        } else {
                            self.uploadSpeed = "0.0"
                            fputs("⚠️ [SpeedTest] uploadSpeed 0, '0.0' olarak ayarlandı\n", stderr)
                        }
                        
                        fputs("✅ [SpeedTest] UI güncellendi - Download: \(self.downloadSpeed) Mbps, Upload: \(self.uploadSpeed) Mbps\n", stderr)
                        fputs("✅ [SpeedTest] isSpeedTestRunning: \(self.isSpeedTestRunning)\n", stderr)
                        fflush(stderr)
                        
                        // Keep test running for longer to show results (10 seconds)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                            fputs("⏱️ [SpeedTest] 10 saniye geçti, test durduruluyor\n", stderr)
                            fputs("⏱️ [SpeedTest] Son değerler - Download: \(self.downloadSpeed), Upload: \(self.uploadSpeed)\n", stderr)
                            fflush(stderr)
                            self.isSpeedTestRunning = false
                            
                            // Reset after showing results (3 seconds later)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                if !self.isSpeedTestRunning {
                                    fputs("🔄 [SpeedTest] Değerler sıfırlanıyor\n", stderr)
                                    fflush(stderr)
                                    self.downloadSpeed = "--"
                                    self.uploadSpeed = "--"
                                    self.speedTestError = nil
                                }
                            }
                        }
                    }
                    
                } catch let decodingError {
                    fputs("❌ [SpeedTest] JSON decode hatası: \(decodingError)\n", stderr)
                    fputs("📄 [SpeedTest] Raw output (ilk 500 karakter): \(String(outputString.prefix(500)))\n", stderr)
                    fflush(stderr)
                    DispatchQueue.main.async {
                        self.speedTestError = "JSON parse hatası: \(decodingError.localizedDescription)"
                        self.isSpeedTestRunning = false
                        self.downloadSpeed = "Hata"
                        self.uploadSpeed = "Hata"
                    }
                }
                
            } catch let processError {
                fputs("❌ [SpeedTest] Process çalıştırma hatası: \(processError)\n", stderr)
                fflush(stderr)
                DispatchQueue.main.async {
                    self.speedTestError = "Process hatası: \(processError.localizedDescription)"
                    self.isSpeedTestRunning = false
                    self.downloadSpeed = "Hata"
                    self.uploadSpeed = "Hata"
                }
            }
        }
    }
    
    // MARK: - Pomodoro Timer
    func togglePomodoro() {
        if isPomodoroRunning {
            stopPomodoro()
        } else {
            startPomodoro()
        }
    }
    
    func startPomodoro() {
        if pomodoroTimeRemaining <= 0 {
            pomodoroTimeRemaining = pomodoroMode.duration
        }
        isPomodoroRunning = true
        schedulePomodoroTimer()
    }
    
    func stopPomodoro() {
        isPomodoroRunning = false
        pomodoroTimer?.invalidate()
    }
    
    func resetPomodoro() {
        stopPomodoro()
        pomodoroTimeRemaining = pomodoroMode.duration
    }
    
    private func schedulePomodoroTimer() {
        pomodoroTimer?.invalidate()
        pomodoroTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.pomodoroTimeRemaining > 0 {
                self.pomodoroTimeRemaining -= 1
            } else {
                self.pomodoroCompleted()
            }
        }
    }
    
    private func pomodoroCompleted() {
        stopPomodoro()
        switch pomodoroMode {
        case .work:
            pomodoroMode = .shortBreak
        case .shortBreak:
            pomodoroMode = .work
        }
        pomodoroTimeRemaining = pomodoroMode.duration
        
        let content = UNMutableNotificationContent()
        content.title = "Pomodoro \(pomodoroMode == .work ? "Break" : "Work")"
        content.body = pomodoroMode == .work ? "Mola bitti, çalışmaya dön!" : "Çalışma oturumu tamamlandı, kısa bir mola ver!"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    private func setupVolumeControl() {
        // Volume control setup
    }
    
    deinit {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let localMonitor = localMouseMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        systemInfoTimer?.invalidate()
        pomodoroTimer?.invalidate()
        clipboardMonitor?.invalidate()
        speedTestTimer?.invalidate()
    }
}
