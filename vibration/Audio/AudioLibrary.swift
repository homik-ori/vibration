import Foundation
import AVFoundation

/// Owns the app's private audio folder (`Documents/Imported`).
///
/// Files picked in the document picker are copied here while the security
/// scoped resource is open, so playback later never depends on the source
/// provider still being reachable.
enum AudioLibrary {
    static let supportedExtensions: Set<String> = [
        "mp3", "wav", "m4a", "flac", "aac", "aif", "aiff", "caf", "mp4", "m4b"
    ]

    static var directory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("Imported", isDirectory: true)
    }

    @discardableResult
    static func ensureDirectory() -> URL {
        let url = directory
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
        return url
    }

    /// Copies a picked file into the sandbox and returns the local URL.
    static func importFile(from source: URL) throws -> URL {
        let scoped = source.startAccessingSecurityScopedResource()
        defer {
            if scoped { source.stopAccessingSecurityScopedResource() }
        }

        ensureDirectory()

        let originalName = source.lastPathComponent
        let base = (originalName as NSString).deletingPathExtension
        let ext = (originalName as NSString).pathExtension
        var destination = directory.appendingPathComponent(originalName)
        var counter = 2
        while FileManager.default.fileExists(atPath: destination.path) {
            let name = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
            destination = directory.appendingPathComponent(name)
            counter += 1
        }

        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    /// All readable tracks in the private folder, newest metadata included.
    static func tracks() -> [Track] {
        ensureDirectory()
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )) ?? []

        return contents
            .filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
            .map { makeTrack(for: $0) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    static func makeTrack(for url: URL) -> Track {
        var duration: Double = 0
        if let file = try? AVAudioFile(forReading: url) {
            let rate = file.processingFormat.sampleRate
            if rate > 0 {
                duration = Double(file.length) / rate
            }
        }
        return Track(
            id: url.path,
            url: url,
            title: url.deletingPathExtension().lastPathComponent,
            duration: duration
        )
    }

    static func delete(_ track: Track) {
        try? FileManager.default.removeItem(at: track.url)
    }
}
