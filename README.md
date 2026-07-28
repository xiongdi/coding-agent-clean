# coding-agent-clean

> 把主流榜单（[artificialanalysis.ai/agents/coding](https://artificialanalysis.ai/agents/coding)、[OpenRouter 编码应用榜](https://openrouter.ai/apps/category/coding)）列出的 coding agent 清理得像刚安装一样——
> 抹掉 **plugins · rules · skills · subagents · tools · MCPs · hooks · memory** 以及所有配置 / 缓存 / 认证 / 状态，保留二进制本体。

**每个条目均经官方文档 / GitHub 源码 / 包注册表验证**（2026-07）。明确排除游戏引擎、通用代理框架、云 SaaS、API 网关等非编码代理。

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
| **云-only 自动跳过** | Jules 没有本地状态，默认跳过（可用 `--cloud-too` 显示） |
| **支持 `-WhatIf` / `-Confirm`** | PowerShell 原生支持 `-WhatIf` 和 `-Confirm` |

### 恢复备份

备份只是把目录原样搬到 `backups/<timestamp>/<agent-id>/` 下，恢复就是把它搬回去：

```powershell
# 例：恢复 Claude Code 的状态
Copy-Item -Recurse ".\backups\20260727_211300\claude-code\.claude" "$env:USERPROFILE\.claude"
```

---

## 支持的 Agent（42 个）

经全量审计（每个条目对照官方源码/文档）。**categories** 列出该 agent 实际拥有的 artifact 类别（plugins / rules / skills / subagents / tools / mcps / hooks / memory / sessions）。

### CLI 工具

| Agent | categories | 状态根（Linux） | 说明 |
|-------|-----------|----------------|------|
| **Claude Code** | plugins, rules, skills, subagents, tools, mcps, hooks | `~/.claude` | 类别最全；Windows: `%USERPROFILE%\.claude` |
| **Grok Build** | plugins, rules, skills, subagents, tools, mcps, hooks, memory | `~/.grok` | xAI TUI harness；`GROK_HOME` |
| **Codex** | plugins, rules, skills, subagents, tools, mcps, hooks, memory | `~/.codex` | OpenAI；`CODEX_HOME`；项目 `.codex/` |
| **Command Code** | skills, subagents, tools, mcps, hooks, memory, sessions | `~/.commandcode` | 终端原生代理 |
| **OpenClaw** | plugins, skills, subagents, tools, mcps, memory | `~/.openclaw` | 多渠道网关+代理框架；`OPENCLAW_HOME` |
| **Hermes Agent** | skills, subagents, tools, memory, mcps | `~/.hermes` | Nous Research；Windows: `%LOCALAPPDATA%\hermes`；`HERMES_HOME` |
| **Kilo Code** | skills, subagents, tools, mcps, rules | `~/.config/kilo` | OpenCode/Roo Code fork；`KILO_CONFIG_DIR` |
| **Oh-My-Pi** | plugins, rules, skills, subagents, tools, mcps, memory | `~/.omp` | omp.sh 终端代理（pi fork） |
| **Goose** | tools, subagents, mcps, skills, memory | `~/.config/goose` | AAIF/Linux Foundation；`GOOSE_PATH_ROOT` |
| **Mistral Vibe** | skills, subagents, tools, mcps, hooks | `~/.vibe` | Mistral AI；binary `vibe`；`VIBE_HOME` |
| **Codebuff** | skills, subagents, tools, mcps, memory | `~/.config/manicode` | 内部代号 manicode |
| **Gemini CLI** | mcps, skills, hooks, memory, tools, rules | `~/.gemini` | Google |
| **pi** | skills, tools, hooks, memory, plugins | `~/.pi/agent` | earendil-works；`PI_CODING_AGENT_DIR` |
| **Crush** | rules, skills, tools, mcps, hooks, memory | `~/.config/crush` | opencode 继承者；Charmbracelet |
| **Genie** | skills, plugins, hooks, mcps | `~/.cosine` | ⚠️ UNVERIFIED（repo 404，域名已出售） |
| **poolside** | skills, mcps, tools | `~/.config/poolside` | Laguna 模型；state 路径未公开验证 |
| **Qwen Code** | skills | `~/.qwen` | Alibaba；`QWEN_HOME` |
| **Kimi CLI** | mcps | `~/.kimi` | Moonshot AI；`KIMI_SHARE_DIR` |
| **opencode** (archived) | tools, mcps, plugins, skills, rules, agents, subagents, hooks | `~/.config/opencode` | 已归档，现 AnomalyCo |
| **Peezy CLI** | tools, mcps | `~/.peezy` | p0.systems |
| **Aider** | — | — | 仅存 `~/.aider/`（OAuth keys），无全局状态 |

### 独立 IDE

| Agent | categories | 状态根（Linux） | 说明 |
|-------|-----------|----------------|------|
| **Kiro** | plugins, rules, skills, subagents, tools, mcps, hooks | `~/.kiro` | Amazon；binary `kiro-cli` |
| **Devin** | rules, mcps, skills, tools | `~/.codeium/windsurf` | Cognition；Devin Desktop + CLI |
| **Google Antigravity** | plugins, rules, skills, mcps, hooks | `~/.gemini/antigravity*` | ⚠️ 路径为推断（网站无技术文档） |
| **Qoder** | mcps, plugins, rules, sessions, skills, subagents, tools, hooks, memory | `~/.config/Qoder`, `~/.qoder` | Bright Zenith；部分路径来自社区工具 |
| **Cursor** | rules, mcps, skills, subagents | `~/.cursor`, `~/.config/Cursor` | Anysphere；VS Code fork |
| **Zed** | extensions, mcps | `~/.config/zed`, `~/.local/share/zed` | Zed Industries；扩展非插件 |
| **Windsurf** | mcps, rules | `~/.codeium/windsurf` | Cognition |

### VS Code / JetBrains 扩展

| Agent | categories | 说明 |
|-------|-----------|------|
| **Continue** | rules, skills, subagents, mcps, hooks | `~/.continue`（API key 明文）；binary `cn` |
| **Amazon Q Developer** | agents, prompts, mcps, subagents, rules | `~/.aws/amazonq/`；NOT cloud-only |
| **Amp** | mcps, tools, skills, rules | Ampcode；`~/.config/amp` + `~/.amp/oauth`；`AMP_DATA_HOME` |
| **Cline** | rules, mcps | `~/.cline/` + `~/Documents/Cline`；NOT project-local only |
| **Mistral Vibe** | skills | CLI agent (also listed under CLI) |
| **Gemini Code Assist** | mcps | 无 agent 自有全局状态 |
| **GitHub Copilot** | — | 认证走系统凭据管理器 |
| **Augment Code** | — | 无全局状态文档 |
| **BLACKBOX AI** | — | 扩展 + CLI binary `blackbox` |
| **Roo Code** (shut down) | rules, mcps | 2026-05-15 关停，仅历史参考 |

### 终端

| Agent | categories | 说明 |
|-------|-----------|------|
| **Warp** | rules, skills, mcps, subagents | workflows=rules, `~/.warp/skills`, `~/.agents` |

### 自托管

| Agent | categories | 说明 |
|-------|-----------|------|
| **OpenHands** | plugins, rules, skills, subagents, tools, mcps, hooks, memory | `~/.openhands`；binary `agent-canvas` |

### 云-only（自动跳过）

**Jules**（Google）— 在 Cloud VM 中运行，无本地状态。

---

## 各平台路径速查

### CLI 工具（全局状态根）

| Agent | Linux | macOS | Windows | 覆盖变量 |
|-------|-------|-------|---------|---------|
| Claude Code | `~/.claude` | `~/.claude` | `%USERPROFILE%\.claude` | — |
| Codex | `~/.codex` | `~/.codex` | `%USERPROFILE%\.codex` | `CODEX_HOME` |
| Gemini CLI | `~/.gemini` | `~/.gemini` | `%USERPROFILE%\.gemini` | — |
| Grok Build | `~/.grok` | `~/.grok` | `~/.grok` | `GROK_HOME` |
| Goose | `~/.config/goose` | `~/Library/Application Support/Block/goose` | `%APPDATA%\Block\goose` | `GOOSE_PATH_ROOT` |
| Mistral Vibe | `~/.vibe` | `~/.vibe` | `%USERPROFILE%\.vibe` | `VIBE_HOME` |
| Kilo Code | `~/.config/kilo` | `~/Library/Application Support/kilo` | `%LOCALAPPDATA%\kilo` | `KILO_CONFIG_DIR` |
| Command Code | `~/.commandcode` | `~/.commandcode` | `%USERPROFILE%\.commandcode` | — |
| Hermes Agent | `~/.hermes` | `~/.hermes` | `%LOCALAPPDATA%\hermes` | `HERMES_HOME` |
| OpenClaw | `~/.openclaw` | `~/.openclaw` | `%USERPROFILE%\.openclaw` | `OPENCLAW_HOME` |
| Oh-My-Pi | `~/.omp` | `~/.omp` | `%USERPROFILE%\.omp` | `PI_CODING_AGENT_DIR` |
| pi | `~/.pi/agent` | `~/.pi/agent` | `%USERPROFILE%\.pi\agent` | `PI_CODING_AGENT_DIR` |
| Codebuff | `~/.config/manicode` | `~/.config/manicode` | `%USERPROFILE%\.config\manicode` | — |
| Crush | `~/.config/crush` + `~/.local/share/crush` | 同左 | `%USERPROFILE%\.config\crush` + `%LOCALAPPDATA%\crush` | `CRUSH_GLOBAL_CONFIG` |
| MiMo Code | `~/.config/mimocode` + `~/.local/share/mimocode` + cache/state | 同左 | `%USERPROFILE%\.config\mimocode` + `%LOCALAPPDATA%` | `MIMOCODE_HOME` |
| poolside | `~/.config/poolside` | `~/.config/poolside` | `%USERPROFILE%\.config\poolside` | — |
| Peezy CLI | `~/.peezy` | `~/.peezy` | `%USERPROFILE%\.peezy` | — |
| opencode | `~/.config/opencode` | `~/.config/opencode` | `%USERPROFILE%\.config\opencode` | — |
| Qwen Code | `~/.qwen` | `~/.qwen` | `%USERPROFILE%\.qwen` | `QWEN_HOME` |
| Kimi CLI | `~/.kimi` | `~/.kimi` | `%USERPROFILE%\.kimi` | `KIMI_SHARE_DIR` |
| Genie | `~/.cosine` | `~/.cosine` | `%USERPROFILE%\.cosine` | — |

### 独立 IDE

| Agent | Linux | macOS | Windows |
|-------|-------|-------|---------|
| Cursor | `~/.config/Cursor`, `~/.cursor` | `~/Library/Application Support/Cursor`, `~/.cursor` | `%APPDATA%\Cursor`, `~/.cursor` |
| Zed | `~/.config/zed`, `~/.local/share/zed`, `~/.cache/zed` | `~/Library/Application Support/Zed`, `Caches/Zed`, `Logs/Zed` | `%APPDATA%\Zed`, `%LOCALAPPDATA%\Zed` |
| Kiro | `~/.kiro` | `~/Library/Application Support/Kiro`, `~/.kiro` | `%APPDATA%\Kiro`, `~/.kiro` |
| Qoder | `~/.config/Qoder`, `~/.qoder` | `~/Library/Application Support/Qoder`, `~/.qoder` | `%APPDATA%\Qoder`, `%LOCALAPPDATA%\Qoder`, `~/.qoder` |
| Windsurf | `~/.codeium/windsurf` | `~/.codeium/windsurf` | `%USERPROFILE%\.codeium\windsurf` |
| Devin | `~/.codeium/windsurf` | `~/.codeium/windsurf` | `%USERPROFILE%\.codeium\windsurf` |

### 代理扩展（有全局状态者）

| Agent | 全局状态根 | 说明 |
|-------|-----------|------|
| Continue | `~/.continue` | VS Code globalStorage 亦有 |
| Cline | `~/.cline` + `~/Documents/Cline` | VS Code: `saoudrizwan` |
| Amazon Q | `~/.aws/amazonq` | 项目 `.amazonq/` |
| Amp | `~/.config/amp` + `~/.amp/oauth` | — |

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
5. **Aider** 没有全局状态目录，只有 `~/.aider/` 存 OAuth keys，需配合 `-IncludeProjectLocal` 清项目 `.aider.*`。
6. **部分路径为推断**：Google Antigravity（网站无技术文档）、Genie（repo 404 / 域名已出售，标记 UNVERIFIED）、Qoder（部分路径来自社区 reset 工具）、poolside（state 路径未公开）。这些在 `agents.json` 的 notes 中均有标注。
7. **Zed 用 "extensions" 不用 "plugins"** — 分类术语以官方为准。

## License

MIT
