//
//  LimitGridView.swift
//  Gyakusan
//

import SwiftUI

struct LimitGridView: View {
    let timeFrame: TimeFrame
    let lifeStats: TimeCalculator.LifeStats?
    let currentDate: Date
    var hasCompletedTask: ((Int) -> Bool)? = nil
    var onSelectIndex: ((Int) -> Void)? = nil
    
    private static let sharedStore = UserDefaults(suiteName: "group.com.suzuki.kenichiro.Gyakusan")
    
    @AppStorage("highlightColorHex", store: sharedStore)
    private var highlightColorHex: String = "#8E8E93"
    
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
                Text("\(passedCount) / \(totalCount) \(unitText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(0..<totalCount, id: \.self) { index in
                    let isCompletedExist = hasCompletedTask?(index) ?? false
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(gridColor(for: index))
                        .aspectRatio(1.0, contentMode: .fit)
                        .overlay(
                            Group {
                                if isCompletedExist {
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(Color(hex: highlightColorHex), lineWidth: 3)
                                }
                            }
                        )
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
    
    private func gridColor(for index: Int) -> Color {
        if index < passedCount {
            return Color.primary
        } else if index == passedCount {
            return Color(hex: highlightColorHex)
        } else {
            return Color(uiColor: .systemGray5)
        }
    }
}

// MARK: - Previews
#Preview("LimitGridView Status Comparison") {
    struct PreviewWrapper: View {
        let calendar = Calendar.current
        let now = Date()
        
        // テスト用の Theme Color (Teal/Green) をセット
        init() {
            let sharedStore = UserDefaults(suiteName: "group.com.suzuki.kenichiro.Gyakusan")
            sharedStore?.set("#00A896", forKey: "highlightColorHex")
        }
        
        var body: some View {
            ScrollView {
                VStack(spacing: 24) {
                    // 1. タスク未完了（通常表示）
                    VStack(alignment: .leading, spacing: 4) {
                        Text("1. Standard Grid (No Completed Tasks)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        
                        LimitGridView(
                            timeFrame: .year,
                            lifeStats: nil,
                            currentDate: now,
                            hasCompletedTask: { _ in false }
                        )
                    }
                    
                    // 2. 特定の月・日・時間に完了タスクあり（枠線表示）
                    VStack(alignment: .leading, spacing: 4) {
                        Text("2. With Completed Tasks (Index 1, 3, 4, 7)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        
                        LimitGridView(
                            timeFrame: .year,
                            lifeStats: nil,
                            currentDate: now,
                            hasCompletedTask: { index in
                                // 過去(1, 3)、現在(4 = 10月/PassedCount 9)、未来(7) に完了タスクが存在するダミー状態
                                [1, 3, 9, 11].contains(index)
                            }
                        )
                    }
                }
                .padding(.vertical)
            }
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }
    
    return PreviewWrapper()
}
