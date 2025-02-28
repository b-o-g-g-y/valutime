import CoreData
import Foundation

class CoreDataManager {
    static let shared = CoreDataManager()
    
    private init() {}
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "ValueTime")
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    // MARK: - User Methods
    
    func createDefaultUser() -> User {
        let user = User(context: viewContext)
        user.id = UUID()
        user.name = "Default User"
        user.defaultHourlyRate = 25.0
        user.preferredCurrency = "USD"
        saveContext()
        return user
    }
    
    func getUser() -> User? {
        let request: NSFetchRequest<User> = User.fetchRequest()
        do {
            let users = try viewContext.fetch(request)
            return users.first ?? createDefaultUser()
        } catch {
            print("Error fetching user: \(error)")
            return createDefaultUser()
        }
    }
    
    // MARK: - Project Methods
    
    func createProject(name: String, hourlyRate: Double, budgetType: String, budget: Double, startDate: Date, endDate: Date?, color: String) -> Project {
        let project = Project(context: viewContext)
        project.id = UUID()
        project.name = name
        project.hourlyRate = hourlyRate
        project.budgetType = budgetType
        project.budget = budget
        project.startDate = startDate
        project.endDate = endDate
        project.color = color
        saveContext()
        return project
    }
    
    func getProjects() -> [Project] {
        let request: NSFetchRequest<Project> = Project.fetchRequest()
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching projects: \(error)")
            return []
        }
    }
    
    func deleteProject(_ project: Project) {
        viewContext.delete(project)
        saveContext()
    }
    
    // MARK: - Activity Methods
    
    func createActivity(name: String, type: String, color: String, icon: String, project: Project?, hourlyRate: Double = 0.0) -> Activity {
        let activity = Activity(context: viewContext)
        activity.id = UUID()
        activity.name = name
        activity.type = type
        activity.color = color
        activity.icon = icon
        activity.project = project
        
        // Set hourly rate based on project or provided value
        if let project = project, hourlyRate == 0.0 {
            activity.hourlyRate = project.hourlyRate
        } else {
            activity.hourlyRate = hourlyRate
        }
        
        saveContext()
        return activity
    }
    
    func getActivities() -> [Activity] {
        let request: NSFetchRequest<Activity> = Activity.fetchRequest()
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching activities: \(error)")
            return []
        }
    }
    
    func deleteActivity(_ activity: Activity) {
        viewContext.delete(activity)
        saveContext()
    }
    
    // MARK: - Activity Session Methods
    
    func createActivitySession(activity: Activity, startTime: Date) -> ActivitySession {
        let session = ActivitySession(context: viewContext)
        session.id = UUID()
        session.activity = activity
        session.startTime = startTime
        session.isPaused = false
        session.pauseTime = nil
        saveContext()
        return session
    }
    
    func endActivitySession(_ session: ActivitySession, endTime: Date, notes: String?) {
        session.endTime = endTime
        session.notes = notes
        session.isPaused = false
        session.pauseTime = nil
        saveContext()
    }
    
    func updateActivitySession(_ session: ActivitySession, startTime: Date? = nil, isPaused: Bool? = nil, pauseTime: Date? = nil) {
        if let startTime = startTime {
            session.startTime = startTime
        }
        
        if let isPaused = isPaused {
            session.isPaused = isPaused
        }
        
        if isPaused == false {
            session.pauseTime = nil
        } else if let pauseTime = pauseTime {
            session.pauseTime = pauseTime
        }
        
        saveContext()
    }
    
    func getActiveSessions() -> [ActivitySession] {
        let request: NSFetchRequest<ActivitySession> = ActivitySession.fetchRequest()
        request.predicate = NSPredicate(format: "endTime == nil")
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching active sessions: \(error)")
            return []
        }
    }
    
    func getPausedSessions() -> [ActivitySession] {
        let request: NSFetchRequest<ActivitySession> = ActivitySession.fetchRequest()
        request.predicate = NSPredicate(format: "endTime == nil AND isPaused == YES")
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching paused sessions: \(error)")
            return []
        }
    }
    
    func getSessionsForActivity(_ activity: Activity) -> [ActivitySession] {
        let request: NSFetchRequest<ActivitySession> = ActivitySession.fetchRequest()
        request.predicate = NSPredicate(format: "activity == %@", activity)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ActivitySession.startTime, ascending: false)]
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching sessions for activity: \(error)")
            return []
        }
    }
    
    func getSessionsInDateRange(start: Date, end: Date) -> [ActivitySession] {
        let request: NSFetchRequest<ActivitySession> = ActivitySession.fetchRequest()
        request.predicate = NSPredicate(format: "(startTime >= %@ AND startTime <= %@) OR (endTime >= %@ AND endTime <= %@) OR (startTime <= %@ AND endTime >= %@)",
                                       start as NSDate, end as NSDate,
                                       start as NSDate, end as NSDate,
                                       start as NSDate, end as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ActivitySession.startTime, ascending: true)]
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching sessions in date range: \(error)")
            return []
        }
    }
    
    func deleteSession(_ session: ActivitySession) {
        viewContext.delete(session)
        saveContext()
    }
} 