import SwiftUI

struct OnboardingView: View {
    @ObservedObject var firstRunState: FirstRunState
    @ObservedObject var aiSharingConsent: AISharingConsentStore
    var onComplete: () -> Void

    @State private var page = 0
    @State private var showPrivacyNotice = false

    private let pageCount = 4

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcomePage.tag(0)
                permissionsPage.tag(1)
                aiSharingPage.tag(2)
                expectationsPage.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .overlay(alignment: .bottom) {
                pageIndicator
                    .padding(.bottom, 20)
            }

            VStack(spacing: 12) {
                if page == 2 {
                    Button("Allow AI features") {
                        aiSharingConsent.grant()
                        page += 1
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)

                    Button("Use on-device features only") {
                        aiSharingConsent.decline()
                        page += 1
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                } else if page < pageCount - 1 {
                    Button("Next", action: advance)
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                } else {
                    Button("Get Started", action: finish)
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                }

                Button("Back") {
                    if page > 0 {
                        page -= 1
                    }
                }
                .foregroundStyle(.secondary)
                .opacity(page > 0 ? 1 : 0)
                .disabled(page == 0)
                .accessibilityHidden(page == 0)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showPrivacyNotice) {
            PrivacyNoticeView()
        }
    }

    private var welcomePage: some View {
        onboardingPage(
            symbol: "speaker.wave.2.fill",
            title: "Place awareness for your ride",
            body: "\(ProductIdentity.displayName) speaks short place updates through your helmet headset. It works alongside your normal navigation app — it does not give turn-by-turn directions.",
            imageName: "OnboardingForest",
            photoCredit: "Photo: Dreamy Pixel · CC BY 4.0"
        )
    }

    private var permissionsPage: some View {
        onboardingPage(
            symbol: "location.fill",
            title: "Location and audio",
            body: "\(ProductIdentity.displayName) uses your location to announce towns and counties while you ride, even when the screen is off or another app is open. Connect your Bluetooth helmet headset so announcements play in your ear.",
            imageName: "OnboardingCoast",
            photoCredit: "Photo: Greenthumb331 · CC BY-SA 4.0"
        )
    }

    private var expectationsPage: some View {
        onboardingPage(
            symbol: "map.fill",
            title: "Welcome to Italy",
            body: "This is the legendary Stelvio Pass, 2,758 metres above sea level — one of the highest paved mountain passes in the Alps.",
            imageName: "OnboardingStelvio",
            photoCredit: "Photo: Fuchs Robert · CC BY 3.0"
        )
    }

    private var aiSharingPage: some View {
        ZStack {
            Image("OnboardingAlps")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            LinearGradient(
                colors: [.black.opacity(0.74), .black.opacity(0.48), .black.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                brandMark
                Spacer()
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
                Text("Choose how facts are made")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("If you allow AI features, RideHorizon sends the current town, county, region or country and your optional fact preferences to OpenAI. If you choose Premium Voice, announcement text is sent to ElevenLabs. Precise GPS coordinates are not sent to either provider.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.96))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Text("You can decline and keep place-name announcements with Apple Voice. You can change this choice in Settings.")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("Read privacy details") {
                    showPrivacyNotice = true
                }
                .buttonStyle(.bordered)
                .tint(.white)
                Spacer()
                Text("Photo: Royonx · CC0")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.78))
                    .padding(.bottom, 34)
            }
            .padding()
        }
    }

    private func onboardingPage(
        symbol: String,
        title: String,
        body: String,
        imageName: String,
        photoCredit: String
    ) -> some View {
        ZStack {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            LinearGradient(colors: [.black.opacity(0.66), .black.opacity(0.22), .black.opacity(0.76)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 24) {
                brandMark
                Spacer()
                Image(systemName: symbol)
                    .font(.system(size: 56))
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .shadow(radius: 3)
                Text(body)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.94))
                    .multilineTextAlignment(.center)
                    .shadow(radius: 3)
                    .padding(.horizontal)
                Spacer()
                Text(photoCredit)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.78))
                    .shadow(radius: 2)
                    .accessibilityLabel(photoCredit.replacingOccurrences(of: "·", with: ","))
                    .padding(.bottom, 34)
            }
            .padding()
        }
    }

    private var brandMark: some View {
        HStack(spacing: 14) {
            Image(systemName: "road.lanes")
                .font(.system(size: 52, weight: .semibold))
            Text(ProductIdentity.displayName)
                .font(.title.bold())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.black.opacity(0.3), in: Capsule())
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Circle()
                    .fill(index == page ? Color.white : Color.white.opacity(0.42))
                    .frame(width: index == page ? 9 : 7, height: index == page ? 9 : 7)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.32), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Onboarding page \(page + 1) of \(pageCount)")
    }

    private func advance() {
        if page == 1 {
            firstRunState.markPermissionExplanationSeen()
        }
        page += 1
    }

    private func finish() {
        guard aiSharingConsent.decision != .notDetermined else {
            page = 2
            return
        }
        firstRunState.markPermissionExplanationSeen()
        firstRunState.completeOnboarding()
        onComplete()
    }
}

struct AISharingChoiceView: View {
    @ObservedObject var consent: AISharingConsentStore
    var onComplete: () -> Void

    @State private var showPrivacyNotice = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)

                    Text("Choose how RideHorizon uses third-party AI")
                        .font(.title.bold())

                    Text("AI facts send the current town, county, region or country and your optional fact preferences to OpenAI. Premium Voice sends announcement text to ElevenLabs. RideHorizon does not send precise GPS coordinates to either provider.")

                    Text("You can decline and continue with place-name announcements and Apple Voice. You can change or withdraw this choice later in Settings.")

                    Button("Read privacy details") {
                        showPrivacyNotice = true
                    }

                    Button("Allow AI features") {
                        consent.grant()
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)

                    Button("Use on-device features only") {
                        consent.decline()
                        onComplete()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                }
                .padding(24)
            }
            .navigationTitle("Privacy choice")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
        .sheet(isPresented: $showPrivacyNotice) {
            PrivacyNoticeView()
        }
    }
}

struct PrivacyNoticeView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("On your iPhone") {
                    Text("RideHorizon uses precise location to identify places, but does not send latitude or longitude to the RideHorizon fact or speech proxy. Ride history stays in memory for the current session. Settings and generated facts are stored locally until cleared; cached facts expire after 30 days.")
                }

                Section("Optional AI features") {
                    Text("With your permission, OpenAI receives the announced place hierarchy and optional rider fact preferences to generate a short fact. ElevenLabs receives announcement text only when Premium Voice is selected. OpenAI may retain API inputs and outputs for up to 30 days unless lower-retention controls apply. RideHorizon asks ElevenLabs not to log the text or generated audio; availability depends on the production account configuration.")
                }

                Section("Service operation") {
                    Text("The RideHorizon proxy receives a random installation identifier and limited request information for access control, abuse prevention and reliability. Provider keys are not stored in the app. Technical logs are designed not to contain coordinates, place content, rider text, device identifiers or credentials.")
                }

                Section("Your controls") {
                    Text("You can withdraw AI permission, use Apple Voice, clear local data, remove location permission in iOS Settings, or stop ride tracking. Clearing local data also removes this installation's beta access credential and requires setup again.")
                }

                Section("Not tracking") {
                    Text("RideHorizon does not use advertising, data brokers or cross-app tracking.")
                }

                Section("Full policy") {
                    Link(
                        "Read the RideHorizon Privacy Policy",
                        destination: URL(string: "https://ridehorizon-invite-beta.rjbarbour.chatgpt.site/privacy")!
                    )
                }
            }
            .navigationTitle("Privacy notice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}
