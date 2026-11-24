import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text(L10n.helloWorld)
            Text(BuildInfo.label)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
