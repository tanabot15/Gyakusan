//
//  FocusTimerView.swift
//  Gyakusan
//

import SwiftUI
import SwiftData
import Combine
import UserNotifications
import ActivityKit

struct FocusTimerView: View {
    @Binding var selectedTab: MainTabView.Tab
    @Binding var targetTask: LimitTask?
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \LimitTask.createdAt, order: .forward) private var allTasks: [LimitTask]
    
    private static let sharedStore = UserDefaults(suiteName: "group.com.suzuki.kenichiro.Gyakusan")
    @AppStorage("highlightColorHex", store: sharedStore)
    private var highlightColorHex: String = "#8E8E93"
    
    @AppStorage("focusTimerEndDate") private var timerEndDateInterval: Double = 0
    @AppStorage("focusTimerIsRunning") private var storedIsRunning: Bool = false
    @AppStorage("focusTimerModeRaw") private var storedTimerModeRaw: String = "focus"
    @AppStorage("focusTimerFocusMinutes") private var focusMinutes: Int = 25
    @AppStorage("focusTimerBreakMinutes") private var breakMinutes: Int = 5
    
    @State private var timerMode: TimerMode = .focus
    @State private var remainingSeconds: Int = 25 * 60
    @State private var isRunning: Bool = false
    
    @State private var selectedPickerTaskID: UUID? = nil
    @State private var confirmedTask: LimitTask? = nil
    
    @State private var isShowingTaskCompletionAlert: Bool = false
    @State private var completedTaskTarget: LimitTask? = nil
    
    // Live Activity Management
    @State private var currentActivity: Activity<FocusTimerAttributes>? = nil
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let timerNotificationID = "FocusTimerNotification"
    
    private var allUncompletedTasks: [LimitTask] {
        allTasks.filter { task in
            !task.isCompleted && task.isCurrentPeriod(for: task.timeFrame)
        }
    }
    
    private var tasksByTimeFrame: [(TimeFrame, [LimitTask])] {
        TimeFrame.allCases.compactMap { frame in
            let tasks = allUncompletedTasks.filter { $0.timeFrame == frame }
            return tasks.isEmpty ? nil : (frame, tasks)
        }
    }
    
    private var currentDefaultSeconds: Int {
        switch timerMode {
        case .focus: return focusMinutes * 60
        case .breakTime: return breakMinutes * 60
        }
    }
    
    private var currentTotalBlocks: Int {
        switch timerMode {
        case .focus: return focusMinutes
        case .breakTime: return breakMinutes
        }
    }
    
    private var elapsedSeconds: Int {
        max(0, currentDefaultSeconds - remainingSeconds)
    }
    
    private var passedMinuteBlocks: Int {
        min(currentTotalBlocks, elapsedSeconds / 60)
    }
    
    private var currentSecondInBlock: Int {
        if elapsedSeconds >= currentDefaultSeconds { return 60 }
        return elapsedSeconds % 60
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
                        topHeaderSection
                        
                        timerGridCard
                    }
                    .padding(.vertical, 16)
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
            .onChange(of: focusMinutes) { _, _ in
                if !isRunning && timerMode == .focus {
                    resetTimer(to: .focus)
                }
            }
            .onChange(of: breakMinutes) { _, _ in
                if !isRunning && timerMode == .breakTime {
                    resetTimer(to: .breakTime)
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
                if let task = targetTask {
                    confirmedTask = task
                    selectedPickerTaskID = task.id
                } else if selectedPickerTaskID == nil {
                    selectedPickerTaskID = allUncompletedTasks.first?.id
                }
            }
            .onChange(of: targetTask) { _, newTask in
                if let task = newTask {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        confirmedTask = task
                        selectedPickerTaskID = task.id
                    }
                }
            }
            .onChange(of: allUncompletedTasks) { _, newTasks in
                if let selectedID = selectedPickerTaskID, !newTasks.contains(where: { $0.id == selectedID }) {
                    selectedPickerTaskID = newTasks.first?.id
                } else if selectedPickerTaskID == nil {
                    selectedPickerTaskID = newTasks.first?.id
                }
            }
        }
    }
    
    // MARK: - Top Header Section (2-Row Layout)
    private var topHeaderSection: some View {
        VStack(spacing: 16) {
            // Row 1: Controls & Giant Countdown Timer
            HStack(alignment: .center, spacing: 12) {
                HStack(spacing: 10) {
                    // Play / Pause Main Button
                    Button(action: { toggleTimer() }) {
                        Image(systemName: isRunning ? "pause.fill" : "play.fill")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(isRunning ? Color.orange : Color(hex: highlightColorHex))
                            .clipShape(Circle())
                            .shadow(color: (isRunning ? Color.orange : Color(hex: highlightColorHex)).opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    
                    // Mode Toggle
                    Button(action: { toggleMode() }) {
                        Image(systemName: timerMode.systemImageName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 40, height: 40)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    // Reset Button
                    Button(action: { resetTimer(to: timerMode) }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 40, height: 40)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                // Countdown Clock Display
                VStack(alignment: .trailing, spacing: 2) {
                    Text(timeString(from: remainingSeconds))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .fontDesign(.monospaced)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(isRunning ? Color.primary : Color.secondary)
                    
                    Text(timerMode.title.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .tracking(1)
                }
            }
            
            // Row 2: Task Selection Menu Bar
            taskMenuButton
        }
        .padding(.horizontal)
    }
        
    // MARK: - Task Menu Button Component (Multi-Timeframe Support)
    private var taskMenuButton: some View {
        let themeColor = Color(hex: highlightColorHex)
        
        return Menu {
            if allUncompletedTasks.isEmpty {
                Text("No Active Tasks")
            } else {
                if confirmedTask != nil {
                    Button(role: .destructive) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            confirmedTask = nil
                            targetTask = nil
                        }
                    } label: {
                        Label("Clear Selected Task", systemImage: "xmark.circle")
                    }
                    Divider()
                }
                
                ForEach(tasksByTimeFrame, id: \.0) { frame, tasks in
                    Menu {
                        ForEach(tasks) { task in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    confirmedTask = task
                                    targetTask = task
                                    selectedPickerTaskID = task.id
                                }
                            } label: {
                                HStack {
                                    Text(task.title)
                                    if confirmedTask?.id == task.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Text(frame.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                // Icon Header
                ZStack {
                    Circle()
                        .fill(
                            confirmedTask == nil
                            ? Color.gray.opacity(0.12)
                            : themeColor.opacity(0.18)
                        )
                        .frame(width: 34, height: 34)
                    
                    Image(systemName: confirmedTask == nil ? "target" : "checkmark.circle.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(
                            confirmedTask == nil
                            ? Color.secondary
                            : themeColor
                        )
                }
                
                // Task Label & Subtitle
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(confirmedTask == nil ? "Select Target Task" : "TARGET TASK")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(confirmedTask == nil ? Color.secondary.opacity(0.7) : themeColor)
                            .tracking(0.6)
                        
                        if let frame = confirmedTask?.timeFrame {
                            Text(frame.title.uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(themeColor.opacity(0.15))
                                .foregroundStyle(themeColor)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(confirmedTask?.title ?? "Tap to assign a target task")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(confirmedTask == nil ? Color.secondary : Color.primary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Action Icon
                if confirmedTask != nil {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            confirmedTask = nil
                            targetTask = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(themeColor.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Group {
                    if confirmedTask == nil {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemBackground))
                    } else {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [themeColor.opacity(0.12), themeColor.opacity(0.05)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        confirmedTask == nil
                        ? Color.clear
                        : themeColor.opacity(0.3),
                        lineWidth: 1.2
                    )
            )
            .shadow(
                color: confirmedTask == nil ? Color.clear : themeColor.opacity(0.12),
                radius: 8,
                x: 0,
                y: 3
            )
        }
    }
    
    // MARK: - Live Activity Control Logic
    private func startActivity(endDate: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endActivity()
        
        let attributes = FocusTimerAttributes(
            taskTitle: confirmedTask?.title ?? "Free Focus",
            timerModeTitle: timerMode.title
        )
        let initialContentState = FocusTimerAttributes.ContentState(
            endDate: endDate,
            isRunning: true,
            totalMinutes: currentTotalBlocks,
            highlightColorHex: highlightColorHex
        )
        
        do {
            let activity = try Activity<FocusTimerAttributes>.request(
                attributes: attributes,
                content: .init(state: initialContentState, staleDate: nil)
            )
            self.currentActivity = activity
        } catch {
            print("Failed to start Live Activity: \(error.localizedDescription)")
        }
    }
    
    private func endActivity() {
        Task {
            for activity in Activity<FocusTimerAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            currentActivity = nil
        }
    }
    
    // MARK: - Pomodoro Log Save Helper
    private func savePomodoroLog(durationMinutes: Int, taskTitle: String? = nil) {
        let log = PomodoroLog(
            completedAt: Date(),
            durationMinutes: durationMinutes,
            taskTitle: taskTitle
        )
        modelContext.insert(log)
        try? modelContext.save()
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
                endActivity()
                handleTimerFinished()
            }
        } else if remainingSeconds > 0 {
            remainingSeconds -= 1
        } else {
            isRunning = false
            storedIsRunning = false
            cancelNotification()
            endActivity()
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
                endActivity()
                handleTimerFinished()
            }
        } else {
            isRunning = false
        }
    }
    
    private func restoreTimerState() {
        if let mode = TimerMode(rawValue: storedTimerModeRaw) {
            timerMode = mode
        }
        
        syncTimerWithTargetDate()
        
        if !storedIsRunning && timerEndDateInterval == 0 {
            remainingSeconds = currentDefaultSeconds
        }
    }
    
    private func scheduleNotification(after seconds: Int) {
        cancelNotification()
        
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
        if timerMode == .focus {
            savePomodoroLog(durationMinutes: focusMinutes, taskTitle: confirmedTask?.title)
        }
        
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
            targetTask = nil
            completedTaskTarget = nil
        }
    }
    
    // MARK: - Minutes-Only Timer Card (With Progressive Fill Effect)
    private var timerGridCard: some View {
        let totalMin = currentTotalBlocks
        let passedMin = passedMinuteBlocks
        let minColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)
        
        let progressInCurrentMinute = Double(currentSecondInBlock) / 60.0
        
        return VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("MINUTES GRID")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .tracking(1)
                    Spacer()
                }
                
                LazyVGrid(columns: minColumns, spacing: 8) {
                    ForEach(0..<totalMin, id: \.self) { index in
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(uiColor: .tertiarySystemFill))
                            
                            if index < passedMin {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.primary)
                            } else if index == passedMin && progressInCurrentMinute > 0 {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color(hex: highlightColorHex))
                                    .opacity(0.15 + (0.85 * progressInCurrentMinute))
                            }
                        }
                        .aspectRatio(1.0, contentMode: .fit)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(index == passedMin && progressInCurrentMinute > 0 ? Color(hex: highlightColorHex) : Color.clear, lineWidth: 1.5)
                        )
                        .animation(.linear(duration: 1.0), value: currentSecondInBlock)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
        .padding(.horizontal)
    }
    
    private func timeString(from totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func toggleTimer() {
        withAnimation {
            if remainingSeconds <= 0 {
                remainingSeconds = currentDefaultSeconds
            }
            
            isRunning.toggle()
            storedIsRunning = isRunning
            
            if isRunning {
                let targetDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
                timerEndDateInterval = targetDate.timeIntervalSince1970
                scheduleNotification(after: remainingSeconds)
                startActivity(endDate: targetDate)
            } else {
                timerEndDateInterval = 0
                cancelNotification()
                endActivity()
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
        remainingSeconds = currentDefaultSeconds
        cancelNotification()
        endActivity()
    }
}

// MARK: - Previews
#Preview {
    struct PreviewContainer {
        @MainActor
        static let container: ModelContainer = {
            do {
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                let container = try ModelContainer(for: LimitTask.self, PomodoroLog.self, configurations: config)
                let context = container.mainContext
                
                let now = Date()
                
                let sampleTasks: [LimitTask] = [
                    LimitTask(
                        title: "day task 1",
                        timeFrameRawValue: TimeFrame.day.rawValue,
                        dueDate: now,
                        isFlagged: true
                    ),
                    LimitTask(
                        title: "month task 1",
                        timeFrameRawValue: TimeFrame.month.rawValue,
                        dueDate: now
                    ),
                    LimitTask(
                        title: "year task 1",
                        timeFrameRawValue: TimeFrame.year.rawValue
                    )
                ]
                
                for task in sampleTasks {
                    context.insert(task)
                }
                
                return container
            } catch {
                fatalError("Failed to create preview container: \(error)")
            }
        }()
    }
    
    return FocusTimerView(
        selectedTab: .constant(.focus),
        targetTask: .constant(nil)
    )
    .modelContainer(PreviewContainer.container)
}
