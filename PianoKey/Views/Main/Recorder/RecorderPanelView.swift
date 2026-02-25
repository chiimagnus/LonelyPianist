import Observation
import SwiftUI

struct RecorderPanelView: View {
    @Bindable var viewModel: PianoKeyViewModel

    var body: some View {
        VStack(spacing: 0) {
            RecorderTransportBarView(viewModel: viewModel)
            Divider()

            HStack(spacing: 0) {
                RecorderLibraryView(viewModel: viewModel)
                    .frame(width: 230)

                Divider()

                VStack(spacing: 0) {
                    placeholderTimeline
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()
            RecorderStatusBarView(viewModel: viewModel)
        }
    }

    private var placeholderTimeline: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform.path.ecg.rectangle")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text("Piano Roll will appear here")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
}
