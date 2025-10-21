//
//  MessageRenderer.swift
//  HChat
//
//  Created by Ryan Liu on 2025/10/21.
//

import SwiftUI

struct RenderOptions {
    var showTimestamp: Bool = true
    var mentionKeyword: String? = nil  // 当前昵称
}

enum MessageFragment: Hashable {
    case text(String)
    case inlineCode(String)
    case codeBlock(String)
    case link(URL)
    case mention(String)
}

struct MessageRenderer {
    static func splitToFragments(_ text: String) -> [MessageFragment] {
        // 粗略实现：```code``` 代码块；`code` 内联；URL 自动；@提及 自动
        var fragments: [MessageFragment] = []
        let codeBlockRegex = try! NSRegularExpression(pattern: "```([\\s\\S]*?)```", options: [])
        let inlineCodeRegex = try! NSRegularExpression(pattern: "`([^`]+)`", options: [])
        let urlDetector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

        // 先提取代码块，替换为占位，最后再展开
        var working = text
        var blocks: [(range: NSRange, content: String)] = []
        codeBlockRegex.enumerateMatches(in: working, options: [], range: NSRange(location: 0, length: (working as NSString).length)) { m, _, _ in
            if let m, m.numberOfRanges >= 2 {
                let r = m.range(at: 0)
                let c = (working as NSString).substring(with: m.range(at: 1))
                blocks.append((r, c))
            }
        }
        // 从后往前替换，避免 range 失效
        for b in blocks.reversed() {
            working = (working as NSString).replacingCharacters(in: b.range, with: "\u{FFFC}")
        }

        func pushText(_ s: String) {
            guard !s.isEmpty else { return }
            let ns = s as NSString
            var last = 0
            // 链接/内联代码/提及
            let mentions = try! NSRegularExpression(pattern: "@[A-Za-z0-9_\\-\\.]+")
            let inlineMatches = inlineCodeRegex.matches(in: s, options: [], range: NSRange(location: 0, length: ns.length))
            let urlMatches = urlDetector.matches(in: s, options: [], range: NSRange(location: 0, length: ns.length))
            let mentionMatches = mentions.matches(in: s, options: [], range: NSRange(location: 0, length: ns.length))
            let all = (inlineMatches.map { ($0.range, "inline") } +
                       urlMatches.map { ($0.range, "url") } +
                       mentionMatches.map { ($0.range, "mention") })
                .sorted { $0.0.location < $1.0.location }
            for (r, kind) in all {
                if r.location > last {
                    fragments.append(.text(ns.substring(with: NSRange(location: last, length: r.location - last))))
                }
                let piece = ns.substring(with: r)
                switch kind {
                case "inline":
                    let inner = (try? inlineCodeRegex.firstMatch(in: piece, range: NSRange(location: 0, length: (piece as NSString).length)).flatMap {
                        (piece as NSString).substring(with: $0.range(at: 1))
                    }) ?? piece
                    fragments.append(.inlineCode(inner))
                case "url":
                    if let u = URL(string: piece) { fragments.append(.link(u)) }
                    else { fragments.append(.text(piece)) }
                default:
                    fragments.append(.mention(piece))
                }
                last = r.location + r.length
            }
            if last < ns.length {
                fragments.append(.text(ns.substring(from: last)))
            }
        }

        // 把占位符拆回代码块
        for chunk in working.split(separator: "\u{FFFC}", omittingEmptySubsequences: false) {
            pushText(String(chunk))
            if !blocks.isEmpty {
                let b = blocks.removeFirst()
                fragments.append(.codeBlock(b.content))
            }
        }
        return fragments
    }
}

extension View {
    func codeStyleInline() -> some View {
        self.font(.system(.body, design: .monospaced))
            .padding(.vertical, 1).padding(.horizontal, 4)
            .background(Color.primary.opacity(0.08))
            .cornerRadius(4)
    }
    func codeStyleBlock() -> some View {
        self.font(.system(.callout, design: .monospaced))
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.06))
            .cornerRadius(6)
    }
}
