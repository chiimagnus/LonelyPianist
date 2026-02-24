import SwiftData
import SwiftUI

@main
@MainActor
struct PianoKeyApp: App {
    private let modelContainer: ModelContainer
    @State private var viewModel: PianoKeyViewModel

    init() {
        let schema = Schema([
            MappingProfileEntity.self
        ])

        do {
            modelContainer = try ModelContainer(for: schema)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }

        let repository = SwiftDataMappingProfileRepository(context: modelContainer.mainContext)
        let viewModel = PianoKeyViewModel(
            midiInputService: CoreMIDIInputService(),
            keyboardEventService: KeyboardEventService(),
            permissionService: AccessibilityPermissionService(),
            repository: repository,
            mappingEngine: DefaultMappingEngine(),
            shortcutService: ShortcutExecutionService()
        )

        viewModel.bootstrap()

        _viewModel = State(initialValue: viewModel)
    }

    var body: some Scene {
        MenuBarExtra("PianoKey", systemImage: "pianokeys") {
            MenuBarPanelView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

        Window("PianoKey", id: "control-panel") {
            ContentView(viewModel: viewModel)
        }
        .defaultSize(width: 560, height: 760)
        .windowResizability(.contentSize)
        .modelContainer(modelContainer)
    }
}
