//
//  ContentView.swift
//  DynamicNotch
//
//  Created for Dynamic Notch utility app
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var viewModel: NotchViewModel
    
    var body: some View {
        Group {
            if viewModel.isExpanded {
                ZStack {
                    // Background - Frosted glass effect
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    
                    // Main Content - Scrollable to fit all content
                    ScrollView {
                        VStack(spacing: 18) {
                            // Top row - System Info (left) + 4 buttons (right in 2x2 grid)
                            HStack(spacing: 16) {
                                // Left side - System Info (CPU, RAM, Disk, GPU)
                                SystemInfoCard(viewModel: viewModel)
                                    .frame(maxWidth: .infinity)
                                
                                // Right side - 4 buttons in 2x2 grid
                            VStack(spacing: 12) {
                                    // Top row
                                    HStack(spacing: 12) {
                                        SmallSquareButton(
                                            icon: "record.circle.fill",
                                            title: "",
                                            color: .red,
                                            action: { viewModel.startScreenRecording() }
                                        )
                                        
                                        // Settings Button (replaces speed test button)
                                        SmallSquareButton(
                                            icon: "gearshape.fill",
                                            title: "",
                                            color: .gray,
                                            action: { viewModel.showSettings.toggle() }
                                        )
                                    }
                                    
                                // Bottom row
                                HStack(alignment: .top, spacing: 12) {
                                    ClipboardCard(viewModel: viewModel)
                                    
                                    PomodoroButton(viewModel: viewModel)
                                        .frame(maxHeight: 70, alignment: .top)
                                }
                                }
                                .frame(width: 152) // Fixed width for 2 buttons
                            }
                            
                            AIChatCard(viewModel: viewModel)
                        }
                        .padding(20)
                    }
                    .overlay(
                        // Settings overlay - positioned correctly
                        Group {
                            if viewModel.showSettings {
                                SettingsView(viewModel: viewModel)
                            }
                        }
                    )
                }
                .scaleEffect(viewModel.isExpanded ? 1.0 : 0.01)
                .opacity(viewModel.isExpanded ? 1.0 : 0.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.75), value: viewModel.isExpanded)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - System Info Card
struct SystemInfoCard: View {
    @ObservedObject var viewModel: NotchViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            // Circular gauges in a row (speedometer style) - no title
            HStack(spacing: 12) {
                CircularGauge(
                    label: "CPU",
                    value: viewModel.cpuUsage,
                    color: .blue
                )
                
                CircularGauge(
                    label: "RAM",
                    value: viewModel.ramUsage,
                    color: .green
                )
                
                CircularGauge(
                    label: "Disk",
                    value: viewModel.diskUsage,
                    color: .orange
                )
                
                CircularGauge(
                    label: "GPU",
                    value: viewModel.gpuUsage,
                    color: .purple
                )
                
                // Internet Speed Gauge
                InternetSpeedGauge(
                    downloadSpeed: viewModel.internetDownloadSpeed,
                    uploadSpeed: viewModel.internetUploadSpeed
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

// MARK: - Internet Speed Gauge
struct InternetSpeedGauge: View {
    let downloadSpeed: String
    let uploadSpeed: String
    
    // Parse speed value from string
    private var downloadValue: Double {
        if downloadSpeed == "--" || downloadSpeed.isEmpty {
            return 0.0
        }
        if let number = Double(downloadSpeed) {
            // Normalize: assume max 200 Mbps = 1.0
            return min(1.0, number / 200.0)
        }
        return 0.0
    }
    
    private var uploadValue: Double {
        if uploadSpeed == "--" || uploadSpeed.isEmpty {
            return 0.0
        }
        if let number = Double(uploadSpeed) {
            // Normalize: assume max 50 Mbps = 1.0
            return min(1.0, number / 50.0)
        }
        return 0.0
    }
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 6)
                    .frame(width: 65, height: 65)
                
                // Download speed arc (top half)
                Circle()
                    .trim(from: 0, to: min(downloadValue, 1.0) * 0.5)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 65, height: 65)
                    .rotationEffect(.degrees(-90))
                
                // Upload speed arc (bottom half)
                if uploadValue > 0 {
                    Circle()
                        .trim(from: 0.5, to: 0.5 + (min(uploadValue, 1.0) * 0.5))
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 65, height: 65)
                        .rotationEffect(.degrees(-90))
                }
                
                // Center value text
                VStack(spacing: 0) {
                    Text(downloadSpeed == "--" ? "--" : downloadSpeed)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("Mbps")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .offset(y: 6)
                }
            }
            
            VStack(spacing: 2) {
                Text("Internet")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))
                
                if downloadSpeed != "--" && uploadSpeed != "--" {
                    Text("↓\(downloadSpeed) ↑\(uploadSpeed)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                } else {
                    Text("Ölçülüyor...")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
}

// MARK: - Small Square Button (iPhone style - icon only)
struct SmallSquareButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    var isLoading: Bool = false
    var badge: String? = nil
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(.white)
                }
                
                if let badge = badge {
                    VStack {
                        HStack {
                            Spacer()
                            Text(badge)
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                                .padding(3)
                        }
                        Spacer()
                    }
                }
            }
            .frame(width: 70, height: 70)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.opacity(0.25))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(color.opacity(0.4), lineWidth: 1.5)
                    )
            )
            
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PomodoroButton: View {
    @ObservedObject var viewModel: NotchViewModel
    
    var body: some View {
        Button(action: { viewModel.togglePomodoro() }) {
            VStack(spacing: 6) {
                PomodoroGauge(
                    isRunning: viewModel.isPomodoroRunning,
                    progress: viewModel.pomodoroProgress,
                    accent: viewModel.pomodoroMode.accentColor
                )
                
                Text(viewModel.pomodoroMode.displayTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                
                Text(viewModel.pomodoroFormattedTime)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button("Sıfırla") {
                viewModel.resetPomodoro()
            }
        }
    }
}

struct PomodoroGauge: View {
    let isRunning: Bool
    let progress: Double
    let accent: Color
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 70, height: 70)
            
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 6)
                .frame(width: 70, height: 70)
            
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    accent,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 70, height: 70)
                .animation(.easeOut(duration: 0.3), value: progress)
            
            Image(systemName: isRunning ? "pause.fill" : "play.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
        }
    }
}

// MARK: - Speed Test Button (small icon button)
struct SpeedTestButton: View {
    @ObservedObject var viewModel: NotchViewModel
    
    var body: some View {
        Button(action: {
            // Debug log
            fputs("🔴 [UI] SpeedTestButton tıklandı!\n", stderr)
            fflush(stderr)
            
            // Call the function
            viewModel.startSpeedTest()
            
            // Verify it was called
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                fputs("🔴 [UI] isSpeedTestRunning: \(viewModel.isSpeedTestRunning)\n", stderr)
                fflush(stderr)
            }
        }) {
            Image(systemName: "speedometer")
                .font(.system(size: 26, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 70, height: 70)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.blue.opacity(0.25))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.blue.opacity(0.4), lineWidth: 1.5)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Speed Test Expanded Card (shows when test is running)
struct SpeedTestExpandedCard: View {
    @ObservedObject var viewModel: NotchViewModel
    
    // Parse speed value from string
    private var downloadValue: Double {
        let speed = viewModel.downloadSpeed
        if speed == "Test..." || speed == "--" || speed.isEmpty {
            return 0.0
        }
        if let number = Double(speed) {
            // Normalize: assume max 200 Mbps = 1.0 (more realistic)
            return min(1.0, number / 200.0)
        }
        return 0.0
    }
    
    private var uploadValue: Double {
        let speed = viewModel.uploadSpeed
        if speed == "Test..." || speed == "--" || speed.isEmpty {
            return 0.0
        }
        if let number = Double(speed) {
            // Normalize: assume max 50 Mbps = 1.0 (more realistic)
            return min(1.0, number / 50.0)
        }
        return 0.0
    }
    
    private var downloadSpeed: String {
        viewModel.downloadSpeed
    }
    
    private var uploadSpeed: String {
        viewModel.uploadSpeed
    }
    
    private var isTesting: Bool {
        downloadSpeed == "Test..." || uploadSpeed == "Test..." || downloadSpeed == "--" || uploadSpeed == "--"
    }
    
    var body: some View {
        Button(action: {
            // Stop test if clicked during test
            fputs("🟡 [UI] SpeedTestExpandedCard tıklandı - test durduruluyor\n", stderr)
            fputs("🟡 [UI] Mevcut değerler - Download: \(downloadSpeed), Upload: \(uploadSpeed)\n", stderr)
            fflush(stderr)
            viewModel.stopSpeedTest()
        }) {
            HStack(spacing: 10) {
                // Small speedometer gauge with loading indicator
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 3)
                        .frame(width: 55, height: 55)
                    
                    if isTesting {
                        // Show loading spinner when testing
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        // Show speedometer arcs when results available
                        Circle()
                            .trim(from: 0, to: min(downloadValue, 1.0) * 0.5)
                            .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 55, height: 55)
                            .rotationEffect(.degrees(-90))
                        
                        if uploadValue > 0 {
                            Circle()
                                .trim(from: 0.5, to: 0.5 + (min(uploadValue, 1.0) * 0.5))
                                .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .frame(width: 55, height: 55)
                                .rotationEffect(.degrees(-90))
                        }
                        
                        Image(systemName: "speedometer")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                
                // Speed values - compact vertical layout
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                        Text(isTesting ? "Test..." : (downloadSpeed.isEmpty ? "--" : downloadSpeed))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        if !isTesting && !downloadSpeed.isEmpty && downloadSpeed != "--" {
                            Text("Mbps")
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                        Text(isTesting ? "Test..." : (uploadSpeed.isEmpty ? "--" : uploadSpeed))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        if !isTesting && !uploadSpeed.isEmpty && uploadSpeed != "--" {
                            Text("Mbps")
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
            }
            .padding(10)
            .frame(width: 160, height: 75) // Slightly larger for better visibility
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.blue.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.blue.opacity(0.5), lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            fputs("🟢 [UI] SpeedTestExpandedCard göründü - Download: \(downloadSpeed), Upload: \(uploadSpeed), isRunning: \(viewModel.isSpeedTestRunning)\n", stderr)
            fflush(stderr)
        }
        .onChange(of: downloadSpeed) { oldValue, newValue in
            fputs("🔄 [UI] downloadSpeed değişti: \(oldValue) -> \(newValue)\n", stderr)
            fflush(stderr)
        }
        .onChange(of: uploadSpeed) { oldValue, newValue in
            fputs("🔄 [UI] uploadSpeed değişti: \(oldValue) -> \(newValue)\n", stderr)
            fflush(stderr)
        }
    }
}

// MARK: - Speedometer Gauge (for speed test)
struct SpeedometerGauge: View {
    let downloadSpeed: String
    let uploadSpeed: String
    
    // Parse speed value from string like "100 MB/s" or "Testing..."
    private var downloadValue: Double {
        if downloadSpeed == "Testing..." || downloadSpeed == "--" {
            return 0.0
        }
        let components = downloadSpeed.components(separatedBy: " ")
        if let numberStr = components.first, let number = Double(numberStr) {
            // Normalize: assume max 1000 MB/s = 1.0
            return min(1.0, number / 1000.0)
        }
        return 0.0
    }
    
    private var uploadValue: Double {
        if uploadSpeed == "Testing..." || uploadSpeed == "--" {
            return 0.0
        }
        let components = uploadSpeed.components(separatedBy: " ")
        if let numberStr = components.first, let number = Double(numberStr) {
            // Normalize: assume max 500 MB/s = 1.0
            return min(1.0, number / 500.0)
        }
        return 0.0
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 3)
                .frame(width: 50, height: 50)
            
            // Download speed arc (top half)
            Circle()
                .trim(from: 0, to: min(downloadValue, 1.0) * 0.5)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 50, height: 50)
                .rotationEffect(.degrees(-90))
            
            // Upload speed arc (bottom half, if needed)
            if uploadValue > 0 {
                Circle()
                    .trim(from: 0.5, to: 0.5 + (min(uploadValue, 1.0) * 0.5))
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
            }
            
            // Center text
            VStack(spacing: 0) {
                Text("↓")
                    .font(.system(size: 8))
                    .foregroundColor(.green)
                Text("↑")
                    .font(.system(size: 8))
                    .foregroundColor(.blue)
            }
        }
    }
}

// MARK: - Clipboard Card
struct ClipboardCard: View {
    @ObservedObject var viewModel: NotchViewModel
    @State private var showPopover = false
    @State private var isTargeted = false
    
    private var statusText: String {
        viewModel.storedFiles.isEmpty ? "Hazır" : "\(viewModel.storedFiles.count) dosya"
    }
    
    var body: some View {
        Button(action: { showPopover.toggle() }) {
            VStack(spacing: 6) {
                ZStack {
                    if viewModel.hasFileInClipboard {
                        Image(systemName: "tray.full")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    if !viewModel.storedFiles.isEmpty {
                        VStack {
                            Spacer()
                            Text("\(viewModel.storedFiles.count)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.4))
                                )
                                .padding(.bottom, 6)
                        }
                    }
                }
                .frame(width: 70, height: 70)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isTargeted ? Color.green.opacity(0.25) : Color.white.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isTargeted ? Color.green.opacity(0.6) : Color.white.opacity(0.25), lineWidth: 1.5)
                        )
                )
                
                Text("Pano")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxHeight: 110, alignment: .top)
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            ClipboardPopoverView(viewModel: viewModel)
                .frame(width: 240, height: 240)
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
    }
    
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                handled = true
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        viewModel.handleFileDrop(url: url)
                    } else if let url = item as? URL {
                        viewModel.handleFileDrop(url: url)
                    }
                }
            }
        }
        
        return handled
    }
}

struct ClipboardPopoverView: View {
    @ObservedObject var viewModel: NotchViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Dosya Tutucu", systemImage: "tray.full")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            
            Text("Dosyayı buraya sürükleyip bırak. Kaydedilen dosyaları tekrar sürükleyerek istediğin yere bırakabilir veya üstüne tıklayıp panoya kopyalayabilirsin.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.8))
            
            if viewModel.storedFiles.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down.on.square")
                        .font(.system(size: 30))
                        .foregroundColor(.white.opacity(0.6))
                    Text("Henüz dosya yok")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(viewModel.storedFiles) { file in
                            ClipboardFileRow(file: file, viewModel: viewModel)
                        }
                    }
                }
            }
        }
        .padding(16)
    }
}

struct ClipboardFileRow: View {
    let file: ClipboardFileItem
    @ObservedObject var viewModel: NotchViewModel
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc")
                .foregroundColor(.white.opacity(0.8))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(file.url.deletingLastPathComponent().path)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: { viewModel.removeStoredFile(file) }) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.white.opacity(0.8))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.08))
        )
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
            viewModel.activateStoredFile(file)
        }
        .onDrag {
            viewModel.providerForStoredFile(file)
        }
    }
}

// MARK: - AI Chat
struct AIChatCard: View {
    @ObservedObject var viewModel: NotchViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("AI Chat", systemImage: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .labelStyle(.titleAndIcon)
                
                Spacer()
                
                if viewModel.isChatLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.7)
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            ChatMessagesList(viewModel: viewModel)
            
            if let error = viewModel.chatError {
                Text(error)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.yellow)
            }
            
            ChatInputField(viewModel: viewModel)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

struct ChatMessagesList: View {
    @ObservedObject var viewModel: NotchViewModel
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.chatMessages) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
            .frame(minHeight: 140, maxHeight: 200)
            .onChange(of: viewModel.chatMessages.count) { _, _ in
                if let lastID = viewModel.chatMessages.last?.id {
                    DispatchQueue.main.async {
                        withAnimation {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
}

struct ChatInputField: View {
    @ObservedObject var viewModel: NotchViewModel
    
    private var isSendDisabled: Bool {
        viewModel.chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isChatLoading
    }
    
    var body: some View {
        HStack(spacing: 10) {
            TextField("Bir şeyler yaz...", text: $viewModel.chatInput)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .foregroundColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.08))
                )
                .onSubmit { viewModel.sendChatMessage() }
            
            Button(action: { viewModel.sendChatMessage() }) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(
                        Circle()
                            .fill(isSendDisabled ? Color.white.opacity(0.12) : Color.blue.opacity(0.85))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isSendDisabled)
        }
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .assistant {
                bubble
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                bubble
            }
        }
    }
    
    private var bubble: some View {
        Text(message.text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .multilineTextAlignment(.leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(message.role == .assistant ? Color.white.opacity(0.08) : Color.blue.opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(message.isError ? Color.red.opacity(0.7) : Color.white.opacity(0.12), lineWidth: 1)
            )
            .frame(maxWidth: 320, alignment: .leading)
    }
}

// MARK: - Circular Gauge (Speedometer style with dynamic colors)
struct CircularGauge: View {
    let label: String
    let value: Double // 0.0 to 1.0
    let color: Color // Base color (not used, calculated dynamically)
    
    // Calculate color based on usage level
    private var usageColor: Color {
        switch value {
        case 0.0..<0.4:
            return .green // İyi (düşük kullanım)
        case 0.4..<0.7:
            return .blue // Orta kullanım
        case 0.7..<0.9:
            return .yellow // Yüksek kullanım
        default:
            return .red // Yüksek riskli (çok yüksek)
        }
    }
    
    // Calculate usage level text
    private var usageLevel: String {
        switch value {
        case 0.0..<0.4:
            return "İyi"
        case 0.4..<0.7:
            return "Orta"
        case 0.7..<0.9:
            return "Yüksek"
        default:
            return "Riskli"
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background circle (full circle, but we'll show top half like speedometer)
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 6)
                    .frame(width: 65, height: 65)
                
                // Progress arc - speedometer style (top half circle, 180 degrees)
                // Color changes based on usage level, grows from left to right
                Circle()
                    .trim(from: 0, to: min(value, 1.0) * 0.5) // Only show top half (0.5 = 180 degrees)
                    .stroke(
                        usageColor,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 65, height: 65)
                    .rotationEffect(.degrees(-90)) // Start from top
                    .animation(.linear(duration: 0.3), value: value)
                
                // Center value text
                VStack(spacing: 0) {
                    Text("\(Int(value * 100))")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("%")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .offset(y: 8)
                }
            }
            
            VStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))
                
                Text(usageLevel)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(usageColor)
            }
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject var viewModel: NotchViewModel
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                
                ScrollView {
                    settingsContent
                        .padding(18)
                }
                .frame(width: min(geometry.size.width * 0.85, 350), height: min(geometry.size.height * 0.8, 500))
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.black.opacity(0.55),
                                    Color.black.opacity(0.45)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 10)
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black.opacity(0.35))
                                .blur(radius: 10)
                        )
                        .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 15)
                )
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
    }
    
    private var settingsContent: some View {
        VStack(spacing: 16) {
            settingsHeader
            Divider()
                .background(Color.white.opacity(0.25))
            settingsList
        }
    }
    
    private var settingsHeader: some View {
        HStack {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 16))
                .foregroundColor(.white)
            
            Text("Ayarlar")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: { viewModel.showSettings = false }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.85))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var settingsList: some View {
        VStack(alignment: .leading, spacing: 14) {
            RefreshIntervalSetting(
                title: "CPU",
                value: Binding(
                    get: { viewModel.cpuRefreshInterval },
                    set: { viewModel.updateCPURefreshInterval($0) }
                ),
                range: 1...60
            )
            
            RefreshIntervalSetting(
                title: "RAM",
                value: Binding(
                    get: { viewModel.ramRefreshInterval },
                    set: { viewModel.updateRAMRefreshInterval($0) }
                ),
                range: 1...60
            )
            
            RefreshIntervalSetting(
                title: "Disk",
                value: Binding(
                    get: { viewModel.diskRefreshInterval },
                    set: { viewModel.updateDiskRefreshInterval($0) }
                ),
                range: 1...60
            )
            
            RefreshIntervalSetting(
                title: "GPU",
                value: Binding(
                    get: { viewModel.gpuRefreshInterval },
                    set: { viewModel.updateGPURefreshInterval($0) }
                ),
                range: 1...60
            )
            
            RefreshIntervalSetting(
                title: "Internet Hız Testi",
                value: Binding(
                    get: { viewModel.internetSpeedRefreshInterval },
                    set: { viewModel.updateInternetSpeedRefreshInterval($0) }
                ),
                range: 10...300
            )
            
            RefreshIntervalSetting(
                title: "Pano",
                value: Binding(
                    get: { viewModel.clipboardRefreshInterval },
                    set: { viewModel.updateClipboardRefreshInterval($0) }
                ),
                range: 1...60
            )
        }
    }
}

// MARK: - Refresh Interval Setting Component
struct RefreshIntervalSetting: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.95))
            
            HStack(spacing: 10) {
                Slider(value: $value, in: range, step: 1)
                    .accentColor(.white)
                
                Text("\(Int(value)) sn")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))
                    .frame(width: 45)
            }
        }
    }
}

struct QuickIntervalButton: View {
    let seconds: Double
    @ObservedObject var viewModel: NotchViewModel
    
    var body: some View {
        Button(action: { viewModel.updateRefreshInterval(seconds) }) {
            Text("\(Int(seconds))s")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(viewModel.refreshInterval == seconds ? .black : .white.opacity(0.95))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(viewModel.refreshInterval == seconds ? Color.white : Color.white.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(viewModel.refreshInterval == seconds ? 0.0 : 0.2), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ContentView(viewModel: NotchViewModel())
        .frame(width: 600, height: 400)
        .background(Color.gray.opacity(0.2))
}
