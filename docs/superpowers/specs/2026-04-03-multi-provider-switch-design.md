# Multi-Provider 切换设计

## 概述

为 CodexBar 添加多 provider 支持（OpenAI OAuth + OpenAI Compatible），允许用户在不同 provider/account 之间快速切换，且不破坏 `~/.codex/sessions` 中的会话历史记录。

## 方案选择

**方案 A（已确认）**：从参考项目 `/Users/csc/github/codexbar` 移植核心服务层（`CodexBarConfig`、`CodexPaths`、`CodexBarConfigStore`、`CodexSyncService`），重写 `TokenStore` 为委托模式，保留现有 UI 风格。

## 文件结构

### 新增文件（从参考项目移植）

| 文件 | 职责 |
|---|---|
| `Models/CodexBarConfig.swift` | 数据模型：`CodexBarProviderKind`、`CodexBarAccountKind`、`CodexBarProvider`、`CodexBarProviderAccount`、`CodexBarConfig`、`CodexBarActiveSelection`、`CodexBarGlobalSettings` |
| `Services/CodexPaths.swift` | 统一路径管理 + `writeSecureFile()` 安全写入（temp file → atomic move → chmod 0600） |
| `Services/CodexBarConfigStore.swift` | 配置持久化 + `migrateFromLegacy()` 自动迁移 |
| `Services/CodexSyncService.swift` | 同步写入 `~/.codex/auth.json` + `config.toml` |
| `Views/CompatibleProviderRowView.swift` | `openai_compatible` provider 行视图（适配当前 glass 主题） |

### 修改文件

| 文件 | 变更 |
|---|---|
| `Services/TokenStore.swift` | 重写为委托 `CodexBarConfigStore` / `CodexSyncService`，保留 `@Published accounts: [TokenAccount]` 对外接口 |
| `Views/MenuBarView.swift` | 添加 provider 切换 UI + 自定义 provider 管理 + 批量删除模式 |

### 保留不动

- `Models/TokenAccount.swift` — 现有模型
- `Services/AccountBuilder.swift` — OAuth token 解析
- `Services/OAuthManager.swift` — OAuth PKCE 流程
- `Services/WhamService.swift` — 配额查询
- `Views/AccountRowView.swift` — OAuth 账号行样式
- `~/.codex/sessions/` — 完全不碰

### 模型关系

`TokenAccount` 作为 OAuth 账号的视图层模型继续存在，`CodexBarProviderAccount` 是持久化层模型，两者通过 `asTokenAccount()` / `fromTokenAccount()` 互转。

## 自动迁移流程

**触发时机**：`TokenStore.init()` 调用 `CodexBarConfigStore.loadOrMigrate()`。

**仅首次执行**，之后直接读 `~/.codexbar/config.json`。

### 迁移步骤

1. 检查 `~/.codexbar/config.json` 是否存在
   - 存在 → 直接加载，跳过迁移
   - 不存在 → 执行以下步骤

2. 读取三个数据源：
   - `~/.codex/token_pool.json` — 现有 OAuth 账号池
   - `~/.codex/auth.json` — 当前激活的 token
   - `~/.codex/config.toml` — model / base_url 等设置

3. 构建 `CodexBarConfig`：
   - 将 `token_pool.json` 中所有账号导入为 `openai-oauth` provider 下的 accounts
   - 从 `auth.json` 中提取额外账号（如果 pool 中没有的话）
   - 从 `config.toml` 读取 `model`、`review_model`、`openai_base_url` 等
   - 根据当前 `auth.json` 中的 `account_id` 确定 `active` 选择

4. 写入 `~/.codexbar/config.json`

**迁移后**：`token_pool.json` 保留不删除（只读不写），`auth.json` + `config.toml` 由 `CodexSyncService` 接管写入。

## 切换逻辑与 Sessions 保护

### 数据流

```
用户点击切换
    ↓
TokenStore.activateCustomProvider() 或 TokenStore.activate()
    ↓
更新 CodexBarConfig.active (providerId + accountId)
    ↓
CodexBarConfigStore.save() → ~/.codexbar/config.json
    ↓
CodexSyncService.synchronize()
    ├─ 写 ~/.codex/auth.json（OAuth token 或 API Key）
    └─ 写 ~/.codex/config.toml（model, openai_base_url 等）
```

### Sessions 保护机制

- `CodexSyncService` 只写 `auth.json` + `config.toml`，代码中没有任何对 `~/.codex/sessions/` 的读写
- Codex 自身以 `sessions/` 目录为独立存储，与 auth/config 无耦合
- 切换 provider 等价于"换一把钥匙"，会话文件完全不受影响

### auth.json 格式区分

| Provider 类型 | auth.json 内容 |
|---|---|
| `openai_oauth` | `auth_mode: "chatgpt"`, `tokens: {access_token, refresh_token, id_token, account_id}`, `OPENAI_API_KEY: null` |
| `openai_compatible` | `OPENAI_API_KEY: "<api-key>"`, 无 tokens 字段 |

### config.toml 写入逻辑

- 始终设置 `model`, `review_model`, `model_reasoning_effort`
- `openai_compatible` 时额外写入 `openai_base_url = "<base-url>"`
- `openai_oauth` 时移除 `openai_base_url`
- 写入前备份为 `config.toml.bak-codexbar-last`

### 安全写入

所有文件操作走 `CodexPaths.writeSecureFile()`（temp file → atomic move → chmod 0600）。

## UI 变更

### summaryCard 改造

- `openai_oauth` 激活时：显示方式与现在一致（email + quota）
- `openai_compatible` 激活时：显示 provider label + host + masked API Key，无 quota 信息

### Provider 切换区域

在 accountsList 上方添加 provider 列表：
- 每个 provider 一行，显示 label + 激活状态指示
- 点击即切换为当前 provider
- `openai_compatible` provider 支持展开显示其下的 accounts（多 key 场景）

### 自定义 Provider 管理

- footer 区域加入口用于添加自定义 provider（输入 label、base URL、API Key）
- 每个 `openai_compatible` provider 支持：添加 account、删除 account、删除整个 provider
- 引入 `CompatibleProviderRowView`（从参考项目移植，适配当前 glass 主题风格）

### 现有 OAuth 账号列表

保持不变，在 OAuth provider 激活时显示。

### 不改的逻辑

- `autoSwitchIfNeeded` 仅对 OAuth 账号生效
- 导出/导入仅覆盖 OAuth 账号
- 刷新 quota 仅对 OAuth 账号生效

## 批量删除

### 交互流程

1. footer 区域新增"批量删除"按钮（图标如 `trash.slash`）
2. 点击后进入"选择模式"：每个账号行前出现 checkbox
3. OAuth 账号和 compatible 账号统一展示 checkbox
4. 底部出现"删除选中 (N)"确认按钮 + "取消"按钮
5. 点击"删除选中"弹出 NSAlert 确认对话框，确认后批量执行

### 删除逻辑

- OAuth 账号：从 `openai-oauth` provider 的 accounts 中移除
- Compatible 账号：从对应 provider 的 accounts 中移除；如果某 provider 下 accounts 被清空，则该 provider 也一并删除
- 如果删除了当前激活的账号/provider，自动 fallback 到剩余的第一个 provider + account
- 删除后统一调用一次 `persist(syncCodex:)` 同步

### 保护措施

- 当前激活的账号可以被选中删除，但确认提示会额外说明"将切换到其他账号"
- 允许全删但给出更强的警告提示
