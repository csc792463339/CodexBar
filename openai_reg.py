import json
import re
import time
import secrets
import hashlib
import base64
import argparse
import urllib.parse
import urllib.request
import urllib.error
from datetime import datetime
from typing import Any, Dict

from curl_cffi import requests

# ==========================================
# 配置常量
# ==========================================

SIGNUP_EMAIL_TEMPLATE = "x{num}@csc-csc.cc"
SIGNUP_EMAIL_START = 51
SIGNUP_EMAIL_END = 65
SIGNUP_PASSWORD = "Csc5632898..."

OPENAI_AUTHORIZE_CONTINUE_URL = "https://auth.openai.com/api/accounts/authorize/continue"
OPENAI_REGISTER_URL = "https://auth.openai.com/api/accounts/user/register"
OPENAI_SEND_OTP_URL = "https://auth.openai.com/api/accounts/email-otp/send"
OPENAI_VALIDATE_OTP_URL = "https://auth.openai.com/api/accounts/email-otp/validate"
OPENAI_CREATE_ACCOUNT_URL = "https://auth.openai.com/api/accounts/create_account"
OPENAI_SENTINEL_REQ_URL = "https://sentinel.openai.com/backend-api/sentinel/req"
OPENAI_SENTINEL_REFERER = "https://sentinel.openai.com/backend-api/sentinel/frame.html?sv=20260219f9f6"

AUTH_URL = "https://auth.openai.com/oauth/authorize"
CLIENT_ID = "app_EMoamEEZ73f0CkXaXp7hrann"
DEFAULT_REDIRECT_URI = "http://localhost:1455/auth/callback"
DEFAULT_SCOPE = "openid email profile offline_access"

MAIL_CODE_API = "http://csc-csc.cc:8080/api/mail/latest?inbox={mail}&type=code"
MAIL_POLL_INTERVAL = 5
MAIL_POLL_ROUND_TIMEOUT = 30
MAIL_MAX_SEND_ATTEMPTS = 2


# ==========================================
# 邮件验证码：轮询与重试
# ==========================================


def _poll_mail_code(email: str, round_timeout: int = MAIL_POLL_ROUND_TIMEOUT) -> str:
    """单轮轮询：在 round_timeout 秒内每 MAIL_POLL_INTERVAL 秒查询一次邮件接口。
    返回 6 位验证码字符串，超时返回空字符串。"""
    url = MAIL_CODE_API.format(mail=email)
    max_attempts = round_timeout // MAIL_POLL_INTERVAL
    for i in range(1, max_attempts + 1):
        try:
            resp = urllib.request.urlopen(url, timeout=10)
            body = resp.read().decode("utf-8", "replace").strip()
        except Exception as e:
            print(f"  [Warn] 轮询请求失败 ({i}/{max_attempts}): {e}")
            time.sleep(MAIL_POLL_INTERVAL)
            continue

        if body and re.fullmatch(r"\d{6}", body):
            print(f"  [OK] 获取到验证码: {body}")
            return body

        print(f"  [*] 等待验证码... ({i}/{max_attempts})")
        time.sleep(MAIL_POLL_INTERVAL)

    return ""


def send_and_poll_verification_code(session: requests.Session, email: str) -> str:
    """发送验证码并轮询获取，最多重试 MAIL_MAX_SEND_ATTEMPTS 次发送。
    返回 6 位验证码字符串，全部失败返回空字符串。"""
    for send_attempt in range(1, MAIL_MAX_SEND_ATTEMPTS + 1):
        print(f"[*] 第 {send_attempt} 次发送验证码到: {email}")
        otp_resp = session.get(
            OPENAI_SEND_OTP_URL,
            headers={
                "referer": "https://auth.openai.com/create-account/password",
                "accept": "application/json",
            },
        )
        if otp_resp.status_code != 200:
            print(f"  [Error] 验证码发送失败，状态码: {otp_resp.status_code}")
            print(f"  {otp_resp.text[:500]}")
            return ""

        print(f"  [OK] 验证码已发送，开始轮询（最长 {MAIL_POLL_ROUND_TIMEOUT} 秒）...")
        code = _poll_mail_code(email)
        if code:
            return code

        if send_attempt < MAIL_MAX_SEND_ATTEMPTS:
            print(f"  [Warn] 本轮 {MAIL_POLL_ROUND_TIMEOUT} 秒内未收到验证码，将重新发送")

    print("[Error] 验证码获取失败，已达最大重试次数")
    return ""


# ==========================================
# Sentinel 相关
# ==========================================


def request_sentinel_data(did: str, flow: str, proxies: Any = None) -> Dict[str, Any]:
    sen_req_body = json.dumps({"p": "", "id": did, "flow": flow}, separators=(",", ":"))
    timeout = 45 if flow == "oauth_create_account" else 15
    attempts = 3 if flow == "oauth_create_account" else 2

    for attempt in range(1, attempts + 1):
        try:
            sen_resp = requests.post(
                OPENAI_SENTINEL_REQ_URL,
                headers={
                    "origin": "https://sentinel.openai.com",
                    "referer": OPENAI_SENTINEL_REFERER,
                    "accept": "application/json",
                    "content-type": "text/plain;charset=UTF-8",
                },
                data=sen_req_body,
                proxies=proxies,
                impersonate="chrome",
                timeout=timeout,
            )
        except Exception as e:
            if attempt < attempts:
                print(f"[Warn] Sentinel 请求失败(flow={flow}, attempt={attempt}/{attempts}): {e}")
                time.sleep(attempt)
                continue
            print(f"[Error] Sentinel 请求失败(flow={flow}): {e}")
            return {}

        if sen_resp.status_code != 200:
            if attempt < attempts:
                print(f"[Warn] Sentinel 异常(flow={flow}, status={sen_resp.status_code}, attempt={attempt}/{attempts})")
                time.sleep(attempt)
                continue
            print(f"[Error] Sentinel 异常拦截，状态码: {sen_resp.status_code}")
            print(sen_resp.text[:500])
            return {}

        data = sen_resp.json() or {}
        if str(data.get("token") or "").strip():
            return data

        if attempt < attempts:
            print(f"[Warn] Sentinel 未返回 token(flow={flow}, attempt={attempt}/{attempts})")
            time.sleep(attempt)
            continue

    print(f"[Error] Sentinel 未返回 token(flow={flow})")
    return {}


def build_sentinel_header(did: str, flow: str, sentinel_data: Dict[str, Any]) -> str:
    sen_token = str((sentinel_data or {}).get("token") or "").strip()
    if not sen_token:
        return ""
    return json.dumps(
        {"p": "", "t": "", "c": sen_token, "id": did, "flow": flow},
        separators=(",", ":"),
    )


def build_sentinel_so_header(did: str, flow: str, sentinel_data: Dict[str, Any]) -> str:
    data = sentinel_data or {}
    sen_token = str(data.get("token") or "").strip()
    so_data = data.get("so") or {}
    snapshot_dx = str(so_data.get("snapshot_dx") or "").strip() if isinstance(so_data, dict) else ""
    if not sen_token or not snapshot_dx:
        return ""
    return json.dumps(
        {"so": snapshot_dx, "c": sen_token, "id": did, "flow": flow},
        separators=(",", ":"),
    )


# ==========================================
# 注册步骤函数
# ==========================================


def check_network(session: requests.Session) -> bool:
    trace = session.get("https://cloudflare.com/cdn-cgi/trace", timeout=10)
    loc_match = re.search(r"^loc=(.+)$", trace.text, re.MULTILINE)
    loc = loc_match.group(1) if loc_match else None
    print(f"[*] 当前 IP 所在地: {loc}")
    if loc in ("CN", "HK"):
        print("[Error] 检查代理哦w - 所在地不支持")
        return True
    return True


def step_authorize(session: requests.Session, email: str, did: str, proxies: Any) -> bool:
    signup_body = json.dumps({"username": {"value": email, "kind": "email"}, "screen_hint": "signup"})
    sentinel_data = request_sentinel_data(did, "authorize_continue", proxies)
    sentinel = build_sentinel_header(did, "authorize_continue", sentinel_data)
    if not sentinel:
        return False

    resp = session.post(
        OPENAI_AUTHORIZE_CONTINUE_URL,
        headers={
            "referer": "https://auth.openai.com/create-account",
            "accept": "application/json",
            "content-type": "application/json",
            "openai-sentinel-token": sentinel,
        },
        data=signup_body,
    )
    print(f"[*] 提交注册表单状态: {resp.status_code}")
    if resp.status_code != 200:
        print(resp.text[:500])
        return False
    return True


def step_register_password(session: requests.Session, email: str, did: str, proxies: Any) -> bool:
    register_body = json.dumps({"password": SIGNUP_PASSWORD, "username": email})

    for attempt in range(1, 3):
        sentinel_data = request_sentinel_data(did, "username_password_create", proxies)
        sentinel = build_sentinel_header(did, "username_password_create", sentinel_data)
        if not sentinel:
            return False

        resp = session.post(
            OPENAI_REGISTER_URL,
            headers={
                "origin": "https://auth.openai.com",
                "referer": "https://auth.openai.com/create-account/password",
                "accept": "application/json",
                "content-type": "application/json",
                "openai-sentinel-token": sentinel,
            },
            data=register_body,
        )
        print(f"[*] 提交密码状态: {resp.status_code}")
        if resp.status_code == 200:
            print(f"[*] 注册密码: {SIGNUP_PASSWORD}")
            return True

        print(resp.text[:500])
        if attempt < 2:
            print("[*] 5 秒后重试提交密码...")
            time.sleep(5)

    print("[Error] 提交密码失败，已重试")
    return False


def step_validate_otp(session: requests.Session, code: str) -> bool:
    resp = session.post(
        OPENAI_VALIDATE_OTP_URL,
        headers={
            "referer": "https://auth.openai.com/email-verification",
            "accept": "application/json",
            "content-type": "application/json",
        },
        data=json.dumps({"code": code}),
    )
    print(f"[*] 验证码校验状态: {resp.status_code}")
    if resp.status_code != 200:
        print(resp.text[:500])
        return False
    return True


def step_create_account(session: requests.Session, did: str, proxies: Any) -> bool:
    sentinel_data = request_sentinel_data(did, "oauth_create_account", proxies)
    sentinel = build_sentinel_header(did, "oauth_create_account", sentinel_data)
    sentinel_so = build_sentinel_so_header(did, "oauth_create_account", sentinel_data)
    if not sentinel:
        return False

    headers = {
        "origin": "https://auth.openai.com",
        "referer": "https://auth.openai.com/about-you",
        "accept": "application/json",
        "content-type": "application/json",
        "openai-sentinel-token": sentinel,
    }
    if sentinel_so:
        headers["openai-sentinel-so-token"] = sentinel_so

    resp = session.post(
        OPENAI_CREATE_ACCOUNT_URL,
        headers=headers,
        data='{"name":"max","birthdate":"1990-03-03"}',
    )
    print(f"[*] 账户创建状态: {resp.status_code}")
    if resp.status_code != 200:
        print(resp.text)
        return False
    return True


# ==========================================
# OAuth 初始化（仅用于获取 Device ID）
# ==========================================


def _b64url_no_pad(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def _sha256_b64url_no_pad(s: str) -> str:
    return _b64url_no_pad(hashlib.sha256(s.encode("ascii")).digest())


def generate_oauth_url() -> str:
    """构造 OAuth authorize URL，用于初始化会话并获取 oai-did cookie。"""
    state = secrets.token_urlsafe(16)
    code_verifier = secrets.token_urlsafe(64)
    code_challenge = _sha256_b64url_no_pad(code_verifier)

    params = {
        "client_id": CLIENT_ID,
        "response_type": "code",
        "redirect_uri": DEFAULT_REDIRECT_URI,
        "scope": DEFAULT_SCOPE,
        "state": state,
        "code_challenge": code_challenge,
        "code_challenge_method": "S256",
        "prompt": "login",
        "id_token_add_organizations": "true",
        "codex_cli_simplified_flow": "true",
    }
    return f"{AUTH_URL}?{urllib.parse.urlencode(params)}"


# ==========================================
# 单次注册流程
# ==========================================


def run(proxy: str | None, email: str) -> bool:
    proxies = {"http": proxy, "https": proxy} if proxy else None
    session = requests.Session(proxies=proxies, impersonate="chrome")

    # 1. 网络检查
    try:
        if not check_network(session):
            return False
    except Exception as e:
        print(f"[Error] 网络连接检查失败: {e}")
        return False

    print(f"[*] 使用注册邮箱: {email}")

    # 2. OAuth 初始化（获取 Device ID）
    try:
        session.get(generate_oauth_url(), timeout=15)
        did = session.cookies.get("oai-did")
        print(f"[*] Device ID: {did}")

        # 3. 提交注册表单
        if not step_authorize(session, email, did, proxies):
            return False

        # 4. 注册密码（失败自动重试一次）
        if not step_register_password(session, email, did, proxies):
            return False

        # 5. 发送验证码 + 轮询获取（2 分钟超时，最多重发一次）
        code = send_and_poll_verification_code(session, email)
        if not code:
            return False

        # 6. 校验验证码
        if not step_validate_otp(session, code):
            return False

        # 7. 创建账户
        if not step_create_account(session, did, proxies):
            return False

        print(f"[OK] 账户注册完成: {email}")
        return True

    except Exception as e:
        print(f"[Error] 运行时发生错误: {e}")
        return False


# ==========================================
# 入口：仅遍历 START..END 各执行一次
# ==========================================


def main() -> None:
    parser = argparse.ArgumentParser(description="OpenAI 自动注册脚本")
    parser.add_argument("--proxy", default=None, help="代理地址，如 http://127.0.0.1:7890")
    args = parser.parse_args()

    emails = [SIGNUP_EMAIL_TEMPLATE.format(num=n) for n in range(SIGNUP_EMAIL_START, SIGNUP_EMAIL_END + 1)]
    print(f"[Info] OpenAI Auto-Registrar — 待注册邮箱: {emails}")

    for i, email in enumerate(emails, 1):
        print(f"\n[{datetime.now().strftime('%H:%M:%S')}] === 第 {i}/{len(emails)} 个邮箱: {email} ===")

        try:
            success = run(args.proxy, email)
            if not success:
                print(f"[-] {email} 注册失败")
        except Exception as e:
            print(f"[Error] 发生未捕获异常: {e}")


if __name__ == "__main__":
    main()
