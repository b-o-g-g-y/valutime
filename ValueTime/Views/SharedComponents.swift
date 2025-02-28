import SwiftUI

// MARK: - Shared UI Components

/// A reusable empty state view that works on all iOS versions
/// Used to display a message when there's no content to show
struct EmptyStateView: View {
    var title: String
    var message: String
    var buttonTitle: String
    var systemImage: String
    var action: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: systemImage)
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: action) {
                Text(buttonTitle)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(ColorTheme.primary)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.top, 10)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

/// A reusable row component for displaying activity sessions
/// Used in both activity details and project details
struct ActivitySessionRow: View {
    let session: ActivitySession
    var showActivityName: Bool = true
    
    var body: some View {
        HStack {
            if showActivityName, let activity = session.activity {
                Circle()
                    .fill(ColorTheme.color(fromHex: activity.color ?? "#4285F4"))
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading) {
                    HStack {
                        Text(activity.name ?? "Activity")
                            .fontWeight(.medium)
                        
                        if let notes = session.notes, !notes.isEmpty {
                            Image(systemName: "note.text")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let startTime = session.startTime, let endTime = session.endTime {
                        Text("\(TimeCalculator.formatDate(startTime)) • \(TimeCalculator.formatTime(startTime)) - \(TimeCalculator.formatTime(endTime))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                VStack(alignment: .leading) {
                    if let startTime = session.startTime, let endTime = session.endTime {
                        HStack {
                            Text("\(TimeCalculator.formatDate(startTime))")
                                .fontWeight(.medium)
                            
                            if let notes = session.notes, !notes.isEmpty {
                                Image(systemName: "note.text")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Text("\(TimeCalculator.formatTime(startTime)) - \(TimeCalculator.formatTime(endTime))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if let startTime = session.startTime, let endTime = session.endTime {
                let duration = TimeCalculator.calculateDuration(from: startTime, to: endTime)
                
                if showActivityName, let activity = session.activity, let project = activity.project {
                    VStack(alignment: .trailing) {
                        Text(TimeCalculator.formatTimeIntervalShort(duration))
                            .fontWeight(.semibold)
                            .monospacedDigit()
                        
                        let earnings = TimeCalculator.calculateEarnings(hourlyRate: project.hourlyRate, timeSpentInSeconds: duration)
                        Text(TimeCalculator.formatCurrency(earnings))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text(TimeCalculator.formatTimeIntervalShort(duration))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
            }
        }
        .padding(.vertical, 4)
    }
} 