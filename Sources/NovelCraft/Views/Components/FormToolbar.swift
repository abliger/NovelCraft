import SwiftUI

/// 通用表单工具栏修饰符，用于编辑/新建弹窗的取消、保存、删除按钮。
struct FormToolbar: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    
    var isSaveDisabled: Bool
    var onSave: () -> Void
    var onDelete: (() -> Void)?
    
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
                    .help("取消")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { onSave() }
                    .disabled(isSaveDisabled)
                    .help("保存")
            }
            if let onDelete {
                ToolbarItem(placement: .destructiveAction) {
                    Button("删除", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                    .help("删除")
                }
            }
        }
    }
}

extension View {
    /// 为表单弹窗添加标准工具栏（取消 / 保存 / 可选删除）。
    func formToolbar(
        isSaveDisabled: Bool,
        onSave: @escaping () -> Void,
        onDelete: (() -> Void)? = nil
    ) -> some View {
        modifier(FormToolbar(isSaveDisabled: isSaveDisabled, onSave: onSave, onDelete: onDelete))
    }
}
