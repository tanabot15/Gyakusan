//
//  LifeGridView.swift
//  Gyakusan
//
//  Created by Kenichiro Suzuki on 2026/07/22.
//

import SwiftUI

struct LimitGridView: View {
    let timeFrame: TimeFrame
    let lifeStats: TimeCalculator.LifeStats?
    let currentDate: Date
    
    @AppStorage("highlightColorHex") private var highlightColorHex: String = "#8E8E93"
    
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
                    RoundedRectangle(cornerRadius: 3)
                        .fill(gridColor(for: index))
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

#Preview("Year Grid View") {
    LimitGridView(
        timeFrame: .year,
        lifeStats: nil,
        currentDate: Date()
    )
    .padding(.vertical)
    .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("Life Grid View") {
    let mockLifeStats = TimeCalculator.LifeStats(
        totalYears: 80,
        passedYears: 32,
        remainingYears: 48,
        remainingMonths: 2,
        remainingDays: 17520,
        progressPercentage: 40.0
    )
    
    LimitGridView(
        timeFrame: .life,
        lifeStats: mockLifeStats,
        currentDate: Date()
    )
    .padding(.vertical)
    .background(Color(uiColor: .systemGroupedBackground))
}
