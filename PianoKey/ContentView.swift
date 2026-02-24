import Observation
import SwiftUI

struct ContentView: View {
    @Bindable var viewModel: PianoKeyViewModel

    var body: some View {
        ControlPanelView(viewModel: viewModel)
            .frame(minWidth: 540, minHeight: 720)
    }
}
