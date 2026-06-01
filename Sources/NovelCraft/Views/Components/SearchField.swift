import SwiftUI

/// 通用搜索输入框，带清除按钮。
struct SearchField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    var placeholder: String = "搜索..."

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .focused($isFocused)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(.tertiarySystemFill))
        .cornerRadius(8)
        .onAppear {
            // 避免窗口打开时自动聚焦到搜索框
            DispatchQueue.main.async {
                isFocused = false
            }
        }
    }
}
