//
//  TaskSectionHeader.swift
//  Gyakusan
//

import SwiftUI

struct TaskSectionHeader: View {
    let title: String
    let count: Int
    @Binding var isExpanded: Bool
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }) {
            HStack {
                Text("\(title) (\(count))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews
#Preview("Interactive") {
    struct TaskSectionHeaderPreviewContainer: View {
        @State private var isExpanded: Bool = false
        
        var body: some View {
            VStack(spacing: 0) {
                TaskSectionHeader(
                    title: "Completed",
                    count: 5,
                    isExpanded: $isExpanded
                )
                
                if isExpanded {
                    Text("Expanded Content Placeholder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }
    
    return TaskSectionHeaderPreviewContainer()
}

#Preview("States Comparison") {
    VStack(spacing: 16) {
        TaskSectionHeader(
            title: "Completed (Collapsed)",
            count: 3,
            isExpanded: .constant(false)
        )
        
        TaskSectionHeader(
            title: "Completed (Expanded)",
            count: 12,
            isExpanded: .constant(true)
        )
    }
    .background(Color(uiColor: .systemGroupedBackground))
}
