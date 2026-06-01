import Foundation
import SwiftUI

/// 写作提示插件。
///
/// 在编辑器工具栏提供一个「写作提示」按钮，点击后随机插入一条写作提示到当前章节末尾。
/// 内置多个分类的提示语料库。
@MainActor
final class WritingPromptPlugin: NovelCraftPlugin, EditorToolbarContributor {
    let id = "com.novelcraft.plugins.writingprompt"
    let name = "写作提示"
    let description = "提供随机写作提示、情节转折建议与场景描写灵感，帮助克服写作瓶颈。"
    let version = "1.0.0"
    let author = "NovelCraft 官方"
    var isEnabled: Bool = true
    
    private var context: PluginContext?
    private let prompts: [PromptCategory] = [
        PromptCategory(
            name: "情节转折",
            prompts: [
                "主角突然收到一封来自过去的信，里面的内容彻底颠覆了他对某件事的认知。",
                "一直被认为是盟友的角色，在关键时刻露出了真实目的。",
                "主角发现手中掌握的证据其实是敌人故意布置的陷阱。",
                "一场看似偶然的相遇，实际上是某人精心策划多年的安排。",
                "主角最信任的人，竟然一直在暗中记录他的一举一动。",
            ]
        ),
        PromptCategory(
            name: "场景描写",
            prompts: [
                "描写一个雨夜中的古老书房，空气中弥漫着旧纸张和松节油的气味。",
                "清晨的第一缕阳光透过斑驳的窗棂，在地板上投下细碎的光影。",
                "熙熙攘攘的集市上，各种声音交织在一起，主角在人群中捕捉到了一个熟悉的声音。",
                "深秋的枫叶铺满了整条石板路，每一步踩下去都会发出细微的碎裂声。",
                "月光洒在结冰的湖面上，远处的山峦只剩下黑色的剪影。",
            ]
        ),
        PromptCategory(
            name: "人物刻画",
            prompts: [
                "描写一个总是微笑的人，但他/她的眼神里藏着说不出的疲惫。",
                "一个看似粗鲁的陌生人，在不经意间展现出的温柔细节。",
                "主角注意到某个配角总是下意识地摩挲手腕上的一道旧伤疤。",
                "两个人明明意见相左，却在某个瞬间露出了完全一致的表情。",
                "一个平日里话不多的人，在谈论某个话题时突然变得滔滔不绝。",
            ]
        ),
        PromptCategory(
            name: "对话技巧",
            prompts: [
                "写一段对话，两个人在讨论天气，但实际上在传递某种暗号。",
                "让两个人用礼貌的措辞进行一场充满火药味的交锋。",
                "一段对话中，一个人不断打断另一个人，但每次打断的内容都透露出更多的信息。",
                "描写一次沉默——有时候，不说出口的话比说出口的话更有分量。",
                "让主角说出一句他/她以为只是玩笑的话，却意外触动了对方的痛处。",
            ]
        ),
        PromptCategory(
            name: "氛围营造",
            prompts: [
                "用环境中的微小声响来制造一种不安的紧张感。",
                "描写一个喜庆场合中，某个人格格不入的细微表现。",
                "让温暖的场景因为一个小小的细节而变得令人不安。",
                "通过描述时间的流逝（沙漏、钟表、天色变化）来渲染焦虑情绪。",
                "用一个反复出现的意象（如某种气味、声音或颜色）来暗示人物的心理变化。",
            ]
        ),
    ]
    
    func setup(context: PluginContext) {
        self.context = context
    }
    
    func teardown() {
        context = nil
    }
    
    var toolbarItems: [PluginToolbarItem] {
        [
            PluginToolbarItem(
                id: "\(id).prompt",
                icon: "lightbulb.max",
                tooltip: "随机写作提示"
            ) { [weak self] in
                self?.insertRandomPrompt()
            }
        ]
    }
    
    private func insertRandomPrompt() {
        guard let context = context else { return }
        guard let chapter = context.selectedChapter else { return }
        
        let category = prompts.randomElement()!
        let prompt = category.prompts.randomElement()!
        let formatted = "\n> 💡 **【\(category.name)】** \(prompt)\n"
        
        chapter.content += formatted
        context.save()
    }
}

private struct PromptCategory {
    let name: String
    let prompts: [String]
}
