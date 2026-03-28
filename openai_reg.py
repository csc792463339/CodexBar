import json
import os
import re
import sys
import time
import uuid
import math
import random
import string
import secrets
import hashlib
import base64
import threading
import argparse
from datetime import datetime, timezone, timedelta
from urllib.parse import urlparse, parse_qs, urlencode, quote
from dataclasses import dataclass
from typing import Any, Dict, Optional, List
import urllib.parse
import urllib.request
import urllib.error

from curl_cffi import requests

# ==========================================
# 动态邮箱与手动验证码
# ==========================================

SIGNUP_EMAIL_TEMPLATE = "hellocsc001x{num}@2925.com"
SIGNUP_EMAIL_START = 7
SIGNUP_EMAIL_END = 20
OPENAI_AUTHORIZE_CONTINUE_URL = "https://auth.openai.com/api/accounts/authorize/continue"
OPENAI_REGISTER_URL = "https://auth.openai.com/api/accounts/user/register"
OPENAI_SEND_OTP_URL = "https://auth.openai.com/api/accounts/email-otp/send"
OPENAI_VALIDATE_OTP_URL = "https://auth.openai.com/api/accounts/email-otp/validate"
OPENAI_CREATE_ACCOUNT_URL = "https://auth.openai.com/api/accounts/create_account"
OPENAI_SELECT_WORKSPACE_URL = "https://auth.openai.com/api/accounts/workspace/select"
OPENAI_SENTINEL_REQ_URL = "https://sentinel.openai.com/backend-api/sentinel/req"
OPENAI_SENTINEL_REFERER = "https://sentinel.openai.com/backend-api/sentinel/frame.html?sv=20260219f9f6"
SIGNUP_PASSWORD = "Casdf@@#23fasdf"


def get_signup_email(attempt: int) -> str:
    span = SIGNUP_EMAIL_END - SIGNUP_EMAIL_START + 1
    index = max(0, attempt - 1) % span
    num = SIGNUP_EMAIL_START + index
    return SIGNUP_EMAIL_TEMPLATE.format(num=num)


def prompt_oai_code(email: str) -> str:
    """通过控制台手动输入 OpenAI 验证码"""
    print(f"[*] OpenAI 验证码已发送到: {email}")
    while True:
        code = input("[*] 请输入 6 位验证码: ").strip()
        if re.fullmatch(r"\d{6}", code):
            return code
        print("[Error] 验证码格式不正确，请重新输入 6 位数字。")


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
                print(
                    f"[Warn] Sentinel 异常拦截(flow={flow}, status={sen_resp.status_code}, attempt={attempt}/{attempts})"
                )
                time.sleep(attempt)
                continue
            print(f"[Error] Sentinel 异常拦截，状态码: {sen_resp.status_code}")
            print(sen_resp.text[:500])
            return {}

        data = sen_resp.json() or {}
        sen_token = str(data.get("token") or "").strip()
        if sen_token:
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


def register_password(session: requests.Session, email: str, did: str, proxies: Any = None) -> str:
    password = SIGNUP_PASSWORD
    register_body = json.dumps({"password": password, "username": email})
    sentinel_data = request_sentinel_data(did, "username_password_create", proxies)
    sentinel = build_sentinel_header(did, "username_password_create", sentinel_data)
    if not sentinel:
        return ""

    register_resp = session.post(
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
    print(f"[*] 提交密码状态: {register_resp.status_code}")
    if register_resp.status_code != 200:
        print(register_resp.text[:500])
        return ""

    print(f"[*] 注册密码: {password}")
    return password


def send_verification_code(session: requests.Session) -> bool:
    otp_resp = session.get(
        OPENAI_SEND_OTP_URL,
        headers={
            "referer": "https://auth.openai.com/create-account/password",
            "accept": "application/json",
        },
    )
    print(f"[*] 验证码发送状态: {otp_resp.status_code}")
    if otp_resp.status_code != 200:
        print(otp_resp.text[:500])
        return False
    return True


def _extract_workspace_id_from_payload(payload: Any) -> str:
    if not isinstance(payload, dict):
        return ""

    workspace_id = str(
        payload.get("workspace_id")
        or payload.get("default_workspace_id")
        or ((payload.get("workspace") or {}).get("id") if isinstance(payload.get("workspace"), dict) else "")
        or ""
    ).strip()
    if workspace_id:
        return workspace_id

    workspaces = payload.get("workspaces") or []
    if isinstance(workspaces, list) and workspaces:
        return str((workspaces[0] or {}).get("id") or "").strip()
    return ""


def extract_workspace_id(session: requests.Session, create_account_data: Optional[Dict[str, Any]] = None) -> str:
    auth_cookie = str(session.cookies.get("oai-client-auth-session") or "").strip()
    candidate_payloads: List[str] = []
    if auth_cookie:
        segments = auth_cookie.split(".")
        if len(segments) >= 2 and segments[1]:
            candidate_payloads.append(segments[1])
        if segments and segments[0]:
            candidate_payloads.append(segments[0])
        candidate_payloads.append(auth_cookie)

    for payload in candidate_payloads:
        raw = str(payload or "").strip()
        if not raw:
            continue
        auth_json: Any = None
        try:
            pad = "=" * ((4 - (len(raw) % 4)) % 4)
            decoded = base64.urlsafe_b64decode((raw + pad).encode("ascii"))
            auth_json = json.loads(decoded.decode("utf-8"))
        except Exception:
            try:
                auth_json = json.loads(raw)
            except Exception:
                auth_json = None

        workspace_id = _extract_workspace_id_from_payload(auth_json)
        if workspace_id:
            return workspace_id

    auth_info_raw = str(session.cookies.get("oai-client-auth-info") or "").strip()
    if auth_info_raw:
        auth_info_text = auth_info_raw
        for _ in range(2):
            decoded = urllib.parse.unquote(auth_info_text)
            if decoded == auth_info_text:
                break
            auth_info_text = decoded
        try:
            auth_info_json = json.loads(auth_info_text)
            workspace_id = _extract_workspace_id_from_payload(auth_info_json)
            if workspace_id:
                return workspace_id
        except Exception:
            pass

    return _extract_workspace_id_from_payload(create_account_data or {})


def extract_continue_url(response: requests.Response) -> str:
    location = str(response.headers.get("Location") or "").strip()
    if response.status_code in [301, 302, 303, 307, 308] and location:
        return urllib.parse.urljoin(OPENAI_SELECT_WORKSPACE_URL, location)

    if response.status_code != 200:
        print(f"[Error] 选择 workspace 失败，状态码: {response.status_code}")
        print(response.text[:500])
        return ""

    try:
        continue_url = str((response.json() or {}).get("continue_url") or "").strip()
        if continue_url:
            return continue_url
    except Exception:
        pass

    body_text = str(response.text or "")
    match = re.search(r'"continue_url"\s*:\s*"([^"]+)"', body_text)
    if match:
        return str(match.group(1) or "").replace("\\/", "/").strip()

    if location:
        return urllib.parse.urljoin(OPENAI_SELECT_WORKSPACE_URL, location)
    return ""


def extract_continue_url_from_payload(payload: Any) -> str:
    if not isinstance(payload, dict):
        return ""

    for key in ("continue_url", "continueUrl", "next_url", "nextUrl", "redirect_url", "redirectUrl", "url"):
        candidate = str(payload.get(key) or "").strip()
        if not candidate:
            continue
        if candidate.startswith("/"):
            return urllib.parse.urljoin(OPENAI_CREATE_ACCOUNT_URL, candidate)
        return candidate
    return ""


# ==========================================
# OAuth 授权与辅助函数
# ==========================================

AUTH_URL = "https://auth.openai.com/oauth/authorize"
TOKEN_URL = "https://auth.openai.com/oauth/token"
CLIENT_ID = "app_EMoamEEZ73f0CkXaXp7hrann"

DEFAULT_REDIRECT_URI = f"http://localhost:1455/auth/callback"
DEFAULT_SCOPE = "openid email profile offline_access"


def _b64url_no_pad(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def _sha256_b64url_no_pad(s: str) -> str:
    return _b64url_no_pad(hashlib.sha256(s.encode("ascii")).digest())


def _random_state(nbytes: int = 16) -> str:
    return secrets.token_urlsafe(nbytes)


def _pkce_verifier() -> str:
    return secrets.token_urlsafe(64)


def _parse_callback_url(callback_url: str) -> Dict[str, Any]:
    candidate = callback_url.strip()
    if not candidate:
        return {"code": "", "state": "", "error": "", "error_description": ""}

    if "://" not in candidate:
        if candidate.startswith("?"):
            candidate = f"http://localhost{candidate}"
        elif any(ch in candidate for ch in "/?#") or ":" in candidate:
            candidate = f"http://{candidate}"
        elif "=" in candidate:
            candidate = f"http://localhost/?{candidate}"

    parsed = urllib.parse.urlparse(candidate)
    query = urllib.parse.parse_qs(parsed.query, keep_blank_values=True)
    fragment = urllib.parse.parse_qs(parsed.fragment, keep_blank_values=True)

    for key, values in fragment.items():
        if key not in query or not query[key] or not (query[key][0] or "").strip():
            query[key] = values

    def get1(k: str) -> str:
        v = query.get(k, [""])
        return (v[0] or "").strip()

    code = get1("code")
    state = get1("state")
    error = get1("error")
    error_description = get1("error_description")

    if code and not state and "#" in code:
        code, state = code.split("#", 1)

    if not error and error_description:
        error, error_description = error_description, ""

    return {
        "code": code,
        "state": state,
        "error": error,
        "error_description": error_description,
    }


def _jwt_claims_no_verify(id_token: str) -> Dict[str, Any]:
    if not id_token or id_token.count(".") < 2:
        return {}
    payload_b64 = id_token.split(".")[1]
    pad = "=" * ((4 - (len(payload_b64) % 4)) % 4)
    try:
        payload = base64.urlsafe_b64decode((payload_b64 + pad).encode("ascii"))
        return json.loads(payload.decode("utf-8"))
    except Exception:
        return {}


def _decode_jwt_segment(seg: str) -> Dict[str, Any]:
    raw = (seg or "").strip()
    if not raw:
        return {}
    pad = "=" * ((4 - (len(raw) % 4)) % 4)
    try:
        decoded = base64.urlsafe_b64decode((raw + pad).encode("ascii"))
        return json.loads(decoded.decode("utf-8"))
    except Exception:
        return {}


def _to_int(v: Any) -> int:
    try:
        return int(v)
    except (TypeError, ValueError):
        return 0


def _post_form(url: str, data: Dict[str, str], timeout: int = 30) -> Dict[str, Any]:
    body = urllib.parse.urlencode(data).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=body,
        method="POST",
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read()
            if resp.status != 200:
                raise RuntimeError(
                    f"token exchange failed: {resp.status}: {raw.decode('utf-8', 'replace')}"
                )
            return json.loads(raw.decode("utf-8"))
    except urllib.error.HTTPError as exc:
        raw = exc.read()
        raise RuntimeError(
            f"token exchange failed: {exc.code}: {raw.decode('utf-8', 'replace')}"
        ) from exc


@dataclass(frozen=True)
class OAuthStart:
    auth_url: str
    state: str
    code_verifier: str
    redirect_uri: str


def generate_oauth_url(
    *, redirect_uri: str = DEFAULT_REDIRECT_URI, scope: str = DEFAULT_SCOPE
) -> OAuthStart:
    state = _random_state()
    code_verifier = _pkce_verifier()
    code_challenge = _sha256_b64url_no_pad(code_verifier)

    params = {
        "client_id": CLIENT_ID,
        "response_type": "code",
        "redirect_uri": redirect_uri,
        "scope": scope,
        "state": state,
        "code_challenge": code_challenge,
        "code_challenge_method": "S256",
        "prompt": "login",
        "id_token_add_organizations": "true",
        "codex_cli_simplified_flow": "true",
    }
    auth_url = f"{AUTH_URL}?{urllib.parse.urlencode(params)}"
    return OAuthStart(
        auth_url=auth_url,
        state=state,
        code_verifier=code_verifier,
        redirect_uri=redirect_uri,
    )


def submit_callback_url(
    *,
    callback_url: str,
    expected_state: str,
    code_verifier: str,
    redirect_uri: str = DEFAULT_REDIRECT_URI,
) -> str:
    cb = _parse_callback_url(callback_url)
    if cb["error"]:
        desc = cb["error_description"]
        raise RuntimeError(f"oauth error: {cb['error']}: {desc}".strip())

    if not cb["code"]:
        raise ValueError("callback url missing ?code=")
    if not cb["state"]:
        raise ValueError("callback url missing ?state=")
    if cb["state"] != expected_state:
        raise ValueError("state mismatch")

    token_resp = _post_form(
        TOKEN_URL,
        {
            "grant_type": "authorization_code",
            "client_id": CLIENT_ID,
            "code": cb["code"],
            "redirect_uri": redirect_uri,
            "code_verifier": code_verifier,
        },
    )

    access_token = (token_resp.get("access_token") or "").strip()
    refresh_token = (token_resp.get("refresh_token") or "").strip()
    id_token = (token_resp.get("id_token") or "").strip()
    expires_in = _to_int(token_resp.get("expires_in"))

    claims = _jwt_claims_no_verify(id_token)
    email = str(claims.get("email") or "").strip()
    auth_claims = claims.get("https://api.openai.com/auth") or {}
    account_id = str(auth_claims.get("chatgpt_account_id") or "").strip()

    now = int(time.time())
    expired_rfc3339 = time.strftime(
        "%Y-%m-%dT%H:%M:%SZ", time.gmtime(now + max(expires_in, 0))
    )
    now_rfc3339 = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now))

    config = {
        "id_token": id_token,
        "access_token": access_token,
        "refresh_token": refresh_token,
        "account_id": account_id,
        "last_refresh": now_rfc3339,
        "email": email,
        "type": "codex",
        "expired": expired_rfc3339,
    }

    return json.dumps(config, ensure_ascii=False, separators=(",", ":"))


# ==========================================
# 核心注册逻辑
# ==========================================


def run(proxy: Optional[str], email: str) -> Optional[str]:
    proxies: Any = None
    if proxy:
        proxies = {"http": proxy, "https": proxy}

    s = requests.Session(proxies=proxies, impersonate="chrome")

    try:
        trace = s.get("https://cloudflare.com/cdn-cgi/trace", timeout=10)
        trace = trace.text
        loc_re = re.search(r"^loc=(.+)$", trace, re.MULTILINE)
        loc = loc_re.group(1) if loc_re else None
        print(f"[*] 当前 IP 所在地: {loc}")
        if loc == "CN" or loc == "HK":
            raise RuntimeError("检查代理哦w - 所在地不支持")
    except Exception as e:
        print(f"[Error] 网络连接检查失败: {e}")
        return None

    print(f"[*] 使用动态注册邮箱: {email}")

    oauth = generate_oauth_url()
    url = oauth.auth_url

    try:
        resp = s.get(url, timeout=15)
        did = s.cookies.get("oai-did")
        print(f"[*] Device ID: {did}")

        signup_body = f'{{"username":{{"value":"{email}","kind":"email"}},"screen_hint":"signup"}}'
        signup_sentinel_data = request_sentinel_data(did, "authorize_continue", proxies)
        sentinel = build_sentinel_header(did, "authorize_continue", signup_sentinel_data)
        if not sentinel:
            return None

        signup_resp = s.post(
            OPENAI_AUTHORIZE_CONTINUE_URL,
            headers={
                "referer": "https://auth.openai.com/create-account",
                "accept": "application/json",
                "content-type": "application/json",
                "openai-sentinel-token": sentinel,
            },
            data=signup_body,
        )
        print(f"[*] 提交注册表单状态: {signup_resp.status_code}")
        if signup_resp.status_code != 200:
            print(signup_resp.text[:500])
            return None

        if not register_password(s, email, did, proxies):
            return None

        if not send_verification_code(s):
            return None

        code = prompt_oai_code(email)
        if not code:
            return None

        code_body = f'{{"code":"{code}"}}'
        code_resp = s.post(
            OPENAI_VALIDATE_OTP_URL,
            headers={
                "referer": "https://auth.openai.com/email-verification",
                "accept": "application/json",
                "content-type": "application/json",
            },
            data=code_body,
        )
        print(f"[*] 验证码校验状态: {code_resp.status_code}")
        if code_resp.status_code != 200:
            print(code_resp.text[:500])
            return None

        create_account_sentinel_data = request_sentinel_data(did, "oauth_create_account", proxies)
        create_account_sentinel = build_sentinel_header(
            did, "oauth_create_account", create_account_sentinel_data
        )
        create_account_so = build_sentinel_so_header(
            did, "oauth_create_account", create_account_sentinel_data
        )
        if not create_account_sentinel:
            return None

        create_account_body = '{"name":"max","birthdate":"1990-03-03"}'
        create_account_headers = {
            "origin": "https://auth.openai.com",
            "referer": "https://auth.openai.com/about-you",
            "accept": "application/json",
            "content-type": "application/json",
            "openai-sentinel-token": create_account_sentinel,
        }
        if create_account_so:
            create_account_headers["openai-sentinel-so-token"] = create_account_so

        create_account_resp = s.post(
            OPENAI_CREATE_ACCOUNT_URL,
            headers=create_account_headers,
            data=create_account_body,
        )
        create_account_status = create_account_resp.status_code
        print(f"[*] 账户创建状态: {create_account_status}")

        if create_account_status != 200:
            print(create_account_resp.text)
            return None

        try:
            create_account_data = create_account_resp.json() or {}
        except Exception:
            create_account_data = {}

        continue_url = extract_continue_url_from_payload(create_account_data)
        if continue_url:
            print("[*] 使用 create_account 返回的 continue_url 继续流程")

        workspace_id = extract_workspace_id(s, create_account_data)
        if workspace_id:
            select_body = f'{{"workspace_id":"{workspace_id}"}}'
            select_resp = s.post(
                OPENAI_SELECT_WORKSPACE_URL,
                headers={
                    "referer": "https://auth.openai.com/sign-in-with-chatgpt/codex/consent",
                    "accept": "application/json",
                    "content-type": "application/json",
                },
                data=select_body,
                allow_redirects=False,
            )

            select_continue_url = extract_continue_url(select_resp)
            if select_continue_url:
                continue_url = select_continue_url
        else:
            print("[*] 未解析到 workspace_id，尝试直接使用 create_account 返回继续流程")

        if not continue_url:
            print(f"[*] create_account 响应键: {sorted(create_account_data.keys())}")
            print("[Error] workspace/select 响应里缺少 continue_url")
            return None

        current_url = continue_url
        for _ in range(6):
            final_resp = s.get(current_url, allow_redirects=False, timeout=15)
            location = final_resp.headers.get("Location") or ""

            if final_resp.status_code not in [301, 302, 303, 307, 308]:
                break
            if not location:
                break

            next_url = urllib.parse.urljoin(current_url, location)
            if "code=" in next_url and "state=" in next_url:
                return submit_callback_url(
                    callback_url=next_url,
                    code_verifier=oauth.code_verifier,
                    redirect_uri=oauth.redirect_uri,
                    expected_state=oauth.state,
                )
            current_url = next_url

        print("[Error] 未能在重定向链中捕获到最终 Callback URL")
        return None

    except Exception as e:
        print(f"[Error] 运行时发生错误: {e}")
        return None


def main() -> None:
    parser = argparse.ArgumentParser(description="OpenAI 自动注册脚本")
    parser.add_argument(
        "--proxy", default=None, help="代理地址，如 http://127.0.0.1:7890"
    )
    parser.add_argument("--once", action="store_true", help="只运行一次")
    parser.add_argument("--sleep-min", type=int, default=5, help="循环模式最短等待秒数")
    parser.add_argument(
        "--sleep-max", type=int, default=30, help="循环模式最长等待秒数"
    )
    args = parser.parse_args()

    sleep_min = max(1, args.sleep_min)
    sleep_max = max(sleep_min, args.sleep_max)

    count = 0
    print("[Info] Yasal's Seamless OpenAI Auto-Registrar Started for ZJH")

    while True:
        count += 1
        print(
            f"\n[{datetime.now().strftime('%H:%M:%S')}] >>> 开始第 {count} 次注册流程 <<<"
        )

        try:
            email = get_signup_email(count)
            token_json = run(args.proxy, email)

            if token_json:
                try:
                    t_data = json.loads(token_json)
                    fname_email = t_data.get("email", "unknown").replace("@", "_")
                except Exception:
                    fname_email = "unknown"

                file_name = f"token_{fname_email}_{int(time.time())}.json"

                with open(file_name, "w", encoding="utf-8") as f:
                    f.write(token_json)

                print(f"[*] 成功! Token 已保存至: {file_name}")
            else:
                print("[-] 本次注册失败。")

        except Exception as e:
            print(f"[Error] 发生未捕获异常: {e}")

        if args.once:
            break

        time.sleep(5)


if __name__ == "__main__":
    main()
