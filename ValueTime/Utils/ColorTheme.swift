import SwiftUI

struct ColorTheme {
    // Main app colors
    static let primary = Color("PrimaryColor")
    static let secondary = Color("SecondaryColor")
    static let accent = Color("AccentColor")
    static let background = Color("BackgroundColor")
    static let text = Color("TextColor")
    static let tertiary = Color("TertiaryColor")
    
    // Activity type colors
    static let work = Color("WorkColor")
    static let leisure = Color("LeisureColor")
    static let sleep = Color("SleepColor")
    static let exercise = Color("ExerciseColor")
    static let study = Color("StudyColor")
    static let personal = Color("PersonalColor")
    static let hobby = Color("HobbyColor")
    static let other = Color("OtherColor")
    
    // Status colors
    static let active = Color.green
    static let inactive = Color.gray
    static let warning = Color.orange
    static let error = Color.red
    
    // Budget status colors
    static let underBudget = Color.green
    static let nearBudget = Color.orange
    static let overBudget = Color.red
    
    // Get color for activity type
    static func colorForActivityType(_ type: String) -> Color {
        switch type.lowercased() {
        case "work":
            return work
        case "leisure":
            return leisure
        case "sleep":
            return sleep
        case "exercise", "gym":
            return exercise
        case "study", "learning":
            return study
        case "personal":
            return personal
        case "hobby":
            return hobby
        case "other":
            return other
        default:
            return accent
        }
    }
    
    // Get color from hex string
    static func color(fromHex hex: String) -> Color {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let red = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000FF) / 255.0
        
        return Color(red: red, green: green, blue: blue)
    }
    
    // Get hex string from color
    static func hexString(from color: Color) -> String {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let redInt = Int(red * 255.0)
        let greenInt = Int(green * 255.0)
        let blueInt = Int(blue * 255.0)
        
        return String(format: "#%02X%02X%02X", redInt, greenInt, blueInt)
    }
    
    // Get color for budget percentage
    static func colorForBudgetPercentage(_ percentage: Double) -> Color {
        if percentage < 75 {
            return underBudget
        } else if percentage < 95 {
            return nearBudget
        } else {
            return overBudget
        }
    }
    
    // Predefined activity colors
    static let activityColors = [
        "#4285F4", // Blue
        "#EA4335", // Red
        "#FBBC05", // Yellow
        "#34A853", // Green
        "#8E44AD", // Purple
        "#F39C12", // Orange
        "#1ABC9C", // Turquoise
        "#E74C3C", // Crimson
        "#3498DB", // Light Blue
        "#2ECC71", // Emerald
        "#9B59B6", // Amethyst
        "#E67E22"  // Carrot
    ]
    
    // Get a random color for a new activity
    static func randomActivityColor() -> String {
        return activityColors.randomElement() ?? "#4285F4"
    }
} 