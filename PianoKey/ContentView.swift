import Observation
import SwiftUI

struct ContentView: View {
    @Bindable var viewModel: PianoKeyViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PianoKey")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Control panel is loading...")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(viewModel.connectionDescription)
                .font(.headline)

            Button(viewModel.isListening ? "Stop Listening" : "Start Listening") {
                viewModel.toggleListening()
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 420)
    }
}
