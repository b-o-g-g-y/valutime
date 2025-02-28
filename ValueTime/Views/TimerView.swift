import SwiftUI
import CoreData

struct TimerView: View {
    @EnvironmentObject private var timerManager: TimerManager
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var selectedActivity: Activity?
    @State private var showingActivityPicker = false
    @State private var showingNoteInput = false
    @State private var sessionNote = ""
    
    // In-app notification states
    @State private var showingInactivityAlert = false
    @State private var showingLongSessionAlert = false
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Activity.name, ascending: true)],
        animation: .default)
    private var activities: FetchedResults<Activity>
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                ColorTheme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom header
                    HStack {
                        Text("Timer")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(ColorTheme.text)
                        
                        Spacer()
                        
                        Circle()
                            .fill(timerManager.isRunning ? ColorTheme.active : ColorTheme.inactive)
                            .frame(width: 12, height: 12)
                    }
                    .padding(.horizontal)
                    .padding(.top, 15)
                    .padding(.bottom, 10)
                    
                    VStack(spacing: 30) {
                        // Timer Display
                        TimerDisplayView()
                        
                        // Current Activity
                        CurrentActivityView(
                            selectedActivity: $selectedActivity,
                            showingActivityPicker: $showingActivityPicker
                        )
                        
                        // Timer Controls
                        TimerControlsView(
                            selectedActivity: $selectedActivity,
                            showingNoteInput: $showingNoteInput,
                            sessionNote: $sessionNote
                        )
                        
                        Spacer()
                        
                        // Recent Sessions
                        RecentSessionsView()
                    }
                    .padding(.horizontal)
                }
                
                // In-app notification banners
                if showingInactivityAlert {
                    InAppNotificationBanner(
                        title: "No Activity Tracking",
                        message: "You haven't been tracking any activity. Start tracking to log your time!",
                        systemImage: "timer",
                        backgroundColor: ColorTheme.secondary,
                        onDismiss: { showingInactivityAlert = false },
                        action: { showingActivityPicker = true }
                    )
                    .transition(.move(edge: .top))
                    .zIndex(100)
                }
                
                if showingLongSessionAlert {
                    InAppNotificationBanner(
                        title: "Long Session Check",
                        message: "You've been tracking \(timerManager.currentSession?.activity?.name ?? "an activity") for a while. Are you still working on it?",
                        systemImage: "clock",
                        backgroundColor: ColorTheme.primary,
                        onDismiss: { showingLongSessionAlert = false },
                        action: nil
                    )
                    .transition(.move(edge: .top))
                    .zIndex(100)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingActivityPicker) {
                ActivityPickerView(selectedActivity: $selectedActivity)
            }
            .sheet(isPresented: $showingNoteInput) {
                NoteInputView(note: $sessionNote, onSave: {
                    timerManager.stopTracking(notes: sessionNote)
                    sessionNote = ""
                })
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("InactivityReminderTriggered"))) { _ in
                withAnimation {
                    showingInactivityAlert = true
                    
                    // Auto-dismiss after 5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        withAnimation {
                            showingInactivityAlert = false
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("LongSessionReminderTriggered"))) { _ in
                withAnimation {
                    showingLongSessionAlert = true
                    
                    // Auto-dismiss after 5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        withAnimation {
                            showingLongSessionAlert = false
                        }
                    }
                }
            }
        }
    }
}

// MARK: - In-App Notification Banner
struct InAppNotificationBanner: View {
    let title: String
    let message: String
    let systemImage: String
    let backgroundColor: Color
    let onDismiss: () -> Void
    let action: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .padding(.trailing, 5)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(2)
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding()
            
            if action != nil {
                Divider()
                    .background(Color.white.opacity(0.3))
                
                Button(action: {
                    onDismiss()
                    action?()
                }) {
                    HStack {
                        Spacer()
                        Text("Take Action")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
        )
        .padding(.horizontal)
        .padding(.top, 10)
    }
}

// MARK: - Timer Display View
struct TimerDisplayView: View {
    @EnvironmentObject private var timerManager: TimerManager
    
    var body: some View {
        VStack(spacing: 10) {
            Text(timerManager.getFormattedElapsedTime())
                .font(.system(size: 60, weight: .bold, design: .monospaced))
                .foregroundColor(timerManager.isRunning ? 
                                (timerManager.isPaused ? ColorTheme.accent : ColorTheme.primary) : 
                                ColorTheme.text)
                .padding(.vertical, 20)
            
            if timerManager.isRunning {
                if timerManager.isPaused {
                    Text("PAUSED")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(ColorTheme.accent)
                } else if let session = timerManager.currentSession, 
                          let activity = session.activity,
                          (activity.hourlyRate > 0 || (activity.project?.hourlyRate ?? 0) > 0) {
                    Text(timerManager.getFormattedCurrentEarnings())
                        .font(.title2)
                        .foregroundColor(ColorTheme.accent)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
}

// MARK: - Current Activity View
struct CurrentActivityView: View {
    @EnvironmentObject private var timerManager: TimerManager
    @Binding var selectedActivity: Activity?
    @Binding var showingActivityPicker: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Current Activity")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Button(action: {
                if !timerManager.isRunning {
                    showingActivityPicker = true
                }
            }) {
                HStack {
                    if let activity = selectedActivity ?? timerManager.currentSession?.activity {
                        Circle()
                            .fill(ColorTheme.color(fromHex: activity.color ?? "#4285F4"))
                            .frame(width: 20, height: 20)
                        
                        VStack(alignment: .leading) {
                            Text(activity.name ?? "Select Activity")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            if let project = activity.project {
                                Text(project.name ?? "No Project")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 20, height: 20)
                        
                        Text("Select Activity")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if !timerManager.isRunning {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                )
            }
            .disabled(timerManager.isRunning)
        }
    }
}

// MARK: - Timer Controls View
struct TimerControlsView: View {
    @EnvironmentObject private var timerManager: TimerManager
    @Binding var selectedActivity: Activity?
    @Binding var showingNoteInput: Bool
    @Binding var sessionNote: String
    
    var body: some View {
        HStack(spacing: 15) {
            if timerManager.isRunning && !timerManager.isPaused {
                // Pause Button
                Button(action: {
                    timerManager.pauseTracking()
                }) {
                    HStack {
                        Image(systemName: "pause.fill")
                        Text("Pause")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ColorTheme.accent)
                    .cornerRadius(12)
                }
                
                // Stop Button
                Button(action: {
                    showingNoteInput = true
                }) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("Stop")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ColorTheme.secondary)
                    .cornerRadius(12)
                }
            } else if timerManager.isPaused {
                // Resume Button
                Button(action: {
                    timerManager.resumeTracking()
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Resume")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ColorTheme.primary)
                    .cornerRadius(12)
                }
                
                // Stop Button
                Button(action: {
                    showingNoteInput = true
                }) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("Stop")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ColorTheme.secondary)
                    .cornerRadius(12)
                }
            } else {
                // Start Button
                Button(action: {
                    if let activity = selectedActivity {
                        timerManager.startTracking(activity: activity)
                    }
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedActivity == nil ? Color.gray : ColorTheme.primary)
                    .cornerRadius(12)
                }
                .disabled(selectedActivity == nil)
            }
        }
    }
}

// MARK: - Recent Sessions View
struct RecentSessionsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var timerManager: TimerManager
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ActivitySession.startTime, ascending: false)],
        predicate: NSPredicate(format: "endTime != nil"),
        animation: .default)
    private var completedSessions: FetchedResults<ActivitySession>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ActivitySession.pauseTime, ascending: false)],
        predicate: NSPredicate(format: "endTime == nil AND isPaused == YES"),
        animation: .default)
    private var pausedSessions: FetchedResults<ActivitySession>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Sessions")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if pausedSessions.isEmpty && completedSessions.isEmpty {
                Text("No recent sessions")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Paused Sessions Section
                        if !pausedSessions.isEmpty {
                            Text("Paused")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                                .padding(.bottom, 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            ForEach(pausedSessions) { session in
                                PausedSessionRow(session: session)
                            }
                        }
                        
                        // Completed Sessions Section
                        if !completedSessions.isEmpty {
                            Text("Completed")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                                .padding(.bottom, 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            ForEach(completedSessions.prefix(5)) { session in
                                SessionRow(session: session)
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
    }
}

// MARK: - Paused Session Row
struct PausedSessionRow: View {
    @EnvironmentObject private var timerManager: TimerManager
    let session: ActivitySession
    
    var body: some View {
        HStack {
            if let activity = session.activity {
                Circle()
                    .fill(ColorTheme.color(fromHex: activity.color ?? "#4285F4"))
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading) {
                    Text(activity.name ?? "Activity")
                        .fontWeight(.medium)
                    
                    if let startTime = session.startTime, let pauseTime = session.pauseTime {
                        Text("\(TimeCalculator.formatTime(startTime)) - \(TimeCalculator.formatTime(pauseTime)) (Paused)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Resume Button
            Button(action: {
                // Use the new resumePausedSession method
                timerManager.resumePausedSession(session)
            }) {
                HStack {
                    Image(systemName: "play.fill")
                        .foregroundColor(.white)
                    Text("Resume")
                        .foregroundColor(.white)
                        .font(.caption)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(ColorTheme.primary)
                .cornerRadius(8)
            }
            .disabled(timerManager.isRunning && !timerManager.isPaused)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                )
        )
    }
}

// MARK: - Session Row
struct SessionRow: View {
    let session: ActivitySession
    
    var body: some View {
        HStack {
            if let activity = session.activity {
                Circle()
                    .fill(ColorTheme.color(fromHex: activity.color ?? "#4285F4"))
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading) {
                    Text(activity.name ?? "Activity")
                        .fontWeight(.medium)
                    
                    if let startTime = session.startTime, let endTime = session.endTime {
                        Text("\(TimeCalculator.formatTime(startTime)) - \(TimeCalculator.formatTime(endTime))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if let startTime = session.startTime, let endTime = session.endTime {
                let duration = TimeCalculator.calculateDuration(from: startTime, to: endTime)
                
                VStack(alignment: .trailing) {
                    Text(TimeCalculator.formatTimeIntervalShort(duration))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                    
                    if let activity = session.activity, let project = activity.project {
                        let earnings = TimeCalculator.calculateEarnings(hourlyRate: project.hourlyRate, timeSpentInSeconds: duration)
                        Text(TimeCalculator.formatCurrency(earnings))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
        )
    }
}

// MARK: - Activity Picker View
struct ActivityPickerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    @Binding var selectedActivity: Activity?
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Activity.name, ascending: true)],
        animation: .default)
    private var activities: FetchedResults<Activity>
    
    @State private var searchText = ""
    
    var filteredActivities: [Activity] {
        if searchText.isEmpty {
            return Array(activities)
        } else {
            return activities.filter { ($0.name ?? "").localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(filteredActivities) { activity in
                    Button(action: {
                        selectedActivity = activity
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Circle()
                                .fill(ColorTheme.color(fromHex: activity.color ?? "#4285F4"))
                                .frame(width: 16, height: 16)
                            
                            VStack(alignment: .leading) {
                                Text(activity.name ?? "Activity")
                                    .fontWeight(.medium)
                                
                                if let project = activity.project {
                                    Text(project.name ?? "No Project")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if activity == selectedActivity {
                                Image(systemName: "checkmark")
                                    .foregroundColor(ColorTheme.primary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .searchable(text: $searchText, prompt: "Search activities")
            .navigationTitle("Select Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Note Input View
struct NoteInputView: View {
    @Environment(\.presentationMode) private var presentationMode
    @Binding var note: String
    var onSave: () -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("Add notes about this session (optional)", text: $note)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Session Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    TimerView()
        .environmentObject(TimerManager.shared)
        .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
} 