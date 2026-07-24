//
//  LifeGridView.swift
//  Gyakusan
//
//  Created by Kenichiro Suzuki on 2026/07/22.
//

import SwiftUI

struct LifeGridView: View {
    let lifeStats: TimeCalculator.LifeStats
    
    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 6), count: 10)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Life Progress Grid")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(lifeStats.passedYears) / \(lifeStats.totalYears) Years")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(0..<lifeStats.gridTotalCount, id: \.self) { index in
                    let isPassed = index < lifeStats.gridPassedCount
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isPassed ? Color.primary : Color(uiColor: .systemGray5))
                        .aspectRatio(1.0, contentMode: .fit)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal)
    }
}

#Preview("Life Grid View") {
    let mockLifeStats = TimeCalculator.LifeStats(
        totalYears: 80,
        passedYears: 32,
        remainingYears: 48,
        remainingDays: 17520,
        progressPercentage: 40.0
    )
    
    LifeGridView(lifeStats: mockLifeStats)
        .padding(.vertical)
        .background(Color(uiColor: .systemGroupedBackground))
}
