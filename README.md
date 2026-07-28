# coding-agent-clean

> 把主流榜单（[artificialanalysis.ai/agents/coding](https://artificialanalysis.ai/agents/coding)、[OpenRouter 编码应用榜](https://openrouter.ai/apps/category/coding)）列出的 coding agent 清理得像刚安装一样——
> 抹掉 **plugins · rules · skills · subagents · tools · MCPs · hooks** 以及所有配置 / 缓存 / 认证 / 状态，保留二进制本体。

跨平台（Windows / macOS / Linux），**默认 dry-run，不改任何东西**，除非你显式传 `--apply` / `-Apply`。

---

## 文件结构

```
coding-agent-clean/
├── agents.json          # 唯一真相源：每个 agent 的路径 + artifact 类别（三平台）
├── clean-agents.ps1     # Windows 运行器 (PowerShell 5.1+)
├── clean-agents.sh      # macOS / Linux 运行器 (bash, 需要 jq)
└── README.md
```

`agents.json` 集中维护路径数据，两个运行器都从它读取——不会出现 PowerShell 和 bash 各写一份导致数据不一致的问题。

---

## 快速开始

### Windows (PowerShell)

```powershell
# 1. 看看会删什么（默认 dry-run，安全）
.\clean-agents.ps1

# 2. 确认后，真正执行
.\clean-agents.ps1 -Apply

# 3. 先备份再删（备份到 ./backups/<timestamp>/）
.\clean-agents.ps1 -Backup -Apply

# 4. 只清理某几个 agent
.\clean-agents.ps1 -Agents claude-code,cursor -Apply

# 5. 连项目本地配置一起清（.clinerules / .cursor/rules / .continue 等）
.\clean-agents.ps1 -IncludeProjectLocal -ProjectRoots C:\Users\ixion\workspace -Apply
```

### macOS / Linux (bash)

```bash
# 1. 预览
./clean-agents.sh

# 2. 执行
./clean-agents.sh --apply

# 3. 备份后执行
./clean-agents.sh --backup --apply

# 4. 指定 agent
./clean-agents.sh --agents claude-code,cursor --apply

# 5. 含项目本地配置
./clean-agents.sh --include-project-local --project-roots ~/workspace --apply
```

> 依赖：bash 版需要 [`jq`](https://stedolan.github.io/jq/)（`brew install jq` / `sudo apt install jq`）。PowerShell 版无额外依赖。

---

## 安全设计

| 机制 | 说明 |
|------|------|
| **默认 dry-run** | 不传 `--apply` / `-Apply` 时只展示，不删任何东西 |
| **`-Backup` / `--backup`** | 删除前把状态移到 `backups/<时间戳>/`，可恢复 |
| **只清状态，不动本体** | `agents.json` 里列的都是 state 路径；安装目录（`/Applications/Cursor.app`、`%LOCALAPPDATA%\Programs\...` 等）**不会被碰** |
| **项目本地默认关闭** | `.cursor/rules`、`.clinerules` 这类项目级配置常被 git 跟踪/团队共用，必须显式加 `-IncludeProjectLocal` 才会清理 |
| **云-only 自动跳过** | Devin、Jules、Manus 没有本地状态，默认跳过（可用 `--cloud-too` 显示） |
| **支持 `-WhatIf` / `-Confirm`** | PowerShell 原生支持 `-WhatIf` 和 `-Confirm` |

### 恢复备份

备份只是把目录原样搬到 `backups/<timestamp>/<agent-id>/` 下，恢复就是把它搬回去：

```powershell
# 例：恢复 Claude Code 的状态
Copy-Item -Recurse ".\backups\20260727_211300\claude-code\.claude" "$env:USERPROFILE\.claude"
```

---

## 支持的 Agent（42 个）

覆盖 [artificialanalysis.ai](https://artificialanalysis.ai/agents/coding) 全量 30 个 + [OpenRouter 编码应用榜](https://openrouter.ai/apps/category/coding) 新增 12 个（去重后）。每个条目均经官方文档/GitHub 验证；明确排除的 non-agent（游戏引擎、通用代理框架、云 SaaS、API 网关等）不列入。

按 artifact 丰富度排序。**categories** 列出该 agent 实际拥有的 artifact 类别（plugins / rules / skills / subagents / tools / mcps / hooks / memory / sessions）。

### CLI 工具

| Agent | categories | 状态根 / 说明 |
|-------|-----------|------|
| **Claude Code** | plugins, rules, skills, subagents, tools, mcps, hooks | `~/.claude`（`CLAUDE_CONFIG_DIR`），类别最全 |
| **Grok Build** | plugins, rules, skills, subagents, tools, mcps, hooks | `~/.grok`（`GROK_HOME`），xAI TUI harness |
| **Command Code** | plugins, rules, skills, subagents, tools, mcps, hooks, memory, sessions | `~/.commandcode` |
| **OpenClaw** | plugins, rules, skills, subagents, tools, mcps, hooks, memory | `~/.openclaw`（`OPENCLAW_HOME`） |
| **Hermes Agent** | skills, subagents, tools, memory, hooks, mcps | `~/.hermes`（`HERMES_HOME`），Nous Research |
| **Kilo Code** | plugins, skills, tools, mcps, rules, subagents, memory, hooks | `~/.config/kilo`，OpenCode/Roo Code fork |
| **Codex** | plugins, skills, tools, mcps, hooks | `~/.codex`（`CODEX_HOME`） |
| **Oh-My-Pi** | plugins, rules, skills, subagents, tools, mcps, hooks, memory | `~/.omp`，omp.sh 终端代理 |
| **Codebuff** | skills, subagents, tools, mcps, memory | `~/.config/manicode`（内部代号 manicode） |
| **Genie** | skills, plugins, hooks, mcps | `cos` CLI，`~/.cosine` |
| **Goose** | plugins, tools | Block 开源 dev agent，`~/.config/goose` |
| **Gemini CLI** | mcps | `~/.gemini`（`GEMINI_CLI_HOME`） |
| **Kimi CLI** | mcps, subagents | `~/.kimi`（`KIMI_SHARE_DIR`） |
| **Qwen Code** | skills | `~/.qwen`（`QWEN_HOME`） |
| **poolside** | skills, mcps, tools, hooks, rules | `~/.config/poolside`，Laguna 模型终端代理 |
| **pi** | skills, tools, hooks, memory, plugins | `~/.pi/agent`（`PI_CODING_AGENT_DIR`） |
| **Crush** | skills, rules, mcps | `~/.config/crush` + `~/.local/share/crush`，opencode 继承者 |
| **opencode** (archived) | tools, mcps | 已归档改名 Crush |
| **Peezy CLI** | tools | `~/.peezy/config.json`，p0.systems |
| **Aider** | — | 纯项目本地 `.aider.*`，无全局状态 |
| **MiMo Code** | plugins, rules, skills, tools, mcps, memory | `~/.config/mimocode`，XiaomiMiMo，OpenCode fork |

### 独立 IDE

| Agent | categories | 说明 |
|-------|-----------|------|
| **Kiro** | plugins, rules, skills, subagents, tools, mcps, hooks | 独有的 hooks / specs / steering |
| **Google Antigravity** | plugins, rules, skills, mcps, hooks | `~/.gemini/antigravity*`，Agentic IDE + CLI + SDK |
| **Cursor** | rules, mcps, skills, subagents | `.cursor/rules/*.mdc`、`mcp.json` |
| **Qoder** | mcps, plugins | Knowledge Engine（路径为推断，未经官方确认） |
| **Zed** | plugins | 扩展即插件，Rust 原生编辑器（非 VS Code） |
| **Windsurf** | MCPs | `mcp_config.json` |

### VS Code / JetBrains 扩展

| Agent | categories | 说明 |
|-------|-----------|------|
| **Continue** | rules, skills, subagents, mcps, hooks | `~/.continue`（API key 明文存储） |
| **Cline** | rules, MCPs | 项目级 `.clinerules`，publisher: saoudrizwan |
| **Roo Code** (shut down) | rules, MCPs | 2026-05-15 关停，仅留作历史参考 |
| **Mistral Vibe** | skills | `mistralai.mistral-vibe-code` |
| **GitHub Copilot** | — | 认证走系统凭据管理器 |
| **Amazon Q** | — | 认证走系统凭据管理器 |
| **Gemini Code Assist** | — | 也读 `~/.config/gcloud` |
| **Augment Code / Amp / BLACKBOX AI** | — | 标准 VS Code 扩展存储 |

### 终端

| Agent | categories | 说明 |
|-------|-----------|------|
| **Warp** | rules, skills, mcps, subagents | workflows=rules、`~/.warp/skills`、`~/.agents` |

### 自托管

| Agent | categories | 说明 |
|-------|-----------|------|
| **OpenHands** | rules, skills, mcps | `~/.openhands`，rules/skills 即 microagents |

### 云-only（自动跳过）

Devin / Jules / Manus — 无本地状态。

---

## 各平台路径速查

### VS Code 扩展（Cline / Roo / Continue / Copilot / …）

| 存储 | Windows | macOS | Linux |
|------|---------|-------|-------|
| Global Storage | `%APPDATA%\Code\User\globalStorage\<pub>.<ext>\` | `~/Library/Application Support/Code/User/globalStorage/<pub>.<ext>/` | `~/.config/Code/User/globalStorage/<pub>.<ext>/` |
| 扩展安装 | `%USERPROFILE%\.vscode\extensions\<pub>.<ext>-*` | `~/.vscode/extensions/<pub>.<ext>-*` | 同左 |
| 密钥 | Windows Credential Manager | Keychain | libsecret |

### 独立 IDE

| Agent | Windows | macOS | Linux |
|-------|---------|-------|-------|
| **Cursor** | `%APPDATA%\Cursor`, `~/.cursor` | `~/Library/Application Support/Cursor`, `~/.cursor` | `~/.config/Cursor`, `~/.cursor` |
| **Windsurf** | `~/.codeium/windsurf` | 同左 | 同左 |
| **Zed** | `%APPDATA%\Zed`, `%LOCALAPPDATA%\Zed` | `~/Library/Application Support/Zed` | `~/.config/zed`, `~/.local/share/zed` |
| **Kiro** | `%APPDATA%\Kiro`, `~/.kiro` | `~/Library/Application Support/Kiro`, `~/.kiro` | `~/.config/Kiro`, `~/.kiro` |
| **Qoder** | `%APPDATA%\Qoder`, `~/.qoder` | `~/Library/Application Support/Qoder`, `~/.qoder` | `~/.config/Qoder`, `~/.qoder` |

### CLI 工具（全局状态根）

| Agent | Linux / macOS | Windows | 覆盖变量 |
|-------|--------------|---------|---------|
| **Claude Code** | `~/.claude` | `%USERPROFILE%\.claude` | `CLAUDE_CONFIG_DIR` |
| **Codex** | `~/.codex` | `%USERPROFILE%\.codex` | `CODEX_HOME` |
| **Gemini CLI** | `~/.gemini` | `%USERPROFILE%\.gemini` | `GEMINI_CLI_HOME` |
| **Grok Build** | `~/.grok` | `%USERPROFILE%\.grok` | `GROK_HOME` |
| **Command Code** | `~/.commandcode` | `%USERPROFILE%\.commandcode` | — |
| **Hermes Agent** | `~/.hermes` | `%LOCALAPPDATA%\hermes` | `HERMES_HOME` |
| **Kilo Code** | `~/.config/kilo` | `%USERPROFILE%\.config\kilo` | `KILO_CONFIG` |
| **Oh-My-Pi** | `~/.omp` | `%USERPROFILE%\.omp` | `PI_CODING_AGENT_DIR` |
| **OpenClaw** | `~/.openclaw` | `%USERPROFILE%\.openclaw` | `OPENCLAW_HOME` |
| **pi** | `~/.pi/agent` | `%USERPROFILE%\.pi\agent` | `PI_CODING_AGENT_DIR` |
| **Codebuff** | `~/.config/manicode` | `%USERPROFILE%\.config\manicode` | — |
| **Crush** | `~/.config/crush`, `~/.local/share/crush`, `~/.cache/crush` | `%USERPROFILE%\.config\crush`, `%LOCALAPPDATA%\crush` | `CRUSH_GLOBAL_CONFIG`, `CRUSH_GLOBAL_DATA` |
| **MiMo Code** | `~/.config/mimocode`, `~/.local/share/mimocode`, `~/.cache/mimocode` | `%USERPROFILE%\.config\mimocode`, `%LOCALAPPDATA%\mimocode` | `MIMOCODE_HOME` |
| **poolside** | `~/.config/poolside` | `%APPDATA%\poolside` | — |
| **Peezy CLI** | `~/.peezy` | `%USERPROFILE%\.peezy` | — |
| **Goose** | `~/.config/goose` | `%APPDATA%\Block\goose` | — |
| **opencode** | `~/.config/opencode`, `~/.opencode.json` | `%USERPROFILE%\.opencode.json` | — |
| **Qwen Code** | `~/.qwen` | `%USERPROFILE%\.qwen` | `QWEN_HOME` |
| **Kimi CLI** | `~/.kimi` | `%USERPROFILE%\.kimi` | `KIMI_SHARE_DIR` |
| **Genie** | `~/.cosine` | 未公开 | — |

---

## 添加新 Agent

在 `agents.json` 的 `agents` 数组里加一条即可，两个运行器自动生效：

```json
{
  "id": "my-agent",
  "name": "My Agent",
  "publisher": "Me",
  "type": "cli",
  "cloud_only": false,
  "categories": ["rules", "mcps"],
  "notes": "说明",
  "paths": {
    "windows": ["%USERPROFILE%\\.my-agent"],
    "macos": ["~/.my-agent"],
    "linux": ["~/.my-agent"]
  },
  "project_local": [
    { "path": ".my-agent-rules", "artifacts": ["rules"] }
  ]
}
```

字段说明：

- `type`：`cli` / `ide` / `extension` / `terminal` / `self-hosted` / `cloud`
- `cloud_only: true` → 运行器自动跳过
- `categories`：从 `plugins, rules, skills, subagents, tools, mcps, hooks, memory, sessions` 里选，没有就 `[]`
- `paths`：三平台全局状态路径，支持 `%VAR%`（Win）、`~`、`$HOME`、`$XDG_*`（Unix）和 `*` 通配符
- `project_local`：项目级配置文件（相对路径），只有开启 `-IncludeProjectLocal` 才清理

---

## 已知限制

1. **项目本地配置需要知道项目根目录** — 脚本不会遍历整台机器找 `.clinerules`，你得通过 `-ProjectRoots` 告诉它扫哪些目录。
2. **密钥链里的认证**（macOS Keychain / Windows Credential Manager）脚本不清理——这些走系统凭据 API，不在文件路径里。想彻底清需手动在系统凭据管理器里删除。
3. **Codex Windows 路径**（`%USERPROFILE%\.codex`）来自社区资料而非官方文档，如果 `$CODEX_HOME` 设过就以它为准。
4. **opencode 已归档**并改名 Crush，路径可能随版本变化。
5. **Aider** 没有全局状态，只有项目本地 `.aider.*` 文件，需配合 `-IncludeProjectLocal` 使用。
6. **Qoder / Google Antigravity** 路径部分为推断（VS Code-fork 惯例），未经官方文档直接确认，首次使用前建议在目标机器上核对。

## License

MIT
