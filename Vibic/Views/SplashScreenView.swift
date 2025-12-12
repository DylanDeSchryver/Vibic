import SwiftUI

struct SplashScreenView: View {
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color(red: 0.545, green: 0.361, blue: 0.965),
                         Color(red: 0.925, green: 0.286, blue: 0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Audio wave bars (subtle, in background)
            HStack(spacing: 12) {
                WaveBar(height: 60)
                WaveBar(height: 100)
                WaveBar(height: 140)
                WaveBar(height: 100)
                WaveBar(height: 60)
            }
            .opacity(0.3)
            
            // Icon and text
            VStack(spacing: 20) {
                Image("LaunchIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 150, height: 150)
                
                Text("Vibic")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}

struct WaveBar: View {
    let height: CGFloat
    
    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.925, green: 0.286, blue: 0.6).opacity(0.6),
                             Color(red: 0.545, green: 0.361, blue: 0.965).opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 28, height: height)
    }
}

#Preview {
    SplashScreenView()
}
