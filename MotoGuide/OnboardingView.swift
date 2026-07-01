import SwiftUI

struct OnboardingView: View {
    @ObservedObject var firstRunState: FirstRunState
    var onComplete: () -> Void

    @State private var page = 0

    private let pageCount = 3

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcomePage.tag(0)
                permissionsPage.tag(1)
                expectationsPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            VStack(spacing: 12) {
                if page < pageCount - 1 {
                    Button("Next", action: advance)
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                } else {
                    Button("Get Started", action: finish)
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                }

                if page > 0 {
                    Button("Back") {
                        page -= 1
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private var welcomePage: some View {
        onboardingPage(
            symbol: "speaker.wave.2.fill",
            title: "Place awareness for your ride",
            body: "MotoGuide speaks short place updates through your helmet headset. It works alongside your normal navigation app — it does not give turn-by-turn directions."
        )
    }

    private var permissionsPage: some View {
        onboardingPage(
            symbol: "location.fill",
            title: "Location and audio",
            body: "MotoGuide uses your location to announce towns and counties while you ride, even when the screen is off or another app is open. Connect your Bluetooth helmet headset so announcements play in your ear."
        )
    }

    private var expectationsPage: some View {
        onboardingPage(
            symbol: "map.fill",
            title: "What to expect",
            body: "You'll hear town and county names as you cross boundaries. Keep your nav app running. Use Quiet mode in Settings to mute speech without stopping location updates."
        )
    }

    private func onboardingPage(symbol: String, title: String, body: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: symbol)
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text(body)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
        .padding()
    }

    private func advance() {
        if page == 1 {
            firstRunState.markPermissionExplanationSeen()
        }
        page += 1
    }

    private func finish() {
        firstRunState.markPermissionExplanationSeen()
        firstRunState.completeOnboarding()
        onComplete()
    }
}
