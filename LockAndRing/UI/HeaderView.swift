import SwiftUI

struct HeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Lock & Ring")
                .font(.system(size: 34, weight: .semibold, design: .rounded))

            Text("Real-time single-mic feedback for tuning, ring, roughness, and stability.")
                .foregroundStyle(.secondary)
        }
    }
}
