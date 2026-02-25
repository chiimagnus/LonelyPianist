import Observation
import SwiftUI

struct ControlPanelView: View {
    @Bindable var viewModel: PianoKeyViewModel

    var body: some View {
        VStack(spacing: 12) {
            Picker("Panel", selection: $viewModel.selectedMainPanelTab) {
                ForEach(PianoKeyViewModel.MainPanelTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            switch viewModel.selectedMainPanelTab {
            case .mappings:
                mappingsView
            case .recorder:
                recorderPlaceholderView
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var mappingsView: some View {
        ScrollView {
            VStack(spacing: 14) {
                StatusSectionView(viewModel: viewModel)
                ProfileSectionView(viewModel: viewModel)
                KeyboardMapSectionView(viewModel: viewModel)
                RulesEditorSectionView(viewModel: viewModel)
                RecentEventSectionView(viewModel: viewModel)
            }
            .padding(16)
        }
    }

    private var recorderPlaceholderView: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Recorder panel is being prepared...")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
