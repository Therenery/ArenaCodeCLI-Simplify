# ArenaCodeCLI-Simplify

把 [arena.ai](https://arena.ai) 的 Agent 模式接进本地 CLI 的一套精简装配：一个 CDP 桥、一个 Windows 启动器、一份把 Qwen Code 改造成 Arena CLI 的补丁。

这里放的是**当前实际在跑的版本**，不是设计稿。

## 组成

| 路径 | 作用 |
|---|---|
| `bridge/` | `arena_bridge.js`，Node 单文件桥，监听 `127.0.0.1:17892`，无第三方依赖 |
| `cli-windows/` | `arena.cmd`，Windows 启动器：探 Chrome → 探桥 → 进 TUI |
| `patches/` | `arena-code-cli.patch`，对 Qwen Code 的改造补丁（70 个文件） |

## 架构

```
客户端（arena CLI / arenav2 / 任意 OpenAI 兼容工具）
   │  HTTP 127.0.0.1:17892
   ▼
arena_bridge.js（node，无第三方依赖）
   ├─ POST /v1/chat/completions   OpenAI 兼容，支持 stream
   ├─ POST /ask                   简化接口
   ├─ GET  /health  /v1/models  /debug  /new
   │
   ├─ CDP → Chrome 9222
   │    ├─ Page.addScriptToEvaluateOnNewDocument 注入拦截脚本
   │    └─ 逐字符 keyDown + 真实鼠标点击（tiptap 只认这条路径）
   │
   └─ 旁路 clone 页面自己的 fetch 流
        ├─ direct：/nextjs-api/stream/create-evaluation   a0: 正文  ag: 思考  ad: 结束
        └─ agent ：/ai-proxy/realtime/v1/sessions/{id}/out  SSE batch → text-delta / reasoning-delta / tool-input-available / finish
```

拦截式指不伪造请求、不碰 reCAPTCHA、不读取 cookie。桥用 CDP 驱动一个真实的 Chrome 标签页，用真实键盘事件输入，旁路读取页面自己发出的流。

## 快速开始

### 1. 起 Chrome

需要一个带远程调试端口的独立 profile：

```cmd
"C:\Program Files\Google\Chrome\Application\chrome.exe" ^
  --remote-debugging-port=9222 ^
  --user-data-dir="F:\__AI__\profiles\arena" ^
  --no-first-run --no-default-browser-check
```

在这个窗口里手动登录 arena.ai，切到 **Agent** 模式。登录态会留在这个 profile 里。

### 2. 起桥

```cmd
cd bridge
node arena_bridge.js
```

体检：

```cmd
curl http://127.0.0.1:17892/health
```

### 3. 起 CLI

```cmd
cd patches
git clone https://github.com/QwenLM/qwen-code.git
cd qwen-code
git checkout 1ccf0d43f35e51389573d87e5ae634c4d782f049
git apply ..\arena-code-cli.patch
npm install
npm run build
```

然后把 `cli-windows\arena.cmd` 里的环境变量指向你的实际路径，或直接设好环境变量后从任意目录调用。

## 环境变量

| 变量 | 默认值 | 说明 |
|---|---|---|
| `ARENA_HOME` | `%~dp0..\qwen-code` | 打好补丁并 build 过的 Qwen Code 根目录 |
| `ARENA_BRIDGE_DIR` | `%~dp0..\bridge` | 桥所在目录 |
| `ARENA_SYSTEM_MD` | `%~dp0..\arena-system.md` | 可选，系统提示词文件；文件不存在则忽略 |
| `ARENA_API_KEY` | `sk-arena-local` | 占位值，桥不校验 |
| `ARENA_CWD` | `%USERPROFILE%\arena-cwd` | CLI 启动时的工作目录 |
| `ARENA_CHROME` | `C:\Program Files\Google\Chrome\Application\chrome.exe` | Chrome 路径 |
| `ARENA_PROFILE` | `%~dp0..\profiles\arena` | Chrome 调试 profile |
| `ARENA_NO_LAUNCH` | 未设置 | 设成任意值则跳过 Chrome/桥的自启 |

## 补丁改了什么

`arena-code-cli.patch` 相对 Qwen Code `1ccf0d43`，70 个文件，主要几块：

- `packages/cli/src/ui/arena-mode.ts`、`commands/arena-text-commands.ts` — Arena 模式与文本指令
- `packages/cli/src/config/storage-paths-lite.ts` — 精简版存储路径
- `packages/core/src/core/prompts.ts` — 提示词调整
- `packages/core/src/memory/*`、`utils/paths.ts` — 记忆与路径
- `packages/cli/src/ui/components/*` — Header / Footer / AsciiArt / MainContent 的品牌与状态栏
- i18n 各语言同步

补丁不含 `bridge/`，桥是独立组件。

## 已验证

| 项 | 结果 |
|---|---|
| 平台 | Windows 11 x64 |
| Node | v22.22.3 |
| 桥体检 | `/health` 返回 Chrome 已连接、队列 0/4 |
| CLI 版本 | `arena --version` → `0.26.4` |
| 单发 | `arena -p '只回一个字：好'` → `好` |
| 补丁 | `git apply --check` 在 `1ccf0d43` 上通过 |

## 已知限制

- 只测过 Windows；`arena.cmd` 是 cmd 批处理，Linux/macOS 需要自己写启动脚本
- Chrome 必须是**带调试端口**的独立实例，日常用的那个 Chrome 抢不到 9222
- 桥靠真实键盘事件输入，页面结构大改就会失效；`/debug` 是排查入口
- 用 WMI / 计划任务拉起的 Chrome 在 session 0，窗口不可见；遇到人机验证要先杀掉再用可见窗口重启
- arena.ai 的条款自行确认，本项目只做本地工作流桥接

## 相关

- [ArenaCodeCLILite](https://github.com/Therenery/ArenaCodeCLILite) — 同一套桥的纯 Rust 终端客户端，零依赖单二进制
