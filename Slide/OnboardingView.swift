import SwiftUI

struct OnboardingView: View {
    @ObservedObject var manager: AccessibilityManager
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 60))
                .foregroundColor(.purple)
            
            Text("Welcome to Slide")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            
            Text("To enable smart window snapping, Slide needs Accessibility permissions to move and resize windows on your behalf.")
                .multilineTextAlignment(.center)
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button(action: {
                manager.promptForTrust()
                manager.openSystemPrefs()
            }) {
                Text("Grant Permission")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(LinearGradient(gradient: Gradient(colors: [Color.purple, Color.blue]), startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
        }
        .padding(40)
        .frame(width: 400, height: 350)
        .background(VisualEffectView().ignoresSafeArea())
    }
}

// Helper to get nice vibrancy
struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .hudWindow // Premium dark glass look
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

#Preview {
    OnboardingView(manager: AccessibilityManager())
}
