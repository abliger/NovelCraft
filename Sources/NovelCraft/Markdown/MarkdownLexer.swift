import Foundation

// MARK: - Token 定义

/// Markdown 词法单元
enum MDToken: Equatable {
    case text(String)
    case hashes(Int)
    case asterisks(Int)
    case underscores(Int)
    case tildes(Int)
    case backticks(Int)
    case openBracket        // [
    case closeBracket       // ]
    case openParen          // (
    case closeParen         // )
    case openDoubleParen    // ((
    case closeDoubleParen   // ))
    case openDoubleBrace    // {{
    case closeDoubleBrace   // }}
    case bang               // !
    case gt                 // >
    case minus              // -
    case plus               // +
    case dot                // .
    case whitespace(String)
    case newline
    case eof
}

// MARK: - Lexer

/// Markdown 词法分析器
///
/// 将输入字符流转换为 Token 序列，为后续语法分析提供基础。
/// 连续的特殊字符被合并为单个 Token（如 `##` -> `.hashes(2)`），
/// 普通文本则被聚合为 `.text` Token。
struct MarkdownLexer {
    private let input: String
    private var index: String.Index
    private var isLineStart: Bool = true

    init(input: String) {
        self.input = input
        self.index = input.startIndex
    }

    /// 执行完整的词法分析，返回 Token 序列（末尾包含 `.eof`）
    func tokenize() -> [MDToken] {
        var lexer = self
        var tokens: [MDToken] = []
        while true {
            let token = lexer.nextToken()
            tokens.append(token)
            if case .eof = token { break }
        }
        return tokens
    }

    // MARK: - 私有方法

    private mutating func nextToken() -> MDToken {
        guard index < input.endIndex else { return .eof }

        // 换行符
        let char = input[index]
        if char == "\n" || char == "\r\n" {
            advance()
            if char == "\r", index < input.endIndex, input[index] == "\n" {
                advance() // \r\n
            }
            isLineStart = true
            return .newline
        }

        // 行首空白优先处理
        if isLineStart {
            if char == " " || char == "\t" {
                var ws = ""
                while index < input.endIndex,
                      input[index] == " " || input[index] == "\t" {
                    ws.append(input[index])
                    advance()
                }
                isLineStart = false
                return .whitespace(ws)
            }
            isLineStart = false
        }

        // 特殊符号
        switch char {
        case "#":  return .hashes(consumeRepeating(Swift.Character("#")))
        case "*":  return .asterisks(consumeRepeating(Swift.Character("*")))
        case "_":  return .underscores(consumeRepeating(Swift.Character("_")))
        case "~":  return .tildes(consumeRepeating(Swift.Character("~")))
        case "`":  return .backticks(consumeRepeating(Swift.Character("`")))
        case "[":  advance(); return .openBracket
        case "]":  advance(); return .closeBracket
        case "(":
            advance()
            if index < input.endIndex, input[index] == "(" {
                advance()
                return .openDoubleParen
            }
            return .openParen
        case ")":
            advance()
            if index < input.endIndex, input[index] == ")" {
                advance()
                return .closeDoubleParen
            }
            return .closeParen
        case "{":
            advance()
            if index < input.endIndex, input[index] == "{" {
                advance()
                return .openDoubleBrace
            }
            return .text("{")
        case "}":
            advance()
            if index < input.endIndex, input[index] == "}" {
                advance()
                return .closeDoubleBrace
            }
            return .text("}")
        case "!":  advance(); return .bang
        case ">":  advance(); return .gt
        case "-":  advance(); return .minus
        case "+":  advance(); return .plus
        case ".":  advance(); return .dot
        default:   break
        }

        // 普通文本（吞到下一个特殊符号或换行为止）
        var text = ""
        while index < input.endIndex {
            let c = input[index]
            if c == "\n" || c == "\r" || isSpecial(c as Swift.Character) { break }
            text.append(c)
            advance()
        }
        return .text(text)
    }

    private mutating func advance() {
        if index < input.endIndex {
            index = input.index(after: index)
        }
    }

    /// 连续吞入相同字符，返回个数（调用前已确认首字符匹配）
    private mutating func consumeRepeating(_ char: Swift.Character) -> Int {
        var count = 1
        advance()
        while index < input.endIndex, input[index] == (char as Swift.Character) {
            count += 1
            advance()
        }
        return count
    }

    /// 判断是否为 Markdown 特殊符号（不含空白与换行）
    private func isSpecial(_ char: Swift.Character) -> Bool {
        "#*_`[]()!>-+~.{}\r\n".contains(char as Swift.Character)
    }
}
