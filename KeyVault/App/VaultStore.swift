import Foundation

/// Where the vault's SwiftData store lives.
///
/// Early builds used SwiftData's default location, `~/Library/Application Support/default.store`,
/// a file name any SwiftData app without a sandbox can share. The vault now has its own file,
/// `Application Support/KeyVault/KeyVault.store` (inside the app's container when sandboxed).
enum VaultStore {
    struct Location {
        let url: URL
        /// True when this launch copied a legacy `default.store` into place.
        let copiedLegacyStore: Bool
    }

    private static let sidecarSuffixes = ["", "-wal", "-shm"]

    static func prepare(fileManager fm: FileManager = .default) -> Location {
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = support.appendingPathComponent("KeyVault", isDirectory: true)
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("KeyVault.store")

        // One-time copy of a vault from the legacy location. Copy, never move: the file may
        // belong to another app. Only attempted when this Mac already has a KeyVault key.
        let legacy = support.appendingPathComponent("default.store")
        guard !fm.fileExists(atPath: url.path),
              fm.fileExists(atPath: legacy.path),
              KeychainManager.keyExists() else {
            return Location(url: url, copiedLegacyStore: false)
        }
        for suffix in sidecarSuffixes {
            let from = URL(fileURLWithPath: legacy.path + suffix)
            guard fm.fileExists(atPath: from.path) else { continue }
            try? fm.copyItem(at: from, to: URL(fileURLWithPath: url.path + suffix))
        }
        return Location(url: url, copiedLegacyStore: fm.fileExists(atPath: url.path))
    }

    static func removeStore(at url: URL, fileManager fm: FileManager = .default) {
        for suffix in sidecarSuffixes {
            try? fm.removeItem(at: URL(fileURLWithPath: url.path + suffix))
        }
    }
}
