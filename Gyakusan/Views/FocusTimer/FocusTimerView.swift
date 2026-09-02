//
//  FocusTimerView.swift
//  Gyakusan
//
//  Created by Kenichiro Suzuki on 2026/08/27.
//

import SwiftUI
import SwiftData
import Combine
import UserNotifications

struct FocusTimerView: View {
    @Binding var selectedTab: MainTabView.Tab
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \LimitTask.createdAt, order: .forward) private var allTasks: [LimitTask]
    
    @AppStorage("highlightColorHex") private var highlightColorHex: String = "#8E8E93"
    
    @AppStorage("focusTimerEndDate") private var timerEndDateInterval: Double = 0
    @AppStorage("focusTimerIsRunning") private var storedIsRunning: Bool = false
    @AppStorage("focusTimerModeRaw") private var storedTimerModeRaw: String = "focus"
    
    @State private var timerMode: TimerMode = .focus
    @State private var remainingSeconds: Int = 25 * 60
    @State private var isRunning: Bool = false
    
    @State private var selectedPickerTaskID: UUID? = nil
    @State private var confirmedTask: LimitTask? = nil
    
    @State private var isShowingTaskCompletionAlert: Bool = false
    @State private var completedTaskTarget: LimitTask? = nil
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let timerNotificationID = "FocusTimerNotification"
    
    private var uncompletedDayTasks: [LimitTask] {
        allTasks.filter { task in
            !task.isCompleted &&
            task.timeFrame == .day &&
            task.isCurrentPeriod(for: .day)
        }
    }
    
    enum TimerMode: String {
        case focus
        case breakTime
        
        var title: String {
            switch self {
            case .focus: return "Focus Time"
            case .breakTime: return "Break Time"
            }
        }
        
        var defaultSeconds: Int {
            switch self {
            case .focus: return 25 * 60
            case .breakTime: return 5 * 60
            }
        }
        
        var totalBlocks: Int {
            switch self {
            case .focus: return 25
            case .breakTime: return 5
            }
        }
        
        var toggleNext: TimerMode {
            switch self {
            case .focus: return .breakTime
            case .breakTime: return .focus
            }
        }
        
        var systemImageName: String {
            switch self {
            case .focus: return "cup.and.saucer.fill"
            case .breakTime: return "brain.filled.head.profile"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BannerAdView()
                    .frame(height: 50)
                    .background(Color(uiColor: .systemGroupedBackground))
                
                ScrollView {
                    VStack(spacing: 20) {
                        taskSelectionSection
                        
                        timerGridCard
                        
                        Text(formattedTime(remainingSeconds))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                            .padding(.vertical, 4)
                        
                        timerControls
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .onReceive(timer) { _ in
                guard isRunning else { return }
                updateTimerState()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    syncTimerWithTargetDate()
                }
            }
            .alert("Focus Finished!", isPresented: $isShowingTaskCompletionAlert) {
                Button("Completed") {
                    if let task = completedTaskTarget {
                        completeTask(task)
                    }
                }
                Button("Not Yet", role: .cancel) {
                    completedTaskTarget = nil
                }
            } message: {
                if let task = completedTaskTarget {
                    Text("Did you complete \"\(task.title)\"?")
                } else {
                    Text("Did you complete your target task?")
                }
            }
            .onAppear {
                restoreTimerState()
                if selectedPickerTaskID == nil {
                    selectedPickerTaskID = uncompletedDayTasks.first?.id
                }
            }
            .onChange(of: uncompletedDayTasks) { _, newTasks in
                if let selectedID = selectedPickerTaskID, !newTasks.contains(where: { $0.id == selectedID }) {
                    selectedPickerTaskID = newTasks.first?.id
                } else if selectedPickerTaskID == nil {
                    selectedPickerTaskID = newTasks.first?.id
                }
            }
        }
    }
    
    // MARK: - Background & Notification Logic
    private func updateTimerState() {
        if timerEndDateInterval > 0 {
            let now = Date().timeIntervalSince1970
            let diff = Int(timerEndDateInterval - now)
            if diff > 0 {
                remainingSeconds = diff
            } else {
                remainingSeconds = 0
                isRunning = false
                storedIsRunning = false
                timerEndDateInterval = 0
                cancelNotification()
                handleTimerFinished()
            }
        } else if remainingSeconds > 0 {
            remainingSeconds -= 1
        } else {
            isRunning = false
            storedIsRunning = false
            cancelNotification()
            handleTimerFinished()
        }
    }
    
    private func syncTimerWithTargetDate() {
        if storedIsRunning && timerEndDateInterval > 0 {
            let now = Date().timeIntervalSince1970
            let diff = Int(timerEndDateInterval - now)
            if diff > 0 {
                remainingSeconds = diff
                isRunning = true
            } else {
                remainingSeconds = 0
                isRunning = false
                storedIsRunning = false
                timerEndDateInterval = 0
                handleTimerFinished()
            }
        }
    }
    
    private func restoreTimerState() {
        if let mode = TimerMode(rawValue: storedTimerModeRaw) {
            timerMode = mode
        }
        syncTimerWithTargetDate()
    }
    
    private func scheduleNotification(after seconds: Int) {
        cancelNotification()
        
        // 0秒以下の場合は通知を発行しない（クラッシュ防止）
        guard seconds > 0 else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "\(timerMode.title) Finished!"
        if timerMode == .focus, let task = confirmedTask {
            content.body = "Great job! Did you complete \"\(task.title)\"?"
        } else {
            content.body = "Time is up! Take a moment to reset."
        }
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: timerNotificationID, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }
    
    private func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [timerNotificationID])
    }
    
    // MARK: - Timer Completion Handler
    private func handleTimerFinished() {
        if timerMode == .focus, let task = confirmedTask {
            completedTaskTarget = task
            isShowingTaskCompletionAlert = true
        }
    }
    
    private func completeTask(_ task: LimitTask) {
        task.isCompleted = true
        task.completedAt = Date()
        
        do {
            try modelContext.save()
            AdMobManager.shared.taskCompleted()
        } catch {
            print("Failed to save completed task state: \(error)")
        }
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            confirmedTask = nil
            completedTaskTarget = nil
        }
    }
    
    // MARK: - Task Selection / Focused Task Card Section
    private var taskSelectionSection: some View {
        VStack(spacing: 12) {
            if let task = confirmedTask {
                focusedTaskCard(for: task)
                    .transition(.scale.combined(with: .opacity))
            } else {
                taskPickerCard
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: confirmedTask)
    }
    
    private var taskPickerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Focus Target", systemImage: "target")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            
            if uncompletedDayTasks.isEmpty {
                HStack {
                    Spacer()
                    Text("No Day Tasks Available")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                HStack(spacing: 12) {
                    Picker("Select Task", selection: $selectedPickerTaskID) {
                        ForEach(uncompletedDayTasks) { task in
                            Text(task.title)
                                .lineLimit(1)
                                .tag(Optional(task.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(uiColor: .tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    
                    Button(action: {
                        if let id = selectedPickerTaskID,
                           let task = uncompletedDayTasks.first(where: { $0.id == id }) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                confirmedTask = task
                            }
                        }
                    }) {
                        Text("Set Focus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(selectedPickerTaskID != nil ? Color.accentColor : Color.gray)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedPickerTaskID == nil)
                }
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    
    private func focusedTaskCard(for task: LimitTask) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 2)
                .fill(task.isFlagged ? Color.orange : Color.accentColor)
                .frame(width: 4)
                .padding(.vertical, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("CURRENT FOCUS")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(task.isFlagged ? Color.orange : Color.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((task.isFlagged ? Color.orange : Color.accentColor).opacity(0.12))
                        .clipShape(Capsule())
                    
                    if task.isFlagged {
                        Image(systemName: "flag.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                
                Text(task.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                
                if let dueDate = task.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text(dueDate.formatted(date: .omitted, time: .shortened))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    confirmedTask = nil
                }
            }) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(Color(uiColor: .tertiarySystemFill))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
    
    // MARK: - Timer Grid Card
    private var timerGridCard: some View {
        let total = timerMode.totalBlocks
        let totalSec = timerMode.defaultSeconds
        let elapsedSec = totalSec - remainingSeconds
        let passedBlocks = min(total, Int(Double(elapsedSec) / Double(totalSec) * Double(total)))
        
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(timerMode.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(passedBlocks) / \(total) min")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<total, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(gridColor(for: index, passedBlocks: passedBlocks))
                        .aspectRatio(1.0, contentMode: .fit)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal)
    }
    
    private func gridColor(for index: Int, passedBlocks: Int) -> Color {
        if index < passedBlocks {
            return Color.primary
        } else if index == passedBlocks && isRunning {
            return Color(hex: highlightColorHex)
        } else {
            return Color(uiColor: .systemGray5)
        }
    }
    
    // MARK: - Timer Controls
    private var timerControls: some View {
        HStack(spacing: 20) {
            Button(action: {
                toggleMode()
            }) {
                Image(systemName: timerMode.systemImageName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 56, height: 56)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            Button(action: {
                toggleTimer()
            }) {
                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(isRunning ? Color.orange : Color.accentColor)
                    .clipShape(Circle())
                    .shadow(color: (isRunning ? Color.orange : Color.accentColor).opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            
            Button(action: {
                resetTimer(to: timerMode)
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 56, height: 56)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }
    
    private func toggleTimer() {
        withAnimation {
            if remainingSeconds <= 0 {
                remainingSeconds = timerMode.defaultSeconds
            }
            
            isRunning.toggle()
            storedIsRunning = isRunning
            
            if isRunning {
                let targetDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
                timerEndDateInterval = targetDate.timeIntervalSince1970
                scheduleNotification(after: remainingSeconds)
            } else {
                timerEndDateInterval = 0
                cancelNotification()
            }
        }
    }
    
    private func toggleMode() {
        withAnimation {
            let nextMode = timerMode.toggleNext
            timerMode = nextMode
            storedTimerModeRaw = nextMode.rawValue
            resetTimer(to: nextMode)
        }
    }
    
    private func resetTimer(to mode: TimerMode) {
        isRunning = false
        storedIsRunning = false
        timerEndDateInterval = 0
        remainingSeconds = mode.defaultSeconds
        cancelNotification()
    }
    
    private func formattedTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

#Preview {
    struct PreviewContainer {
        @MainActor
        static let container: ModelContainer = {
            do {
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                let container = try ModelContainer(for: LimitTask.self, configurations: config)
                let context = container.mainContext
                
                let now = Date()
                
                let sampleDayTasks: [LimitTask] = [
                    LimitTask(
                        title: "day task 1",
                        timeFrameRawValue: TimeFrame.day.rawValue,
                        dueDate: now,
                        isFlagged: true
                    ),
                    LimitTask(
                        title: "day task 2",
                        timeFrameRawValue: TimeFrame.day.rawValue,
                        dueDate: now.addingTimeInterval(3600)
                    ),
                    LimitTask(
                        title: "day task 3",
                        timeFrameRawValue: TimeFrame.day.rawValue
                    )
                ]
                
                for task in sampleDayTasks {
                    context.insert(task)
                }
                
                return container
            } catch {
                fatalError("Failed to create preview container: \(error)")
            }
        }()
    }
    
    return FocusTimerView(selectedTab: .constant(.focus))
        .modelContainer(PreviewContainer.container)
}
