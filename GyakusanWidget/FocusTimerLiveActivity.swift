//
//  FocusTimerLiveActivity.swift
//  GyakusanWidgetExtension
//
//  Created by Kenichiro Suzuki on 2026/09/14.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct FocusTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusTimerAttributes.self) { context in
            // MARK: - Lock Screen & Banner View
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(context.attributes.timerModeTitle, systemImage: "timer")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text(context.attributes.taskTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                HStack(alignment: .center) {
                    // Countdown View
                    Text(timerInterval: Date()...context.state.endDate, pauseTime: context.state.isRunning ? nil : Date())
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)

                    Spacer()

                    // Dot Progress View
                    HStack(spacing: 4) {
                        ForEach(0..<min(context.state.totalMinutes, 10), id: \.self) { index in
                            Circle()
                                .fill(index < 5 ? Color.primary : Color(uiColor: .systemGray4))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }
            .padding(16)
            .activityBackgroundTint(Color(uiColor: .secondarySystemGroupedBackground))
            .activitySystemActionForegroundColor(Color.primary)

        } dynamicIsland: { context in
            // MARK: - Dynamic Island Layout
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        Text(context.attributes.timerModeTitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(context.attributes.taskTitle)
                            .font(.footnote.weight(.semibold))
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date()...context.state.endDate, pauseTime: context.state.isRunning ? nil : Date())
                        .font(.title2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.accentColor)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(Color.accentColor)
            } compactTrailing: {
                Text(timerInterval: Date()...context.state.endDate, pauseTime: context.state.isRunning ? nil : Date())
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .frame(width: 44)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
}
