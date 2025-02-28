//
//  ContentView.swift
//  ValueTime
//
//  Created by Bogdan on 2/28/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @EnvironmentObject private var timerManager: TimerManager
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar")
                }
                .tag(0)
            
            TimerView()
                .tabItem {
                    Label("Timer", systemImage: "timer")
                }
                .tag(1)
            
            ProjectsView()
                .tabItem {
                    Label("Projects", systemImage: "folder")
                }
                .tag(2)
            
            ActivitiesView()
                .tabItem {
                    Label("Activities", systemImage: "list.bullet")
                }
                .tag(3)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(4)
        }
        .accentColor(ColorTheme.primary)
        .onAppear {
            // Check for active sessions when app starts
            if timerManager.isRunning {
                // If there's an active session, switch to the timer tab
                selectedTab = 1
            }
            
            // Apply custom navigation bar appearance
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.titleTextAttributes = [.foregroundColor: UIColor(ColorTheme.text)]
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(ColorTheme.text)]
            
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var timerManager: TimerManager
    
    @FetchRequest(
        entity: ActivitySession.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \ActivitySession.startTime, ascending: false)],
        predicate: NSPredicate(format: "startTime >= %@ AND endTime != nil", Calendar.current.startOfDay(for: Date()) as NSDate),
        animation: .default)
    private var todaySessions: FetchedResults<ActivitySession>
    
    @FetchRequest(
        entity: ActivitySession.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \ActivitySession.startTime, ascending: false)],
        predicate: NSPredicate(format: "endTime != nil"),
        animation: .default)
    private var recentSessions: FetchedResults<ActivitySession>
    
    @FetchRequest(
        entity: Project.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Project.name, ascending: true)],
        animation: .default)
    private var projects: FetchedResults<Project>
    
    @FetchRequest(
        entity: Activity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Activity.name, ascending: true)],
        animation: .default)
    private var activities: FetchedResults<Activity>
    
    @State private var selectedTab = 0
    @State private var isRefreshing = false
    @State private var refreshID = UUID()
    
    var body: some View {
        NavigationView {
            ScrollView {
                RefreshableView(action: {
                    // Refresh data
                    refreshID = UUID()
                    refreshData()
                }) {
                    VStack(spacing: 16) {
                        HourlyWorthSummaryCard(sessions: Array(recentSessions))
                            .padding(.horizontal)
                        
                        CurrentStatusCard()
                            .padding(.horizontal)
                        
                        TodaySummaryCard(sessions: Array(todaySessions))
                            .padding(.horizontal)
                        
                        ActivityCategoriesCard(activities: activities, sessions: Array(todaySessions))
                            .padding(.horizontal)
                        
                        RecentActivitiesCard(sessions: Array(recentSessions.prefix(5)))
                            .padding(.horizontal)
                        
                        ProjectsOverviewCard(projects: Array(projects))
                            .padding(.horizontal)
                    }
                    .padding(.vertical)
                    .id(refreshID)
                }
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        refreshID = UUID()
                        refreshData()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }
    
    private func refreshData() {
        isRefreshing = true
        
        // Refresh fetch requests
        todaySessions.nsPredicate = NSPredicate(format: "startTime >= %@ AND endTime != nil", Calendar.current.startOfDay(for: Date()) as NSDate)
        recentSessions.nsPredicate = NSPredicate(format: "endTime != nil")
        
        // Simulate a brief delay for visual feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isRefreshing = false
        }
    }
}

// MARK: - Refreshable View
struct RefreshableView<Content: View>: View {
    var action: () async -> Void
    var content: () -> Content
    
    @State private var isRefreshing = false
    @State private var offset: CGFloat = 0
    
    init(action: @escaping () async -> Void, @ViewBuilder content: @escaping () -> Content) {
        self.action = action
        self.content = content
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            content()
                .offset(y: isRefreshing ? 50 : 0)
                .animation(.easeOut(duration: 0.2), value: isRefreshing)
            
            if isRefreshing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                    .padding(.top, 15)
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: ViewOffsetKey.self, value: geo.frame(in: .global).minY)
            }
        )
        .onPreferenceChange(ViewOffsetKey.self) { offset in
            self.offset = offset
            
            if offset > 70 && !isRefreshing {
                isRefreshing = true
                Task {
                    await action()
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay for visual feedback
                    isRefreshing = false
                }
            }
        }
    }
}

struct ViewOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct CurrentStatusCard: View {
    @EnvironmentObject private var timerManager: TimerManager
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Status")
                .font(.headline)
                .foregroundColor(ColorTheme.text.opacity(0.8))
            
            if timerManager.isRunning, let session = timerManager.currentSession, let activity = session.activity {
                HStack(spacing: 15) {
                    Circle()
                        .fill(ColorTheme.color(fromHex: activity.color ?? "#4285F4"))
                        .frame(width: 12, height: 12)
                    
                    VStack(alignment: .leading) {
                        Text(activity.name ?? "Activity")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if let project = activity.project {
                            Text(project.name ?? "Project")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text(timerManager.getFormattedElapsedTime())
                            .font(.title2)
                            .fontWeight(.bold)
                            .monospacedDigit()
                        
                        // Only show earnings if there's an hourly rate
                        let hourlyRate = activity.hourlyRate > 0 ? activity.hourlyRate : (activity.project?.hourlyRate ?? 0.0)
                        if hourlyRate > 0 {
                            Text(timerManager.getFormattedCurrentEarnings())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 10, x: 0, y: 4)
            } else {
                HStack(spacing: 15) {
                    Circle()
                        .fill(ColorTheme.inactive)
                        .frame(width: 12, height: 12)
                    
                    Text("No active tracking")
                        .font(.title3)
                    
                    Spacer()
                    
                    NavigationLink(destination: TimerView()) {
                        Text("Start Tracking")
                            .fontWeight(.semibold)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(ColorTheme.primary)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 10, x: 0, y: 4)
            }
        }
    }
}

struct TodaySummaryCard: View {
    let sessions: [ActivitySession]
    @Environment(\.colorScheme) private var colorScheme
    @FetchRequest(
        entity: Activity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Activity.type, ascending: true)],
        animation: .default)
    private var activities: FetchedResults<Activity>
    
    var totalDuration: TimeInterval {
        sessions.reduce(0) { result, session in
            guard let startTime = session.startTime, let endTime = session.endTime else { return result }
            return result + endTime.timeIntervalSince(startTime)
        }
    }
    
    var totalEarnings: Double {
        sessions.reduce(0) { result, session in
            guard let startTime = session.startTime, let endTime = session.endTime, 
                  let activity = session.activity else { return result }
            
            let duration = endTime.timeIntervalSince(startTime)
            let hourlyRate = activity.hourlyRate > 0 ? activity.hourlyRate : (activity.project?.hourlyRate ?? 0.0)
            return result + TimeCalculator.calculateEarnings(hourlyRate: hourlyRate, timeSpentInSeconds: duration)
        }
    }
    
    var uniqueActivities: Int {
        Set(sessions.compactMap { $0.activity }).count
    }
    
    var idleHours: TimeInterval {
        // Calculate total available time for today (from midnight until now)
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let totalAvailableTime = now.timeIntervalSince(startOfDay)
        
        // Debug logging for idle hours calculation
        print("Today's idle hours calculation:")
        print("  Total available time: \(TimeCalculator.formatTimeInterval(totalAvailableTime))")
        print("  Total tracked time: \(TimeCalculator.formatTimeInterval(totalDuration))")
        print("  Resulting idle time: \(TimeCalculator.formatTimeInterval(max(0, totalAvailableTime - totalDuration)))")
        
        // Idle time is available time minus tracked time
        return max(0, totalAvailableTime - totalDuration)
    }
    
    var activityCategories: [ActivityCategory] {
        // Group activities by type
        let groupedActivities = Dictionary(grouping: sessions) { session in
            session.activity?.type ?? "Other"
        }
        
        return groupedActivities.map { type, sessionsOfType in
            // Calculate total duration for this category
            let totalDuration = sessionsOfType.reduce(0.0) { result, session in
                guard let startTime = session.startTime,
                      let endTime = session.endTime else { return result }
                
                return result + endTime.timeIntervalSince(startTime)
            }
            
            // Calculate total earnings for this category
            let totalEarnings = sessionsOfType.reduce(0.0) { result, session in
                guard let startTime = session.startTime,
                      let endTime = session.endTime,
                      let activity = session.activity else { return result }
                
                let duration = endTime.timeIntervalSince(startTime)
                let hourlyRate = activity.hourlyRate > 0 ? activity.hourlyRate : 
                                (activity.project?.hourlyRate ?? 0.0)
                
                return result + TimeCalculator.calculateEarnings(hourlyRate: hourlyRate, timeSpentInSeconds: duration)
            }
            
            // Get a representative color for this category
            let color = sessionsOfType.first?.activity?.color ?? "#4285F4"
            
            return ActivityCategory(
                type: type,
                totalDuration: totalDuration,
                totalEarnings: totalEarnings,
                effectiveHourlyWorth: 0, // Not needed for this view
                color: color,
                activityCount: sessionsOfType.count
            )
        }
        .sorted { $0.totalDuration > $1.totalDuration }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Summary")
                    .font(.headline)
                    .foregroundColor(ColorTheme.text.opacity(0.8))
                
                Spacer()
                
                Text(TimeCalculator.getCurrentDateFormatted())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if sessions.isEmpty {
                Text("No activity data for today")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 10, x: 0, y: 4)
            } else {
                VStack(spacing: 12) {
                    // Activity categories breakdown
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hours by Category")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        ForEach(activityCategories, id: \.type) { category in
                            HStack {
                                Circle()
                                    .fill(ColorTheme.color(fromHex: category.color))
                                    .frame(width: 10, height: 10)
                                
                                Text(category.type.capitalized)
                                    .font(.subheadline)
                                
                                Spacer()
                                
                                Text(TimeCalculator.formatTimeIntervalShort(category.totalDuration))
                                    .font(.subheadline)
                                    .monospacedDigit()
                                
                                Text(TimeCalculator.formatCurrency(category.totalEarnings))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .frame(width: 70, alignment: .trailing)
                                    .monospacedDigit()
                            }
                            .padding(.vertical, 2)
                        }
                        
                        // Idle time
                        HStack {
                            Circle()
                                .fill(ColorTheme.inactive)
                                .frame(width: 10, height: 10)
                            
                            Text("Idle")
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Text(TimeCalculator.formatTimeIntervalShort(idleHours))
                                .font(.subheadline)
                                .monospacedDigit()
                            
                            Text("$0.00")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(width: 70, alignment: .trailing)
                                .monospacedDigit()
                        }
                        .padding(.vertical, 2)
                        
                        Divider()
                            .padding(.vertical, 4)
                        
                        // Totals
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "list.bullet")
                                        .font(.caption)
                                        .foregroundColor(ColorTheme.secondary)
                                    
                                    Text("\(uniqueActivities) Activities")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "clock.fill")
                                        .font(.caption)
                                        .foregroundColor(ColorTheme.primary)
                                    
                                    Text("\(TimeCalculator.formatTimeIntervalShort(totalDuration)) Tracked")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "moon.zzz.fill")
                                        .font(.caption)
                                        .foregroundColor(ColorTheme.inactive)
                                    
                                    Text("\(TimeCalculator.formatTimeIntervalShort(idleHours)) Idle")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("Total Earned")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(TimeCalculator.formatCurrency(totalEarnings))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(ColorTheme.accent)
                            }
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 10, x: 0, y: 4)
                }
            }
        }
    }
}

struct SummaryItem: View {
    var title: String
    var value: String
    var icon: String
    var color: Color
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 10, x: 0, y: 4)
    }
}

struct RecentActivitiesCard: View {
    let sessions: [ActivitySession]
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activities")
                    .font(.headline)
                    .foregroundColor(ColorTheme.text.opacity(0.8))
                
                Spacer()
                
                NavigationLink(destination: ActivitiesView()) {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundColor(ColorTheme.primary)
                }
            }
            
            if sessions.isEmpty {
                Text("No recent activities")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 10, x: 0, y: 4)
            } else {
                VStack(spacing: 12) {
                    ForEach(sessions) { session in
                        ActivitySessionRow(session: session)
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
                            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 8, x: 0, y: 3)
                    }
                }
            }
        }
    }
}

struct ProjectsOverviewCard: View {
    let projects: [Project]
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Projects Overview")
                    .font(.headline)
                    .foregroundColor(ColorTheme.text.opacity(0.8))
                
                Spacer()
                
                NavigationLink(destination: ProjectsView()) {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundColor(ColorTheme.primary)
                }
            }
            
            if projects.isEmpty {
                Text("No active projects")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 10, x: 0, y: 4)
            } else {
                VStack(spacing: 12) {
                    ForEach(projects) { project in
                        ProjectOverviewRow(project: project)
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
                            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 8, x: 0, y: 3)
                    }
                }
            }
        }
    }
}

struct ActivityCategoriesCard: View {
    let activities: FetchedResults<Activity>
    let sessions: [ActivitySession]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Activity Categories")
                    .font(.headline)
                Spacer()
                NavigationLink(destination: ActivitiesView()) {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundColor(ColorTheme.primary)
                }
            }
            
            if activityCategories.isEmpty {
                Text("No activity data available")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(activityCategories, id: \.type) { category in
                    ActivityCategoryRow(category: category)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    var activityCategories: [ActivityCategory] {
        // Group activities by type
        let groupedActivities = Dictionary(grouping: activities) { $0.type ?? "Other" }
        
        return groupedActivities.map { type, activitiesOfType in
            // Calculate total duration for this category
            let totalDuration = sessions.reduce(0.0) { result, session in
                guard let activity = session.activity,
                      let startTime = session.startTime,
                      let endTime = session.endTime,
                      activity.type == type else { return result }
                
                return result + endTime.timeIntervalSince(startTime)
            }
            
            // Calculate total earnings for this category
            let totalEarnings = sessions.reduce(0.0) { result, session in
                guard let activity = session.activity,
                      let startTime = session.startTime,
                      let endTime = session.endTime,
                      activity.type == type else { return result }
                
                let duration = endTime.timeIntervalSince(startTime)
                let hourlyRate = activity.hourlyRate > 0 ? activity.hourlyRate : 
                                (activity.project?.hourlyRate ?? 0.0)
                
                return result + TimeCalculator.calculateEarnings(hourlyRate: hourlyRate, timeSpentInSeconds: duration)
            }
            
            // Calculate effective hourly worth
            let hoursSpent = totalDuration / 3600
            let effectiveHourlyWorth = hoursSpent > 0 ? totalEarnings / hoursSpent : 0
            
            // Get a representative color for this category
            let color = activitiesOfType.first?.color ?? "#4285F4"
            
            return ActivityCategory(
                type: type,
                totalDuration: totalDuration,
                totalEarnings: totalEarnings,
                effectiveHourlyWorth: effectiveHourlyWorth,
                color: color,
                activityCount: activitiesOfType.count
            )
        }
        .sorted { $0.totalEarnings > $1.totalEarnings }
    }
}

struct ActivityCategory {
    let type: String
    let totalDuration: TimeInterval
    let totalEarnings: Double
    let effectiveHourlyWorth: Double
    let color: String
    let activityCount: Int
}

struct ActivityCategoryRow: View {
    let category: ActivityCategory
    
    var body: some View {
        HStack {
            Circle()
                .fill(ColorTheme.color(fromHex: category.color))
                .frame(width: 12, height: 12)
            
            Text(category.type.capitalized)
                .font(.subheadline)
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(TimeCalculator.formatTimeInterval(category.totalDuration))
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Text("Worth:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(TimeCalculator.formatCurrency(category.effectiveHourlyWorth) + "/hr")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ProjectOverviewRow: View {
    let project: Project
    
    @FetchRequest private var sessions: FetchedResults<ActivitySession>
    
    init(project: Project) {
        self.project = project
        
        let request: NSFetchRequest<ActivitySession> = ActivitySession.fetchRequest()
        request.predicate = NSPredicate(format: "activity.project == %@ AND endTime != nil", project)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ActivitySession.startTime, ascending: false)]
        _sessions = FetchRequest(fetchRequest: request, animation: .default)
    }
    
    var totalDuration: TimeInterval {
        sessions.reduce(0) { result, session in
            guard let startTime = session.startTime, let endTime = session.endTime else { return result }
            return result + endTime.timeIntervalSince(startTime)
        }
    }
    
    var totalEarnings: Double {
        if project.budgetType == "hourly" {
            return TimeCalculator.calculateEarnings(hourlyRate: project.hourlyRate, timeSpentInSeconds: totalDuration)
        } else {
            // For fixed budget projects, just return the percentage of budget based on time spent
            return project.budget * min(1.0, totalDuration / (3600 * 40)) // Assuming 40 hours if estimatedHours is not available
        }
    }
    
    var budgetPercentage: Double {
        if project.budgetType == "fixed" {
            return (totalEarnings / project.budget) * 100
        } else {
            return 0
        }
    }
    
    var body: some View {
        NavigationLink(destination: ProjectDetailView(project: project)) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Circle()
                        .fill(ColorTheme.color(fromHex: project.color ?? "#4285F4"))
                        .frame(width: 14, height: 14)
                    
                    Text(project.name ?? "Project")
                        .font(.headline)
                    
                    Spacer()
                    
                    if project.budgetType == "fixed" {
                        Text(String(format: "%.1f%%", budgetPercentage))
                            .font(.subheadline)
                            .foregroundColor(ColorTheme.colorForBudgetPercentage(budgetPercentage))
                    }
                }
                
                HStack {
                    Text(TimeCalculator.formatTimeIntervalShort(totalDuration))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(TimeCalculator.formatCurrency(totalEarnings))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
        }
    }
}

struct HourlyWorthSummaryCard: View {
    let sessions: [ActivitySession]
    @Environment(\.colorScheme) private var colorScheme
    @State private var useTrackedHoursOnly = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Average Hourly Worth")
                    .font(.subheadline)
                    .foregroundColor(ColorTheme.text.opacity(0.6))
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(useTrackedHoursOnly ? "Tracked Only" : "All Hours")
                        .font(.caption2)
                        .foregroundColor(ColorTheme.text.opacity(0.6))
                    
                    Toggle("", isOn: $useTrackedHoursOnly)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: ColorTheme.primary))
                        .scaleEffect(0.8)
                }
            }
            
            if sessions.isEmpty {
                Text("No activity data available")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                HStack(spacing: 16) {
                    TimeFrameWorthItem(
                        title: "Today",
                        value: calculateAverageHourlyWorth(for: .day, trackedOnly: useTrackedHoursOnly),
                        icon: "clock.fill",
                        color: ColorTheme.primary,
                        startDate: Calendar.current.startOfDay(for: Date()),
                        totalHours: calculateTotalHours(for: .day),
                        totalEarned: calculateTotalEarnings(for: .day),
                        availableHours: calculateAvailableHours(for: .day, trackedOnly: useTrackedHoursOnly)
                    )
                    
                    TimeFrameWorthItem(
                        title: "Week",
                        value: calculateAverageHourlyWorth(for: .week, trackedOnly: useTrackedHoursOnly),
                        icon: "calendar.badge.clock",
                        color: ColorTheme.accent,
                        startDate: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date(),
                        totalHours: calculateTotalHours(for: .week),
                        totalEarned: calculateTotalEarnings(for: .week),
                        availableHours: calculateAvailableHours(for: .week, trackedOnly: useTrackedHoursOnly)
                    )
                    
                    TimeFrameWorthItem(
                        title: "Month",
                        value: calculateAverageHourlyWorth(for: .month, trackedOnly: useTrackedHoursOnly),
                        icon: "chart.bar.fill",
                        color: ColorTheme.secondary,
                        startDate: Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date(),
                        totalHours: calculateTotalHours(for: .month),
                        totalEarned: calculateTotalEarnings(for: .month),
                        availableHours: calculateAvailableHours(for: .month, trackedOnly: useTrackedHoursOnly)
                    )
                    
                    TimeFrameWorthItem(
                        title: "Year",
                        value: calculateAverageHourlyWorth(for: .year, trackedOnly: useTrackedHoursOnly),
                        icon: "chart.line.uptrend.xyaxis",
                        color: ColorTheme.accent,
                        startDate: Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date(),
                        totalHours: calculateTotalHours(for: .year),
                        totalEarned: calculateTotalEarnings(for: .year),
                        availableHours: calculateAvailableHours(for: .year, trackedOnly: useTrackedHoursOnly)
                    )
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground).opacity(0.8))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 5, x: 0, y: 2)
    }
    
    enum TimeFrame {
        case day, week, month, year
    }
    
    func calculateAverageHourlyWorth(for timeFrame: TimeFrame, trackedOnly: Bool = false) -> Double {
        let calendar = Calendar.current
        let now = Date()
        
        // Determine the start date based on the time frame
        let startDate: Date
        switch timeFrame {
        case .day:
            startDate = calendar.startOfDay(for: now) // This already uses midnight
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        }
        
        // Filter sessions within the time frame
        let filteredSessions = sessions.filter { session in
            guard let startTime = session.startTime, let endTime = session.endTime else { return false }
            return startTime >= startDate && endTime <= now
        }
        
        // Calculate total duration and earnings
        var totalDuration: TimeInterval = 0
        var totalEarnings: Double = 0
        
        for session in filteredSessions {
            guard let startTime = session.startTime,
                  let endTime = session.endTime,
                  let activity = session.activity else { continue }
            
            let duration = endTime.timeIntervalSince(startTime)
            totalDuration += duration
            
            // Use activity's hourly rate if available, otherwise use project's rate
            let hourlyRate = activity.hourlyRate > 0 ? activity.hourlyRate : (activity.project?.hourlyRate ?? 0.0)
            let sessionEarnings = TimeCalculator.calculateEarnings(hourlyRate: hourlyRate, timeSpentInSeconds: duration)
            totalEarnings += sessionEarnings
            
            // Debug logging for each session
            print("[\(timeFrame)] Session: \(activity.name ?? "Unknown") - Duration: \(TimeCalculator.formatTimeInterval(duration)), Rate: \(hourlyRate), Earnings: \(sessionEarnings)")
        }
        
        // Calculate total available time in the period (including idle time)
        var totalAvailableTime: TimeInterval
        
        if trackedOnly {
            // If using tracked hours only, just use the total duration
            totalAvailableTime = totalDuration
        } else {
            // Otherwise calculate based on the time frame
            switch timeFrame {
            case .day:
                // For today, use the time elapsed since midnight until now
                let startOfDay = calendar.startOfDay(for: now)
                totalAvailableTime = now.timeIntervalSince(startOfDay)
                print("[\(timeFrame)] Using elapsed time for today: \(TimeCalculator.formatTimeInterval(totalAvailableTime))")
            case .week:
                // For a week, consider 7 full days
                totalAvailableTime = 7 * 24 * 3600
            case .month:
                // For a month, approximate 30 full days
                totalAvailableTime = 30 * 24 * 3600
            case .year:
                // For a year, approximate 365 full days
                totalAvailableTime = 365 * 24 * 3600
            }
            
            // Get the user's tracking start date from UserDefaults
            if let trackingStartDate = UserDefaults.standard.object(forKey: "trackingStartDate") as? Date {
                // Only adjust if we're explicitly asked to consider tracking start date
                // For now, we'll use the full time period regardless of when tracking started
                /*
                // If the tracking start date is after our calculated start date, adjust the available time
                if trackingStartDate > startDate {
                    let adjustedAvailableTime = now.timeIntervalSince(trackingStartDate) // Use full 24 hours
                    let originalAvailableTime = totalAvailableTime
                    totalAvailableTime = min(totalAvailableTime, adjustedAvailableTime)
                    adjustedForTrackingStart = true
                    
                    // Debug logging for tracking start date adjustment
                    print("[\(timeFrame)] Adjusted available time due to tracking start date: \(TimeCalculator.formatDateTime(trackingStartDate))")
                    print("[\(timeFrame)] Original available time: \(TimeCalculator.formatTimeInterval(originalAvailableTime)), Adjusted: \(TimeCalculator.formatTimeInterval(totalAvailableTime))")
                }
                */
            }
        }
        
        // Debug logging for final calculation
        let totalHours = totalDuration / 3600
        let availableHours = totalAvailableTime / 3600
        let calculationMethod = trackedOnly ? "Tracked Hours Only" : "All Available Hours"
        let result = totalAvailableTime > 0 ? totalEarnings / (totalAvailableTime / 3600) : 0
        
        print("[\(timeFrame)] Summary (Method: \(calculationMethod)):")
        print("  Start Date: \(TimeCalculator.formatDateTime(startDate))")
        print("  End Date: \(TimeCalculator.formatDateTime(now))")
        print("  Sessions Count: \(filteredSessions.count)")
        print("  Total Duration: \(TimeCalculator.formatTimeInterval(totalDuration)) (\(String(format: "%.2f", totalHours)) hours)")
        print("  Total Earnings: \(TimeCalculator.formatCurrency(totalEarnings))")
        print("  Available Time: \(TimeCalculator.formatTimeInterval(totalAvailableTime)) (\(String(format: "%.2f", availableHours)) hours)")
        print("  Average Hourly Worth: \(TimeCalculator.formatCurrency(result))")
        
        // Calculate average hourly worth based on total available time
        return result
    }
    
    func calculateTotalHours(for timeFrame: TimeFrame) -> Double {
        let calendar = Calendar.current
        let now = Date()
        
        // Determine the start date based on the time frame
        let startDate: Date
        switch timeFrame {
        case .day:
            startDate = calendar.startOfDay(for: now)
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        }
        
        // Filter sessions within the time frame
        let filteredSessions = sessions.filter { session in
            guard let startTime = session.startTime, let endTime = session.endTime else { return false }
            return startTime >= startDate && endTime <= now
        }
        
        // Calculate total duration
        var totalDuration: TimeInterval = 0
        for session in filteredSessions {
            guard let startTime = session.startTime, let endTime = session.endTime else { continue }
            totalDuration += endTime.timeIntervalSince(startTime)
        }
        
        return totalDuration / 3600
    }
    
    func calculateTotalEarnings(for timeFrame: TimeFrame) -> Double {
        let calendar = Calendar.current
        let now = Date()
        
        // Determine the start date based on the time frame
        let startDate: Date
        switch timeFrame {
        case .day:
            startDate = calendar.startOfDay(for: now)
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        }
        
        // Filter sessions within the time frame
        let filteredSessions = sessions.filter { session in
            guard let startTime = session.startTime, let endTime = session.endTime else { return false }
            return startTime >= startDate && endTime <= now
        }
        
        // Calculate total earnings
        var totalEarnings: Double = 0
        for session in filteredSessions {
            guard let startTime = session.startTime, let endTime = session.endTime, let activity = session.activity else { continue }
            let duration = endTime.timeIntervalSince(startTime)
            let hourlyRate = activity.hourlyRate > 0 ? activity.hourlyRate : (activity.project?.hourlyRate ?? 0.0)
            totalEarnings += TimeCalculator.calculateEarnings(hourlyRate: hourlyRate, timeSpentInSeconds: duration)
        }
        
        return totalEarnings
    }
    
    func calculateAvailableHours(for timeFrame: TimeFrame, trackedOnly: Bool = false) -> Double {
        if trackedOnly {
            return calculateTotalHours(for: timeFrame)
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        // Determine the start date based on the time frame
        let startDate: Date
        switch timeFrame {
        case .day:
            startDate = calendar.startOfDay(for: now)
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        }
        
        // Calculate total available time in the period (including idle time)
        var totalAvailableTime: TimeInterval
        switch timeFrame {
        case .day:
            // For today, use the time elapsed since midnight until now
            let startOfDay = calendar.startOfDay(for: now)
            totalAvailableTime = now.timeIntervalSince(startOfDay)
        case .week:
            // For a week, consider 7 full days
            totalAvailableTime = 7 * 24 * 3600
        case .month:
            // For a month, approximate 30 full days
            totalAvailableTime = 30 * 24 * 3600
        case .year:
            // For a year, approximate 365 full days
            totalAvailableTime = 365 * 24 * 3600
        }
        
        // Get the user's tracking start date from UserDefaults
        if let trackingStartDate = UserDefaults.standard.object(forKey: "trackingStartDate") as? Date {
            // Only adjust if we're explicitly asked to consider tracking start date
            // For now, we'll use the full time period regardless of when tracking started
            /*
            // If the tracking start date is after our calculated start date, adjust the available time
            if trackingStartDate > startDate {
                let adjustedAvailableTime = now.timeIntervalSince(trackingStartDate) // Use full 24 hours
                totalAvailableTime = min(totalAvailableTime, adjustedAvailableTime)
            }
            */
        }
        
        return totalAvailableTime / 3600
    }
}

struct TimeFrameWorthItem: View {
    var title: String
    var value: Double
    var icon: String
    var color: Color
    var startDate: Date
    var totalHours: Double
    var totalEarned: Double
    var availableHours: Double
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(TimeCalculator.formatCurrency(value))
                .font(.subheadline)
                .fontWeight(.semibold)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                // .overlay(
                //     Image(systemName: "info.circle")
                //         .font(.system(size: 10))
                //         .foregroundColor(color.opacity(0.7))
                //         .offset(x: 5, y: -5),
                //     alignment: .topTrailing
                // )
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .popover(isPresented: .constant(false)) { } // This is a workaround to make .popover modifier work with .onTapGesture
        .onTapGesture {
            // Create and show a tooltip alert
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            
            let calculationMethod = totalHours == availableHours ? "Tracked Hours Only" : "All Available Hours"
            
            let message = """
            Start date: \(dateFormatter.string(from: startDate))
            Total tracked hours: \(String(format: "%.2f", totalHours))
            Total earned: \(TimeCalculator.formatCurrency(totalEarned))
            Available hours: \(String(format: "%.2f", availableHours)) (\(calculationMethod))
            
            Calculation: \(TimeCalculator.formatCurrency(totalEarned)) ÷ \(String(format: "%.2f", availableHours)) = \(TimeCalculator.formatCurrency(value))/hr
            
            Note: "Tracked Hours" uses only the time you've actively tracked.
            "All Hours" includes all available time in the period.
            """
            
            #if os(iOS)
            let alert = UIAlertController(title: "\(title) Hourly Worth Details", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(alert, animated: true)
            }
            #endif
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(TimerManager.shared)
        .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
}
