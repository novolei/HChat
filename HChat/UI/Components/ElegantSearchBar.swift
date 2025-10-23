import SwiftUI

struct ElegantSearchBar: View {
  @Binding var text: String
  @FocusState private var isFocused: Bool

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 18, weight: .semibold))
        .foregroundColor(isFocused ? Color(hex: "6F4BF5") : ModernTheme.tertiaryText)
        .padding(.leading, 6)

      TextField("搜索消息或用户", text: $text)
        .textCase(.none)
        .textInputAutocapitalization(.never)
        .disableAutocorrection(true)
        .font(.system(size: 16, weight: .medium, design: .rounded))
        .focused($isFocused)

      if !text.isEmpty {
        Button {
          withAnimation(.easeOut(duration: 0.15)) {
            text = ""
          }
          HapticManager.selection()
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Color.white, Color(hex: "6F4BF5"))
        }
        .buttonStyle(.plain)
        .transition(.scale.combined(with: .opacity))
      }
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 14)
    .background(
      RoundedRectangle(cornerRadius: 26, style: .continuous)
        .fill(
          LinearGradient(
            colors: [Color.white.opacity(0.95), Color.white.opacity(0.75)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
    )
    .overlay(
      RoundedRectangle(cornerRadius: 26, style: .continuous)
        .stroke(
          LinearGradient(
            colors: [Color(hex: "C8B6FF").opacity(isFocused ? 0.9 : 0.4), Color(hex: "90F7EC").opacity(isFocused ? 0.9 : 0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: isFocused ? 1.6 : 1
        )
    )
    .shadow(color: Color.black.opacity(0.07), radius: 16, y: 10)
    .animation(.easeInOut(duration: 0.2), value: isFocused)
  }
}

#Preview {
//  StatefulPreviewWrapper("") { ElegantSearchBar(text: $0) }
}
