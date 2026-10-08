//
//  LifeEventFormSheet.swift
//  Gyakusan
//

import SwiftUI
import SwiftData

struct LifeEventFormSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var eventToEdit: LifeEvent?
    
    @State private var title: String = ""
    @State private var date: Date = Date()
    @State private var iconName: String = "star.fill"
    @State private var note: String = ""
    
    private let availableIcons = [
        // life, family
        "heart.fill",                     // marridge
        "figure.2.and.child.holdinghands",// family
        "house.fill",                     // movement
        "pawprint.fill",                  // pet
        
        // work, education
        "briefcase.fill",                 // work
        "graduationcap.fill",             // educaiton
        "building.2.fill",                // entrep
        "laptopcomputer",                 // project
        
        // lifestyle
        "airplane",                       // trip
        "banknote.fill",                  // money
        "figure.run",                     // sports
        
        // achievement
        "trophy.fill",                    // trophy
        "flag.fill",                      // target
        "sparkles"                        // day
    ]
    
    private var isEditing: Bool { eventToEdit != nil }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Event Details")) {
                    TextField("Event Title (e.g. Joined Company, Married)", text: $title)
                    
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                
                Section(header: Text("Icon")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 12) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.title3)
                                .frame(width: 40, height: 40)
                                .background(iconName == icon ? Color.accentColor.opacity(0.2) : Color.clear)
                                .foregroundStyle(iconName == icon ? Color.accentColor : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(iconName == icon ? Color.accentColor : Color.clear, lineWidth: 1.5)
                                )
                                .onTapGesture {
                                    iconName = icon
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("Note")) {
                    TextField("Note (Optional)", text: $note, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle(isEditing ? "Edit Life Event" : "New Life Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEvent()
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let event = eventToEdit {
                    title = event.title
                    date = event.date
                    iconName = event.iconName
                    note = event.note
                }
            }
        }
    }
    
    private func saveEvent() {
        if let event = eventToEdit {
            event.title = title
            event.date = date
            event.iconName = iconName
            event.note = note
        } else {
            let newEvent = LifeEvent(title: title, date: date, iconName: iconName, note: note)
            modelContext.insert(newEvent)
        }
        try? modelContext.save()
    }
}

#Preview {
    LifeEventFormSheet()
}
