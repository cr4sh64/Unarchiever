import Foundation

enum ExtractError: LocalizedError {
    case passwordNeeded
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .passwordNeeded: return "Mot de passe requis ou incorrect."
        case .failed(let message): return message
        }
    }
}

final class Extractor {
    let sevenZip: URL
    private let lock = NSLock()
    private var process: Process?
    private var staging: URL?

    init(sevenZip: URL) { self.sevenZip = sevenZip }

    /// Extrait à côté de l'archive, dans un nouveau dossier ; n'écrase jamais rien.
    func extract(_ archive: URL, password: String? = nil) throws -> URL {
        let fm = FileManager.default
        let parent = archive.deletingLastPathComponent()
        let tmp = parent.appendingPathComponent(".unarchiever-\(UUID().uuidString)")
        do {
            try fm.createDirectory(at: tmp, withIntermediateDirectories: false)
        } catch {
            throw ExtractError.failed("Impossible d'écrire dans « \(parent.lastPathComponent) » : \(error.localizedDescription)")
        }
        lock.withLock { staging = tmp }
        defer {
            try? fm.removeItem(at: tmp)
            lock.withLock { staging = nil }
        }

        try run(archive, into: tmp, password: password)

        // .tar.gz, .tgz… : 7zz ne retire que la compression, le .tar reste à ouvrir.
        let compressed = ["gz", "tgz", "bz2", "tbz", "tbz2", "xz", "txz", "zst", "tzst", "z", "lzma"]
        let items = try fm.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil)
        if items.count == 1, items[0].pathExtension.lowercased() == "tar",
           compressed.contains(archive.pathExtension.lowercased()) {
            let tar = tmp.appendingPathComponent("\(UUID().uuidString).tar")
            try fm.moveItem(at: items[0], to: tar) // nom unique : ne peut heurter le contenu du tar
            try run(tar, into: tmp, password: nil)
            try fm.removeItem(at: tar)
        }

        propagateQuarantine(from: archive, to: tmp)
        let destination = Self.freeURL(in: parent, name: Self.baseName(of: archive))
        try fm.moveItem(at: tmp, to: destination)
        return destination
    }

    /// À la fermeture de l'app : arrête 7zz et retire le dossier temporaire.
    func abort() {
        let (running, tmp) = lock.withLock { (process, staging) }
        if let running, running.isRunning {
            running.terminate()
            running.waitUntilExit()
        }
        if let tmp { try? FileManager.default.removeItem(at: tmp) }
    }

    private func run(_ archive: URL, into directory: URL, password: String?) throws {
        let p = Process()
        p.executableURL = sevenZip
        // -spd : pas de jokers, un nom contenant * ou ? reste littéral.
        p.arguments = ["x", "-y", "-spd", "-bso0", "-bsp0", "-o" + directory.path, "--", archive.path]
        let output = Pipe()
        p.standardOutput = output
        p.standardError = output
        if let password {
            // Par stdin et non -p : les arguments sont visibles de tous dans `ps`.
            let input = Pipe()
            input.fileHandleForWriting.write(Data((password + "\n").utf8))
            try input.fileHandleForWriting.close()
            p.standardInput = input
        } else {
            p.standardInput = FileHandle.nullDevice
        }
        try p.run()
        lock.withLock { process = p }
        let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        p.waitUntilExit()
        lock.withLock { process = nil }

        if p.terminationStatus == 0 { return }
        // Sans mot de passe, 7zz tente de le lire sur stdin et rend 255.
        if text.contains("Wrong password") || (password == nil && p.terminationStatus == 255) {
            throw ExtractError.passwordNeeded
        }
        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        throw ExtractError.failed(lines.filter { !$0.isEmpty }.prefix(4).joined(separator: "\n"))
    }

    static func baseName(of archive: URL) -> String {
        var url = archive.deletingPathExtension()
        // foo.tar.gz → foo ; foo.7z.001 → foo
        if ["tar", "7z", "zip"].contains(url.pathExtension.lowercased()) { url.deletePathExtension() }
        return url.lastPathComponent
    }

    static func freeURL(in directory: URL, name: String) -> URL {
        var candidate = directory.appendingPathComponent(name)
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(name) \(n)")
            n += 1
        }
        return candidate
    }

    /// Sans cela, Gatekeeper ne vérifierait pas une app extraite d'une archive téléchargée.
    private func propagateQuarantine(from archive: URL, to directory: URL) {
        let name = "com.apple.quarantine"
        let size = getxattr(archive.path, name, nil, 0, 0, 0)
        guard size > 0 else { return }
        var value = [UInt8](repeating: 0, count: size)
        guard getxattr(archive.path, name, &value, size, 0, 0) == size else { return }
        let files = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)
        for case let file as URL in files ?? .init() {
            if setxattr(file.path, name, value, size, 0, XATTR_NOFOLLOW) == 0 || errno != EACCES { continue }
            // Fichier en lecture seule : macOS refuse l'attribut, on ouvre l'écriture le temps de le poser.
            var info = stat()
            guard lstat(file.path, &info) == 0 else { continue }
            chmod(file.path, info.st_mode | S_IWUSR)
            setxattr(file.path, name, value, size, 0, XATTR_NOFOLLOW)
            chmod(file.path, info.st_mode)
        }
        setxattr(directory.path, name, value, size, 0, XATTR_NOFOLLOW)
    }
}
