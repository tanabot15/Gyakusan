//
//  TimelineView.swift
//  Gyakusan
//

import SwiftUI
import SwiftData

struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - AppStorage (Highlight Color)
    private static let sharedStore = UserDefaults(suiteName: "group.com.suzuki.kenichiro.Gyakusan")
    
    @AppStorage("highlightColorHex", store: sharedStore)
    private var highlightColorHex: String = "#8E8E93"
    
    private var presentColor: Color {
        Color(hex: highlightColorHex)
    }
    
    @Query private var userProfiles: [UserProfile]
    @Query(sort: \LimitTask.createdAt, order: .reverse) private var allTasks: [LimitTask]
    @Query(sort: \LifeEvent.date, order: .reverse) private var allEvents: [LifeEvent]
    
    @State private var currentDate: Date = Date()
    @State private var showingAddEventSheet: Bool = false
    @State private var showingAddTaskSheet: Bool = false
    @State private var selectedEventForEdit: LifeEvent? = nil
    
    private var currentProfile: UserProfile {
        userProfiles.first ?? UserProfile()
    }
    
    private var timelineTasks: [LimitTask] {
        allTasks.filter { $0.showInTimeline }
    }

    private struct AgeGroup: Identifiable {
        let id: String
        let age: Int?
        let ageText: String
        let yearText: String
        let isCurrentAge: Bool
        let isPast: Bool
        let tasks: [LimitTask]
        let events: [LifeEvent]
    }
    
    private var timelineGroups: [AgeGroup] {
        let calendar = Calendar.current
        let birthYear = calendar.component(.year, from: currentProfile.birthday)
        let currentAge = calendar.dateComponents([.year], from: currentProfile.birthday, to: currentDate).year ?? 0
        
        var tasksByAge: [Int: [LimitTask]] = [:]
        var eventsByAge: [Int: [LifeEvent]] = [:]
        var undatedTasks: [LimitTask] = []
        
        for task in timelineTasks {
            let targetDate: Date? = task.completedAt ?? task.dueDate
            if let date = targetDate {
                let ageAtTask = calendar.dateComponents([.year], from: currentProfile.birthday, to: date).year ?? 0
                tasksByAge[ageAtTask, default: []].append(task)
            } else {
                undatedTasks.append(task)
            }
        }
        
        for event in allEvents {
            let ageAtEvent = calendar.dateComponents([.year], from: currentProfile.birthday, to: event.date).year ?? 0
            eventsByAge[ageAtEvent, default: []].append(event)
        }
        
        let allAgesWithItems = Set(tasksByAge.keys).union(eventsByAge.keys).sorted()
        
        let minAge = 0
        let maxAge = max(currentAge + 5, max(currentProfile.targetAge, allAgesWithItems.last ?? currentAge))
        
        var groups: [AgeGroup] = []
        
        for age in minAge...maxAge {
            let tasks = tasksByAge[age] ?? []
            let events = eventsByAge[age] ?? []
            
            if !tasks.isEmpty || !events.isEmpty || age == currentAge || age % 10 == 0 {
                groups.append(AgeGroup(
                    id: "\(age)",
                    age: age,
                    ageText: "\(age) y/o",
                    yearText: "\(birthYear + age)",
                    isCurrentAge: age == currentAge,
                    isPast: age < currentAge,
                    tasks: tasks,
                    events: events
                ))
            }
        }
        
        if !undatedTasks.isEmpty {
            groups.append(AgeGroup(
                id: "someday",
                age: nil,
                ageText: "Someday",
                yearText: "Future",
                isCurrentAge: false,
                isPast: false,
                tasks: undatedTasks,
                events: []
            ))
        }
        
        return groups
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    BannerAdView()
                        .frame(height: 50)
                        .background(Color(uiColor: .systemGroupedBackground))
                    
                    ScrollView {
                        lifeTimelineSection
                            .padding(.vertical, 8)
                            .padding(.bottom, 80)
                    }
                }
                .background(Color(uiColor: .systemGroupedBackground))
                
                floatingControlBar
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
            }
            .sheet(isPresented: $showingAddEventSheet) {
                LifeEventFormSheet()
            }
            .sheet(isPresented: $showingAddTaskSheet) {
                TaskFormSheet(selectedTimeFrame: .life)
            }
            .sheet(item: $selectedEventForEdit) { event in
                LifeEventFormSheet(eventToEdit: event)
            }
        }
    }
    
    // MARK: - Floating Control Bar
    @ViewBuilder
    private var floatingControlBar: some View {
        HStack(spacing: 12) {
            Button(action: {
                showingAddEventSheet = true
            }) {
                Image(systemName: "calendar.badge.plus")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(.orange)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)

            Button(action: {
                showingAddTaskSheet = true
            }) {
                Image(systemName: "plus")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.accentColor)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Life Timeline Section
    private var lifeTimelineSection: some View {
        VStack(spacing: 0) {
            ForEach(timelineGroups) { group in
                HStack(alignment: .top, spacing: 8) {
                    // Left: Age & Year
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(group.ageText)
                            .font(.subheadline)
                            .fontWeight(group.isCurrentAge ? .bold : .semibold)
                            .foregroundStyle(
                                group.isCurrentAge ? presentColor : (group.id == "someday" ? .orange : (group.isPast ? .secondary : .primary))
                            )
                        
                        Text(group.yearText)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(width: 52, alignment: .trailing)
                    
                    // Center: Timeline Axis
                    VStack(spacing: 0) {
                        Circle()
                            .fill(
                                group.isCurrentAge ? presentColor :
                                (group.id == "someday" ? Color.orange :
                                ((group.tasks.isEmpty && group.events.isEmpty) ? Color.gray.opacity(0.3) :
                                (group.isPast ? Color.blue : Color.green)))
                            )
                            .frame(width: group.isCurrentAge ? 12 : 8, height: group.isCurrentAge ? 12 : 8)
                            .padding(.top, 4)
                        
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 2)
                            .frame(maxHeight: .infinity)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        if group.isCurrentAge {
                            Text("PRESENT")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(presentColor)
                        }
                        
                        // Life Events Display (Right aligned)
                        ForEach(group.events) { event in
                            HStack {
                                Spacer(minLength: 0)
                                timelineEventCard(event)
                            }
                        }
                        
                        // Tasks Display (Left aligned)
                        ForEach(group.tasks) { task in
                            HStack {
                                timelineTaskCard(task)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 12)
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
        .padding(.horizontal, 8)
    }
    
    // MARK: - Timeline Event Card (Distinctive Milestone Style)
    private func timelineEventCard(_ event: LifeEvent) -> some View {
        Button {
            selectedEventForEdit = event
        } label: {
            HStack(spacing: 8) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Image(systemName: event.iconName)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(presentColor)
                    .frame(width: 24, height: 24)
                    .background(presentColor.opacity(0.12))
                    .clipShape(Circle())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(presentColor.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(presentColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Timeline Task Card with NavigationLink
    private func timelineTaskCard(_ task: LimitTask) -> some View {
        NavigationLink(destination: TaskFormSheet(taskToEdit: task)) {
            HStack(spacing: 8) {
                Button {
                    withAnimation {
                        task.isCompleted.toggle()
                        task.completedAt = task.isCompleted ? Date() : nil
                        try? modelContext.save()
                    }
                } label: {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.body)
                        .foregroundStyle(task.isCompleted ? .green : .secondary)
                }
                .buttonStyle(.plain)
                
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    struct PreviewContainer {
        @MainActor
        static let container: ModelContainer = {
            do {
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                let container = try ModelContainer(for: LimitTask.self, UserProfile.self, LifeEvent.self, configurations: config)
                let context = container.mainContext
                
                let profile = UserProfile()
                profile.birthday = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
                profile.targetAge = 80
                context.insert(profile)
                
                let event = LifeEvent(title: "Joined Company", date: Calendar.current.date(byAdding: .year, value: -5, to: Date())!, iconName: "briefcase.fill")
                context.insert(event)
                
                let pastTask = LimitTask(
                    title: "Achieved Life Goal Example",
                    timeFrameRawValue: TimeFrame.life.rawValue
                )
                pastTask.isCompleted = true
                pastTask.completedAt = Calendar.current.date(byAdding: .year, value: -2, to: Date())
                context.insert(pastTask)
                
                return container
            } catch {
                fatalError("Failed to create preview container: \(error)")
            }
        }()
    }
    
    return TimelineView()
        .environment(\.isPreview, true)
        .modelContainer(PreviewContainer.container)
}
