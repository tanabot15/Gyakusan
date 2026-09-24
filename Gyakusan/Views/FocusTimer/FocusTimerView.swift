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
import ActivityKit

struct FocusTimerView: View {
    @Binding var selectedTab: MainTabView.Tab
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \LimitTask.createdAt, order: .forward) private var allTasks: [LimitTask]
    
    @AppStorage("highlightColorHex") private var highlightColorHex: String = "#8E8E93"
    
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
    
    private var uncompletedDayTasks: [LimitTask] {
        allTasks.filter { task in
            !task.isCompleted &&
            task.timeFrame == .day &&
            task.isCurrentPeriod(for: .day)
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
    
    // MARK: - Top Header Section (4 Equal Controls)
        private var topHeaderSection: some View {
            HStack(spacing: 12) {
                Spacer()
                    .frame(width: 12)
                // 1. Play / Pause Main Button
                Button(action: { toggleTimer() }) {
                    Image(systemName: isRunning ? "pause.fill" : "play.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(isRunning ? Color.orange : Color.accentColor)
                        .clipShape(Circle())
                        .shadow(color: (isRunning ? Color.orange : Color.accentColor).opacity(0.25), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                
                // 2. Mode Toggle
                Button(action: { toggleMode() }) {
                    Image(systemName: timerMode.systemImageName)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 40, height: 40)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                // 3. Reset Button
                Button(action: { resetTimer(to: timerMode) }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                Spacer()
                    .frame(width: 8)
                
                // 4. Task Selection Menu (タスク設定ボタン)
                taskMenuButton
                
                Spacer()
            }
            .padding(.horizontal)
        }
        
    // MARK: - Task Menu Button Component
    private var taskMenuButton: some View {
        Menu {
            if uncompletedDayTasks.isEmpty {
                Text("No Day Tasks")
            } else {
                if confirmedTask != nil {
                    Button(role: .destructive) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            confirmedTask = nil
                        }
                    } label: {
                        Label("Clear Selected Task", systemImage: "xmark.circle")
                    }
                    Divider()
                }
                
                ForEach(uncompletedDayTasks) { task in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            confirmedTask = task
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
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: confirmedTask == nil ? "target" : "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(confirmedTask == nil ? Color.secondary : Color.accentColor)
                
                Text(confirmedTask?.title ?? "Set Task")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(confirmedTask == nil ? Color.secondary : Color.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                confirmedTask == nil
                ? Color(uiColor: .secondarySystemBackground)
                : Color.accentColor.opacity(0.12)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(confirmedTask == nil ? Color.clear : Color.accentColor.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    private func focusedTaskBar(for task: LimitTask) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(task.isFlagged ? Color.orange : Color.accentColor)
                .frame(width: 6, height: 6)
            
            Text(task.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    confirmedTask = nil
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(Capsule())
    }
    
    private var compactControls: some View {
        HStack(spacing: 8) {
            // Mode Toggle
            Button(action: { toggleMode() }) {
                Image(systemName: timerMode.systemImageName)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            // Play / Pause Main Button
            Button(action: { toggleTimer() }) {
                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(isRunning ? Color.orange : Color.accentColor)
                    .clipShape(Circle())
                    .shadow(color: (isRunning ? Color.orange : Color.accentColor).opacity(0.25), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            
            // Reset Button
            Button(action: { resetTimer(to: timerMode) }) {
                Image(systemName: "arrow.clockwise")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
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
        }
    }
    
    private func restoreTimerState() {
        if let mode = TimerMode(rawValue: storedTimerModeRaw) {
            timerMode = mode
        }
        
        if storedIsRunning && timerEndDateInterval > 0 {
            syncTimerWithTargetDate()
        } else {
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
    
    // MARK: - Refined Pure-Grid Timer Card
    private var timerGridCard: some View {
        let totalMin = currentTotalBlocks
        let passedMin = passedMinuteBlocks
        
        let minColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)
        let secColumns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 10)
        
        return VStack(spacing: 20) {
            // 1. Minutes Grid
            VStack(alignment: .leading, spacing: 8) {
                Text("MINUTES")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .tracking(1)
                
                LazyVGrid(columns: minColumns, spacing: 8) {
                    ForEach(0..<totalMin, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(minuteGridColor(for: index, passed: passedMin))
                            .aspectRatio(1.0, contentMode: .fit)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(index == passedMin && isRunning ? Color(hex: highlightColorHex) : Color.clear, lineWidth: 1.5)
                            )
                            .animation(.easeInOut(duration: 0.2), value: passedMin)
                    }
                }
            }
            
            // 2. Seconds Grid (Square Grid - 60 Blocks)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("SECONDS")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .tracking(1)
                    Spacer()
                    if isRunning && passedMin < totalMin {
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(Color(hex: highlightColorHex))
                            .frame(width: 6, height: 6)
                            .opacity(currentSecondInBlock % 2 == 0 ? 1.0 : 0.2)
                    }
                }
                
                LazyVGrid(columns: secColumns, spacing: 4) {
                    ForEach(0..<60, id: \.self) { secIndex in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(secondGridColor(for: secIndex))
                            .aspectRatio(1.0, contentMode: .fit)
                            .animation(.easeOut(duration: 0.15), value: currentSecondInBlock)
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
    
    // 分ブロックのカラーロジック
    private func minuteGridColor(for index: Int, passed: Int) -> Color {
        if index < passed {
            return Color.primary
        } else if index == passed && isRunning {
            return Color(hex: highlightColorHex).opacity(0.8)
        } else {
            return Color(uiColor: .tertiarySystemFill)
        }
    }
    
    // 秒ブロックのカラーロジック（分ブロックと配色ロジックを完全一致化）
    private func secondGridColor(for secIndex: Int) -> Color {
        let currentSec = currentSecondInBlock
        if passedMinuteBlocks >= currentTotalBlocks {
            return Color.primary
        }
        
        if secIndex < currentSec {
            return Color.primary // 経過した秒：.primary
        } else if secIndex == currentSec && isRunning {
            return Color(hex: highlightColorHex) // 現在の秒：highlightColorHex
        } else {
            return Color(uiColor: .tertiarySystemFill) // 未経過：背景と同化する灰色
        }
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
