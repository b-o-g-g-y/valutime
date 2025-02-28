import SwiftUI
import CoreData
// EmptyStateView and ActivitySessionRow are now imported from SharedComponents
// AddSessionView and SessionDetailView are defined in ActivitiesView.swift but are part of the same module

struct ProjectsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Project.name, ascending: true)],
        animation: .default)
    private var projects: FetchedResults<Project>
    
    @State private var showingAddProject = false
    @State private var searchText = ""
    
    var filteredProjects: [Project] {
        if searchText.isEmpty {
            return Array(projects)
        } else {
            return projects.filter { ($0.name ?? "").localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                ColorTheme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom header
                    HStack {
                        Text("Projects")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(ColorTheme.text)
                        
                        Spacer()
                        
                        Button(action: {
                            showingAddProject = true
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
                        if projects.isEmpty {
                            EmptyStateView(
                                title: "No Projects",
                                message: "Add projects to organize your activities.",
                                buttonTitle: "Add Project",
                                systemImage: "folder",
                                action: { showingAddProject = true }
                            )
                        } else {
                            VStack(spacing: 0) {
                                // Search bar
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.secondary)
                                    
                                    TextField("Search projects", text: $searchText)
                                        .foregroundColor(.primary)
                                }
                                .padding(10)
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .padding(.horizontal)
                                .padding(.bottom, 10)
                                
                                // Projects list
                                ScrollView {
                                    LazyVStack(spacing: 12) {
                                        ForEach(filteredProjects) { project in
                                            NavigationLink(destination: ProjectDetailView(project: project)) {
                                                ProjectRow(project: project)
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
            .sheet(isPresented: $showingAddProject) {
                AddProjectView()
            }
        }
    }
    
    private func deleteProjects(offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredProjects[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Error deleting project: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct ProjectRow: View {
    let project: Project
    
    var body: some View {
        HStack {
            Circle()
                .fill(ColorTheme.color(fromHex: project.color ?? "#4285F4"))
                .frame(width: 16, height: 16)
            
            VStack(alignment: .leading) {
                Text(project.name ?? "Project")
                    .fontWeight(.medium)
                
                HStack {
                    Text("$\(String(format: "%.2f", project.hourlyRate))/hr")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if project.budgetType == "fixed" {
                        Text("• Budget: $\(String(format: "%.2f", project.budget))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if let activities = project.activities as? Set<Activity>, !activities.isEmpty {
                Text("\(activities.count) activities")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ProjectDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    
    let project: Project
    
    @State private var name: String
    @State private var hourlyRate: Double
    @State private var budgetType: String
    @State private var budget: Double
    @State private var startDate: Date
    @State private var endDate: Date?
    @State private var color: String
    @State private var selectedActivity: Activity?
    @State private var showingAddSession = false
    
    @FetchRequest private var activities: FetchedResults<Activity>
    @FetchRequest private var sessions: FetchedResults<ActivitySession>
    
    init(project: Project) {
        self.project = project
        _name = State(initialValue: project.name ?? "")
        _hourlyRate = State(initialValue: project.hourlyRate)
        _budgetType = State(initialValue: project.budgetType ?? "hourly")
        _budget = State(initialValue: project.budget)
        _startDate = State(initialValue: project.startDate ?? Date())
        _endDate = State(initialValue: project.endDate)
        _color = State(initialValue: project.color ?? "#4285F4")
        
        // Create a fetch request for activities related to this project
        let activitiesRequest: NSFetchRequest<Activity> = Activity.fetchRequest()
        activitiesRequest.predicate = NSPredicate(format: "project == %@", project)
        activitiesRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Activity.name, ascending: true)]
        _activities = FetchRequest(fetchRequest: activitiesRequest, animation: .default)
        
        // Create a fetch request for sessions related to activities in this project
        let sessionsRequest: NSFetchRequest<ActivitySession> = ActivitySession.fetchRequest()
        sessionsRequest.predicate = NSPredicate(format: "activity.project == %@", project)
        sessionsRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ActivitySession.startTime, ascending: false)]
        _sessions = FetchRequest(fetchRequest: sessionsRequest, animation: .default)
    }
    
    var totalHours: Double {
        sessions.reduce(0) { total, session in
            if let startTime = session.startTime, let endTime = session.endTime {
                return total + endTime.timeIntervalSince(startTime) / 3600
            }
            return total
        }
    }
    
    var totalEarnings: Double {
        return hourlyRate * totalHours
    }
    
    var budgetPercentage: Double {
        guard budgetType == "fixed" && budget > 0 else { return 0 }
        return (totalEarnings / budget) * 100
    }
    
    var effectiveHourlyRate: Double {
        guard budgetType == "fixed" && totalHours > 0 else { return hourlyRate }
        return budget / totalHours
    }
    
    var body: some View {
        Form {
            Section(header: Text("Project Details")) {
                TextField("Name", text: $name)
                
                HStack {
                    Text("Hourly Rate")
                    Spacer()
                    TextField("Rate", value: $hourlyRate, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                
                Picker("Budget Type", selection: $budgetType) {
                    Text("Hourly").tag("hourly")
                    Text("Fixed").tag("fixed")
                }
                
                if budgetType == "fixed" {
                    HStack {
                        Text("Budget")
                        Spacer()
                        TextField("Budget", value: $budget, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                
                DatePicker("End Date", selection: Binding(
                    get: { endDate ?? Date() },
                    set: { endDate = $0 }
                ), displayedComponents: .date)
                
                ColorPicker("Color", selection: Binding(
                    get: { ColorTheme.color(fromHex: color) },
                    set: { color = ColorTheme.hexString(from: $0) }
                ))
            }
            
            Section(header: Text("Project Summary")) {
                HStack {
                    Text("Total Hours")
                    Spacer()
                    Text(String(format: "%.2f", totalHours))
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Total Earnings")
                    Spacer()
                    Text(TimeCalculator.formatCurrency(totalEarnings))
                        .fontWeight(.semibold)
                }
                
                if budgetType == "fixed" {
                    HStack {
                        Text("Budget Used")
                        Spacer()
                        Text(String(format: "%.1f%%", budgetPercentage))
                            .fontWeight(.semibold)
                            .foregroundColor(ColorTheme.colorForBudgetPercentage(budgetPercentage))
                    }
                    
                    HStack {
                        Text("Effective Rate")
                        Spacer()
                        Text(TimeCalculator.formatCurrency(effectiveHourlyRate) + "/hr")
                            .fontWeight(.semibold)
                            .foregroundColor(effectiveHourlyRate >= hourlyRate ? ColorTheme.underBudget : ColorTheme.overBudget)
                    }
                }
            }
            
            Section(header: Text("Activities (\(activities.count))")) {
                if activities.isEmpty {
                    Text("No activities in this project")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(activities) { activity in
                        NavigationLink(destination: ActivityDetailView(activity: activity)) {
                            ActivityRow(activity: activity)
                        }
                        .contextMenu {
                            Button(action: {
                                // Show add session view for this activity
                                showAddSessionForActivity(activity)
                            }) {
                                Label("Add Session", systemImage: "plus.circle")
                            }
                        }
                    }
                }
                
                NavigationLink(destination: AddActivityToProjectView(project: project)) {
                    Label("Add Activity", systemImage: "plus")
                }
            }
            
            Section(header: Text("Recent Sessions")) {
                if sessions.isEmpty {
                    Text("No sessions recorded")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(sessions.prefix(5)) { session in
                        NavigationLink(destination: SessionDetailView(session: session)) {
                            ActivitySessionRow(session: session)
                        }
                    }
                    
                    if sessions.count > 5 {
                        NavigationLink(destination: ProjectSessionsView(project: project)) {
                            Text("View All Sessions")
                        }
                    }
                }
            }
            
            Section {
                Button(action: saveProject) {
                    Text("Save Changes")
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                }
                .listRowBackground(ColorTheme.primary)
                
                Button(role: .destructive, action: deleteProject) {
                    Text("Delete Project")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle(project.name ?? "Project Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddSession) {
            if let activity = selectedActivity {
                AddSessionView(activity: activity)
            }
        }
    }
    
    private func saveProject() {
        withAnimation {
            project.name = name
            project.hourlyRate = hourlyRate
            project.budgetType = budgetType
            project.budget = budget
            project.startDate = startDate
            project.endDate = endDate
            project.color = color
            
            do {
                try viewContext.save()
                presentationMode.wrappedValue.dismiss()
            } catch {
                let nsError = error as NSError
                print("Error saving project: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private func deleteProject() {
        withAnimation {
            viewContext.delete(project)
            
            do {
                try viewContext.save()
                presentationMode.wrappedValue.dismiss()
            } catch {
                let nsError = error as NSError
                print("Error deleting project: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private func showAddSessionForActivity(_ activity: Activity) {
        selectedActivity = activity
        showingAddSession = true
    }
}

struct AddProjectView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    
    @State private var name = ""
    @State private var hourlyRate = 25.0
    @State private var budgetType = "hourly"
    @State private var budget = 0.0
    @State private var startDate = Date()
    @State private var endDate: Date? = nil
    @State private var color = ColorTheme.randomActivityColor()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Project Details")) {
                    TextField("Name", text: $name)
                    
                    HStack {
                        Text("Hourly Rate")
                        Spacer()
                        TextField("Rate", value: $hourlyRate, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Picker("Budget Type", selection: $budgetType) {
                        Text("Hourly").tag("hourly")
                        Text("Fixed").tag("fixed")
                    }
                    
                    if budgetType == "fixed" {
                        HStack {
                            Text("Budget")
                            Spacer()
                            TextField("Budget", value: $budget, format: .currency(code: "USD"))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    
                    Toggle("Has End Date", isOn: Binding(
                        get: { endDate != nil },
                        set: { if $0 { endDate = Date() } else { endDate = nil } }
                    ))
                    
                    if endDate != nil {
                        DatePicker("End Date", selection: Binding(
                            get: { endDate ?? Date() },
                            set: { endDate = $0 }
                        ), displayedComponents: .date)
                    }
                    
                    ColorPicker("Color", selection: Binding(
                        get: { ColorTheme.color(fromHex: color) },
                        set: { color = ColorTheme.hexString(from: $0) }
                    ))
                }
                
                Section {
                    Button(action: addProject) {
                        Text("Add Project")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                    .disabled(name.isEmpty)
                    .listRowBackground(name.isEmpty ? Color.gray : ColorTheme.primary)
                }
            }
            .navigationTitle("New Project")
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
    
    private func addProject() {
        withAnimation {
            let newProject = CoreDataManager.shared.createProject(
                name: name,
                hourlyRate: hourlyRate,
                budgetType: budgetType,
                budget: budget,
                startDate: startDate,
                endDate: endDate,
                color: color
            )
            
            presentationMode.wrappedValue.dismiss()
        }
    }
}

struct AddActivityToProjectView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    
    let project: Project
    
    @State private var name = ""
    @State private var type = "work"
    @State private var color = ""
    @State private var icon = "circle.fill"
    
    init(project: Project) {
        self.project = project
        _color = State(initialValue: project.color ?? "#4285F4")
    }
    
    var body: some View {
        Form {
            Section(header: Text("New Activity for \(project.name ?? "Project")")) {
                TextField("Activity Name", text: $name)
                
                Picker("Type", selection: $type) {
                    Text("Work").tag("work")
                    Text("Leisure").tag("leisure")
                    Text("Sleep").tag("sleep")
                    Text("Exercise").tag("exercise")
                    Text("Study").tag("study")
                    Text("Personal").tag("personal")
                    Text("Hobby").tag("hobby")
                    Text("Other").tag("other")
                }
                
                ColorPicker("Color", selection: Binding(
                    get: { ColorTheme.color(fromHex: color) },
                    set: { color = ColorTheme.hexString(from: $0) }
                ))
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
        .navigationTitle("Add Activity")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func addActivity() {
        withAnimation {
            let newActivity = CoreDataManager.shared.createActivity(
                name: name,
                type: type,
                color: color,
                icon: icon,
                project: project
            )
            
            presentationMode.wrappedValue.dismiss()
        }
    }
}

struct ProjectSessionsView: View {
    let project: Project
    
    @FetchRequest private var sessions: FetchedResults<ActivitySession>
    
    init(project: Project) {
        self.project = project
        
        // Create a fetch request for sessions related to activities in this project
        let request: NSFetchRequest<ActivitySession> = ActivitySession.fetchRequest()
        request.predicate = NSPredicate(format: "activity.project == %@", project)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ActivitySession.startTime, ascending: false)]
        _sessions = FetchRequest(fetchRequest: request, animation: .default)
    }
    
    var body: some View {
        List {
            ForEach(sessions) { session in
                NavigationLink(destination: SessionDetailView(session: session)) {
                    ActivitySessionRow(session: session)
                }
            }
        }
        .navigationTitle("All Sessions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Color Theme Extensions
extension ColorTheme {
    // This method is already defined in ColorTheme.swift but with slightly different thresholds
    // Removing this to avoid redeclaration conflicts
}

#Preview {
    ProjectsView()
        .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
} 

