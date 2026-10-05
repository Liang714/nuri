/// Rounds to the nearest multiple of `step` (half away from zero).
public func roundTo(_ value: Double, step: Double) -> Double {
    (value / step).rounded() * step
}

/// Rounds up to the next multiple of `step`.
public func ceilTo(_ value: Double, step: Double) -> Double {
    (value / step).rounded(.up) * step
}
