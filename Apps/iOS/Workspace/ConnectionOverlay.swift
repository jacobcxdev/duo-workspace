import SwiftUI
import DuoCore

struct ConnectionOverlay: View {
    let model: SessionModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if case .failed = model.state {
                    Image(systemName: "wifi.exclamationmark").font(.largeTitle)
                    Text(model.needsPairing ? "Pairing required" : "Connection interrupted").font(.title3.bold())
                    Text(model.message).font(.callout).foregroundStyle(.secondary)
                    if model.needsPairing {
                        Button("Back to Macs", systemImage: "lock.rotation", action: model.disconnect)
                            .buttonStyle(.borderedProminent).foregroundStyle(Color("OnAccent")).controlSize(.large)
                    } else {
                        Button("Reconnect", systemImage: "arrow.clockwise", action: model.reconnect)
                            .buttonStyle(.borderedProminent).foregroundStyle(Color("OnAccent")).controlSize(.large)
                    }
                } else {
                    ProgressView().controlSize(.large)
                    Text(model.message).font(.callout)
                    if model.awaitingApproval, let code = model.verificationCode {
                        Text(code).font(.system(.largeTitle, design: .monospaced).bold())
                            .accessibilityLabel("Verification code")
                            .accessibilityValue(code.map(String.init).joined(separator: ", "))
                            .accessibilityIdentifier("pairing.verificationCode")
                        Text("Approve on your Mac only if both codes match.").font(.footnote).foregroundStyle(.secondary)
                    }
                    if model.reconnectAttempt > 0 {
                        Text("Attempt \(model.reconnectAttempt) of 3").font(.caption).foregroundStyle(.secondary)
                        Button("Reconnect now", action: model.reconnect).buttonStyle(.bordered)
                    }
                }
            }
            .multilineTextAlignment(.center)
            .padding(24)
            .frame(maxWidth: 420)
            .frame(maxWidth: .infinity)
        }
        .defaultScrollAnchor(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.88))
        .accessibilityElement(children: .contain)
    }
}
