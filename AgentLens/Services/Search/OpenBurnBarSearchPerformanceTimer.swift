import Foundation
import Dispatch

// MARK: - Performance Timer

/// Utilities for measuring query performance timing.
enum OpenBurnBarPerformanceTimer {
    /// Returns current uptime in nanoseconds.
    static func now() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }

    /// Calculates elapsed time in milliseconds since the given start time.
    static func elapsedMilliseconds(since start: UInt64) -> Double {
        let end = DispatchTime.now().uptimeNanoseconds
        guard end >= start else { return 0 }
        return Double(end - start) / 1_000_000
    }
}
