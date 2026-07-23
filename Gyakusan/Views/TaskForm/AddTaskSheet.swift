//
//  AddTaskSheet.swift
//  Gyakusan
//
//  Created by Kenichiro Suzuki on 2026/07/22.
//

import SwiftUI
import SwiftData

struct AddTaskSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State var selectedTimeFrame: TimeFrame
    @State private var title: String = ""
    @FocusState private var isTitleFocused: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Task Name")) {
                    TextField("Enter task title...", text: $title)
                        .focused($isTitleFocused)
                }
                
                Section(header: Text("Time Frame")) {
                    Picker("Time Frame", selection: $selectedTimeFrame) {
                        ForEach(TimeFrame.allCases) { timeFrame in
                            Text(timeFrame.localizedTitle)
                                .tag(timeFrame)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addTask()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                isTitleFocused = true
            }
        }
    }
    
    private func addTask() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        let newTask = LimitTask(
            title: trimmedTitle,
            timeFrameRawValue: selectedTimeFrame.rawValue
        )
        
        modelContext.insert(newTask)
        dismiss()
    }
}

#Preview {
    AddTaskSheet(selectedTimeFrame: .month)
        .modelContainer(for: LimitTask.self, inMemory: true)
}
