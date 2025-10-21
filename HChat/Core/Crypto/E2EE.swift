//
//  E2EE.swift
//  HChat
//
//  Created by Ryan Liu on 2025/10/21.
//

import Foundation
import CryptoKit

struct GroupPassphraseEncryptor {
    let symmetricKey: SymmetricKey

    static func makeFrom(passphrase: String, channelName: String, iterations: Int = 250_000) -> GroupPassphraseEncryptor {
        let salt = Data(("hc:" + channelName).utf8)
        let keyData = PBKDF2_HMAC_SHA256(password: Data(passphrase.utf8), salt: salt, iterations: iterations, derivedKeyLength: 32)
        return GroupPassphraseEncryptor(symmetricKey: SymmetricKey(data: keyData))
    }

    func encryptForTransport(plaintext: String) throws -> String {
        let nonce = AES.GCM.Nonce()
        let sealed = try AES.GCM.seal(Data(plaintext.utf8), using: symmetricKey, nonce: nonce)
        let combined = sealed.ciphertext + sealed.tag
        let env: [String: Any] = ["v": 1, "alg": "AES-GCM",
                                  "iv": Data(nonce).base64EncodedString(),
                                  "ct": combined.base64EncodedString()]
        let json = try JSONSerialization.data(withJSONObject: env)
        return "E2EE:" + json.base64EncodedString()
    }

    func decryptFromTransportIfNeeded(text: String) -> String {
        guard text.hasPrefix("E2EE:") else { return text }
        do {
            let b64 = String(text.dropFirst(5))
            guard let data = Data(base64Encoded: b64),
                  let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ivB64 = obj["iv"] as? String,
                  let ctB64 = obj["ct"] as? String,
                  let ivData = Data(base64Encoded: ivB64),
                  let cipherPlusTag = Data(base64Encoded: ctB64) else { return "（解密失败：格式错误）" }
            guard cipherPlusTag.count >= 16 else { return "（解密失败：密文过短）" }
            let tag = cipherPlusTag.suffix(16)
            let cipher = cipherPlusTag.prefix(cipherPlusTag.count - 16)
            let sealed = try AES.GCM.SealedBox(nonce: .init(data: ivData), ciphertext: cipher, tag: tag)
            let plain = try AES.GCM.open(sealed, using: symmetricKey)
            return String(decoding: plain, as: UTF8.self)
        } catch { return "（解密失败：\(error.localizedDescription)）" }
    }

    // PBKDF2（纯 Swift）
    private static func PBKDF2_HMAC_SHA256(password: Data, salt: Data, iterations: Int, derivedKeyLength: Int) -> Data {
        func INT(_ i: UInt32) -> Data { withUnsafeBytes(of: i.bigEndian) { Data($0) } }
        func hmac(_ key: Data, _ msg: Data) -> Data {
            let sk = SymmetricKey(data: key)
            return Data(HMAC<SHA256>.authenticationCode(for: msg, using: sk))
        }
        var out = Data(); var block: UInt32 = 1
        while out.count < derivedKeyLength {
            let u1 = hmac(password, salt + INT(block)); var t = u1
            if iterations > 1 {
                var up = u1
                for _ in 2...iterations { let u = hmac(password, up); t = Data(zip(t, u).map(^)); up = u }
            }
            out.append(t); block += 1
        }
        return out.prefix(derivedKeyLength)
    }
}
