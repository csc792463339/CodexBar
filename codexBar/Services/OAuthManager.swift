import Foundation
import AppKit
import Combine
import CryptoKit

class OAuthManager: NSObject, ObservableObject {
    static let shared = OAuthManager()

    // OpenAI OAuth 参数（与 Codex Desktop 保持一致）
    private let clientId = "app_EMoamEEZ73f0CkXaXp7hrann"
    private let callbackPort: UInt16 = 1455
    private let authURL = "https://auth.openai.com/oauth/authorize"
    private let tokenURL = "https://auth.openai.com/oauth/token"
    private let scope = "openid profile email offline_access api.connectors.read api.connectors.invoke"
    private var redirectURI: String { "http://localhost:\(callbackPort)/auth/callback" }

    @Published var isAuthenticating = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private var codeVerifier: String = ""
    private var expectedState: String = ""
    private var localServer: LocalCallbackServer?
    private var completionHandler: ((Result<OAuthTokens, Error>) -> Void)?

    func startOAuth(completion: @escaping (Result<OAuthTokens, Error>) -> Void) {
        do {
            let url = try prepareAuthorizationSession(completion: completion)
            NSWorkspace.shared.open(url)
        } catch {
            fail(error)
        }
    }

    func copyAuthorizationLinkToClipboard() {
        do {
            let url = try prepareAuthorizationSession(completion: defaultCompletionHandler())
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            guard pasteboard.setString(url.absoluteString, forType: .string) else {
                fail(OAuthError.clipboardWriteFailed)
                return
            }
            publishSuccess(L.oauthLinkCopied)
        } catch {
            fail(error)
        }
    }

    func cancel() {
        resetPendingSession()
    }

    func clearErrorMessage() {
        errorMessage = nil
    }

    func clearSuccessMessage() {
        successMessage = nil
    }

    func consumeErrorMessage() -> String? {
        defer { errorMessage = nil }
        return errorMessage
    }

    func consumeSuccessMessage() -> String? {
        defer { successMessage = nil }
        return successMessage
    }

    // MARK: - Private

    private func prepareAuthorizationSession(completion: @escaping (Result<OAuthTokens, Error>) -> Void) throws -> URL {
        resetPendingSession()
        successMessage = nil
        errorMessage = nil

        completionHandler = completion
        codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        expectedState = UUID().uuidString.replacingOccurrences(of: "-", with: "")

        var components = URLComponents(string: authURL)
        components?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "id_token_add_organizations", value: "true"),
            URLQueryItem(name: "codex_cli_simplified_flow", value: "true"),
            URLQueryItem(name: "state", value: expectedState),
            URLQueryItem(name: "originator", value: "Codex Desktop"),
        ]

        guard let url = components?.url else {
            completionHandler = nil
            throw OAuthError.invalidURL
        }

        let server = LocalCallbackServer(port: callbackPort)
        do {
            try server.start { [weak self] code, returnedState in
                guard let self else { return }
                guard returnedState == self.expectedState else {
                    self.fail(OAuthError.stateMismatch)
                    return
                }
                let verifier = self.codeVerifier
                let completion = self.completionHandler
                self.localServer = nil
                self.codeVerifier = ""
                self.expectedState = ""
                self.completionHandler = nil
                self.isAuthenticating = false
                self.exchangeCode(code, codeVerifier: verifier, completion: completion)
            }
        } catch {
            completionHandler = nil
            isAuthenticating = false
            throw error
        }

        localServer = server
        isAuthenticating = true
        return url
    }

    private func defaultCompletionHandler() -> (Result<OAuthTokens, Error>) -> Void {
        { [weak self] result in
            guard case .success(let tokens) = result else { return }
            let account = AccountBuilder.build(from: tokens)
            TokenStore.shared.addOrUpdate(account)
            self?.publishSuccess(L.oauthAccountAdded)
            Task {
                await WhamService.shared.refreshOne(account: account, store: TokenStore.shared)
            }
        }
    }

    private func exchangeCode(_ code: String, codeVerifier: String, completion: ((Result<OAuthTokens, Error>) -> Void)?) {
        guard let url = URL(string: tokenURL) else {
            finishExchange(.failure(OAuthError.invalidURL), completion: completion)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "-._~"))
        let body: [String: String] = [
            "grant_type": "authorization_code",
            "client_id": clientId,
            "code": code,
            "redirect_uri": redirectURI,
            "code_verifier": codeVerifier,
        ]
        request.httpBody = body
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self else { return }
            if let error {
                self.finishExchange(.failure(error), completion: completion)
                return
            }
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                self.finishExchange(.failure(OAuthError.noToken), completion: completion)
                return
            }
            if let errMsg = json["error"] as? String {
                let desc = json["error_description"] as? String ?? ""
                self.finishExchange(.failure(OAuthError.serverError("\(errMsg): \(desc)")), completion: completion)
                return
            }
            guard let accessToken = json["access_token"] as? String,
                  let refreshToken = json["refresh_token"] as? String,
                  let idToken = json["id_token"] as? String else {
                self.finishExchange(.failure(OAuthError.noToken), completion: completion)
                return
            }
            let tokens = OAuthTokens(
                accessToken: accessToken,
                refreshToken: refreshToken,
                idToken: idToken
            )
            self.finishExchange(.success(tokens), completion: completion)
        }.resume()
    }

    private func fail(_ error: Error) {
        DispatchQueue.main.async {
            let completion = self.completionHandler
            self.resetPendingSession(clearMessages: false)
            self.publishError(error.localizedDescription)
            completion?(.failure(error))
            self.completionHandler = nil
        }
    }

    private func finishExchange(_ result: Result<OAuthTokens, Error>, completion: ((Result<OAuthTokens, Error>) -> Void)?) {
        DispatchQueue.main.async {
            switch result {
            case .success(let tokens):
                completion?(.success(tokens))
            case .failure(let error):
                self.publishError(error.localizedDescription)
                completion?(.failure(error))
            }
        }
    }

    private func resetPendingSession(clearMessages: Bool = true) {
        localServer?.stop()
        localServer = nil
        completionHandler = nil
        codeVerifier = ""
        expectedState = ""
        isAuthenticating = false
        if clearMessages {
            errorMessage = nil
            successMessage = nil
        }
    }

    private func publishError(_ message: String) {
        successMessage = nil
        errorMessage = message
    }

    private func publishSuccess(_ message: String) {
        errorMessage = nil
        successMessage = message
    }

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = verifier.data(using: .ascii)!
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

struct OAuthTokens {
    let accessToken: String
    let refreshToken: String
    let idToken: String
}

enum OAuthError: LocalizedError {
    case invalidURL, stateMismatch, noToken, clipboardWriteFailed
    case callbackServerUnavailable(Int)
    case serverError(String)
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的授权 URL"
        case .stateMismatch: return "State 验证失败"
        case .noToken: return "未获取到 Token"
        case .clipboardWriteFailed: return L.clipboardWriteFailed
        case .callbackServerUnavailable(let port): return L.callbackServerUnavailable(port)
        case .serverError(let msg): return "授权失败: \(msg)"
        }
    }
}

/// 轻量级本地 HTTP 服务器，监听 OAuth 回调
class LocalCallbackServer {
    private let port: UInt16
    private let lock = NSLock()
    private var isRunning = false
    private var serverFd: Int32 = -1
    private var handler: ((String, String) -> Void)?

    init(port: UInt16) {
        self.port = port
    }

    func start(handler: @escaping (String, String) -> Void) throws {
        let serverFd = socket(AF_INET, SOCK_STREAM, 0)
        guard serverFd >= 0 else { throw OAuthError.callbackServerUnavailable(Int(port)) }

        var opt: Int32 = 1
        setsockopt(serverFd, SOL_SOCKET, SO_REUSEADDR, &opt, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr = in_addr(s_addr: INADDR_ANY)
        memset(&addr.sin_zero, 0, MemoryLayout.size(ofValue: addr.sin_zero))

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(serverFd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            close(serverFd)
            throw OAuthError.callbackServerUnavailable(Int(port))
        }
        guard Darwin.listen(serverFd, 5) == 0 else {
            close(serverFd)
            throw OAuthError.callbackServerUnavailable(Int(port))
        }

        lock.lock()
        self.handler = handler
        self.serverFd = serverFd
        isRunning = true
        lock.unlock()

        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.listen(on: serverFd)
        }
    }

    func stop() {
        let fd = closeListeningSocket(clearHandler: true)
        guard fd >= 0 else { return }
        shutdown(fd, SHUT_RDWR)
        close(fd)
    }

    private func listen(on serverFd: Int32) {
        while shouldContinueListening(on: serverFd) {
            let clientFd = accept(serverFd, nil, nil)
            guard clientFd >= 0 else {
                if shouldContinueListening(on: serverFd) {
                    continue
                }
                break
            }

            var buffer = [UInt8](repeating: 0, count: 4096)
            let bytesRead = recv(clientFd, &buffer, buffer.count - 1, 0)
            let request = bytesRead > 0 ? String(bytes: buffer.prefix(bytesRead), encoding: .utf8) ?? "" : ""

            if let (code, state) = parseCallback(request) {
                let html = """
                <!DOCTYPE html>
                <html lang="zh-CN">
                <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <title>Authorized · 授权成功 · Codex Bar</title>
                <style>
                  * { box-sizing: border-box; margin: 0; padding: 0; }
                  body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
                    background: #0d0d0d;
                    color: #f0f0f0;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    min-height: 100vh;
                  }
                  .card {
                    text-align: center;
                    padding: 48px 40px;
                    background: #1a1a1a;
                    border: 1px solid #2a2a2a;
                    border-radius: 20px;
                    max-width: 380px;
                    width: 90%;
                    box-shadow: 0 24px 64px rgba(0,0,0,0.5);
                  }
                  .logo {
                    width: 64px;
                    height: 64px;
                    background: linear-gradient(135deg, #10b981, #059669);
                    border-radius: 16px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    margin: 0 auto 24px;
                    font-size: 32px;
                  }
                  .check {
                    display: inline-flex;
                    align-items: center;
                    justify-content: center;
                    width: 48px;
                    height: 48px;
                    background: rgba(16,185,129,0.15);
                    border-radius: 50%;
                    margin-bottom: 20px;
                  }
                  .check svg { width: 24px; height: 24px; }
                  h1 {
                    font-size: 20px;
                    font-weight: 600;
                    margin-bottom: 10px;
                    color: #fff;
                  }
                  p {
                    font-size: 14px;
                    color: #888;
                    line-height: 1.6;
                  }
                  .badge {
                    display: inline-block;
                    margin-top: 28px;
                    padding: 6px 16px;
                    background: rgba(16,185,129,0.1);
                    border: 1px solid rgba(16,185,129,0.3);
                    border-radius: 999px;
                    font-size: 12px;
                    color: #10b981;
                    font-weight: 500;
                    letter-spacing: 0.3px;
                  }
                </style>
                </head>
                <body>
                <div class="card">
                  <div class="logo">⌘</div>
                  <div class="check">
                    <svg viewBox="0 0 24 24" fill="none" stroke="#10b981" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                      <polyline points="20 6 9 17 4 12"/>
                    </svg>
                  </div>
                  <h1>Authorized · 授权成功</h1>
                  <p>Account added to Codex Bar<br>You can close this page.<br><br>账号已添加到 Codex Bar<br>可以关闭此页面了</p>
                  <div class="badge">✓ Return to Codex Bar · 可以返回 Codex Bar</div>
                </div>
                </body>
                </html>
                """
                let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nConnection: close\r\n\r\n\(html)"
                _ = response.withCString { send(clientFd, $0, strlen($0), 0) }
                close(clientFd)
                let callback = completeListeningSession(on: serverFd)
                callback?(code, state)
                break
            } else {
                let response = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                _ = response.withCString { send(clientFd, $0, strlen($0), 0) }
                close(clientFd)
            }
        }
    }

    private func shouldContinueListening(on fd: Int32) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return isRunning && serverFd == fd
    }

    private func completeListeningSession(on fd: Int32) -> ((String, String) -> Void)? {
        let callback = takeHandlerForSocket(fd)
        shutdown(fd, SHUT_RDWR)
        close(fd)
        return callback
    }

    private func closeListeningSocket(clearHandler: Bool) -> Int32 {
        lock.lock()
        defer { lock.unlock() }
        let fd = serverFd
        serverFd = -1
        isRunning = false
        if clearHandler {
            handler = nil
        }
        return fd
    }

    private func takeHandlerForSocket(_ fd: Int32) -> ((String, String) -> Void)? {
        lock.lock()
        defer { lock.unlock() }
        guard serverFd == fd else { return nil }
        let callback = handler
        handler = nil
        serverFd = -1
        isRunning = false
        return callback
    }

    private func parseCallback(_ request: String) -> (String, String)? {
        // 解析 GET /auth/callback?code=xxx&state=yyy HTTP/1.1
        guard let line = request.components(separatedBy: "\r\n").first,
              line.hasPrefix("GET ") else { return nil }
        let parts = line.components(separatedBy: " ")
        guard parts.count >= 2 else { return nil }
        let path = parts[1]
        guard let urlComponents = URLComponents(string: "http://localhost" + path),
              let code = urlComponents.queryItems?.first(where: { $0.name == "code" })?.value,
              let state = urlComponents.queryItems?.first(where: { $0.name == "state" })?.value else { return nil }
        return (code, state)
    }
}
