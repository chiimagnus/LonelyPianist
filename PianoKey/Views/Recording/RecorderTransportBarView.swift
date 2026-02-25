import Observation
import SwiftUI

struct RecorderTransportBarView: View {
    @Bindable var viewModel: PianoKeyViewModel

    @State private var renamingTakeID: UUID?
    @State private var renameDraft = ""

    var body: some View {
        HStack(spacing: 10) {
            Button {
                viewModel.startRecordingTake()
            } label: {
                Label("Rec", systemImage: "record.circle")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(!viewModel.canRecord)

            Button {
                viewModel.playSelectedTake()
            } label: {
                Label("Play", systemImage: "play.fill")
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.canPlay)

            Button {
                viewModel.stopTransport()
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.canStop)

            Spacer(minLength: 0)

            Picker(
                selection: selectionBinding,
                label: Label("Library", systemImage: "tray.full")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            ) {
                if viewModel.takes.isEmpty {
                    Text("No takes").tag(Optional<UUID>.none)
                } else {
                    ForEach(viewModel.takes) { take in
                        Text(take.name).tag(Optional(take.id))
                    }
                }
            }
            .pickerStyle(.menu)
            .disabled(viewModel.takes.isEmpty)

            Menu {
                if let selectedTake = viewModel.selectedTake {
                    Button("Rename") {
                        renamingTakeID = selectedTake.id
                        renameDraft = selectedTake.name
                    }

                    Divider()

                    Button("Delete", role: .destructive) {
                        viewModel.deleteTake(selectedTake.id)
                    }
                } else {
                    Text("No take selected")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .disabled(viewModel.selectedTake == nil)

            Text(modeText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(durationText)
                .font(.system(.body, design: .monospaced))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .alert("Rename Take", isPresented: renameAlertBinding) {
            TextField("Take name", text: $renameDraft)
            Button("Save") {
                guard let renamingTakeID else { return }
                viewModel.renameTake(renamingTakeID, to: renameDraft)
                self.renamingTakeID = nil
            }
            Button("Cancel", role: .cancel) {
                renamingTakeID = nil
            }
        }
    }

    private var renameAlertBinding: Binding<Bool> {
        Binding(
            get: { renamingTakeID != nil },
            set: { isPresented in
                if !isPresented {
                    renamingTakeID = nil
                }
            }
        )
    }

    private var selectionBinding: Binding<UUID?> {
        Binding(
            get: { viewModel.selectedTakeID },
            set: { newValue in
                guard let newValue else { return }
                viewModel.selectTake(newValue)
            }
        )
    }

    private var modeText: String {
        switch viewModel.recorderMode {
        case .idle:
            return "Idle"
        case .recording:
            return "Recording"
        case .playing:
            return "Playing"
        }
    }

    private var durationText: String {
        let seconds = Int(viewModel.selectedTake?.durationSec ?? 0)
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%02d:%02d", minutes, remainder)
    }
}
