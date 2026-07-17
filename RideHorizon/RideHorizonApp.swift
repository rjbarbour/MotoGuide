//
//  RideHorizonApp.swift
//  RideHorizon
//
//  Created by Robert Barbour on 10/07/2024.
//

import SwiftUI

@main
struct RideHorizonApp: App {
    @StateObject private var privateBetaAccess = PrivateBetaAccessModel()

    init() {
        #if DEBUG
        DebugProxyTokenImporter.importFromEnvironment()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if privateBetaAccess.hasCredential {
                    ContentView()
                } else {
                    PrivateBetaAccessView(model: privateBetaAccess)
                }
            }
            .onAppear {
                privateBetaAccess.refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .rideHorizonCredentialInvalidated)) { _ in
                privateBetaAccess.refresh()
            }
        }
    }
}

@MainActor
final class PrivateBetaAccessModel: ObservableObject {
    @Published var inviteCode = ""
    @Published private(set) var hasCredential = KeychainCredentialLoader.loadRideHorizonProxyToken() != nil
    @Published private(set) var isWorking = false
    @Published private(set) var errorMessage: String?

    private let provisioner: ProxyCredentialProvisioner

    init(provisioner: ProxyCredentialProvisioner = ProxyCredentialProvisioner()) {
        self.provisioner = provisioner
    }

    func refresh() {
        hasCredential = KeychainCredentialLoader.loadRideHorizonProxyToken() != nil
    }

    func redeem() async {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await provisioner.redeem(inviteCode: inviteCode)
            inviteCode = ""
            hasCredential = true
        } catch let error as CredentialProvisioningError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "RideHorizon could not complete setup. Please try again."
        }
    }
}

struct PrivateBetaAccessView: View {
    @ObservedObject var model: PrivateBetaAccessModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color.blue.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "road.lanes")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(.white)
                Text(ProductIdentity.displayName)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                Text("Private Beta Access")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))
                Text("Enter the one-time invite code supplied by Digital Mercenaries.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.75))

                SecureField("Invite code", text: $model.inviteCode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.oneTimeCode)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("Private beta invite code")

                if let errorMessage = model.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(Color.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await model.redeem() }
                } label: {
                    if model.isWorking {
                        ProgressView().tint(.white)
                    } else {
                        Text("Activate RideHorizon")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(model.isWorking || model.inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()
            }
            .padding(28)
            .frame(maxWidth: 520)
        }
    }
}
