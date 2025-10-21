//
//  CallManager..swift
//  HChat
//
//  Created by Ryan Liu on 2025/10/21.
//

#if canImport(LiveKit)
import Foundation
import Observation
import LiveKit

@MainActor
@Observable
final class CallManager {
    var room: Room = Room()
    var isConnected: Bool = false
    var statusText: String = "未连接"
    var lastError: String?

    func join(roomName: String, identity: String) {
        Task { @MainActor in
            do {
                let (lkUrl, token) = try await Self.fetchToken(room: roomName, identity: identity)
                try await room.connect(url: lkUrl, token: token)
                self.isConnected = true
                self.statusText = "已加入：\(roomName)"
                self.lastError = nil
            } catch {
                self.isConnected = false
                self.statusText = "连接失败"
                self.lastError = error.localizedDescription
            }
        }
    }

    func leave() {
        Task { @MainActor in
            await room.disconnect()
            self.isConnected = false
            self.statusText = "未连接"
        }
    }

    private static func fetchToken(room: String, identity: String) async throws -> (String, String) {
        var req = URLRequest(url: URL(string: "https://hc.go-lv.com/api/rtc/token")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["room": room, "identity": identity])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        return (obj["livekitUrl"] as! String, obj["token"] as! String)
    }
}
#endif
