//
//  TimeFramePicker.swift
//  Gyakusan
//
//  Created by Kenichiro Suzuki on 2026/07/22.
//

import SwiftUI

struct TimeFramePicker: View {
    @Binding var selectedTimeFrame: TimeFrame
    
    var body: some View {
        Picker("TimeFrame", selection: $selectedTimeFrame) {
            ForEach(TimeFrame.allCases) { timeFrame in
                Text(timeFrame.localizedTitle)
                    .tag(timeFrame)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
}

#Preview {
    TimeFramePicker(selectedTimeFrame: .constant(.year))
}
