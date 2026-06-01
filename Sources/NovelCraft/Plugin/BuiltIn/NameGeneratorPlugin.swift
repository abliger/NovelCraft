import Foundation
import SwiftUI

/// 人名生成器插件。
///
/// 在编辑器工具栏提供「生成人名」按钮，在侧边栏提供人名生成面板。
/// 支持中文姓名、西方姓名、奇幻风格的姓名生成。
@MainActor
final class NameGeneratorPlugin: NovelCraftPlugin, EditorToolbarContributor, SidebarPanelContributor {
    let id = "com.novelcraft.plugins.namegenerator"
    let name = "人名生成器"
    let description = "一键生成中文姓名、西方姓名与奇幻风格姓名，可直接插入到编辑器中。"
    let version = "1.0.0"
    let author = "NovelCraft 官方"
    var isEnabled: Bool = true
    
    private weak var context: PluginContext?
    
    // MARK: - 语料库
    
    private let chineseSurnames = [
        "李", "王", "张", "刘", "陈", "杨", "赵", "黄", "周", "吴",
        "徐", "孙", "胡", "朱", "高", "林", "何", "郭", "马", "罗",
        "梁", "宋", "郑", "谢", "韩", "唐", "冯", "于", "董", "萧",
        "程", "曹", "袁", "邓", "许", "傅", "沈", "曾", "彭", "吕",
    ]
    private let chineseMaleNames = [
        "伟", "强", "磊", "军", "洋", "勇", "杰", "涛", "超", "明",
        "辉", "刚", "建", "峰", "宇", "浩", "博", "文", "武", "志",
        "华", "东", "林", "云", "天", "风", "辰", "墨", "轩", "然",
        "清", "遥", "尘", "瑾", "翊", "宸", "珩", "琰", "珏", "珂",
    ]
    private let chineseFemaleNames = [
        "芳", "娜", "敏", "静", "丽", "艳", "娟", "霞", "秀", "玲",
        "婷", "雪", "梅", "莉", "倩", "瑶", "琪", "涵", "萱", "芷",
        "婉", "妍", "琳", "欣", "怡", "茹", "彤", "玥", "歆", "苒",
        "漾", "卿", "绾", "鸢", "璃", "洛", "笙", "染", "辞", "浅",
    ]
    private let chineseNeutralNames = [
        "安", "宁", "和", "平", "乐", "言", "思", "念", "初", "望",
        "知", "行", "书", "画", "音", "羽", "竹", "兰", "松", "柏",
        "青", "白", "玄", "素", "锦", "绣", "琴", "棋", "诗", "酒",
    ]
    
    private let westernFirstNames = [
        "James", "John", "Robert", "Michael", "William", "David", "Richard", "Joseph", "Thomas", "Charles",
        "Mary", "Patricia", "Jennifer", "Linda", "Elizabeth", "Barbara", "Susan", "Jessica", "Sarah", "Karen",
        "Arthur", "Edward", "George", "Henry", "Oliver", "Sebastian", "Theodore", "Vincent", "Wesley", "Zachary",
        "Amelia", "Charlotte", "Eleanor", "Florence", "Grace", "Harriet", "Isabella", "Juliet", "Katherine", "Margaret",
    ]
    private let westernLastNames = [
        "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", "Martinez",
        "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson", "Thomas", "Taylor", "Moore", "Jackson", "Martin",
        "Ashford", "Blackwood", "Caldwell", "Davenport", "Ellington", "Fairchild", "Garrison", "Harrington", "Kingsley", "Lockwood",
        "Montgomery", "Northwood", "Pennington", "Quincy", "Redford", "Shelton", "Thornfield", "Underwood", "Vance", "Waverly",
    ]
    
    private let fantasyPrefixes = [
        "Ael", "Thal", "Mor", "Syl", "Kal", "Ver", "Zar", "Lun", "Dra", "Nyx",
        "Eld", "Rhy", "Vor", "Xan", "Ysol", "Kael", "Fen", "Gor", "Il", "Oph",
    ]
    private let fantasySuffixes = [
        "dorin", "ian", "ara", "eth", "on", "iel", "ira", "os", "une", "ax",
        "indra", "ovar", "umas", "eris", "alon", "endil", "amir", "oth", "exus", "ael",
    ]
    private let fantasyTitles = [
        "", "the Wise", "the Brave", "Shadowbane", "Stormborn", "Dawnstrider",
        "Ironheart", "Moonwhisper", "Firebrand", "Frostward", "Starweaver",
    ]
    
    func setup(context: PluginContext) {
        self.context = context
    }
    
    func teardown() {
        context = nil
    }
    
    // MARK: - EditorToolbarContributor
    
    var toolbarItems: [PluginToolbarItem] {
        [
            PluginToolbarItem(
                id: "\(id).insertname",
                icon: "person.badge.plus",
                tooltip: "生成并插入人名"
            ) { [weak self] in
                self?.generateAndInsertName()
            }
        ]
    }
    
    // MARK: - SidebarPanelContributor
    
    var sidebarPanels: [PluginSidebarPanel] {
        [
            PluginSidebarPanel(
                id: "\(id).panel",
                title: "人名生成",
                icon: "person.fill.questionmark"
            ) { [weak self] in
                AnyView(NameGeneratorPanelView(plugin: self))
            }
        ]
    }
    
    // MARK: - 生成逻辑
    
    private func generateAndInsertName() {
        let name = generateName(style: .chinese)
        guard let chapter = context?.selectedChapter else { return }
        chapter.content += name
        context?.save()
    }
    
    func generateName(style: NameStyle) -> String {
        switch style {
        case .chinese:
            let surname = chineseSurnames.randomElement()!
            let roll = Int.random(in: 0...2)
            let namePart: String
            switch roll {
            case 0: namePart = chineseMaleNames.randomElement()!
            case 1: namePart = chineseFemaleNames.randomElement()!
            default: namePart = chineseNeutralNames.randomElement()!
            }
            if Bool.random() {
                let second = chineseNeutralNames.randomElement()!
                return surname + namePart + second
            }
            return surname + namePart
            
        case .western:
            let first = westernFirstNames.randomElement()!
            let last = westernLastNames.randomElement()!
            return "\(first) \(last)"
            
        case .fantasy:
            let prefix = fantasyPrefixes.randomElement()!
            let suffix = fantasySuffixes.randomElement()!
            let title = fantasyTitles.randomElement()!
            let base = prefix + suffix
            if title.isEmpty {
                return base
            }
            return "\(base) \(title)"
        }
    }
    
    func insertNameIntoChapter(_ name: String) {
        guard let chapter = context?.selectedChapter else { return }
        chapter.content += name
        context?.save()
    }
}

// MARK: - 面板视图

struct NameGeneratorPanelView: View {
    weak var plugin: NameGeneratorPlugin?
    
    @State private var selectedStyle: NameStyle = .chinese
    @State private var generatedName: String = ""
    
    var body: some View {
        VStack(spacing: 16) {
            Picker("风格", selection: $selectedStyle) {
                ForEach(NameStyle.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .pickerStyle(.segmented)
            
            Button {
                generatedName = plugin?.generateName(style: selectedStyle) ?? ""
            } label: {
                Label("生成人名", systemImage: "dice")
            }
            .buttonStyle(.borderedProminent)
            
            if !generatedName.isEmpty {
                VStack(spacing: 8) {
                    Text(generatedName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .textSelection(.enabled)
                    
                    HStack(spacing: 12) {
                        Button {
                            copyToClipboard(generatedName)
                        } label: {
                            Label("复制", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        
                        Button {
                            plugin?.insertNameIntoChapter(generatedName)
                        } label: {
                            Label("插入", systemImage: "text.insert")
                        }
                        .buttonStyle(.bordered)
                        .disabled(plugin == nil)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = text
        #endif
    }
}

enum NameStyle: String, CaseIterable, Identifiable {
    case chinese, western, fantasy
    
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .chinese: return "中文"
        case .western: return "西方"
        case .fantasy: return "奇幻"
        }
    }
}

#if canImport(UIKit)
import UIKit
#endif
