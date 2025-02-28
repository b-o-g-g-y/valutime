import Foundation

class TimeCalculator {
    
    // Calculate duration between two dates in seconds
    static func calculateDuration(from startDate: Date, to endDate: Date) -> TimeInterval {
        return endDate.timeIntervalSince(startDate)
    }
    
    // Format seconds into a readable time string (HH:MM:SS)
    static func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        let seconds = Int(interval) % 60
        
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    // Format seconds into a readable time string with hours and minutes only (HH:MM)
    static func formatTimeIntervalShort(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        
        return String(format: "%02d:%02d", hours, minutes)
    }
    
    // Calculate earnings based on hourly rate and time spent
    static func calculateEarnings(hourlyRate: Double, timeSpentInSeconds: TimeInterval) -> Double {
        let hoursSpent = timeSpentInSeconds / 3600
        return hourlyRate * hoursSpent
    }
    
    // Format currency amount based on locale
    static func formatCurrency(_ amount: Double, currencyCode: String = "USD") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
    }
    
    // Calculate effective hourly rate for fixed-cost projects
    static func calculateEffectiveHourlyRate(fixedCost: Double, timeSpentInSeconds: TimeInterval) -> Double {
        let hoursSpent = timeSpentInSeconds / 3600
        guard hoursSpent > 0 else { return 0 }
        return fixedCost / hoursSpent
    }
    
    // Calculate opportunity cost
    static func calculateOpportunityCost(hourlyRate: Double, timeSpentInSeconds: TimeInterval) -> Double {
        return calculateEarnings(hourlyRate: hourlyRate, timeSpentInSeconds: timeSpentInSeconds)
    }
    
    // Calculate time remaining for a project based on budget
    static func calculateTimeRemainingInBudget(budget: Double, hourlyRate: Double, timeSpentInSeconds: TimeInterval) -> TimeInterval {
        let spentAmount = calculateEarnings(hourlyRate: hourlyRate, timeSpentInSeconds: timeSpentInSeconds)
        let remainingBudget = budget - spentAmount
        
        guard remainingBudget > 0 && hourlyRate > 0 else { return 0 }
        
        let remainingHours = remainingBudget / hourlyRate
        return remainingHours * 3600
    }
    
    // Calculate percentage of budget used
    static func calculateBudgetPercentageUsed(budget: Double, hourlyRate: Double, timeSpentInSeconds: TimeInterval) -> Double {
        let spentAmount = calculateEarnings(hourlyRate: hourlyRate, timeSpentInSeconds: timeSpentInSeconds)
        
        guard budget > 0 else { return 0 }
        
        return (spentAmount / budget) * 100
    }
    
    // Get current date formatted as string
    static func getCurrentDateFormatted() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }
    
    // Get current time formatted as string
    static func getCurrentTimeFormatted() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: Date())
    }
    
    // Format date to string
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    // Format time to string
    static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    // Format date and time to string
    static func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - NumberFormatter Extension
extension NumberFormatter {
    static var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }
} 