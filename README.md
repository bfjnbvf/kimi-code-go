# Kimi Code Go

一个轻量级 macOS 启动器，用于管理 Kimi Code Web 的本地服务。

双击打开 → 自动启动本地 Kimi Web 服务器 → 打开浏览器 → 关闭标签页约 60 秒后自动关闭服务器并退出。

## 功能

- **自动启动**：检测不到已有 Kimi 服务时，自动在默认端口（58627）启动新服务
- **智能接管**：检测到已有 Kimi 服务时（任意端口），直接打开浏览器并进入监听模式
- **自动退出**：关闭浏览器标签页后，连续 2 次轮询（约 60 秒）无连接 → 关闭服务器 → App 退出
- **端口冲突提醒**：默认端口被非 Kimi 进程占用时，弹窗提醒后退出
- **Token 轮转容错**：会话中途执行 `kimi web rotate-token` 后，自动重新读取令牌

## 系统要求

- macOS（任意版本）
- 已安装 Kimi Code CLI，位于以下任一路径：
  - `~/.kimi-code/bin/kimi`
  - `~/.kimi/bin/kimi`
  - `/usr/local/bin/kimi`
  - `/opt/homebrew/bin/kimi`

App 在运行时动态搜索 kimi 二进制，不包含任何用户特定的绝对路径。

## 构建与安装

```sh
./build.sh
cp -R "build/Kimi Code Go.app" /Applications/
```

或直接双击运行 `build/Kimi Code Go.app`。

## 工作原理

```
App 启动
  ├─ 扫描系统中正在运行的 Kimi Web 进程
  │   ├─ 找到 → 打开浏览器，进入监听模式
  │   └─ 未找到 → 检查默认端口
  │       ├─ 被其他进程占用 → 弹窗提醒，退出
  │       └─ 空闲 → 启动新服务器（127.0.0.1:58627）
  │
  ├─ 每 30 秒轮询 /api/v1/connections
  │   ├─ 有连接 → 计数器归零
  │   ├─ 无连接 → 计数器 +1
  │   └─ API 不可用 → 尝试重读 token，不计入
  │
  └─ 计数器 ≥ 2 → SIGTERM 关闭服务器 → App 退出
```

## 安全与隐私

- 服务器显式绑定 `127.0.0.1`，不对外暴露
- 保留 Kimi Web 的 Bearer Token 认证，**不使用** `--dangerous-bypass-auth`
- Token 仅在运行期间从本地文件读取，仅作为 HTTP 头发送至 `127.0.0.1`，不存储、不记录、不上传
- 退出时仅对自己启动（或接管）的 Kimi 进程发送 SIGTERM，不影响其他进程
- 若怀疑 Token 泄露，可执行 `kimi web rotate-token` 立即轮转

## 注意事项

- 如果找不到 Token 文件，服务仍会正常启动，但"关闭标签页后自动退出"功能将不可用
- 从 Activity Monitor 强制终止 App 时，`on quit` 不会触发，服务器可能残留，可手动执行 `kimi web kill all`
- 构建脚本使用 ad-hoc 签名，仅适合本地使用；公开发布需替换为 Developer ID 签名并公证

## 许可证

MIT
