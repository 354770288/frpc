# frpc 一键管理脚本（优化版）

> 支持自动版本识别（TOML / INI）、预配置连通性测试端口、快捷命令、服务管理、配置重建、快速排障。

---

## ✨ 功能概览

| 功能 | 菜单项 | 说明 |
|------|--------|------|
| 安装 frpc | 1 | 自动检测系统架构、获取版本、下载并创建 systemd 服务，预配置 3547 测试端口 |
| 更新 frpc 配置 | 2 | 编辑或重新生成配置文件（保留 3547 端口） |
| 更改 frps 服务器 | 3 | 直接修改 serverAddr / server_addr 与端口 |
| 重启 frpc 服务 | 4 | 优雅重启并显示状态 |
| 查看 frpc 状态 | 5 | 展示 systemd 状态 + 最近 10 行日志 |
| 查看配置文件 | 6 | 输出当前配置内容 |
| 连通性测试（新） | 7 | 复用现有配置，通过预设 3547 端口测试访问外网 |
| 卸载 frpc | 8 | 完整卸载（含服务与目录） |
| 安装快捷命令 | 9 | 安装全局 `frp` 命令 |
| 卸载快捷命令 | 10 | 移除全局命令 |
| 退出 | 0 | 退出脚本 |

---

## 🚀 快速开始

```bash
# 下载脚本
curl -O https://raw.githubusercontent.com/354770288/frpc/main/frpc_install.sh
chmod +x frpc_install.sh

# 运行（需 root）
sudo ./frpc_install.sh
```

或者安装快捷命令后直接运行：
```bash
sudo ./frpc_install.sh 9   # 安装快捷命令
frp                      # 打开菜单
```

---

## 🧠 智能特性

- 自动判断当前 frp 版本是否使用 **TOML（v0.52.0+）** 或 **INI（旧版本）**
- 安装时自动创建对应格式配置文件
- 预置连通性测试代理条目（remotePort = 3547）
- 支持通过参数非交互调用（便于脚本集成 / 运维批量化）

---

## 🧩 支持的快捷参数调用

| 命令 | 等价菜单 | 示例 |
|------|----------|------|
| frp install | 1 | `frp install` |
| frp config | 2 | `frp config` |
| frp server | 3 | `frp server` |
| frp restart | 4 | `frp restart` |
| frp status | 5 | `frp status` |
| frp view | 6 | `frp view` |
| frp test | 7 | `frp test` |
| frp uninstall | 8 | `frp uninstall` |
| frp shortcut | 9 | `frp shortcut` |
| frp unshortcut | 10 | `frp unshortcut` |

> 未安装快捷命令时可用：`./frpc_install.sh test` 等

---

## 🛠 配置文件说明

### 1. TOML（frp v0.52.0+）

安装后生成示例：
```toml
serverAddr = "your.frp.server.com"
serverPort = 7000
# auth.token = "your_token_here"

transport.tcpMux = true
transport.poolCount = 1

log.to = "./frpc.log"
log.level = "trace"
log.maxDays = 2

[[proxies]]
name = "tcp_xxxxx"
type = "tcp"
localIP = "127.0.0.1"
localPort = 1122
remotePort = 1122

[[proxies]]
name = "connectivity_test_3547"
type = "tcp"
localIP = "127.0.0.1"
localPort = 3547
remotePort = 3547
```

### 2. INI（旧版 < v0.52.0）

```ini
[common]
server_addr = your.frp.server.com
server_port = 7000
# token = your_token_here
log_file = ./frpc.log
log_level = trace
log_max_days = 2
tcp_mux = true

[tcp_xxxxx]
type = tcp
local_ip = 127.0.0.1
local_port = 1122
remote_port = 1122

[connectivity_test_3547]
type = tcp
local_ip = 127.0.0.1
local_port = 3547
remote_port = 3547
```

### 添加新代理（示例）

TOML：
```toml
[[proxies]]
name = "web_8080"
type = "tcp"
localIP = "127.0.0.1"
localPort = 8080
remotePort = 18080
```

INI：
```ini
[web_8080]
type = tcp
local_ip = 127.0.0.1
local_port = 8080
remote_port = 18080
```

---

## 🌐 连通性测试（选项 7）

测试目标：验证 frpc 是否成功连上 frps 且链路可透传访问外网。

流程包括：
1. 检查服务是否运行
2. 确认配置文件是否包含 3547 代理
3. 启动本地 SOCKS5 测试（端口 3547）
4. 通过 `curl --socks5 <frps>:3547 https://www.google.com/` 验证可达性
5. 输出延迟 / HTTP 状态 / 连接阶段结果
6. 自动清理测试进程

成功输出示例：
```
✓ 连通性测试成功！
✓ frpc 与 frps 服务器连接正常
✓ 可以正常通过代理访问外部网站
```

失败常见错误：
| 错误码 | 说明 | 处理建议 |
|--------|------|----------|
| 7 | 连接被拒绝 | 检查 frps 是否放行 3547 |
| 28/124 | 超时 | 网络丢包 / frps 未响应 |
| 56 | 连接中断 | 中间链路被重置（可能是防火墙） |

> 注意：frps 端需要放行 remotePort=3547（或在防火墙中开放），否则测试无意义。

---

## 🔄 重新生成配置

如果配置损坏或想恢复初始模板：
```
frp config   # 选择“2. 重新生成配置文件”
```
然后编辑：
```
vim /usr/local/frp/frpc.toml   # 或 frpc.ini
systemctl restart frpc
```

---

## 🧪 常用命令速查

```bash
# 安装最新版
frp install

# 指定版本（交互选择输入）
frp install

# 查看服务状态
frp status

# 快速查看日志
journalctl -u frpc -n 30 --no-pager

# 重启
frp restart

# 连通性测试
frp test

# 卸载
frp uninstall
```

---

## 🧹 卸载

```bash
frp uninstall
# 移除快捷方式（如已安装）
frp unshortcut
```

卸载会删除：
- /usr/local/frp/
- systemd 服务文件 /etc/systemd/system/frpc.service

---

## 🔐 安全建议

| 项目 | 建议 |
|------|------|
| token / auth | 必须启用（生产环境） |
| 日志级别 | trace 仅用于调试，上线改为 info 或 warning |
| remotePort | 避免使用易扫描的 80/22 等敏感端口 |
| 文件权限 | 配置可限制为 600 并设定运行用户 |
| 防火墙 | 仅放行必要的 remotePort / server_port |

---

## 🛠 故障排查

| 现象 | 排查建议 |
|------|----------|
| 服务无法启动 | `systemctl status frpc` + `journalctl -u frpc -n 50` |
| 连通性测试失败 | 确认 frps 放行 3547 / frps 端是否有对应配置 |
| 配置不生效 | 修改后是否重启：`systemctl restart frpc` |
| 版本不兼容 | 确认当前 frp 版本：`/usr/local/frp/frpc --version` |
| 高延迟 | 检查网络 RTT / 关闭不必要的 proxies |

---

## 🧾 版本检测逻辑

脚本通过解析 frpc 版本号：
- 当版本号 >= v0.52.0 使用 TOML
- 否则使用 INI
- 重新生成配置会保留检测逻辑

---

## 🤝 贡献

欢迎提交：
- 脚本改进
- 新功能建议
- Bug 反馈

Fork 项目后 PR 或直接开 Issue。

---

## 📄 许可证

本脚本遵循 MIT License（若需可添加 LICENSE 文件）。

---

## 📝 变更记录（简述）

| 日期 | 更新内容 |
|------|----------|
| 2025-01-14 | 增加连通性测试、端口预配置、快捷命令、版本识别 |
| 2025-01-14 | 优化服务管理、交互提示与错误处理 |

---

## 🔚 结语

如果该脚本对你有帮助，欢迎 Star 支持一下！
问题反馈 / 功能建议：直接提交 Issue。

祝使用愉快 🛠️
