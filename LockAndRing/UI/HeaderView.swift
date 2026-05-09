import SwiftUI

struct HeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Lock & Ring")
                .font(.system(size: 34, weight: .semibold, design: .rounded))

            Text("Single-mic ensemble feedback for harmonic lock, ring, roughness, and stability.")
                .foregroundStyle(.secondary)
        }
    }
}
