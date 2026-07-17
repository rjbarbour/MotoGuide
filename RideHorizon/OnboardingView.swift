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
            .tabViewStyle(.page(indexDisplayMode: .never))
            .overlay(alignment: .bottom) {
                pageIndicator
                    .padding(.bottom, 20)
            }

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
        firstRunState.markPermissionExplanationSeen()
        firstRunState.completeOnboarding()
        onComplete()
    }
}
