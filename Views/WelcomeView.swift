import SwiftUI

struct WelcomeView: View {
    var onFinished: () -> Void

    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            // Black background to match the Rally logo
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Image("RallyLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 320)
                    .padding(.horizontal, 24)

                Text("RISE. RECORD. RESULT.")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .tracking(4)
                    .foregroundStyle(Color.rallyOrange)
            }
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.6)) {
                opacity = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                onFinished()
            }
        }
    }
}
