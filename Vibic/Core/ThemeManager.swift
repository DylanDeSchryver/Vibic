import SwiftUI

enum AppTheme: String, CaseIterable {
    case purple = "Purple"
    case red = "Red"
    case blue = "Blue"
    case green = "Green"
    
    var color: Color {
        switch self {
        case .purple:
            return Color(red: 0.549, green: 0.310, blue: 0.984)
        case .red:
            return Color(red: 0.94, green: 0.27, blue: 0.33)
        case .blue:
            return Color(red: 0.20, green: 0.50, blue: 0.95)
        case .green:
            return Color(red: 0.20, green: 0.78, blue: 0.45)
        }
    }
    
    var gradientColors: [Color] {
        switch self {
        case .purple:
            return [Color(red: 0.545, green: 0.361, blue: 0.965),
                    Color(red: 0.925, green: 0.286, blue: 0.6)]
        case .red:
            return [Color(red: 0.94, green: 0.27, blue: 0.33),
                    Color(red: 0.98, green: 0.45, blue: 0.25)]
        case .blue:
            return [Color(red: 0.20, green: 0.50, blue: 0.95),
                    Color(red: 0.30, green: 0.75, blue: 0.90)]
        case .green:
            return [Color(red: 0.20, green: 0.78, blue: 0.45),
                    Color(red: 0.55, green: 0.90, blue: 0.45)]
        }
    }
}

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @AppStorage("selectedTheme") private var selectedThemeRaw: String = AppTheme.purple.rawValue
    
    var currentTheme: AppTheme {
        get { AppTheme(rawValue: selectedThemeRaw) ?? .purple }
        set {
            selectedThemeRaw = newValue.rawValue
            objectWillChange.send()
        }
    }
    
    var accentColor: Color {
        currentTheme.color
    }
    
    var gradientColors: [Color] {
        currentTheme.gradientColors
    }
    
    private init() {}
}

// Environment key for theme
struct ThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .purple
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// View modifier for easy theme access
extension View {
    func themed() -> some View {
        self.tint(ThemeManager.shared.accentColor)
    }
}
