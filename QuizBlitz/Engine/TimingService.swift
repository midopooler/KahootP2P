import Foundation

enum TimingService {
    static func currentUptimeNs() -> UInt64 {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        let ticks = mach_absolute_time()
        return ticks * UInt64(info.numer) / UInt64(info.denom)
    }

    static func elapsedMs(from startNs: UInt64, to endNs: UInt64) -> Double {
        return Double(endNs - startNs) / 1_000_000.0
    }

    static func elapsedSeconds(from startNs: UInt64, to endNs: UInt64) -> Double {
        return Double(endNs - startNs) / 1_000_000_000.0
    }
}
