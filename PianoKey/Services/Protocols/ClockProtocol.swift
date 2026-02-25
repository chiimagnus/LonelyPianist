import Foundation

protocol ClockProtocol {
    nonisolated func now() -> Date
}

struct SystemClock: ClockProtocol {
    nonisolated func now() -> Date {
        Date()
    }
}
