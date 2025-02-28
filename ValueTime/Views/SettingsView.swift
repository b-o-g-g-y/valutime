import SwiftUI
import CoreData

// Extension to dismiss keyboard
extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \User.name, ascending: true)],
        animation: .default)
    private var users: FetchedResults<User>
    
    // Current values
    @State private var name: String
    @State private var defaultHourlyRate: Double
    @State private var defaultCurrency: String
    @State private var trackingStartDate: Date
    
    // Original values to track changes
    @State private var originalName: String
    @State private var originalHourlyRate: Double
    @State private var originalCurrency: String
    @State private var originalTrackingStartDate: Date
    
    // Notification settings
    @State private var inactivityReminderEnabled: Bool
    @State private var inactivityReminderInterval: TimeInterval
    @State private var longSessionReminderEnabled: Bool
    @State private var longSessionReminderInterval: TimeInterval
    
    // Original notification settings to track changes
    @State private var originalInactivityEnabled: Bool
    @State private var originalInactivityInterval: TimeInterval
    @State private var originalLongSessionEnabled: Bool
    @State private var originalLongSessionInterval: TimeInterval
    
    // Feedback states
    @State private var showingSaveConfirmation = false
    @State private var saveError: Error?
    @State private var isSaving = false
    @State private var showToast = false
    
    // For hourly rate text field
    @State private var hourlyRateText: String = ""
    @FocusState private var isHourlyRateFocused: Bool
    
    // Check if profile settings have changed
    private var profileSettingsChanged: Bool {
        return name != originalName ||
               defaultHourlyRate != originalHourlyRate ||
               defaultCurrency != originalCurrency
    }
    
    // Check if tracking date has changed
    private var trackingDateChanged: Bool {
        return !Calendar.current.isDate(trackingStartDate, inSameDayAs: originalTrackingStartDate)
    }
    
    // Check if notification settings have changed
    private var notificationSettingsChanged: Bool {
        return inactivityReminderEnabled != originalInactivityEnabled ||
               inactivityReminderInterval != originalInactivityInterval ||
               longSessionReminderEnabled != originalLongSessionEnabled ||
               longSessionReminderInterval != originalLongSessionInterval
    }
    
    // Check if any settings have changed
    private var hasChanges: Bool {
        return profileSettingsChanged || trackingDateChanged || notificationSettingsChanged
    }
    
    // Date formatter for tracking start date
    private let dateFormatter = { () -> DateFormatter in
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    // Date picker state
    @State private var showDatePicker = false
    
    init() {
        let user = CoreDataManager.shared.getUser()
        let userName = user?.name ?? ""
        let hourlyRate = user?.defaultHourlyRate ?? 25.0
        let savedCurrency = UserDefaults.standard.string(forKey: "userDefaultCurrency") ?? "USD"
        
        // Get tracking start date from UserDefaults or use a default date (1 month ago)
        let defaultStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let savedTrackingStartDate = UserDefaults.standard.object(forKey: "trackingStartDate") as? Date ?? defaultStartDate
        
        // Initialize current values
        _name = State(initialValue: userName)
        _defaultHourlyRate = State(initialValue: hourlyRate)
        _defaultCurrency = State(initialValue: savedCurrency)
        _hourlyRateText = State(initialValue: String(format: "%.2f", hourlyRate))
        _trackingStartDate = State(initialValue: savedTrackingStartDate)
        
        // Initialize original values
        _originalName = State(initialValue: userName)
        _originalHourlyRate = State(initialValue: hourlyRate)
        _originalCurrency = State(initialValue: savedCurrency)
        _originalTrackingStartDate = State(initialValue: savedTrackingStartDate)
        
        // Initialize notification settings
        let inactivityEnabled = NotificationSettings.shared.inactivityReminderEnabled
        let inactivityInterval = NotificationSettings.shared.inactivityReminderInterval
        let longSessionEnabled = NotificationSettings.shared.longSessionReminderEnabled
        let longSessionInterval = NotificationSettings.shared.longSessionReminderInterval
        
        _inactivityReminderEnabled = State(initialValue: inactivityEnabled)
        _inactivityReminderInterval = State(initialValue: inactivityInterval)
        _longSessionReminderEnabled = State(initialValue: longSessionEnabled)
        _longSessionReminderInterval = State(initialValue: longSessionInterval)
        
        // Initialize original notification settings
        _originalInactivityEnabled = State(initialValue: inactivityEnabled)
        _originalInactivityInterval = State(initialValue: inactivityInterval)
        _originalLongSessionEnabled = State(initialValue: longSessionEnabled)
        _originalLongSessionInterval = State(initialValue: longSessionInterval)
    }
    
    var body: some View {
        ZStack {
            mainNavigationView
            
            // Floating save button that appears when changes are made
            if hasChanges && !isSaving {
                saveButton
            }
            
            // Saving indicator that replaces the floating button when saving
            if isSaving {
                savingIndicator
            }
            
            // Toast notification
            if showToast {
                successToast
            }
            
            // Unsaved changes indicator that appears at the top when user makes changes
            if hasChanges {
                unsavedChangesIndicator
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showToast)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hasChanges)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSaving)
    }
    
    private var mainNavigationView: some View {
        NavigationView {
            ZStack(alignment: .top) {
                ColorTheme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom header
                    HStack {
                        Text("Settings")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(ColorTheme.text)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 15)
                    .padding(.bottom, 10)
                    
                    settingsForm
                }
            }
            .navigationBarHidden(true)
            .alert(isPresented: Binding<Bool>(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Alert(
                    title: Text("Error Saving Settings"),
                    message: Text(saveError?.localizedDescription ?? "An unknown error occurred"),
                    dismissButton: .default(Text("OK"))
                )
            }
            // Add a tap gesture to dismiss keyboard
            .onTapGesture {
                isHourlyRateFocused = false
                UIApplication.shared.endEditing()
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isHourlyRateFocused = false
                        UIApplication.shared.endEditing()
                    }
                }
            }
        }
    }
    
    private var settingsForm: some View {
        Form {
            userProfileSection
            
            notificationSettingsSection
        }
        .padding(.bottom, hasChanges ? 80 : 0) // Add padding at the bottom when floating button is visible
    }
    
    private var userProfileSection: some View {
        Section {
            TextField("Name", text: $name)
            
            HStack {
                Text("Default Hourly Rate")
                Spacer()
                TextField("Rate", text: $hourlyRateText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($isHourlyRateFocused)
                    .onChange(of: hourlyRateText) { newValue in
                        if let newRate = Double(newValue.replacingOccurrences(of: ",", with: ".")) {
                            defaultHourlyRate = newRate
                        }
                    }
            }
            
            Menu {
                Picker("Default Currency", selection: $defaultCurrency) {
                    Text("USD ($)").tag("USD")
                    Text("EUR (€)").tag("EUR")
                    Text("GBP (£)").tag("GBP")
                    Text("JPY (¥)").tag("JPY")
                    Text("CAD ($)").tag("CAD")
                    Text("AUD ($)").tag("AUD")
                }
            } label: {
                HStack {
                    Text("Default Currency")
                    Spacer()
                    Text(getCurrencySymbol(for: defaultCurrency) + " " + defaultCurrency)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Text("Tracking Start Date")
                Spacer()
                
                // Format the date for display
                Text(dateFormatter.string(from: trackingStartDate))
                    .foregroundColor(ColorTheme.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.1))
                    )
                    .onTapGesture {
                        showDatePicker = true
                    }
            }
            .padding(.vertical, 4)
            .sheet(isPresented: $showDatePicker) {
                VStack {
                    HStack {
                        Button("Cancel") {
                            showDatePicker = false
                        }
                        .padding()
                        
                        Spacer()
                        
                        Button("Done") {
                            showDatePicker = false
                        }
                        .padding()
                        .foregroundColor(ColorTheme.primary)
                        .bold()
                    }
                    
                    DatePicker("Select Date", selection: $trackingStartDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding()
                    
                    Spacer()
                }
            }
        } header: {
            Text("User Profile")
        } footer: {
            Text("The tracking start date is used to calculate your average hourly worth. Only time tracked after this date will be included in calculations.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var notificationSettingsSection: some View {
        Section(header: Text("Notification Settings")) {
            Toggle("Inactivity Reminders", isOn: $inactivityReminderEnabled)
            
            if inactivityReminderEnabled {
                inactivityReminderMenu
            }
            
            Toggle("Long Session Check-ins", isOn: $longSessionReminderEnabled)
            
            if longSessionReminderEnabled {
                longSessionReminderMenu
            }
        }
    }
    
    private var inactivityReminderMenu: some View {
        Menu {
            ForEach(0..<NotificationSettings.shared.inactivityIntervalOptions.count, id: \.self) { index in
                let option = NotificationSettings.shared.inactivityIntervalOptions[index]
                Button(action: {
                    inactivityReminderInterval = option.value
                }) {
                    if option.value == inactivityReminderInterval {
                        Label(option.label, systemImage: "checkmark")
                    } else {
                        Text(option.label)
                    }
                }
            }
        } label: {
            HStack {
                Text("Reminder Frequency")
                Spacer()
                Text(NotificationSettings.shared.getFormattedInterval(interval: inactivityReminderInterval))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var longSessionReminderMenu: some View {
        Menu {
            ForEach(0..<NotificationSettings.shared.longSessionIntervalOptions.count, id: \.self) { index in
                let option = NotificationSettings.shared.longSessionIntervalOptions[index]
                Button(action: {
                    longSessionReminderInterval = option.value
                }) {
                    if option.value == longSessionReminderInterval {
                        Label(option.label, systemImage: "checkmark")
                    } else {
                        Text(option.label)
                    }
                }
            }
        } label: {
            HStack {
                Text("Check-in After")
                Spacer()
                Text(NotificationSettings.shared.getFormattedInterval(interval: longSessionReminderInterval))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var saveButton: some View {
        VStack {
            Spacer()
            
            Button(action: saveSettings) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 20))
                    
                    Text("Save Changes")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .padding(.vertical, 16)
                .padding(.horizontal, 24)
                .background(
                    Capsule()
                        .fill(ColorTheme.primary)
                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                )
            }
            .padding(.bottom, 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hasChanges)
        .zIndex(90)
    }
    
    private var savingIndicator: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text("Saving...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background(
                Capsule()
                    .fill(Color.gray.opacity(0.8))
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
            )
            .padding(.bottom, 20)
        }
        .zIndex(90)
    }
    
    private var successToast: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 24))
                
                Text("Settings Saved Successfully")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(Color.green)
                    .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
            )
            .padding(.bottom, 40)
            .padding(.horizontal, 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .zIndex(100)
    }
    
    private var unsavedChangesIndicator: some View {
        VStack {
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 16))
                
                Text("Unsaved changes")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange)
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .zIndex(80)
    }
    
    private func getCurrencySymbol(for currencyCode: String) -> String {
        switch currencyCode {
        case "USD", "CAD", "AUD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY": return "¥"
        default: return "$"
        }
    }
    
    private func saveSettings() {
        // Dismiss keyboard first
        isHourlyRateFocused = false
        UIApplication.shared.endEditing()
        
        // Set saving state
        isSaving = true
        
        // Perform the save operation
        DispatchQueue.main.async {
            let user = CoreDataManager.shared.getUser()
            user?.name = name
            user?.defaultHourlyRate = defaultHourlyRate
            
            // Save the currency to UserDefaults for persistence
            UserDefaults.standard.set(defaultCurrency, forKey: "userDefaultCurrency")
            
            // Save tracking start date to UserDefaults
            UserDefaults.standard.set(trackingStartDate, forKey: "trackingStartDate")
            
            // Save notification settings
            NotificationSettings.shared.inactivityReminderEnabled = inactivityReminderEnabled
            NotificationSettings.shared.inactivityReminderInterval = inactivityReminderInterval
            NotificationSettings.shared.longSessionReminderEnabled = longSessionReminderEnabled
            NotificationSettings.shared.longSessionReminderInterval = longSessionReminderInterval
            
            do {
                try viewContext.save()
                
                // Update original values to match current values
                originalName = name
                originalHourlyRate = defaultHourlyRate
                originalCurrency = defaultCurrency
                originalTrackingStartDate = trackingStartDate
                originalInactivityEnabled = inactivityReminderEnabled
                originalInactivityInterval = inactivityReminderInterval
                originalLongSessionEnabled = longSessionReminderEnabled
                originalLongSessionInterval = longSessionReminderInterval
                
                // Show success checkmark in button
                isSaving = false
                showingSaveConfirmation = true
                
                // Provide haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                // Show toast notification with animation
                withAnimation {
                    showToast = true
                }
                
                // Hide the checkmark and toast after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation {
                        showingSaveConfirmation = false
                        showToast = false
                    }
                }
                
            } catch {
                isSaving = false
                saveError = error
                
                // Provide error haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
                
                print("Error saving settings: \(error as NSError)")
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
} 