import DesignSystem
import Persistence
import SwiftData
import SwiftUI

/// The composition root: it owns the local store and hands it to the state and the scene.
@main
struct NuriApp: App {
    @State private var appState: AppState
    private let container: ModelContainer

    init() {
        let defaults: UserDefaults
        let inMemory: Bool
        #if DEBUG
        // UI tests start from an empty, throwaway store. Release builds ignore the argument.
        if ProcessInfo.processInfo.arguments.contains("-uiTestFreshState") {
            let suite = "nuri.uitest"
            UserDefaults().removePersistentDomain(forName: suite)
            defaults = UserDefaults(suiteName: suite) ?? .standard
            inMemory = true
        } else {
            defaults = .standard
            inMemory = false
        }
        #else
        defaults = .standard
        inMemory = false
        #endif

        let container = Self.makeContainer(inMemory: inMemory)
        self.container = container
        let consentLog: any ConsentLogging
        #if DEBUG
        // UI tests prove that a consent record that cannot be written is shown to the person. Release builds ignore the argument.
        consentLog = ProcessInfo.processInfo.arguments.contains("-uiTestConsentWriteFails")
            ? UnwritableConsentLog() : SwiftDataConsentLog(context: container.mainContext)
        #else
        consentLog = SwiftDataConsentLog(context: container.mainContext)
        #endif
        let state = AppState(
            defaults: defaults,
            consentLog: consentLog,
            profileExists: { (try? ProfileRepository(context: container.mainContext).exists()) ?? false }
        )
        #if DEBUG
        // UI tests that look at the profile at accessibility text sizes (where the consent switches sit below the fold) start
        // there, through the same consent call the consent screen makes. Release builds ignore the argument.
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTestFreshState"), arguments.contains("-uiTestSkipToProfile") {
            state.chooseGuest()
            try? state.recordConsent(adult: true, healthData: true, analytics: false)
        }
        #endif
        _appState = State(initialValue: state)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .tint(.nuriTint)
        }
        .modelContainer(container)
    }

    /// Health data lives in `Application Support/Nuri/Nuri.store`, readable only after the first unlock since boot.
    /// Without a store the app has nothing safe to fall back on (a silent in-memory store would lose the person's data).
    private static func makeContainer(inMemory: Bool) -> ModelContainer {
        do {
            if inMemory { return try NuriStore.makeContainer(inMemory: true) }
            let folder = try FileManager.default
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appending(path: "Nuri", directoryHint: .isDirectory)
            #if os(iOS)
            // Files created inside take this protection class.
            try FileManager.default.createDirectory(
                at: folder, withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
            #else
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            #endif
            return try NuriStore.makeContainer(url: folder.appending(path: "Nuri.store", directoryHint: .notDirectory))
        } catch {
            fatalError("Nuri could not open its local store: \(error)")
        }
    }
}

#if DEBUG
/// A consent history that always fails to write (UI tests only, see `-uiTestConsentWriteFails`).
@MainActor
private struct UnwritableConsentLog: ConsentLogging {
    struct WriteFailure: Error {}

    func append(_ event: ConsentEvent) throws { throw WriteFailure() }
    func events() throws -> [ConsentEvent] { [] }
}
#endif
