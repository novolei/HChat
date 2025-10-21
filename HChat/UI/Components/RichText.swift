////
////  RichText.swift
////  HChat
////
////  Created by Ryan Liu on 2025/10/21.
////
//
//import SwiftUI
//import Foundation
//
//struct RichMessageText: View {
//    let message: ChatMessage
//    let myBaseNick: String
//
//    var body: some View {
//        if let att = message.attachment {
//            AttachmentCardView(attachment: att)
//        } else {
//            Text(build(message: message, myBaseNick: myBaseNick))
//                .font(HackTheme.monospacedBody)
//                .textSelection(.enabled)
//        }
//    }
//
//    private func build(message: ChatMessage, myBaseNick: String) -> AttributedString {
//        var text = message.plaintext
//        var isAction = false
//        if text.hasPrefix("/me ") {
//            isAction = true
//            text = "* \(message.senderNickname.hcBaseNick) " + text.dropFirst(4)
//        }
//
//        // 抽取 ```code``` 块
//        var codeBlocks: [(placeholder: String, content: String, lang: String?)] = []
//        var tmp = text
//        let reBlock = try! NSRegularExpression(pattern: "```(\\w+)?\\n([\\s\\S]*?)```")
//        let ns = tmp as NSString
//        for m in reBlock.matches(in: tmp, range: NSRange(location: 0, length: ns.length)).reversed() {
//            let lang = m.range(at: 1).location != NSNotFound ? ns.substring(with: m.range(at: 1)) : nil
//            let content = ns.substring(with: m.range(at: 2))
//            let ph = "§§CB\(UUID().uuidString)§§"
//            codeBlocks.append((ph, content, lang))
//            if let r = Range(m.range, in: tmp) { tmp.replaceSubrange(r, with: ph) }
//        }
//
//        var attr = AttributedString(tmp)
//
//        // 链接
//        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
//            let nsM = tmp as NSString
//            detector.matches(in: tmp, range: NSRange(location: 0, length: nsM.length)).forEach { m in
//                if let url = m.url, let r = Range(m.range, in: attr) {
//                    attr[r].foregroundColor = .cyan
//                    attr[r].underlineStyle = .single
//                    attr[r].link = url
//                }
//            }
//        }
//
//        // 行内 `
//        let reInline = try! NSRegularExpression(pattern: "`([^`]+)`")
//        let nsI = tmp as NSString
//        reInline.matches(in: tmp, range: NSRange(location: 0, length: nsI.length)).forEach { m in
//            if let r = Range(m.range(at: 1), in: attr) {
//                attr[r].font = .system(size: UIFont.labelFontSize, weight: .regular).monospaced()
//                attr[r].backgroundColor = UIColor.black.withAlphaComponent(0.25)
//                attr[r].foregroundColor = .white
//            }
//        }
//
//        // @ 我
//        let mention = "@\(myBaseNick)"
//        if !myBaseNick.isEmpty, let re = try? NSRegularExpression(pattern: NSRegularExpression.escapedPattern(for: mention), options: [.caseInsensitive]) {
//            let nsM = tmp as NSString
//            re.matches(in: tmp, range: NSRange(location: 0, length: nsM.length)).forEach { m in
//                if let r = Range(m.range, in: attr) {
//                    attr[r].backgroundColor = UIColor.yellow.withAlphaComponent(0.2)
//                    attr[r].foregroundColor = .yellow
//                    attr[r].font = .system(size: UIFont.labelFontSize, weight: .semibold)
//                }
//            }
//        }
//
//        // /me 风格
//        if isAction {
//            attr.font = .system(size: UIFont.labelFontSize, weight: .regular).italic()
//            attr.foregroundColor = UIColor(colorForNickname(message.senderNickname))
//        }
//
//        // 回填代码块
//        var final = String(attr.characters)
//        for cb in codeBlocks {
//            let pretty = "\n╭─ \(cb.lang ?? "code") ─────────────\n\(cb.content)\n╰────────────────────\n"
//            final = final.replacingOccurrences(of: cb.placeholder, with: pretty)
//        }
//        var attrFinal = AttributedString(final)
//        return attrFinal
//    }
//}
