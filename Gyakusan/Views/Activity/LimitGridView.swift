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
        case .life: return "Life Grid"
        case .year: return "Year Grid"
        case .month: return "Month Grid"
        case .day: return "Day Grid"
        }
    }
    
    private var totalCount: Int {
        switch timeFrame {
        case .life:
            let totalYears = lifeStats?.totalYears ?? 80
            return totalYears * 12
        case .year:
            return 12 * 32 // 12ヶ月 × 32個 (16列 * 2行)
        case .month:
            let range = calendar.range(of: .day, in: .month, for: currentDate)
            let days = range?.count ?? 30
            return days * 24
        case .day:
            return 288 // 24時間 * 12 (5分ブロック)
        }
    }
    
    private var passedCount: Int {
        switch timeFrame {
        case .life:
            let passedYears = lifeStats?.passedYears ?? 0
            let month = calendar.component(.month, from: currentDate)
            return (passedYears * 12) + (month - 1)
        case .year:
            let month = calendar.component(.month, from: currentDate)
            let day = calendar.component(.day, from: currentDate)
            return ((month - 1) * 32) + (day - 1)
        case .month:
            let day = calendar.component(.day, from: currentDate)
            let hour = calendar.component(.hour, from: currentDate)
            return ((day - 1) * 24) + hour
        case .day:
            let hour = calendar.component(.hour, from: currentDate)
            let minute = calendar.component(.minute, from: currentDate)
            return (hour * 12) + (minute / 5)
        }
    }
    
    private var columnsCount: Int {
        switch timeFrame {
        case .life: return 24  // 横24列 (2年/行)
        case .year: return 16  // 横16列 (1ヶ月につき2行)
        case .month: return 24 // 横24列 (24時間/行)
        case .day: return 12   // 横12列 (1時間＝12個の5分ブロック/行)
        }
    }
    
    private var rowCount: Int {
        totalCount / columnsCount
    }
    
    private var scalerWidth: CGFloat {
        switch timeFrame {
        case .life: return 32
        case .year: return 26
        case .month: return 22
        case .day: return 32
        }
    }
    
    // 全TimeFrameでグリッド間隔を2ptに統一
    private var gridSpacing: CGFloat { 2.0 }
    
    private var cellCornerRadius: CGFloat {
        switch timeFrame {
        case .life, .month, .day: return 1.5
        case .year: return 1.0
        }
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
            // MARK: - Header & Legend
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                HStack(spacing: 8) {
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
            
            // MARK: - Synchronized Scaler & Grid Row List
            VStack(spacing: gridSpacing) {
                ForEach(0..<rowCount, id: \.self) { rowIndex in
                    HStack(spacing: 6) {
                        // 左側スケーラー（各行のグリッド中央に完全同期）
                        Group {
                            if let text = scalerText(for: rowIndex) {
                                Text(text)
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            } else {
                                Color.clear
                            }
                        }
                        .frame(width: scalerWidth, alignment: .trailing)
                        .frame(maxHeight: .infinity, alignment: .center)
                        
                        // 右側グリッド（画面横幅いっぱいに自動伸縮）
                        HStack(spacing: gridSpacing) {
                            ForEach(0..<columnsCount, id: \.self) { colIndex in
                                let index = (rowIndex * columnsCount) + colIndex
                                
                                if isInvalidDateIndex(index) {
                                    Color.clear
                                        .frame(maxWidth: .infinity)
                                        .aspectRatio(1.0, contentMode: .fit)
                                } else {
                                    let count = taskCountForIndex?(index) ?? 0
                                    
                                    cellView(for: index, taskCount: count)
                                        .frame(maxWidth: .infinity)
                                        .aspectRatio(1.0, contentMode: .fit)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            onSelectIndex?(index)
                                        }
                                }
                            }
                        }
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
    
    // MARK: - Scaler Label Provider
    private func scalerText(for rowIndex: Int) -> String? {
        switch timeFrame {
        case .life:
            let age = rowIndex * 2
            return age % 4 == 0 ? "\(age)y" : nil
            
        case .year:
            if rowIndex % 2 == 0 {
                let monthIndex = (rowIndex / 2)
                if monthIndex < 12 {
                    return calendar.shortMonthSymbols[monthIndex]
                }
            }
            return nil
            
        case .month:
            let day = rowIndex + 1
            return (day == 1 || day % 5 == 0) ? "\(day)d" : nil
            
        case .day:
            if rowIndex % 2 == 0 {
                return String(format: "%02d:00", rowIndex)
            }
            return nil
        }
    }
    
    // MARK: - Invalid Date Helper for Year Grid
    private func isInvalidDateIndex(_ index: Int) -> Bool {
        guard timeFrame == .year else { return false }
        
        let currentYear = calendar.component(.year, from: currentDate)
        let monthIndex = (index / 32) + 1
        let dayIndex = (index % 32) + 1
        
        guard let monthStart = calendar.date(from: DateComponents(year: currentYear, month: monthIndex, day: 1)),
              let maxDays = calendar.range(of: .day, in: .month, for: monthStart)?.count else {
            return false
        }
        
        return dayIndex > maxDays
    }
    
    // MARK: - Grid Cell Renderer
    @ViewBuilder
    private func cellView(for index: Int, taskCount: Int) -> some View {
        if index == passedCount {
            RoundedRectangle(cornerRadius: cellCornerRadius, style: .continuous)
                .fill(rainbowGradient)
                .shadow(color: Color.orange.opacity(0.35), radius: 3, x: 0, y: 1)
        } else if index < passedCount {
            let pastBaseColor = Color(white: 0.82)
            
            RoundedRectangle(cornerRadius: cellCornerRadius, style: .continuous)
                .fill(pastBaseColor)
                .overlay(
                    Group {
                        if taskCount > 0 {
                            RoundedRectangle(cornerRadius: cellCornerRadius, style: .continuous)
                                .fill(themeColor.opacity(heatmapOpacity(for: taskCount)))
                        }
                    }
                )
        } else {
            let futureColor = Color(white: 0.18)
            
            RoundedRectangle(cornerRadius: cellCornerRadius, style: .continuous)
                .fill(futureColor)
        }
    }
    
    private func sampleLegendCell(taskCount: Int) -> some View {
        let pastBaseColor = Color(white: 0.82)
        
        return RoundedRectangle(cornerRadius: 1.5)
            .fill(pastBaseColor)
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
#Preview("Light Mode - Year") {
    ScrollView {
        VStack(spacing: 20) {
            LimitGridView(
                timeFrame: .year,
                lifeStats: nil,
                currentDate: Date(),
                taskCountForIndex: { index in index % 7 }
            )
        }
        .padding(.vertical)
    }
    .background(Color(uiColor: .systemGroupedBackground))
    .preferredColorScheme(.light)
}

#Preview("Dark Mode - Day") {
    ScrollView {
        VStack(spacing: 20) {
            LimitGridView(
                timeFrame: .day,
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
