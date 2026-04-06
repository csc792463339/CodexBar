import Foundation

/// 从 OAuth tokens 解析账号信息，构建 CodexBarProviderAccount
struct AccountBuilder {
    static func build(from tokens: OAuthTokens) -> CodexBarProviderAccount {
        let claims = decodeJWT(tokens.accessToken)
        let authClaims = claims["https://api.openai.com/auth"] as? [String: Any] ?? [:]

        let orgAccountId = authClaims["chatgpt_account_id"] as? String ?? ""
        let planType = authClaims["chatgpt_plan_type"] as? String ?? "free"

        let idClaims = decodeJWT(tokens.idToken)
        let email = idClaims["email"] as? String ?? ""
        // sub 是个人用户级唯一 ID，chatgpt_account_id 是 org 级 ID（同 org 下相同）
        let sub = idClaims["sub"] as? String ?? orgAccountId

        return CodexBarProviderAccount(
            id: sub,
            kind: .oauthTokens,
            label: email.isEmpty ? String(sub.prefix(8)) : email,
            email: email,
            openAIAccountId: orgAccountId,
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
            idToken: tokens.idToken,
            lastRefresh: Date(),
            addedAt: Date(),
            planType: planType
        )
    }

    /// 解码 JWT payload（不验签）
    static func decodeJWT(_ token: String) -> [String: Any] {
        let parts = token.components(separatedBy: ".")
        guard parts.count >= 2 else { return [:] }
        var base64 = parts[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 { base64 += String(repeating: "=", count: 4 - remainder) }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return json
    }
}
