//
//  LimitGridView.swift
//  Gyakusan
//

import SwiftUI

struct LimitGridView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let timeFrame: TimeFrame
    let lifeStats: TimeCalculator.LifeStats?
    let currentDate: Date
    var taskCountForIndex: ((Int) -> Int)? = nil
    var onSelectIndex: ((Int) -> Void)? = nil
    
    private static let sharedStore = UserDefaults(suiteName: "group.com.suzuki.kenichiro.Gyakusan")
    
    @AppStorage("highlightColorHex", store: sharedStore)
    private var highlightColorHex: String = "#8E8E93"
    
    private var themeColor: Color {
        Color(hex: highlightColorHex)
    }
    
    private var calendar: Calendar { .current }
    
    private var title: String {
        switch timeFrame {
        case .life: return "Life Grid (Years)"
        case .year: return "Year Grid (Months)"
        case .month: return "Month Grid (Days)"
        case .day: return "Day Grid (Hours)"
        }
    }
    
    private var totalCount: Int {
        switch timeFrame {
        case .life:
            return lifeStats?.totalYears ?? 80
        case .year:
            return 12
        case .month:
            let range = calendar.range(of: .day, in: .month, for: currentDate)
            return range?.count ?? 30
        case .day:
            return 24
        }
    }
    
    private var passedCount: Int {
        switch timeFrame {
        case .life:
            return lifeStats?.gridPassedCount ?? 0
        case .year:
            let month = calendar.component(.month, from: currentDate)
            return max(0, month - 1)
        case .month:
            let day = calendar.component(.day, from: currentDate)
            return max(0, day - 1)
        case .day:
            let hour = calendar.component(.hour, from: currentDate)
            return hour
        }
    }
    
    private var unitText: String {
        switch timeFrame {
        case .life: return "Years"
        case .year: return "Months"
        case .month: return "Days"
        case .day: return "Hours"
        }
    }
    
    private var columns: [GridItem] {
        let count: Int
        switch timeFrame {
        case .life: count = 10
        case .year: count = 6
        case .month: count = 7
        case .day: count = 6
        }
        return Array(repeating: GridItem(.flexible(), spacing: 6), count: count)
    }
    
    private var rainbowGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.55, green: 0.20, blue: 0.85),
                Color(red: 0.95, green: 0.25, blue: 0.60),
                Color(red: 1.00, green: 0.50, blue: 0.25),
                Color(red: 1.00, green: 0.85, blue: 0.30)
            ],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // MARK: - ヒートマップ凡例 (現在 + レベル別)
                HStack(spacing: 8) {
                    // 現在セル凡例
                    HStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(rainbowGradient)
                            .frame(width: 8, height: 8)
                        Text("Now")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                    
                    Divider()
                        .frame(height: 8)
                    
                    // タスク達成度凡例
                    HStack(spacing: 3) {
                        Text("Less")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.tertiary)
                        
                        HStack(spacing: 2) {
                            sampleLegendCell(taskCount: 0)
                            sampleLegendCell(taskCount: 1)
                            sampleLegendCell(taskCount: 2)
                            sampleLegendCell(taskCount: 3)
                        }
                        
                        Text("More")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal)
            
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(0..<totalCount, id: \.self) { index in
                    let count = taskCountForIndex?(index) ?? 0
                    
                    cellView(for: index, taskCount: count)
                        .aspectRatio(1.0, contentMode: .fit)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelectIndex?(index)
                        }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal)
    }
    
    // MARK: - Grid Cell Renderer
    @ViewBuilder
    private func cellView(for index: Int, taskCount: Int) -> some View {
        if index == passedCount {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(rainbowGradient)
                .shadow(color: Color.orange.opacity(0.35), radius: 4, x: 0, y: 2)
        } else if index < passedCount {
            let baseColor = colorScheme == .dark
                ? Color(white: 0.82)
                : Color(white: 0.18)
            
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(baseColor)
                .overlay(
                    Group {
                        if taskCount > 0 {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(themeColor.opacity(heatmapOpacity(for: taskCount)))
                        }
                    }
                )
        } else {
            let futureColor = colorScheme == .dark
                ? Color(white: 0.18)
                : Color(white: 0.82)
            
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(futureColor)
        }
    }
    
    private func sampleLegendCell(taskCount: Int) -> some View {
        let baseColor = colorScheme == .dark ? Color(white: 0.5) : Color(white: 0.5)
        
        return RoundedRectangle(cornerRadius: 1.5)
            .fill(baseColor)
            .overlay(
                Group {
                    if taskCount > 0 {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(themeColor.opacity(heatmapOpacity(for: taskCount)))
                    }
                }
            )
            .frame(width: 8, height: 8)
    }
    
    private func heatmapOpacity(for taskCount: Int) -> Double {
        switch taskCount {
        case 0: return 0.0
        case 1: return 0.45
        case 2: return 0.75
        default: return 1.0
        }
    }
}

// MARK: - Previews
#Preview("Light Mode") {
    ScrollView {
        VStack(spacing: 20) {
            LimitGridView(
                timeFrame: .month,
                lifeStats: nil,
                currentDate: Date(),
                taskCountForIndex: { index in index % 4 }
            )
        }
        .padding(.vertical)
    }
    .background(Color(uiColor: .systemGroupedBackground))
    .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    ScrollView {
        VStack(spacing: 20) {
            LimitGridView(
                timeFrame: .month,
                lifeStats: nil,
                currentDate: Date(),
                taskCountForIndex: { index in index % 4 }
            )
        }
        .padding(.vertical)
    }
    .background(Color(uiColor: .systemGroupedBackground))
    .preferredColorScheme(.dark)
}
