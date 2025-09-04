#!/bin/bash

# frpc一键安装脚本 - 优化版
# 支持连通性测试和端口预配置
# Author: 354770288
# Date: 2025-01-14

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# 颜色定义
Red="\033[31m"
Green="\033[32m"
Yellow="\033[33m"
Blue="\033[36m"
Font="\033[0m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
YellowBG="\033[43;37m"

# 全局变量
FRP_NAME="frpc"
FRP_PATH="/usr/local/frp"

# 检测系统架构
check_sys() {
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
    elif grep -q -E -i "debian" /etc/issue; then
        release="debian"
    elif grep -q -E -i "ubuntu" /etc/issue; then
        release="ubuntu"
    elif grep -q -E -i "centos|red hat|redhat" /etc/issue; then
        release="centos"
    elif grep -q -E -i "debian" /proc/version; then
        release="debian"
    elif grep -q -E -i "ubuntu" /proc/version; then
        release="ubuntu"
    elif grep -q -E -i "centos|red hat|redhat" /proc/version; then
        release="centos"
    fi
    
    bit=$(uname -m)
    case $bit in
        x86_64) bit="amd64" ;;
        aarch64) bit="arm64" ;;
        armv7l) bit="arm" ;;
        *) echo -e "${Red}不支持的系统架构: $bit${Font}"; exit 1 ;;
    esac
}

# 安装依赖
install_deps() {
    if [[ ${release} == "centos" ]]; then
        yum update -y && yum install curl wget tar -y
    else
        apt update -y && apt install curl wget tar -y
    fi
}

# 获取最新版本号
get_latest_version() {
    local latest_version=$(curl -s "https://api.github.com/repos/fatedier/frp/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [[ -z "$latest_version" ]]; then
        latest_version="v0.58.1"  # 备用版本
    fi
    echo "$latest_version"
}

# 判断是否为TOML版本
is_toml_version() {
    local version=$1
    version=${version#v}  # 移除v前缀
    
    # 提取主版本号和次版本号
    local major=$(echo "$version" | cut -d. -f1)
    local minor=$(echo "$version" | cut -d. -f2)
    
    # v0.52.0及以上版本使用TOML
    if [ "$major" -gt 0 ] || ([ "$major" -eq 0 ] && [ "$minor" -ge 52 ]); then
        return 0  # true
    else
        return 1  # false
    fi
}

# 获取配置文件扩展名
get_config_extension() {
    local version=$1
    if is_toml_version "$version"; then
        echo "toml"
    else
        echo "ini"
    fi
}

# 获取现有配置文件路径
get_existing_config_path() {
    if [ -f "${FRP_PATH}/${FRP_NAME}.toml" ]; then
        echo "${FRP_PATH}/${FRP_NAME}.toml"
    elif [ -f "${FRP_PATH}/${FRP_NAME}.ini" ]; then
        echo "${FRP_PATH}/${FRP_NAME}.ini"
    else
        echo ""
    fi
}

# 创建配置文件（优化版 - 预配置3547端口）
create_config() {
    local version=$1
    local config_ext=$(get_config_extension "$version")
    
    echo -e "${Blue}正在创建 ${config_ext^^} 格式配置文件...${Font}"
    
    if is_toml_version "$version"; then
        # 创建TOML格式配置文件
        cat >${FRP_PATH}/${FRP_NAME}.toml <<EOF
# frpc.toml
serverAddr = "your.frp.server.com"
serverPort = 7000
# auth.token = "your_token_here"

# 优化 TCP 传输性能
transport.tcpMux = true
transport.poolCount = 1

# 配置日志
log.to = "./frpc.log"
log.level = "trace"
log.maxDays = 2

# TCP代理示例 - 自定义端口
[[proxies]]
name = "tcp_${RANDOM}"
type = "tcp"
localIP = "127.0.0.1"
localPort = 1122
remotePort = 1122

# 连通性测试专用端口 - 预配置 3547
[[proxies]]
name = "connectivity_test_3547"
type = "tcp"
localIP = "127.0.0.1"
localPort = 3547
remotePort = 3547
EOF
    else
        # 创建INI格式配置文件
        cat >${FRP_PATH}/${FRP_NAME}.ini <<EOF
[common]
server_addr = your.frp.server.com
server_port = 7000
# token = your_token_here

# 配置日志
log_file = ./frpc.log
log_level = trace
log_max_days = 2
# 网络层优化
tcp_mux = true

[tcp_${RANDOM}]
type = tcp
local_ip = 127.0.0.1
local_port = 1122
remote_port = 1122

# 连通性测试专用端口 - 预配置 3547
[connectivity_test_3547]
type = tcp
local_ip = 127.0.0.1
local_port = 3547
remote_port = 3547
EOF
    fi
    
    echo -e "${Green}✓ 已创建 ${config_ext^^} 格式配置文件，包含连通性测试端口 3547${Font}"
}

# 下载frpc
download_frpc() {
    local version=$1
    
    echo -e "${Blue}开始下载 frpc ${version}...${Font}"
    
    # 构建下载URL
    local download_url="https://github.com/fatedier/frp/releases/download/${version}/frp_${version#v}_linux_${bit}.tar.gz"
    local tmp_file="/tmp/frp_${version#v}_linux_${bit}.tar.gz"
    
    # 下载文件
    if ! wget -O "$tmp_file" "$download_url"; then
        echo -e "${Red}下载失败！${Font}"
        return 1
    fi
    
    # 创建目录
    mkdir -p "$FRP_PATH"
    
    # 解压
    if ! tar -xzf "$tmp_file" -C /tmp/; then
        echo -e "${Red}解压失败！${Font}"
        return 1
    fi
    
    # 复制文件
    local extract_dir="/tmp/frp_${version#v}_linux_${bit}"
    cp "${extract_dir}/${FRP_NAME}" "${FRP_PATH}/"
    chmod +x "${FRP_PATH}/${FRP_NAME}"
    
    # 清理临时文件
    rm -f "$tmp_file"
    rm -rf "$extract_dir"
    
    echo -e "${Green}✓ frpc 下载完成${Font}"
    return 0
}

# 创建systemd服务
create_service() {
    local config_path="$1"
    
    cat >/etc/systemd/system/${FRP_NAME}.service <<EOF
[Unit]
Description=Frp client service
After=network.target

[Service]
Type=simple
User=nobody
Restart=on-failure
RestartSec=5s
ExecStart=${FRP_PATH}/${FRP_NAME} -c ${config_path}
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable ${FRP_NAME}
    echo -e "${Green}✓ 系统服务创建完成${Font}"
}

# 检查是否已安装
check_installed() {
    if [[ -f "${FRP_PATH}/${FRP_NAME}" ]]; then
        return 0
    else
        return 1
    fi
}

# 安装frpc
install_frpc() {
    echo -e "${Green}=========================================================================${Font}"
    echo -e "${YellowBG}                            安装 frpc                                   ${Font}"
    echo -e "${Green}=========================================================================${Font}"
    
    if check_installed; then
        echo -e "${Yellow}frpc 已安装！是否重新安装？(y/n)${Font}"
        read -p "" reinstall
        if [[ $reinstall != "y" && $reinstall != "Y" ]]; then
            return
        fi
    fi
    
    check_sys
    install_deps
    
    # 获取版本信息
    echo -e "${Blue}获取最新版本信息...${Font}"
    local latest_version=$(get_latest_version)
    echo -e "${Green}最新版本: ${latest_version}${Font}"
    
    # 询问版本选择
    echo -e "${Yellow}选择安装版本:${Font}"
    echo -e "${Blue}1. 安装最新版本 (${latest_version})${Font}"
    echo -e "${Blue}2. 手动输入版本号${Font}"
    read -p "请选择 [1-2]: " version_choice
    
    case $version_choice in
        1)
            install_version="$latest_version"
            ;;
        2)
            read -p "请输入版本号 (如: v0.58.1): " install_version
            if [[ ! $install_version =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo -e "${Red}版本号格式错误！${Font}"
                return 1
            fi
            ;;
        *)
            echo -e "${Red}无效选择！${Font}"
            return 1
            ;;
    esac
    
    # 下载并安装
    if download_frpc "$install_version"; then
        # 创建配置文件（包含3547端口）
        create_config "$install_version"
        
        # 获取配置文件路径
        local config_ext=$(get_config_extension "$install_version")
        local config_path="${FRP_PATH}/${FRP_NAME}.${config_ext}"
        
        # 创建服务
        create_service "$config_path"
        
        echo -e "${Green}=========================================================================${Font}"
        echo -e "${Green}✓ frpc 安装完成！${Font}"
        echo -e "${Blue}配置文件: ${config_path}${Font}"
        echo -e "${Blue}请编辑配置文件后使用以下命令启动服务:${Font}"
        echo -e "${Yellow}  systemctl start ${FRP_NAME}${Font}"
        echo -e "${Yellow}  systemctl status ${FRP_NAME}${Font}"
        echo -e "${Green}✓ 已预配置连通性测试端口 3547${Font}"
        echo -e "${Green}=========================================================================${Font}"
    else
        echo -e "${Red}安装失败！${Font}"
        return 1
    fi
}

# 更新配置
update_config() {
    echo -e "${Green}=========================================================================${Font}"
    echo -e "${YellowBG}                           更新 frpc 配置                               ${Font}"
    echo -e "${Green}=========================================================================${Font}"
    
    if ! check_installed; then
        echo -e "${Red}frpc 未安装！${Font}"
        return 1
    fi
    
    local config_path=$(get_existing_config_path)
    if [[ -z "$config_path" ]]; then
        echo -e "${Red}配置文件不存在！${Font}"
        return 1
    fi
    
    echo -e "${Blue}当前配置文件: ${config_path}${Font}"
    echo -e "${Yellow}请选择操作:${Font}"
    echo -e "${Blue}1. 编辑配置文件${Font}"
    echo -e "${Blue}2. 重新生成配置文件${Font}"
    read -p "请选择 [1-2]: " config_choice
    
    case $config_choice in
        1)
            if command -v nano > /dev/null; then
                nano "$config_path"
            elif command -v vim > /dev/null; then
                vim "$config_path"
            else
                echo -e "${Red}未找到文本编辑器！${Font}"
                return 1
            fi
            ;;
        2)
            # 检测当前版本
            local current_version=$(${FRP_PATH}/${FRP_NAME} --version 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            if [[ -z "$current_version" ]]; then
                current_version="v0.58.1"  # 默认版本
            fi
            create_config "$current_version"
            ;;
        *)
            echo -e "${Red}无效选择！${Font}"
            return 1
            ;;
    esac
    
    echo -e "${Green}配置更新完成！${Font}"
}

# 更改frps服务器
change_server() {
    echo -e "${Green}=========================================================================${Font}"
    echo -e "${YellowBG}                          更改 frps 服务器                              ${Font}"
    echo -e "${Green}=========================================================================${Font}"
    
    if ! check_installed; then
        echo -e "${Red}frpc 未安装！${Font}"
        return 1
    fi
    
    local config_path=$(get_existing_config_path)
    if [[ -z "$config_path" ]]; then
        echo -e "${Red}配置文件不存在！${Font}"
        return 1
    fi
    
    local config_ext="${config_path##*.}"
    
    echo -e "${Blue}当前配置文件: ${config_path} (${config_ext^^} 格式)${Font}"
    
    # 显示当前服务器信息
    if [[ "$config_ext" == "toml" ]]; then
        local current_server=$(grep '^serverAddr' "$config_path" | cut -d'"' -f2 2>/dev/null)
        local current_port=$(grep '^serverPort' "$config_path" | cut -d'=' -f2 | tr -d ' ' 2>/dev/null)
    else
        local current_server=$(grep '^server_addr' "$config_path" | cut -d'=' -f2 | tr -d ' ' 2>/dev/null)
        local current_port=$(grep '^server_port' "$config_path" | cut -d'=' -f2 | tr -d ' ' 2>/dev/null)
    fi
    
    echo -e "${Yellow}当前服务器: ${current_server:-"未设置"}${Font}"
    echo -e "${Yellow}当前端口: ${current_port:-"未设置"}${Font}"
    
    # 输入新的服务器信息
    read -p "请输入新的 frps 服务器地址: " new_server
    read -p "请输入新的 frps 服务器端口 [7000]: " new_port
    
    if [[ -z "$new_server" ]]; then
        echo -e "${Red}服务器地址不能为空！${Font}"
        return 1
    fi
    
    new_port=${new_port:-7000}
    
    # 更新配置文件
    if [[ "$config_ext" == "toml" ]]; then
        sed -i "s/^serverAddr = .*/serverAddr = \"$new_server\"/" "$config_path"
        sed -i "s/^serverPort = .*/serverPort = $new_port/" "$config_path"
    else
        sed -i "s/^server_addr = .*/server_addr = $new_server/" "$config_path"
        sed -i "s/^server_port = .*/server_port = $new_port/" "$config_path"
    fi
    
    echo -e "${Green}✓ 服务器配置已更新${Font}"
    echo -e "${Blue}新服务器: $new_server:$new_port${Font}"
    echo -e "${Yellow}请重启 frpc 服务使配置生效${Font}"
}

# 重启frpc
restart_frpc() {
    echo -e "${Green}=========================================================================${Font}"
    echo -e "${YellowBG}                           重启 frpc 服务                               ${Font}"
    echo -e "${Green}=========================================================================${Font}"
    
    if ! check_installed; then
        echo -e "${Red}frpc 未安装！${Font}"
        return 1
    fi
    
    echo -e "${Blue}正在重启 frpc 服务...${Font}"
    
    systemctl stop ${FRP_NAME}
    sleep 2
    systemctl start ${FRP_NAME}
    sleep 2
    
    if systemctl is-active --quiet ${FRP_NAME}; then
        echo -e "${Green}✓ frpc 服务重启成功${Font}"
        systemctl status ${FRP_NAME} --no-pager -l
    else
        echo -e "${Red}✗ frpc 服务重启失败${Font}"
        echo -e "${Yellow}查看错误日志:${Font}"
        journalctl -u ${FRP_NAME} --no-pager -l -n 20
    fi
}

# 查看frpc状态
status_frpc() {
    echo -e "${Green}=========================================================================${Font}"
    echo -e "${YellowBG}                           frpc 服务状态                                ${Font}"
    echo -e "${Green}=========================================================================${Font}"
    
    if ! check_installed; then
        echo -e "${Red}frpc 未安装！${Font}"
        return 1
    fi
    
    # 显示服务状态
    echo -e "${Blue}服务状态:${Font}"
    systemctl status ${FRP_NAME} --no-pager -l
    
    echo -e "\n${Blue}最近日志:${Font}"
    journalctl -u ${FRP_NAME} --no-pager -l -n 10
    
    # 显示配置信息
    local config_path=$(get_existing_config_path)
    if [[ -n "$config_path" ]]; then
        local config_ext="${config_path##*.}"
        echo -e "\n${Blue}配置文件: ${config_path} (${config_ext^^} 格式)${Font}"
        
        if [[ "$config_ext" == "toml" ]]; then
            local server=$(grep '^serverAddr' "$config_path" | cut -d'"' -f2 2>/dev/null)
            local port=$(grep '^serverPort' "$config_path" | cut -d'=' -f2 | tr -d ' ' 2>/dev/null)
        else
            local server=$(grep '^server_addr' "$config_path" | cut -d'=' -f2 | tr -d ' ' 2>/dev/null)
            local port=$(grep '^server_port' "$config_path" | cut -d'=' -f2 | tr -d ' ' 2>/dev/null)
        fi
        
        echo -e "${Yellow}服务器: ${server:-"未配置"}:${port:-"未配置"}${Font}"
    fi
}

# 查看配置文件
view_config() {
    echo -e "${Green}=========================================================================${Font}"
    echo -e "${YellowBG}                           查看 frpc 配置                               ${Font}"
    echo -e "${Green}=========================================================================${Font}"
    
    if ! check_installed; then
        echo -e "${Red}frpc 未安装！${Font}"
        return 1
    fi
    
    local config_path=$(get_existing_config_path)
    if [[ -z "$config_path" ]]; then
        echo -e "${Red}配置文件不存在！${Font}"
        return 1
    fi
    
    local config_ext="${config_path##*.}"
    echo -e "${Blue}配置文件: ${config_path} (${config_ext^^} 格式)${Font}"
    echo -e "${Green}=========================================================================${Font}"
    
    cat "$config_path"
    
    echo -e "${Green}=========================================================================${Font}"
}

# 连通性测试功能（优化版）
connectivity_test() {
    echo -e "${Green}=========================================================================${Font}"
    echo -e "${YellowBG}                         连通性测试                                     ${Font}"
    echo -e "${Green}=========================================================================${Font}"
    
    # 检查frpc是否已安装
    if ! check_installed; then
        echo -e "${Red}frpc 未安装，请先安装！${Font}"
        echo -n -e "${Yellow}按任意键返回主菜单...${Font}"
        read -n 1
        return
    fi
    
    # 检查frpc服务是否运行
    if ! systemctl is-active --quiet ${FRP_NAME}; then
        echo -e "${Red}frpc 服务未运行，请先启动服务！${Font}"
        echo -e "${Yellow}可以使用选项 4 重启服务${Font}"
        echo -n -e "${Yellow}按任意键返回主菜单...${Font}"
        read -n 1
        return
    fi
    
    # 获取配置文件路径
    CONFIG_PATH=$(get_existing_config_path)
    if [ -z "$CONFIG_PATH" ]; then
        echo -e "${Red}配置文件不存在！${Font}"
        echo -n -e "${Yellow}按任意键返回主菜单...${Font}"
        read -n 1
        return
    fi
    
    CONFIG_EXT="${CONFIG_PATH##*.}"
    echo -e "${Blue}使用配置文件: ${CONFIG_PATH} (${CONFIG_EXT^^} 格式)${Font}"
    
    # 获取frps服务器地址
    if [ "$CONFIG_EXT" = "toml" ]; then
        FRPS_SERVER=$(grep '^serverAddr' "$CONFIG_PATH" | cut -d'"' -f2 2>/dev/null)
        if [ -z "$FRPS_SERVER" ]; then
            FRPS_SERVER=$(grep '^serverAddr' "$CONFIG_PATH" | cut -d'=' -f2 | tr -d ' "' 2>/dev/null)
        fi
    else
        FRPS_SERVER=$(grep '^server_addr' "$CONFIG_PATH" | cut -d'=' -f2 | tr -d ' ' 2>/dev/null)
    fi
    
    if [ -z "$FRPS_SERVER" ]; then
        echo -e "${Red}无法获取 frps 服务器地址！请检查配置文件${Font}"
        echo -n -e "${Yellow}按任意键返回主菜单...${Font}"
        read -n 1
        return
    fi
    
    echo -e "${Blue}FRPS 服务器地址: ${Yellow}$FRPS_SERVER${Font}"
    
    # 检查配置文件中是否包含3547端口配置
    if grep -q "3547" "$CONFIG_PATH"; then
        echo -e "${Green}✓ 检测到配置文件已包含端口 3547 的代理配置${Font}"
    else
        echo -e "${Yellow}⚠ 配置文件中未找到端口 3547 的配置${Font}"
        echo -e "${Yellow}建议使用选项 1 重新安装 frpc 以获得完整的测试功能${Font}"
    fi
    
    SOCKS5_PORT=3547
    
    # 启动本地SOCKS5代理测试
    echo -e "${Blue}正在启动本地 SOCKS5 代理测试 (端口 ${SOCKS5_PORT})...${Font}"
    
    # 使用 ssh 创建本地 SOCKS5 代理进行测试
    timeout 3 ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no -D ${SOCKS5_PORT} -N localhost >/dev/null 2>&1 &
    PROXY_PID=$!
    
    # 等待代理启动
    echo -e "${Blue}等待本地代理启动...${Font}"
    sleep 2
    
    # 测试连通性
    echo -e "${Blue}正在测试连通性...${Font}"
    echo -e "${Yellow}测试目标: ${FRPS_SERVER}:${SOCKS5_PORT} -> https://www.google.com/${Font}"
    
    # 执行连通性测试
    CURL_OUTPUT=$(timeout 20 curl --connect-timeout 10 --max-time 15 --socks5 "${FRPS_SERVER}:${SOCKS5_PORT}" -s -w "HTTP状态码: %{http_code}\n连接时间: %{time_connect}s\n总耗时: %{time_total}s\n" https://www.google.com/ 2>&1)
    CURL_EXIT_CODE=$?
    
    echo -e "${Green}=========================================================================${Font}"
    echo -e "${Blue}连通性测试结果:${Font}"
    echo -e "${Green}=========================================================================${Font}"
    
    if [ $CURL_EXIT_CODE -eq 0 ]; then
        if echo "$CURL_OUTPUT" | grep -q "google\|200\|301\|302"; then
            echo -e "${Green}✓ 连通性测试成功！${Font}"
            echo -e "${Green}✓ frpc 与 frps 服务器连接正常${Font}"
            echo -e "${Green}✓ 可以正常通过代理访问外部网站${Font}"
            echo -e "${Blue}详细信息:${Font}"
            echo "$CURL_OUTPUT" | tail -3
        else
            echo -e "${Yellow}⚠ 部分成功 - 连接建立但响应异常${Font}"
            echo -e "${Yellow}响应内容: ${Font}"
            echo "$CURL_OUTPUT" | head -5
        fi
    else
        echo -e "${Red}✗ 连通性测试失败！${Font}"
        case $CURL_EXIT_CODE in
            7)
                echo -e "${Red}错误: 无法连接到代理服务器${Font}"
                echo -e "${Yellow}可能原因:${Font}"
                echo -e "${Yellow}  1. frps 服务器未配置端口 3547${Font}"
                echo -e "${Yellow}  2. frpc 服务未正常连接到 frps${Font}"
                echo -e "${Yellow}  3. 网络防火墙阻止连接${Font}"
                ;;
            28|124)
                echo -e "${Red}错误: 连接超时${Font}"
                echo -e "${Yellow}可能原因: 网络延迟过高或服务器无响应${Font}"
                ;;
            56)
                echo -e "${Red}错误: 网络连接中断${Font}"
                ;;
            *)
                echo -e "${Red}错误代码: $CURL_EXIT_CODE${Font}"
                echo -e "${Red}错误信息: ${Font}"
                echo "$CURL_OUTPUT"
                ;;
        esac
    fi
    
    echo -e "${Green}=========================================================================${Font}"
    
    # 清理本地代理进程
    echo -e "${Blue}正在清理测试进程...${Font}"
    
    if [ ! -z "$PROXY_PID" ]; then
        kill $PROXY_PID 2>/dev/null
        wait $PROXY_PID 2>/dev/null
    fi
    
    # 清理可能残留的进程
    pkill -f "ssh.*-D.*${SOCKS5_PORT}" 2>/dev/null
    
    echo -e "${Green}清理完成！${Font}"
    echo -n -e "${Yellow}按任意键返回主菜单...${Font}"
    read -n 1
}

# 卸载frpc
uninstall_frpc() {
    echo -e "${Green}=========================================================================${Font}"
    echo -e "${YellowBG}                           卸载 frpc                                   ${Font}"
    echo -e "${Green}=========================================================================${Font}"
    
    if ! check_installed; then
        echo -e "${Yellow}frpc 未安装！${Font}"
        return 0
    fi
    
    echo -e "${Red}警告: 此操作将完全删除 frpc 及其配置文件！${Font}"
    read -p "确认卸载 frpc？(y/n): " confirm
    
    if [[ $confirm != "y" && $confirm != "Y" ]]; then
        echo -e "${Yellow}取消卸载${Font}"
        return 0
    fi
    
    # 停止并禁用服务
    echo -e "${Blue}停止 frpc 服务...${Font}"
    systemctl stop ${FRP_NAME} 2>/dev/null
    systemctl disable ${FRP_NAME} 2>/dev/null
    
    # 删除服务文件
    rm -f /etc/systemd/system/${FRP_NAME}.service
    systemctl daemon-reload
    
    # 删除程序文件
    rm -rf ${FRP_PATH}
    
    echo -e "${Green}✓ frpc 卸载完成${Font}"
}

# 安装快捷命令
install_shortcut() {
    echo -e "${Green}=========================================================================${Font}"
    echo -e "${YellowBG}                          安装快捷命令                                  ${Font}"
    echo -e "${Green}=========================================================================${Font}"
    
    local script_path="$(realpath "$0")"
    local shortcut_path="/usr/local/bin/frp"
    
    # 创建快捷命令脚本
    cat > "$shortcut_path" <<EOF
#!/bin/bash
# frpc 管理快捷命令
exec "$script_path" "\$@"
EOF
    
    chmod +x "$shortcut_path"
    
    echo -e "${Green}✓ 快捷命令安装完成${Font}"
    echo -e "${Blue}现在可以使用 'frp' 命令来管理 frpc${Font}"
    echo -e "${Yellow}示例: frp        # 显示菜单${Font}"
}

# 卸载快捷命令
uninstall_shortcut() {
    echo -e "${Green}=========================================================================${Font}"
    echo -e "${YellowBG}                          卸载快捷命令                                  ${Font}"
    echo -e "${Green}=========================================================================${Font}"
    
    if [[ -f "/usr/local/bin/frp" ]]; then
        rm -f "/usr/local/bin/frp"
        echo -e "${Green}✓ 快捷命令卸载完成${Font}"
    else
        echo -e "${Yellow}快捷命令未安装${Font}"
    fi
}

# 显示菜单
show_menu() {
    clear
    echo -e "${Green}=========================================================================${Font}"
    echo -e "${GreenBG}                         frpc 一键管理脚本                              ${Font}"
    echo -e "${Green}=========================================================================${Font}"
    echo -e "${Green}                        优化版 - 支持连通性测试                         ${Font}"
    echo -e "${Blue}  系统: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2) ${Font}"
    echo -e "${Blue}  架构: $(uname -m) ${Font}"
    echo -e "${Green}=========================================================================${Font}"
    echo -e "${Green}  1. 安装 frpc              6. 查看 frpc 配置${Font}"
    echo -e "${Green}  2. 更新 frpc 配置         7. 连通性测试 ${YellowBG}[新功能]${Font}"
    echo -e "${Green}  3. 更改 frps 服务器       8. 卸载 frpc${Font}"
    echo -e "${Green}  4. 重启 frpc              9. 安装快捷命令${Font}"
    echo -e "${Green}  5. 查看 frpc 状态        10. 卸载快捷命令${Font}"
    echo -e "${Green}=========================================================================${Font}"
    echo -e "${Green}  0. 退出脚本${Font}"
    echo -e "${Green}=========================================================================${Font}"
    
    # 显示当前状态
    if check_installed; then
        local config_path=$(get_existing_config_path)
        if [[ -n "$config_path" ]]; then
            local config_ext="${config_path##*.}"
            echo -e "${Blue}  状态: 已安装 (${config_ext^^} 格式)${Font}"
            
            if systemctl is-active --quiet ${FRP_NAME}; then
                echo -e "${Green}  服务: 运行中 ✓${Font}"
            else
                echo -e "${Red}  服务: 已停止 ✗${Font}"
            fi
            
            # 检查是否包含测试端口
            if grep -q "3547" "$config_path" 2>/dev/null; then
                echo -e "${Green}  测试: 支持连通性测试 ✓${Font}"
            else
                echo -e "${Yellow}  测试: 建议重新安装以支持连通性测试${Font}"
            fi
        else
            echo -e "${Yellow}  状态: 已安装但配置文件缺失${Font}"
        fi
    else
        echo -e "${Red}  状态: 未安装${Font}"
    fi
    
    echo -e "${Green}=========================================================================${Font}"
}

# 主函数
main() {
    # 检查root权限
    if [[ $EUID -ne 0 ]]; then
        echo -e "${Red}请使用 root 权限运行此脚本！${Font}"
        echo -e "${Yellow}sudo $0${Font}"
        exit 1
    fi
    
    # 如果有参数，直接执行对应功能
    if [[ $# -gt 0 ]]; then
        case $1 in
            install|1) install_frpc ;;
            config|2) update_config ;;
            server|3) change_server ;;
            restart|4) restart_frpc ;;
            status|5) status_frpc ;;
            view|6) view_config ;;
            test|7) connectivity_test ;;
            uninstall|8) uninstall_frpc ;;
            shortcut|9) install_shortcut ;;
            unshortcut|10) uninstall_shortcut ;;
            *) echo -e "${Red}未知参数: $1${Font}" ;;
        esac
        exit 0
    fi
    
    # 交互式菜单
    while true; do
        show_menu
        read -p "请选择操作 [0-10]: " choice
        
        case $choice in
            1) install_frpc ;;
            2) update_config ;;
            3) change_server ;;
            4) restart_frpc ;;
            5) status_frpc ;;
            6) view_config ;;
            7) connectivity_test ;;
            8) uninstall_frpc ;;
            9) install_shortcut ;;
            10) uninstall_shortcut ;;
            0) 
                echo -e "${Green}感谢使用 frpc 管理脚本！${Font}"
                exit 0 
                ;;
            *)
                echo -e "${Red}无效选择，请重新输入！${Font}"
                sleep 2
                ;;
        esac
        
        if [[ $choice != "7" ]]; then  # 连通性测试有自己的暂停
            echo -n -e "${Yellow}按任意键继续...${Font}"
            read -n 1
        fi
    done
}

# 脚本入口
main "$@"
