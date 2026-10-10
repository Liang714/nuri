import SwiftUI

public extension EnvironmentValues {
    /// True when the person has turned on Hide numbers. The app root sets it from its settings.
    ///
    /// Components that can show digits (calories, grams, minutes) or ads read this and gate themselves,
    /// so a screen that forgets to check cannot leak a number. `AdCard` and `NuriProgressBar` do.
    @Entry var nuriHideNumbers: Bool = false
}
