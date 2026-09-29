//
//  QuickAddInlineRow.swift
//  Gyakusan
//

import SwiftUI

struct QuickAddInlineRow: View {
    let timeFrame: TimeFrame
    @Binding var title: String
    @Binding var dueDate: Date
    var focusState: FocusState<Bool>.Binding
    let onSubmit: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "circle")
                .font(.title3)
                .foregroundStyle(.tertiary)
            
            VStack(alignment: .leading, spacing: 4) {
                TextField("New Task...", text: $title)
                    .font(.body)
                    .focused(focusState)
                    .submitLabel(.done)
                    .onSubmit {
                        onSubmit()
                    }
                
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                    
                    DatePicker(
                        "",
                        selection: $dueDate,
                        displayedComponents: timeFrame == .day ? [.date, .hourAndMinute] : [.date]
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .scaleEffect(0.85, anchor: .leading)
                }
            }
            
            Spacer()
            
            if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button(action: onSubmit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Previews
#Preview("Empty") {
    struct QuickAddPreviewContainer: View {
        @State private var title: String = ""
        @State private var dueDate: Date = Date()
        @FocusState private var isFocused: Bool
        
        var body: some View {
            QuickAddInlineRow(
                timeFrame: .day,
                title: $title,
                dueDate: $dueDate,
                focusState: $isFocused,
                onSubmit: {}
            )
            .padding()
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }
    
    return QuickAddPreviewContainer()
}

#Preview("With Text") {
    struct QuickAddWithTextPreviewContainer: View {
        @State private var title: String = "Buy new MacBook Pro"
        @State private var dueDate: Date = Date()
        @FocusState private var isFocused: Bool
        
        var body: some View {
            QuickAddInlineRow(
                timeFrame: .month,
                title: $title,
                dueDate: $dueDate,
                focusState: $isFocused,
                onSubmit: {}
            )
            .padding()
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }
    
    return QuickAddWithTextPreviewContainer()
}
