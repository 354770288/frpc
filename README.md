# FRPC 管理脚本

一个功能完整的 FRPC (Fast Reverse Proxy Client) 管理脚本，支持自动安装、配置和管理 frpc 服务。

## 功能特性

- 🚀 **一键安装**: 自动下载并安装指定版本的 frpc
- 🔧 **配置管理**: 支持编辑和更新 frpc 配置文件
- 🔄 **版本兼容**: 自动识别并支持 INI (< 0.52.0) 和 TOML (>= 0.52.0) 配置格式
- 🏗️ **架构支持**: 自动检测系统架构 (x86_64/aarch64)
- 🎛️ **服务管理**: 启动、停止、重启和查看 frpc 服务状态
- 📝 **日志监控**: 查看和监控 frpc 运行日志
- 🔗 **快捷命令**: 安装全局快捷命令，随时随地管理 frpc
- 🛡️ **安全卸载**: 完整清理 frpc 相关文件和服务

## 系统要求

- Linux 系统 (支持 systemd)
- Root 权限
- 网络连接 (用于下载 frp 安装包)
- 支持的架构: x86_64 (amd64) 或 aarch64 (arm64)

## 快速开始

### 下载脚本

```bash
wget https://raw.githubusercontent.com/354770288/frpc/main/frpc_install.sh
chmod +x frpc_install.sh
```

### 运行脚本

```bash
sudo ./frpc_install.sh
```

## 功能菜单

脚本提供直观的菜单界面，包含以下功能：

1. **安装 frpc** - 下载并安装指定版本的 frpc
2. **更新 frpc 配置** - 使用编辑器修改配置文件
3. **更改 frps 服务器** - 快速修改服务器地址
4. **重启 frpc** - 重启 frpc 服务
5. **查看 frpc 状态** - 显示服务状态和运行信息
6. **查看 frpc 配置** - 显示当前配置文件内容
7. **卸载 frpc** - 完全移除 frpc 及相关文件
8. **安装快捷命令** - 安装全局 `frp` 命令
9. **卸载快捷命令** - 移除全局快捷命令

## 目录结构

```
/usr/local/frp/
├── frpc                 # frpc 可执行文件
├── frpc.ini/.toml      # 配置文件 (取决于版本)
└── frpc.log            # 日志文件

/lib/systemd/system/
└── frpc.service        # systemd 服务文件

/usr/local/bin/
└── frp                 # 快捷命令 (可选)
```

## 配置文件格式

### TOML 格式 (frp >= 0.52.0)

```toml
# frpc.toml
serverAddr = "your.frp.server.com"
serverPort = 7000
# auth.token = "your_token_here"

# 优化配置
transport.tcpMux = true
log.to = "./frpc.log"
log.level = "trace"
log.maxDays = 2

# TCP代理示例
[[proxies]]
name = "tcp_example"
type = "tcp"
localIP = "127.0.0.1"
localPort = 1122
remotePort = 1122
```

### INI 格式 (frp < 0.52.0)

```ini
[common]
server_addr = your.frp.server.com
server_port = 7000
# token = your_token_here

log_file = ./frpc.log
log_level = trace
log_max_days = 2
tcp_mux = true

[tcp_example]
type = tcp
local_ip = 127.0.0.1
local_port = 1122
remote_port = 1122
```

## 使用示例

### 安装 frpc

1. 运行脚本选择 `1` 安装 frpc
2. 输入版本号，如 `0.54.0` 或 `0.38.0`
3. 脚本自动下载、安装并配置服务

### 配置 frpc

1. 选择 `2` 更新配置
2. 使用编辑器修改配置文件
3. 保存后选择重启服务使配置生效

### 快速更改服务器

1. 选择 `3` 更改 frps 服务器
2. 输入新的服务器地址
3. 脚本自动更新配置并重启服务

## 快捷命令

安装快捷命令后，可以在任何目录使用：

```bash
# 启动管理界面
frp

# 以管理员权限启动
sudo frp
```

## 服务管理

### 使用 systemctl 命令

```bash
# 启动服务
sudo systemctl start frpc

# 停止服务
sudo systemctl stop frpc

# 重启服务
sudo systemctl restart frpc

# 查看状态
sudo systemctl status frpc

# 开机自启
sudo systemctl enable frpc

# 禁用自启
sudo systemctl disable frpc

# 查看日志
sudo journalctl -u frpc -f
```

## 故障排除

### 常见问题

1. **权限问题**: 确保使用 `sudo` 运行脚本
2. **网络问题**: 检查网络连接，确保能访问 GitHub
3. **版本问题**: 确认输入的版本号格式正确 (如: 0.54.0)
4. **架构问题**: 脚本自动检测，目前支持 x86_64 和 aarch64

### 日志查看

```bash
# 查看 frpc 日志文件
sudo tail -f /usr/local/frp/frpc.log

# 查看系统服务日志
sudo journalctl -u frpc -n 50
```

## 注意事项

- 脚本需要 root 权限运行
- 安装前会自动检查并提示卸载现有版本
- 配置文件修改后需要重启服务才能生效
- 卸载操作会删除所有相关文件，请谨慎操作
- 建议在修改配置前备份原配置文件

## 贡献

欢迎提交 Issue 和 Pull Request 来改进这个脚本。

## 许可证

本项目采用开源许可证，详情请查看仓库中的 LICENSE 文件。

## 相关链接

- [FRP 官方仓库](https://github.com/fatedier/frp)
- [FRP 官方文档](https://gofrp.org/)
