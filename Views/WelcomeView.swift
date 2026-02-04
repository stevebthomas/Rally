import SwiftUI

struct WelcomeView: View {
    var onFinished: () -> Void

    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image("RallyLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220)

                Text("RISE. RECORD. RESULT.")
                    .font(.system(size: 18, weight: .black, design: .default))
                    .tracking(3)
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
