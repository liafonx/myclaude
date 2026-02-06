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
`codeagent-wrapper` 默认始终从 `cexll/myclaude` 的 Releases 下载，除非设置 `CODEAGENT_WRAPPER_REPO` 覆盖。

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
