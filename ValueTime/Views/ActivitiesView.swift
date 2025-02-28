import SwiftUI
import CoreData
// EmptyStateView and ActivitySessionRow are now imported from SharedComponents

struct ActivitiesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Activity.name, ascending: true)],
        animation: .default)
    private var activities: FetchedResults<Activity>
    
    @State private var showingAddActivity = false
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
            ZStack(alignment: .top) {
                ColorTheme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom header
                    HStack {
                        Text("Activities")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(ColorTheme.text)
                        
                        Spacer()
                        
                        Button(action: {
                            showingAddActivity = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(ColorTheme.primary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 15)
                    .padding(.bottom, 10)
                    
                    ZStack {
                        if activities.isEmpty {
                            EmptyStateView(
                                title: "No Activities",
                                message: "Add activities to start tracking your time.",
                                buttonTitle: "Add Activity",
                                systemImage: "list.bullet",
                                action: { showingAddActivity = true }
                            )
                        } else {
                            VStack(spacing: 0) {
                                // Search bar
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.secondary)
                                    
                                    TextField("Search activities", text: $searchText)
                                        .foregroundColor(.primary)
                                }
                                .padding(10)
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .padding(.horizontal)
                                .padding(.bottom, 10)
                                
                                // Activities list
                                ScrollView {
                                    LazyVStack(spacing: 12) {
                                        ForEach(filteredActivities) { activity in
                                            NavigationLink(destination: ActivityDetailView(activity: activity)) {
                                                ActivityRow(activity: activity)
                                                    .padding(.horizontal)
                                                    .padding(.vertical, 12)
                                                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
                                                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 8, x: 0, y: 3)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                        .padding(.horizontal)
                                    }
                                    .padding(.bottom, 20)
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddActivity) {
                AddActivityView()
            }
        }
    }
    
    private func deleteActivities(offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredActivities[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Error deleting activity: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct ActivityRow: View {
    let activity: Activity
    
    var body: some View {
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
            
            if let sessions = activity.sessions as? Set<ActivitySession>, !sessions.isEmpty {
                Text("\(sessions.count) sessions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ActivityDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    
    let activity: Activity
    
    @State private var name: String
    @State private var type: String
    @State private var color: String
    @State private var icon: String
    @State private var project: Project?
    @State private var hourlyRate: Double
    @State private var useProjectRate: Bool
    @State private var showingAddSession = false
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Project.name, ascending: true)],
        animation: .default)
    private var projects: FetchedResults<Project>
    
    @FetchRequest private var sessions: FetchedResults<ActivitySession>
    
    init(activity: Activity) {
        self.activity = activity
        _name = State(initialValue: activity.name ?? "")
        _type = State(initialValue: activity.type ?? "")
        _color = State(initialValue: activity.color ?? "#4285F4")
        _icon = State(initialValue: activity.icon ?? "")
        _project = State(initialValue: activity.project)
        _hourlyRate = State(initialValue: activity.hourlyRate)
        
        // Determine if using project rate
        let usingProjectRate = activity.project != nil && activity.hourlyRate == 0.0
        _useProjectRate = State(initialValue: usingProjectRate)
        
        // Create a fetch request for sessions related to this activity
        let request: NSFetchRequest<ActivitySession> = ActivitySession.fetchRequest()
        request.predicate = NSPredicate(format: "activity == %@", activity)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ActivitySession.startTime, ascending: false)]
        _sessions = FetchRequest(fetchRequest: request, animation: .default)
    }
    
    var body: some View {
        Form {
            Section(header: Text("Activity Details")) {
                TextField("Name", text: $name)
                
                Picker("Type", selection: $type) {
                    Text("Work").tag("work")
                    Text("Leisure").tag("leisure")
                    Text("Sleep").tag("sleep")
                    Text("Exercise").tag("exercise")
                    Text("Study").tag("study")
                    Text("Personal").tag("personal")
                }
                
                ColorPicker("Color", selection: Binding(
                    get: { ColorTheme.color(fromHex: color) },
                    set: { color = ColorTheme.hexString(from: $0) }
                ))
                
                Picker("Project", selection: $project) {
                    Text("None").tag(nil as Project?)
                    ForEach(projects) { project in
                        Text(project.name ?? "").tag(project as Project?)
                    }
                }
            }
            
            Section(header: Text("Hourly Rate")) {
                if project != nil {
                    Toggle("Use Project Rate", isOn: $useProjectRate)
                }
                
                if project == nil || !useProjectRate {
                    HStack {
                        Text("$")
                        TextField("0.00", value: $hourlyRate, formatter: NumberFormatter.currencyFormatter)
                            .keyboardType(.decimalPad)
                    }
                }
                
                if project != nil && useProjectRate {
                    HStack {
                        Text("Project Rate")
                        Spacer()
                        Text(TimeCalculator.formatCurrency(project!.hourlyRate))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Show effective hourly worth based on sessions
                if !sessions.isEmpty {
                    let effectiveRate = calculateEffectiveHourlyWorth()
                    HStack {
                        Text("Effective Hourly Worth")
                        Spacer()
                        Text(TimeCalculator.formatCurrency(effectiveRate))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section(header: Text("Sessions")) {
                Button(action: {
                    showingAddSession = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(ColorTheme.primary)
                        Text("Add Session")
                            .foregroundColor(ColorTheme.primary)
                    }
                }
                
                if sessions.isEmpty {
                    Text("No sessions recorded")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(sessions) { session in
                        NavigationLink(destination: SessionDetailView(session: session)) {
                            ActivitySessionRow(session: session, showActivityName: false)
                        }
                    }
                    .onDelete(perform: deleteSessions)
                }
            }
            
            Section {
                Button(action: saveActivity) {
                    Text("Save Changes")
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                }
                .listRowBackground(ColorTheme.primary)
                
                Button(role: .destructive, action: deleteActivity) {
                    Text("Delete Activity")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle(activity.name ?? "Activity Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddSession) {
            AddSessionView(activity: activity)
        }
    }
    
    private func calculateEffectiveHourlyWorth() -> Double {
        // Calculate total duration of all sessions
        let totalDuration = sessions.reduce(0.0) { result, session in
            guard let startTime = session.startTime, let endTime = session.endTime else { return result }
            return result + endTime.timeIntervalSince(startTime)
        }
        
        // Get the hourly rate to use
        let rateToUse = useProjectRate && project != nil ? project!.hourlyRate : hourlyRate
        
        // Calculate total earnings
        let totalEarnings = TimeCalculator.calculateEarnings(hourlyRate: rateToUse, timeSpentInSeconds: totalDuration)
        
        // Calculate effective hourly worth
        let hoursSpent = totalDuration / 3600
        return hoursSpent > 0 ? totalEarnings / hoursSpent : 0
    }
    
    private func saveActivity() {
        withAnimation {
            // Determine the hourly rate to use
            let rateToUse = (project != nil && useProjectRate) ? 0.0 : hourlyRate
            
            // Update activity properties
            activity.name = name
            activity.type = type
            activity.color = color
            activity.icon = icon
            activity.project = project
            activity.hourlyRate = rateToUse
            
            // Save changes
            do {
                try viewContext.save()
                presentationMode.wrappedValue.dismiss()
            } catch {
                let nsError = error as NSError
                print("Error saving activity: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private func deleteActivity() {
        withAnimation {
            viewContext.delete(activity)
            
            do {
                try viewContext.save()
                presentationMode.wrappedValue.dismiss()
            } catch {
                let nsError = error as NSError
                print("Error deleting activity: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private func deleteSessions(at offsets: IndexSet) {
        withAnimation {
            offsets.map { sessions[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Error deleting session: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct AddActivityView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    
    @State private var name = ""
    @State private var type = "work"
    @State private var color = ColorTheme.randomActivityColor()
    @State private var icon = "circle.fill"
    @State private var project: Project?
    @State private var hourlyRate = 0.0
    @State private var useProjectRate = true
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Project.name, ascending: true)],
        animation: .default)
    private var projects: FetchedResults<Project>
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Activity Details")) {
                    TextField("Name", text: $name)
                    
                    Picker("Type", selection: $type) {
                        Text("Work").tag("work")
                        Text("Leisure").tag("leisure")
                        Text("Sleep").tag("sleep")
                        Text("Exercise").tag("exercise")
                        Text("Study").tag("study")
                        Text("Personal").tag("personal")
                    }
                    
                    ColorPicker("Color", selection: Binding(
                        get: { ColorTheme.color(fromHex: color) },
                        set: { color = ColorTheme.hexString(from: $0) }
                    ))
                    
                    Picker("Project", selection: $project) {
                        Text("None").tag(nil as Project?)
                        ForEach(projects) { project in
                            Text(project.name ?? "").tag(project as Project?)
                        }
                    }
                }
                
                Section(header: Text("Hourly Rate")) {
                    if project != nil {
                        Toggle("Use Project Rate", isOn: $useProjectRate)
                    }
                    
                    if project == nil || !useProjectRate {
                        HStack {
                            Text("$")
                            TextField("0.00", value: $hourlyRate, formatter: NumberFormatter.currencyFormatter)
                                .keyboardType(.decimalPad)
                        }
                    }
                    
                    if project != nil && useProjectRate {
                        HStack {
                            Text("Project Rate")
                            Spacer()
                            Text(TimeCalculator.formatCurrency(project!.hourlyRate))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section {
                    Button(action: addActivity) {
                        Text("Add Activity")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                    .disabled(name.isEmpty)
                    .listRowBackground(name.isEmpty ? Color.gray : ColorTheme.primary)
                }
            }
            .navigationTitle("New Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func addActivity() {
        withAnimation {
            // Determine the hourly rate to use
            let rateToUse = (project != nil && useProjectRate) ? 0.0 : hourlyRate
            
            let newActivity = CoreDataManager.shared.createActivity(
                name: name,
                type: type,
                color: color,
                icon: icon,
                project: project,
                hourlyRate: rateToUse
            )
            
            presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Add Session View
public struct AddSessionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    
    let activity: Activity
    
    @State private var startDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var endDate = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var notes = ""
    
    var isValidSession: Bool {
        return endDate > startDate
    }
    
    var sessionDuration: TimeInterval {
        return endDate.timeIntervalSince(startDate)
    }
    
    var formattedDuration: String {
        return TimeCalculator.formatTimeIntervalShort(sessionDuration)
    }
    
    var earnings: Double {
        if let project = activity.project {
            return TimeCalculator.calculateEarnings(hourlyRate: project.hourlyRate, timeSpentInSeconds: sessionDuration)
        } else {
            // Use default hourly rate if no project is associated
            let defaultRate = CoreDataManager.shared.getUser()?.defaultHourlyRate ?? 25.0
            return TimeCalculator.calculateEarnings(hourlyRate: defaultRate, timeSpentInSeconds: sessionDuration)
        }
    }
    
    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Session Details")) {
                    HStack {
                        Circle()
                            .fill(ColorTheme.color(fromHex: activity.color ?? "#4285F4"))
                            .frame(width: 16, height: 16)
                        
                        Text(activity.name ?? "Activity")
                            .fontWeight(.medium)
                        
                        if let project = activity.project {
                            Spacer()
                            Text(project.name ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    DatePicker("Start Time", selection: $startDate)
                        .onChange(of: startDate) { newValue in
                            if endDate <= newValue {
                                // Ensure end time is after start time by adding 1 hour
                                endDate = Calendar.current.date(byAdding: .hour, value: 1, to: newValue) ?? newValue
                            }
                        }
                    
                    DatePicker("End Time", selection: $endDate)
                        .onChange(of: endDate) { newValue in
                            if newValue <= startDate {
                                // Ensure start time is before end time
                                startDate = Calendar.current.date(byAdding: .hour, value: -1, to: newValue) ?? newValue
                            }
                        }
                    
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(formattedDuration)
                            .fontWeight(.semibold)
                    }
                    
                    if let project = activity.project {
                        HStack {
                            Text("Earnings")
                            Spacer()
                            Text(TimeCalculator.formatCurrency(earnings))
                                .fontWeight(.semibold)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Notes")
                            .font(.headline)
                            .padding(.bottom, 5)
                        
                        TextEditor(text: $notes)
                            .frame(minHeight: 100)
                            .padding(4)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                
                Section {
                    Button(action: addSession) {
                        Text("Add Session")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                    .disabled(!isValidSession)
                    .listRowBackground(isValidSession ? ColorTheme.primary : Color.gray)
                }
            }
            .navigationTitle("Add Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func addSession() {
        withAnimation {
            // Create a new session
            let session = ActivitySession(context: viewContext)
            session.id = UUID()
            session.activity = activity
            session.startTime = startDate
            session.endTime = endDate
            session.notes = notes.isEmpty ? nil : notes
            
            do {
                try viewContext.save()
                presentationMode.wrappedValue.dismiss()
            } catch {
                let nsError = error as NSError
                print("Error saving session: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

// MARK: - Session Detail View
public struct SessionDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    
    let session: ActivitySession
    
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var notes: String
    
    var isValidSession: Bool {
        return endDate > startDate
    }
    
    var sessionDuration: TimeInterval {
        return endDate.timeIntervalSince(startDate)
    }
    
    var formattedDuration: String {
        return TimeCalculator.formatTimeIntervalShort(sessionDuration)
    }
    
    var earnings: Double {
        if let activity = session.activity, let project = activity.project {
            return TimeCalculator.calculateEarnings(hourlyRate: project.hourlyRate, timeSpentInSeconds: sessionDuration)
        } else {
            // Use default hourly rate if no project is associated
            let defaultRate = CoreDataManager.shared.getUser()?.defaultHourlyRate ?? 25.0
            return TimeCalculator.calculateEarnings(hourlyRate: defaultRate, timeSpentInSeconds: sessionDuration)
        }
    }
    
    init(session: ActivitySession) {
        self.session = session
        _startDate = State(initialValue: session.startTime ?? Date())
        _endDate = State(initialValue: session.endTime ?? Date())
        _notes = State(initialValue: session.notes ?? "")
    }
    
    public var body: some View {
        Form {
            Section(header: Text("Session Details")) {
                if let activity = session.activity {
                    HStack {
                        Circle()
                            .fill(ColorTheme.color(fromHex: activity.color ?? "#4285F4"))
                            .frame(width: 16, height: 16)
                        
                        Text(activity.name ?? "Activity")
                            .fontWeight(.medium)
                        
                        if let project = activity.project {
                            Spacer()
                            Text(project.name ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                DatePicker("Start Time", selection: $startDate)
                    .onChange(of: startDate) { newValue in
                        if endDate <= newValue {
                            // Ensure end time is after start time by adding 1 hour
                            endDate = Calendar.current.date(byAdding: .hour, value: 1, to: newValue) ?? newValue
                        }
                    }
                
                DatePicker("End Time", selection: $endDate)
                    .onChange(of: endDate) { newValue in
                        if newValue <= startDate {
                            // Ensure start time is before end time
                            startDate = Calendar.current.date(byAdding: .hour, value: -1, to: newValue) ?? newValue
                        }
                    }
                
                HStack {
                    Text("Duration")
                    Spacer()
                    Text(formattedDuration)
                        .fontWeight(.semibold)
                }
                
                if let activity = session.activity, let project = activity.project {
                    HStack {
                        Text("Earnings")
                        Spacer()
                        Text(TimeCalculator.formatCurrency(earnings))
                            .fontWeight(.semibold)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Notes")
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                        .padding(4)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
            
            Section {
                Button(action: saveSession) {
                    Text("Save Changes")
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                }
                .disabled(!isValidSession)
                .listRowBackground(isValidSession ? ColorTheme.primary : Color.gray)
                
                Button(role: .destructive, action: deleteSession) {
                    Text("Delete Session")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Edit Session")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func saveSession() {
        withAnimation {
            session.startTime = startDate
            session.endTime = endDate
            session.notes = notes.isEmpty ? nil : notes
            
            do {
                try viewContext.save()
                presentationMode.wrappedValue.dismiss()
            } catch {
                let nsError = error as NSError
                print("Error saving session: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private func deleteSession() {
        withAnimation {
            viewContext.delete(session)
            
            do {
                try viewContext.save()
                presentationMode.wrappedValue.dismiss()
            } catch {
                let nsError = error as NSError
                print("Error deleting session: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

#Preview {
    ActivitiesView()
        .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
} 