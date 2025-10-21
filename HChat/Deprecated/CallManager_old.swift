#if canImport(LiveKit)
import SwiftUI
import LiveKit

//final class CallManager: ObservableObject {
//    @Published var room: Room = Room()
//    @Published var isConnected: Bool = false
//    @Published var statusText: String = "未连接"
//    @Published var lastError: String?
//
//    /// 对外非 async；内部统一用 Task 处理并发与 await
//    func join(roomName: String, identity: String) {
//        Task {
//            do {
//                let (lkUrl, token) = try await Self.fetchToken(room: roomName, identity: identity)
//                // LiveKit v2：connect(url:token:)
//                try await room.connect(url: lkUrl, token: token)
//                await MainActor.run {
//                    self.isConnected = true
//                    self.statusText = "已加入：\(roomName)"
//                    self.lastError = nil
//                }
//            } catch {
//                await MainActor.run {
//                    self.isConnected = false
//                    self.statusText = "连接失败"
//                    self.lastError = error.localizedDescription
//                }
//            }
//        }
//    }
//
//    func leave() {
//        Task {
//            await room.disconnect()   // <- async API
//            await MainActor.run {
//                self.isConnected = false
//                self.statusText = "未连接"
//            }
//        }
//    }
//
//
//    // MARK: - 后端换取 Token（async 私有函数）
//    private static func fetchToken(room: String, identity: String) async throws -> (String, String) {
//        var req = URLRequest(url: URL(string: "https://hc.go-lv.com/api/rtc/token")!)
//        req.httpMethod = "POST"
//        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        req.httpBody = try JSONSerialization.data(withJSONObject: [
//            "room": room,
//            "identity": identity
//        ])
//        let (data, resp) = try await URLSession.shared.data(for: req)
//        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
//            throw URLError(.badServerResponse)
//        }
//        guard
//            let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
//            let url = obj["livekitUrl"] as? String,
//            let token = obj["token"] as? String
//        else { throw URLError(.cannotParseResponse) }
//        return (url, token)
//    }
//}

/// 极简通话页（用 .sheet 弹出）
struct CallView: View {
    @State private var callManager = CallManager()
    let roomName: String
    let identity: String

    var body: some View {
        VStack(spacing: 16) {
            Text(callManager.statusText).font(.headline)

            Button(callManager.isConnected ? "离开通话" : "加入通话") {
                if callManager.isConnected {
                    callManager.leave()
                } else {
                    callManager.join(roomName: roomName, identity: identity) // 不需要 Task{}
                }
            }
            .buttonStyle(.borderedProminent)

            if let e = callManager.lastError {
                Text(e)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}
#endif
