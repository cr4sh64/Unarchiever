import SwiftUI

let extractor = Extractor(sevenZip: Bundle.main.url(forAuxiliaryExecutable: "7zz")!)

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) { extractor.abort() }
}

@main
struct UnarchieverApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        Window("Unarchiever", id: "main") { DropView() }
            .windowResizability(.contentSize)
    }
}

// ObservableObject et non @State : avec le SDK 27, la macro @State exige Xcode complet.
final class DropState: ObservableObject {
    @Published var current: String?
    @Published var message = "Glissez une archive ici"
    @Published var targeted = false
}

struct DropView: View {
    @StateObject private var state = DropState()

    var body: some View {
        VStack(spacing: 14) {
            if let current = state.current {
                ProgressView()
                Text("Extraction de \(current)…").lineLimit(2).truncationMode(.middle)
            } else {
                Image(systemName: "archivebox")
                    .font(.system(size: 48))
                    .foregroundStyle(state.targeted ? Color.accentColor : .secondary)
                    .accessibilityHidden(true)
                Text(state.message).multilineTextAlignment(.center)
                Button("Choisir…", action: choose)
            }
        }
        .padding()
        .frame(width: 340, height: 240)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(state.targeted ? Color.accentColor : .secondary.opacity(0.5),
                              style: StrokeStyle(lineWidth: 2, dash: [7]))
        }
        .padding()
        .contentShape(Rectangle()) // toute la fenêtre accepte le dépôt, vide compris
        .dropDestination(for: URL.self) { urls, _ in start(urls) } isTargeted: { state.targeted = $0 }
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK { _ = start(panel.urls) }
    }

    private func start(_ urls: [URL]) -> Bool {
        let files = urls.filter(\.isFileURL)
        guard state.current == nil, !files.isEmpty else { return false }
        state.current = files[0].lastPathComponent // tout de suite : refuse un second dépôt simultané
        Task { await extractAll(files) }
        return true
    }

    @MainActor
    private func extractAll(_ files: [URL]) async {
        var done: [URL] = []
        var errors: [String] = []
        for file in files {
            state.current = file.lastPathComponent
            do {
                if let folder = try await extract(file) { done.append(folder) }
            } catch {
                errors.append("\(file.lastPathComponent) : \(error.localizedDescription)")
            }
        }
        state.current = nil
        state.message = done.isEmpty ? "Glissez une archive ici"
            : done.count == 1 ? "« \(done[0].lastPathComponent) » extrait" : "\(done.count) archives extraites"
        if !done.isEmpty { NSWorkspace.shared.activateFileViewerSelecting(done) }
        if !errors.isEmpty {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Extraction impossible"
            alert.informativeText = errors.joined(separator: "\n\n")
            alert.runModal()
        }
    }

    /// nil si l'utilisateur annule la saisie du mot de passe.
    @MainActor
    private func extract(_ file: URL) async throws -> URL? {
        var password: String?
        while true {
            let attempt = password
            do {
                return try await Task.detached { try extractor.extract(file, password: attempt) }.value
            } catch ExtractError.passwordNeeded {
                guard let typed = askPassword(for: file, retry: attempt != nil) else { return nil }
                password = typed
            }
        }
    }

    @MainActor
    private func askPassword(for file: URL, retry: Bool) -> String? {
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.setAccessibilityLabel("Mot de passe")
        let alert = NSAlert()
        alert.messageText = retry ? "Mot de passe incorrect" : "Archive protégée"
        alert.informativeText = "Mot de passe de « \(file.lastPathComponent) » :"
        alert.accessoryView = field
        alert.addButton(withTitle: "Extraire")
        alert.addButton(withTitle: "Annuler")
        alert.window.initialFirstResponder = field
        return alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil
    }
}
