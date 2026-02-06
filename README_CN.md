# Codeagent 路由工具集

[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Claude Code](https://img.shields.io/badge/Claude-Code-blue)](https://claude.ai/code)
[![Version](https://img.shields.io/badge/Version-6.x-green)](https://github.com/liafonx/myclaude)

> 以 `codeagent` + `codeagent-wrapper` 为核心的单技能子代理路由工具（Codex/Claude/Gemini/OpenCode）

## 快速开始

```bash
npx github:liafonx/myclaude
```

## 核心定位

本仓库当前主线能力只有两部分：
- `skills/codeagent`：子代理创建时的后端路由与调用规范
- `codeagent-wrapper`：多后端执行二进制

其它工作流技能/模块保留在仓库中，仅作为**协作路由参考资料**，不是主要安装目标。

## 核心架构

| 角色 | 智能体 | 职责 |
|------|-------|------|
| **编排者** | Claude Code | 规划、上下文收集、验证 |
| **执行者** | codeagent-wrapper | 代码编辑、测试执行（Codex/Claude/Gemini/OpenCode 后端）|

## 安装与配置

```bash
# 交互式安装器（推荐）
npx github:liafonx/myclaude

# 列出可安装项
npx github:liafonx/myclaude --list

# 检测已安装 modules 并从 GitHub 更新
npx github:liafonx/myclaude --update

# 指定安装目录 / 强制覆盖
npx github:liafonx/myclaude --install-dir ~/.claude --force

# 从你自己的 fork/repo 作为发布源安装
npx github:liafonx/myclaude --repo <your-owner>/<your-repo>
```

`--update` 会在目标安装目录（默认 `~/.claude`，优先读取 `installed_modules.json`）检测已安装模块，并从你选择的仓库更新 codeagent 内容。

默认安装/列表会使用你运行 `npx github:<owner>/<repo>` 对应的仓库内容。
`codeagent-wrapper` 会从 `config.json` 中配置的仓库下载（`modules.codeagent.operations[].repo`，默认 `liafonx/myclaude`）。
如需兼容旧 shell 安装方式，仍可通过 `CODEAGENT_WRAPPER_REPO` 覆盖。

### 模块配置

`config.json` 现在是 codeagent-first：

```json
{
  "modules": {
    "codeagent": { "enabled": true }
  }
}
```

### 运行前依赖

- `codeagent-wrapper` 二进制（由安装器处理）
- 后端 CLI 需单独安装：
  - `codex`
  - `claude`
  - `gemini`
  - `opencode`（可选）

可执行：
```bash
bash ~/.claude/skills/codeagent/scripts/check_backends.sh
```
进行本机检查。

### 维护者发布辅助脚本

本地构建 wrapper 发行资产：

```bash
scripts/release_wrapper_assets.sh --tag v1.0.2
```

构建并上传到 GitHub Release：

```bash
scripts/release_wrapper_assets.sh --tag v1.0.2 --upload --repo liafonx/myclaude
```

### 默认模型与参数配置

`codeagent-wrapper` 会读取以下默认配置：

- `~/.codeagent/config.yaml`（全局默认）
- `~/.codeagent/models.json`（agent 预设 + 后端 API 配置）

安装器行为：

- 安装时会从仓库内置模板创建 `~/.codeagent/config.yaml` 与 `~/.codeagent/models.json`（仅当文件不存在时）。
- 如果你已经有自己的配置文件，安装器不会覆盖。

示例 `~/.codeagent/config.yaml`：

```yaml
backend: codex
model: gpt-4.1
reasoning-effort: medium
agent: ""
prompt-file: ""
skip-permissions: false
full-output: false
```

示例 `~/.codeagent/models.json`：

```json
{
  "default_backend": "codex",
  "default_model": "gpt-4.1",
  "backends": {
    "codex": {
      "base_url": "https://api.openai.com/v1",
      "api_key": "YOUR_OPENAI_API_KEY",
      "model": "gpt-4.1",
      "reasoning": "medium",
      "use_api": false
    },
    "claude": {
      "base_url": "https://api.anthropic.com",
      "api_key": "YOUR_ANTHROPIC_API_KEY",
      "model": "claude-sonnet-4",
      "reasoning": "medium",
      "skip_permissions": false,
      "use_api": false
    },
    "gemini": {
      "base_url": "https://generativelanguage.googleapis.com",
      "api_key": "YOUR_GEMINI_API_KEY",
      "model": "gemini-2.5-pro",
      "reasoning": "medium",
      "use_api": false
    },
    "opencode": {
      "base_url": "",
      "api_key": "",
      "model": "opencode/grok-code",
      "reasoning": "medium",
      "use_api": false
    }
  },
  "agents": {
    "develop": {
      "backend": "codex",
      "model": "gpt-4.1",
      "prompt_file": "~/.codeagent/agents/develop.md",
      "reasoning": "high",
      "description": "Code development",
      "yolo": false,
      "base_url": "",
      "api_key": "",
      "allowed_tools": [],
      "disallowed_tools": []
    },
    "docs-writer": {
      "backend": "claude",
      "model": "claude-sonnet-4",
      "reasoning": "medium",
      "prompt_file": "~/.codeagent/agents/docs-writer.md",
      "description": "Documentation and structured writing",
      "yolo": false,
      "base_url": "",
      "api_key": "",
      "allowed_tools": [],
      "disallowed_tools": []
    },
    "ui-builder": {
      "backend": "gemini",
      "model": "gemini-2.5-pro",
      "reasoning": "medium",
      "prompt_file": "~/.codeagent/agents/ui-builder.md",
      "description": "UI, layout, and accessibility tasks",
      "yolo": false,
      "base_url": "",
      "api_key": "",
      "allowed_tools": [],
      "disallowed_tools": []
    },
    "oss-coder": {
      "backend": "opencode",
      "model": "opencode/grok-code",
      "reasoning": "medium",
      "prompt_file": "~/.codeagent/agents/oss-coder.md",
      "description": "Open-source/local model workflow",
      "yolo": false,
      "base_url": "",
      "api_key": "",
      "allowed_tools": [],
      "disallowed_tools": []
    }
  }
}
```

配置优先级（高 -> 低）：

1. CLI 参数（`--backend`、`--model`、`--reasoning-effort`）
2. `models.json` 中 `--agent` 预设
3. `models.json` 中后端默认值（`backends.<name>.model`、`backends.<name>.reasoning`、`backends.<name>.skip_permissions`）
4. `config.yaml` 与 `CODEAGENT_*` 环境变量（全局兜底）
5. 内置默认值

后端参数说明：

- Codex：支持 `model` 与 `reasoning-effort`
- Claude：支持 `model`、`skip-permissions`、`base_url`/`api_key`
- Gemini：支持 `model`、`base_url`/`api_key`（同时会读取 `~/.gemini/.env`）
- OpenCode：支持 `model`
- `backends.<name>.use_api` 控制 API 注入模式：
  - `false`：忽略 `base_url` / `api_key`，走本机 CLI 登录/会话。
  - `true`：向 CLI 进程注入后端 API 环境变量。

说明：

- 后端调用默认是 CLI 模式（依赖本机 `codex` / `claude` / `gemini` / `opencode` 命令）。
- `base_url` / `api_key` 只是可选的后端环境注入，不是必填。

## 后端 CLI 要求

| 后端 | 必需功能 |
|------|----------|
| Codex | `codex e`, `--json`, `-C`, `resume` |
| Claude | `--output-format stream-json`, `-r` |
| Gemini | `-o stream-json`, `-y`, `-r` |
| OpenCode | `opencode run --format json` |

## 文档

- [codeagent-wrapper](codeagent-wrapper/README.md)
- [agent.md](agent.md) — 工作流技能与 codeagent 路由技能协作协议
- [skills/codeagent/SKILL.md](skills/codeagent/SKILL.md) — 路由规则与调用格式
- [Plugin System](PLUGIN_README.md)

## 故障排查

**Codex wrapper 未找到：**
```bash
# 选择：codeagent-wrapper
npx github:liafonx/myclaude
```

**模块未加载：**
```bash
cat ~/.claude/installed_modules.json
npx github:liafonx/myclaude --force
```

**后端 CLI 错误：**
```bash
which codex && codex --version
which claude && claude --version
which gemini && gemini --version
which opencode && opencode --version
```

## FAQ

| 问题 | 解决方案 |
|------|----------|
| "Unknown event format" | 日志显示问题，可忽略 |
| Gemini 无法读取 .gitignore 文件 | 从 .gitignore 移除或使用其他后端 |
| Codex 权限拒绝 | 在 ~/.codex/config.yaml 设置 `approval_policy = "never"` |

更多问题请访问 [GitHub Issues](https://github.com/liafonx/myclaude/issues)。

## 许可证

AGPL-3.0 - 查看 [LICENSE](LICENSE)

### 商业授权

如需商业授权（无需遵守 AGPL 义务），请联系：evanxian9@gmail.com

## 支持

- [GitHub Issues](https://github.com/liafonx/myclaude/issues)
