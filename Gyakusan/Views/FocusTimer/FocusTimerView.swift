//
//  FocusTimerView.swift
//  Gyakusan
//
//  Created by Kenichiro Suzuki on 2026/08/27.
//

import SwiftUI
import Combine

struct FocusTimerView: View {
    @Binding var selectedTab: MainTabView.Tab
    
    @AppStorage("highlightColorHex") private var highlightColorHex: String = "#8E8E93"
    
    @State private var timerMode: TimerMode = .focus
    @State private var remainingSeconds: Int = 25 * 60
    @State private var isRunning: Bool = false
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    enum TimerMode {
        case focus
        case breakTime
        
        var title: String {
            switch self {
            case .focus: return "Focus Time"
            case .breakTime: return "Break Time"
            }
        }
        
        var defaultSeconds: Int {
            switch self {
            case .focus: return 25 * 60
            case .breakTime: return 5 * 60
            }
        }
        
        var totalBlocks: Int {
            switch self {
            case .focus: return 25
            case .breakTime: return 5
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
                    VStack(spacing: 24) {
                        timerGridCard
                        
                        Text(formattedTime(remainingSeconds))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                            .padding(.vertical, 8)
                        
                        timerControls
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .onReceive(timer) { _ in
                guard isRunning else { return }
                if remainingSeconds > 0 {
                    remainingSeconds -= 1
                } else {
                    isRunning = false
                }
            }
        }
    }
    
    // MARK: - Timer Grid Card (LimitGridView スタイル)
    private var timerGridCard: some View {
        let total = timerMode.totalBlocks
        let totalSec = timerMode.defaultSeconds
        let elapsedSec = totalSec - remainingSeconds
        // 経過時間をブロック数に換算
        let passedBlocks = min(total, Int(Double(elapsedSec) / Double(totalSec) * Double(total)))
        
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(timerMode.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(passedBlocks) / \(total) min")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<total, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(gridColor(for: index, passedBlocks: passedBlocks))
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
    
    private func gridColor(for index: Int, passedBlocks: Int) -> Color {
        if index < passedBlocks {
            return Color.primary
        } else if index == passedBlocks && isRunning {
            return Color(hex: highlightColorHex)
        } else {
            return Color(uiColor: .systemGray5)
        }
    }
    
    // MARK: - Timer Controls
    private var timerControls: some View {
        HStack(spacing: 20) {
            // Focus ↔ Break
            Button(action: {
                toggleMode()
            }) {
                Image(systemName: timerMode.systemImageName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 56, height: 56)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            // Play ↔ Pause
            Button(action: {
                withAnimation {
                    isRunning.toggle()
                }
            }) {
                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(isRunning ? Color.orange : Color.accentColor)
                    .clipShape(Circle())
                    .shadow(color: (isRunning ? Color.orange : Color.accentColor).opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            
            // Reset
            Button(action: {
                resetTimer(to: timerMode)
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 56, height: 56)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }
    
    private func toggleMode() {
        withAnimation {
            let nextMode = timerMode.toggleNext
            timerMode = nextMode
            resetTimer(to: nextMode)
        }
    }
    
    private func resetTimer(to mode: TimerMode) {
        isRunning = false
        remainingSeconds = mode.defaultSeconds
    }
    
    private func formattedTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

#Preview {
    FocusTimerView(selectedTab: .constant(.focus))
        .environment(\.isPreview, true)
}
