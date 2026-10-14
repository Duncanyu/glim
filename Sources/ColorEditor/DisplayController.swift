import CoreGraphics
import Foundation

@MainActor
final class DisplayController {
    private var originals: [CGDirectDisplayID: GammaTable] = [:]
    private var lastApplied: [CGDirectDisplayID: GammaTable] = [:]

    func apply(_ settings: DisplaySettings, to displayID: CGDirectDisplayID) throws {
        let original: GammaTable
        if let saved = originals[displayID], let expected = lastApplied[displayID] {
            let current = try readTable(for: displayID)
            original = current.approximatelyEquals(expected) ? saved : current
            originals[displayID] = original
        } else {
            original = try readTable(for: displayID)
            originals[displayID] = original
        }
        let adjusted = original.adjusted(with: settings)
        try write(adjusted, to: displayID)
        lastApplied[displayID] = adjusted
    }

    func restore(_ displayID: CGDirectDisplayID) throws {
        guard let original = originals[displayID] else { return }
        if let expected = lastApplied[displayID] {
            let current = try readTable(for: displayID)
            if current.approximatelyEquals(expected) { try write(original, to: displayID) }
        }
        originals.removeValue(forKey: displayID)
        lastApplied.removeValue(forKey: displayID)
    }

    @discardableResult
    func restoreAll() -> String? {
        var firstError: String?
        for displayID in Array(originals.keys) {
            do { try restore(displayID) }
            catch { if firstError == nil { firstError = error.localizedDescription } }
        }
        return firstError
    }

    func forgetDisconnectedDisplays(keeping ids: Set<CGDirectDisplayID>) {
        originals = originals.filter { ids.contains($0.key) }
        lastApplied = lastApplied.filter { ids.contains($0.key) }
    }

    private func readTable(for displayID: CGDirectDisplayID) throws -> GammaTable {
        let capacity = Int(CGDisplayGammaTableCapacity(displayID))
        guard (2...16_384).contains(capacity) else { throw DisplayError.unavailable }

        var red = [CGGammaValue](repeating: 0, count: capacity)
        var green = red
        var blue = red
        var count: UInt32 = 0
        let result = red.withUnsafeMutableBufferPointer { r in
            green.withUnsafeMutableBufferPointer { g in
                blue.withUnsafeMutableBufferPointer { b in
                    CGGetDisplayTransferByTable(displayID, UInt32(capacity), r.baseAddress, g.baseAddress, b.baseAddress, &count)
                }
            }
        }
        guard result == .success, count >= 2, count <= UInt32(capacity) else { throw DisplayError.readFailed(result.rawValue) }
        let length = Int(count)
        guard red[..<length].allSatisfy(\.isFinite),
              green[..<length].allSatisfy(\.isFinite),
              blue[..<length].allSatisfy(\.isFinite) else { throw DisplayError.invalidTable }
        return GammaTable(red: Array(red[..<length]), green: Array(green[..<length]), blue: Array(blue[..<length]))
    }

    private func write(_ table: GammaTable, to displayID: CGDirectDisplayID) throws {
        let result = table.red.withUnsafeBufferPointer { r in
            table.green.withUnsafeBufferPointer { g in
                table.blue.withUnsafeBufferPointer { b in
                    CGSetDisplayTransferByTable(displayID, UInt32(table.count), r.baseAddress, g.baseAddress, b.baseAddress)
                }
            }
        }
        guard result == .success else { throw DisplayError.writeFailed(result.rawValue) }
    }
}

private enum DisplayError: LocalizedError {
    case unavailable
    case invalidTable
    case readFailed(Int32)
    case writeFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .unavailable: return "This display does not expose a usable gamma table."
        case .invalidTable: return "This display returned an invalid color curve."
        case .readFailed(let code): return "Could not read this display's existing color curve (error \(code))."
        case .writeFailed(let code): return "macOS rejected this display adjustment (error \(code))."
        }
    }
}
