//
//  DebugLog.swift
//  EvoArc
//
//  Compile-time-gated logging. `dlog` is a no-op in release builds, so debug
//  prints don't ship to App Store users (binary bloat + privacy leak risk).
//

import Foundation

@inlinable
nonisolated func dlog(
    _ message: @autoclosure () -> Any,
    file: StaticString = #fileID,
    line: UInt = #line
) {
    #if DEBUG
    Swift.print("[\(file):\(line)] \(message())")
    #endif
}
