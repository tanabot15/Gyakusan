//
//  LimitGridView.swift
//  Gyakusan
//

import SwiftUI

struct LimitGridView: View {
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("Less")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                    
                    HStack(spacing: 2) {
                        gridCellColor(taskCount: 0)
                            .frame(width: 8, height: 8)
                            .clipShape(RoundedRectangle(cornerRadius: 1.5))
                        gridCellColor(taskCount: 1)
                            .frame(width: 8, height: 8)
                            .clipShape(RoundedRectangle(cornerRadius: 1.5))
                        gridCellColor(taskCount: 2)
                            .frame(width: 8, height: 8)
                            .clipShape(RoundedRectangle(cornerRadius: 1.5))
                        gridCellColor(taskCount: 3)
                            .frame(width: 8, height: 8)
                            .clipShape(RoundedRectangle(cornerRadius: 1.5))
                    }
                    
                    Text("More")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal)
            
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(0..<totalCount, id: \.self) { index in
                    let count = taskCountForIndex?(index) ?? 0
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(gridCellColor(taskCount: count))
                        .aspectRatio(1.0, contentMode: .fit)
                        .overlay(alignment: .top) {
                            if index == passedCount {
                                Circle()
                                    .fill(themeColor)
                                    .frame(width: 6, height: 6)
                                    .offset(y: -8)
                            }
                        }
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
    
    private func gridCellColor(taskCount: Int) -> Color {
        if taskCount == 0 {
            return Color(uiColor: .systemGray5)
        } else if taskCount == 1 {
            return themeColor.opacity(0.35)
        } else if taskCount == 2 {
            return themeColor.opacity(0.65)
        } else {
            return themeColor // 3個以上
        }
    }
}

#Preview("LimitGridView") {
    LimitGridView(
        timeFrame: .month,
        lifeStats: nil,
        currentDate: Date(),
        taskCountForIndex: { index in index % 4 }
    )
}
