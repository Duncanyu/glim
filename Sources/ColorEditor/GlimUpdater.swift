import AppKit
import CryptoKit
import Foundation

struct GlimRelease: Decodable {
    let tagName: String
    let assets: [GlimAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case assets
    }

    var archive: GlimAsset? { assets.first { $0.name == "Glim-\(tagName.dropFirst()).zip" } }
    var checksum: GlimAsset? { assets.first { $0.name == "Glim-\(tagName.dropFirst()).zip.sha256" } }
}

struct GlimAsset: Decodable {
    let name: String
    let downloadURL: URL

    enum CodingKeys: String, CodingKey {
        case name
        case downloadURL = "browser_download_url"
    }
}

struct GlimVersion: Comparable {
    let major: Int
    let minor: Int
    let patch: Int

    init?(_ value: String) {
        let number = value.hasPrefix("v") ? String(value.dropFirst()) : value
        let parts = number.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let major = Int(parts[0]), major >= 0,
              let minor = Int(parts[1]), minor >= 0,
              let patch = Int(parts[2]), patch >= 0 else { return nil }
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}

@MainActor
final class GlimUpdater {
    private let session: URLSession
    private var timer: Timer?
    private var checkTask: Task<Void, Never>?
    private var checking = false
    private var generation = 0
    private var enabled = false
    private var installing = false

    init(session: URLSession = .shared) { self.session = session }

    func setEnabled(_ enabled: Bool) {
        guard self.enabled != enabled else { return }
        stop()
        self.enabled = enabled
        guard enabled else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.check() }
        }
        checkTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            self?.check()
        }
    }

    func stop() {
        generation += 1
        enabled = false
        checking = false
        timer?.invalidate()
        timer = nil
        checkTask?.cancel()
        checkTask = nil
    }

    private func check() {
        guard enabled, !installing, !checking else { return }
        checking = true
        let generation = self.generation
        checkTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.generation == generation {
                    self.checking = false
                    self.checkTask = nil
                }
            }
            do {
                var request = URLRequest(url: URL(string: "https://api.github.com/repos/Duncanyu/glim/releases?per_page=20")!)
                request.setValue("Glim/\(self.currentVersion)", forHTTPHeaderField: "User-Agent")
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                let (data, response) = try await self.session.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200,
                      self.enabled, self.generation == generation else { return }
                let releases = try JSONDecoder().decode([GlimRelease].self, from: data)
                guard let current = GlimVersion(self.currentVersion),
                      let release = releases.filter({ release in
                          guard let version = GlimVersion(release.tagName) else { return false }
                          return release.tagName.hasPrefix("v") && version > current &&
                              release.archive != nil && release.checksum != nil
                      }).max(by: { GlimVersion($0.tagName)! < GlimVersion($1.tagName)! }) else { return }
                self.offer(release)
            } catch {
                NSLog("Glim update check failed: %@", error.localizedDescription)
            }
        }
    }

    private func offer(_ release: GlimRelease) {
        guard enabled, !installing else { return }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Glim \(release.tagName) is available"
        alert.informativeText = "Download and install this update from GitHub? Your current settings will be kept."
        alert.addButton(withTitle: "Install Update")
        alert.addButton(withTitle: "Later")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        installing = true
        Task { [weak self] in
            guard let self else { return }
            do { try await self.install(release) }
            catch {
                self.installing = false
                let failure = NSAlert()
                failure.messageText = "Glim could not install the update"
                failure.informativeText = "\(error.localizedDescription) You can download it from GitHub Releases."
                failure.addButton(withTitle: "OK")
                failure.addButton(withTitle: "Open Releases")
                if failure.runModal() == .alertSecondButtonReturn {
                    NSWorkspace.shared.open(URL(string: "https://github.com/Duncanyu/glim/releases")!)
                }
            }
        }
    }

    private func install(_ release: GlimRelease) async throws {
        guard let archive = release.archive, let checksum = release.checksum else { throw UpdateError.invalidRelease }
        let currentApp = Bundle.main.bundleURL.standardizedFileURL
        guard currentApp.pathExtension == "app" else { throw UpdateError.invalidApp }
        let parent = currentApp.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: parent.path) else { throw UpdateError.unwritableDestination }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlimUpdate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let (download, archiveResponse) = try await session.download(from: archive.downloadURL)
        guard (archiveResponse as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError.downloadFailed }
        let archiveURL = directory.appendingPathComponent(archive.name)
        try FileManager.default.moveItem(at: download, to: archiveURL)
        let (checksumData, checksumResponse) = try await session.data(from: checksum.downloadURL)
        guard (checksumResponse as? HTTPURLResponse)?.statusCode == 200,
              let expected = Self.checksum(in: checksumData, for: archive.name) else { throw UpdateError.invalidChecksum }
        let actual = SHA256.hash(data: try Data(contentsOf: archiveURL))
            .map { String(format: "%02x", $0) }.joined()
        guard actual == expected else { throw UpdateError.invalidChecksum }

        try run("/usr/bin/ditto", ["-x", "-k", archiveURL.path, directory.path])
        let newApp = directory.appendingPathComponent("Glim.app")
        guard let bundle = Bundle(url: newApp),
              bundle.bundleIdentifier == Bundle.main.bundleIdentifier,
              bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String == String(release.tagName.dropFirst()) else {
            throw UpdateError.invalidApp
        }
        try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", newApp.path])

        let identifier = UUID().uuidString
        let stagedApp = parent.appendingPathComponent(".Glim-update-\(identifier).app")
        let backupApp = parent.appendingPathComponent(".Glim-backup-\(identifier).app")
        try FileManager.default.copyItem(at: newApp, to: stagedApp)
        do {
            try launchReplacement(current: currentApp, staged: stagedApp, backup: backupApp)
        } catch {
            try? FileManager.default.removeItem(at: stagedApp)
            throw error
        }
        try? FileManager.default.removeItem(at: directory)
        NSApp.terminate(nil)
    }

    nonisolated static func checksum(in data: Data, for archiveName: String) -> String? {
        let parts = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
        guard parts.count == 2, parts[1] == archiveName,
              parts[0].count == 64,
              parts[0].allSatisfy({ $0.isHexDigit }) else { return nil }
        return parts[0].lowercased()
    }

    private func launchReplacement(current: URL, staged: URL, backup: URL) throws {
        let script = """
        #!/bin/sh
        while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 1; done
        if /bin/mv \(quote(current.path)) \(quote(backup.path)); then
          if /bin/mv \(quote(staged.path)) \(quote(current.path)); then
            /usr/bin/open \(quote(current.path))
            /bin/rm -rf \(quote(backup.path))
          else
            /bin/mv \(quote(backup.path)) \(quote(current.path))
            /usr/bin/open \(quote(current.path))
          fi
        fi
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script]
        try process.run()
    }

    private func run(_ executable: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw UpdateError.invalidApp }
    }

    private var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    private func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

private enum UpdateError: LocalizedError {
    case invalidRelease, invalidChecksum, downloadFailed, invalidApp, unwritableDestination

    var errorDescription: String? {
        switch self {
        case .invalidRelease: "The GitHub release is missing required files."
        case .invalidChecksum: "The download did not match its SHA-256 checksum."
        case .downloadFailed: "The download failed."
        case .invalidApp: "The downloaded app could not be verified."
        case .unwritableDestination: "Glim cannot write to its current Applications folder."
        }
    }
}
