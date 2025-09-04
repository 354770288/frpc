#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# fonts color
Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
Blue="\033[34m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
YellowBG="\033[43;37m"
Font="\033[0m"

# variable
WORK_PATH=$(dirname $(readlink -f $0))
FRP_NAME=frpc
FRP_PATH=/usr/local/frp
SCRIPT_PATH=$(readlink -f $0)
SHORTCUT_PATH=/usr/local/bin/frp

# 检测系统架构
detect_platform() {
    if [ $(uname -m) = "x86_64" ]; then
        export PLATFORM=amd64
    elif [ $(uname -m) = "aarch64" ]; then
        export PLATFORM=arm64
    else
        echo -e "${Red}不支持的系统架构: $(uname -m)${Font}"
        exit 1
    fi
}

# 显示主菜单
show_menu() {
    clear
    echo -e "${Green}=========================================================================${Font}"
    echo -e "${GreenBG}                         FRPC 管理脚本                                  ${Font}"
    echo -e "${Green}=========================================================================${Font}"
    echo -e "${Green}1.${Font} 安装 frpc"
    echo -e "${Green}2.${Font} 更新 frpc 配置"
    echo -e "${Green}3.${Font} 更改 frps 服务器"
    echo -e "${Green}4.${Font} 重启 frpc"
    echo -e "${Green}5.${Font} 查看 frpc 状态"
    echo -e "${Green}6.${Font} 查看 frpc 配置"
    echo -e "${Green}7.${Font} 卸载 frpc"
    echo -e "${Green}8.${Font} 安装快捷命令 (frp)"
    echo -e "${Green}9.${Font} 卸载快捷命令"
    echo -e "${Green}0.${Font} 退出脚本"
    echo -e "${Green}=========================================================================${Font}"
    if [ -f "$SHORTCUT_PATH" ]; then
        echo -e "${Blue}提示: 快捷命令已安装，可直接在终端输入 'frp' 启动脚本${Font}"
        echo -e "${Green}=========================================================================${Font}"
    fi
    echo -n -e "${Yellow}请选择操作 [0-9]: ${Font}"
}

# 验证版本号格式
validate_version() {
    local version=$1
    if [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    else
        echo -e "${Red}版本号格式错误！请使用 x.xx.x 格式（如：0.38.0）${Font}"
        return 1
    fi
}

# 比较版本号
version_compare() {
    local version1=$1
    local version2=$2
    
    # 将版本号分解为数组
    IFS='.' read -r -a ver1 <<< "$version1"
    IFS='.' read -r -a ver2 <<< "$version2"
    
    # 比较主版本号
    if [ ${ver1[0]} -gt ${ver2[0]} ]; then
        return 1
    elif [ ${ver1[0]} -lt ${ver2[0]} ]; then
        return 2
    fi
    
    # 比较次版本号
    if [ ${ver1[1]} -gt ${ver2[1]} ]; then
        return 1
    elif [ ${ver1[1]} -lt ${ver2[1]} ]; then
        return 2
    fi
    
    # 比较修订版本号
    if [ ${ver1[2]} -gt ${ver2[2]} ]; then
        return 1
    elif [ ${ver1[2]} -lt ${ver2[2]} ]; then
        return 2
    fi
    
    return 0  # 相等
}

# 检查版本是否使用TOML格式 (>= 0.52.0)
is_toml_version() {
    local version=$1
    version_compare "$version" "0.52.0"
    local result=$?
    if [ $result -eq 1 ] || [ $result -eq 0 ]; then
        return 0  # 使用TOML
    else
        return 1  # 使用INI
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

# 检查是否已安装
check_installed() {
    if [ -f "/usr/local/frp/${FRP_NAME}" ] || [ -f "/usr/local/frp/${FRP_NAME}.ini" ] || [ -f "/usr/local/frp/${FRP_NAME}.toml" ] || [ -f "/lib/systemd/system/${FRP_NAME}.service" ]; then
        return 0
    else
        return 1
    fi
}

# 获取已安装版本的配置文件路径
get_existing_config_path() {
    if [ -f "${FRP_PATH}/${FRP_NAME}.toml" ]; then
        echo "${FRP_PATH}/${FRP_NAME}.toml"
    elif [ -f "${FRP_PATH}/${FRP_NAME}.ini" ]; then
        echo "${FRP_PATH}/${FRP_NAME}.ini"
    else
        echo ""
    fi
}

# 更改frps服务器地址
change_frps_server() {
    echo -e "${Green}=========================================================================${Font}"
    echo -e "${YellowBG}                         更改 FRPS 服务器                               ${Font}"
    echo -e "${Green}=========================================================================${Font}"
    
    if ! check_installed; then
        echo -e "${Red}frpc 未安装，请先安装！${Font}"
        echo -n -e "${Yellow}按任意键返回主菜单...${Font}"
        read -n 1
        return
    fi
    
    CONFIG_PATH=$(get_existing_config_path)
    
    if [ -z "$CONFIG_PATH" ]; then
        echo -e "${Red}配置文件不存在！${Font}"
        echo -n -e "${Yellow}按任意键返回主菜单...${Font}"
        read -n 1
        return
    fi
    
    CONFIG_EXT="${CONFIG_PATH##*.}"
    
    echo -e "${Blue}当前配置文件: ${CONFIG_PATH} (${CONFIG_EXT^^} 格式)${Font}"
    
    # 显示当前服务器地址
    if [ "$CONFIG_EXT" = "toml" ]; then
        CURRENT_SERVER=$(grep '^serverAddr' "$CONFIG_PATH" | cut -d'"' -f2 2>/dev/null)
        if [ -z "$CURRENT_SERVER" ]; then
            CURRENT_SERVER=$(grep '^serverAddr' "$CONFIG_PATH" | cut -d'=' -f2 | tr -d ' "' 2>/dev/null)
        fi
    else
        CURRENT_SERVER=$(grep '^server_addr' "$CONFIG_PATH" | cut -d'=' -f2 | tr -d ' ' 2>/dev/null)
    fi
    
    if [ -n "$CURRENT_SERVER" ]; then
        echo -e "${Blue}当前服务器地址: ${Yellow}$CURRENT_SERVER${Font}"
    else
        echo -e "${Yellow}未能获取当前服务器地址${Font}"
    fi
    
    # 输入新的服务器地址
    echo -n -e "${Yellow}请输入新的 frps 服务器地址: ${Font}"
    read -r NEW_SERVER
    
    if [ -z "$NEW_SERVER" ]; then
        echo -e "${Red}服务器地址不能为空！${Font}"
        echo -n -e "${Yellow}按任意键返回主菜单...${Font}"
        read -n 1
        return
    fi
    
    # 备份配置文件
    cp "$CONFIG_PATH" "${CONFIG_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "${Blue}已备份原配置文件${Font}"
    
    # 更新配置文件
    if [ "$CONFIG_EXT" = "toml" ]; then
        # TOML格式
        if grep -q '^serverAddr' "$CONFIG_PATH"; then
            sed -i "s|^serverAddr = .*|serverAddr = \"$NEW_SERVER\"|" "$CONFIG_PATH"
        else
            echo -e "${Red}配置文件中未找到 serverAddr 配置项${Font}"
            echo -n -e "${Yellow}按任意键返回主菜单...${Font}"
            read -n 1
            return
        fi
    else
        # INI格式
        if grep -q '^server_addr' "$CONFIG_PATH"; then
            sed -i "s|^server_addr = .*|server_addr = $NEW_SERVER|" "$CONFIG_PATH"
        else
            echo -e "${Red}配置文件中未找到 server_addr 配置项${Font}"
            echo -n -e "${Yellow}按任意键返回主菜单...${Font}"
            read -n 1
            return
        fi
    fi
    
    echo -e "${Green}frps 服务器地址已更新为: ${Yellow}$NEW_SERVER${Font}"
    
    # 重启frpc服务
    echo -e "${Blue}正在重启 frpc 服务...${Font}"
    systemctl restart ${FRP_NAME}
    
    if [ $? -eq 0 ]; then
        echo -e "${Green}frpc 服务重启成功！${Font}"
    else
        echo -e "${Red}frpc 服务重启失败！${Font}"
    fi
    
    # 延迟5秒后查看日志
    echo -e "${Blue}等待 5 秒后查看 frpc 日志...${Font}"
    sleep 5
    
    LOG_PATH="/usr/local/frp/frpc.log"
    if [ -f "$LOG_PATH" ]; then
        echo -e "${Green}=========================================================================${Font}"
        echo -e "${Blue}FRPC 日志内容 (最新 20 行):${Font}"
        echo -e "${Green}=========================================================================${Font}"
        tail -n 20 "$LOG_PATH"
        echo -e "${Green}=========================================================================${Font}"
    else
        echo -e "${Yellow}日志文件 $LOG_PATH 不存在${Font}"
        echo -e "${Blue}尝试查看系统日志:${Font}"
        journalctl -u ${FRP_NAME} -n 10 --no-pager
    fi
    
    echo -n -e "${Yellow}按任意键返回主菜单...${Font}"
    read -n 1
}

# 安装快捷命令
install_shortcut() {
    echo -e "${Green}=========================================================================${Font}"
    echo -e "${YellowBG}                         安装快捷命令                                   ${Font}"
    echo -e "${Green}=========================================================================${Font}"
    
    if [ -f "$SHORTCUT_PATH" ]; then
        echo -e "${Yellow}快捷命令已存在！${Font}"
        echo -n -e "${Yellow}是否要重新安装？[y/N]: ${Font}"
        read -r reinstall_choice
        if [[ ! $reinstall_choice =~ ^[Yy]$ ]]; then
            echo -n -e "${Yellow}按任意键返回主菜单...${Font}"
            read -n 1
            return
        fi
    fi
    
    echo -e "${Blue}正在安装快捷命令...${Font}"
    
    # 复制脚本到系统路径
    if cp "$SCRIPT_PATH" "$SHORTCUT_PATH"; then
        chmod +x "$SHORTCUT_PATH"
        echo -e "${Green}快捷命令安装成功！${Font}"
        echo -e "${Green}现在您可以在终端的任何位置输入 '${Yellow}frp${Green}' 来启动此脚本${Font}"
        echo -e "${Blue}用法示例:${Font}"
        echo -e "${Yellow}  frp${Font}           # 启动菜单界面"
        echo -e "${Yellow}  sudo frp${Font}      # 以管理员权限启动"
    else
        echo -e "${Red}快捷命令安装失败！请检查权限${Font}"
    fi
    
    echo -n -e "${Yellow}按任意键返回主菜单...${Font}"
    read -n 1
}

# 卸载快捷命令
uninstall_shortcut() {
    echo -e "${Green}=========================================================================${Font}"
    echo -e "${RedBG}                         卸载快捷命令                                   ${Font}"
    echo -e "${Green}=========================================================================${Font}"
    
    if [ ! -f "$SHORTCUT_PATH" ]; then
        echo -e "${Yellow}快捷命令未安装！${Font}"
        echo -n -e "${Yellow}按任意键返回主菜单...${Font}"
        read -n 1
        return
    fi
    
    echo -e "${Red}确定要卸载快捷命令吗？${Font}"
    echo -n -e "${Yellow}确认卸载？[y/N]: ${Font}"
    read -r confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        if rm -f "$SHORTCUT_PATH"; then
            echo -e "${Green}快捷命令卸载成功！${Font}"
        else
            echo -e "${Red}快捷命令卸载失败！${Font}"
        fi
    else
        echo -e "${Yellow}取消卸载操作。${Font}"
    fi
    
    echo -n -e "${Yellow}按任意键返回主菜单...${Font}"
    read -n 1
}

# 安装 frpc
install_frpc() {
    echo -e "${Green}=========================================================================${Font}"
    echo -e "${YellowBG}                           安装 FRPC                                    ${Font}"
    echo -e "${Green}=========================================================================${Font}"
    
    # 检查是否已安装
    if check_installed; then
        echo -e "${Red}检测到系统已安装 frpc，请先卸载后再安装！${Font}"
        echo -n -e "${Yellow}是否要先卸载现有版本？[y/N]: ${Font}"
        read -r uninstall_choice
        if [[ $uninstall_choice =~ ^[Yy]$ ]]; then
            uninstall_frpc
        else
            return
        fi
    fi
    
    # 输入版本号
    while true; do
        echo -e "${Blue}提示：frp 从 0.52.0 版本开始使用 TOML 配置格式，之前版本使用 INI 格式${Font}"
        echo -n -e "${Yellow}请输入要安装的版本号 (格式: x.xx.x，如 0.38.0 或 0.54.0): ${Font}"
        read -r FRP_VERSION
        if validate_version "$FRP_VERSION"; then
            break
        fi
    done
    
    detect_platform
    FILE_NAME=frp_${FRP_VERSION}_linux_${PLATFORM}
    CONFIG_EXT=$(get_config_extension "$FRP_VERSION")
    
    echo -e "${Blue}开始安装 frpc v${FRP_VERSION} (${PLATFORM})...${Font}"
    echo -e "${Blue}配置文件格式: ${CONFIG_EXT^^}${Font}"
    
    # 停止现有进程
    stop_frpc_process
    
    # 创建目录
    mkdir -p ${FRP_PATH}
    
    # 下载并解压
    echo -e "${Blue}正在下载 frp...${Font}"
    if wget -P ${WORK_PATH} https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/${FILE_NAME}.tar.gz -O ${FILE_NAME}.tar.gz; then
        echo -e "${Green}下载成功！${Font}"
    else
        echo -e "${Red}下载失败！请检查网络连接或版本号是否正确。${Font}"
        return
    fi
    
    echo -e "${Blue}正在解压文件...${Font}"
    tar -zxvf ${FILE_NAME}.tar.gz && mv ${FILE_NAME}/${FRP_NAME} ${FRP_PATH}
    
    # 创建配置文件
    create_config "$FRP_VERSION"
    
    # 创建系统服务
    create_service "$FRP_VERSION"
    
    # 启动服务
    systemctl daemon-reload
    systemctl start ${FRP_NAME}
    systemctl enable ${FRP_NAME}
    
    # 清理临时文件
    rm -rf ${WORK_PATH}/${FILE_NAME}.tar.gz ${WORK_PATH}/${FILE_NAME}
    
    echo -e "${Green}=========================================================================${Font}"
    echo -e "${Green}安装成功！${Font}"
    echo -e "${Yellow}配置文件: /usr/local/frp/${FRP_NAME}.${CONFIG_EXT}${Font}"
    echo -e "${Yellow}请记得修改配置文件，修改完成后请重启服务: systemctl restart ${FRP_NAME}${Font}"
    
    # 提示安装快捷命令
    if [ ! -f "$SHORTCUT_PATH" ]; then
        echo -e "${Blue}提示: 您可以安装快捷命令，以便在任何地方使用 'frp' 命令启动此脚本${Font}"
    fi
    echo -e "${Green}=========================================================================${Font}"
    
    echo -n -e "${Yellow}按任意键返回主菜单...${Font}"
    read -n 1
}

# 停止 frpc 进程
stop_frpc_process() {
    while ! test -z "$(ps -A | grep -w ${FRP_NAME})"; do
        FRPCPID=$(ps -A | grep -w ${FRP_NAME} | awk 'NR==1 {print $1}')
        kill -9 $FRPCPID 2>/dev/null
        echo -e "${Yellow}已终止 frpc 进程 (PID: $FRPCPID)${Font}"
    done
}

# 创建配置文件
create_config() {
    local version=$1
    local config_ext=$(get_config_extension "$version")
    
    if is_toml_version "$version"; then
        # 创建TOML格式配置文件
        cat >${FRP_PATH}/${FRP_NAME}.toml <<EOF
# frpc.toml
serverAddr = "your.frp.server.com"
serverPort = 7000
# auth.token = "your_token_here"


# TCP代理示例 - 自定义端口
[[proxies]]
name = "tcp_${RANDOM}"
type = "tcp"
localIP = "127.0.0.1"
localPort = 1122
remotePort = 1122

# 优化 TCP 传输性能
transport.tcpMux = true                   # TCP多路复用，减少连接消耗
# 配置日志
log.to = "./frpc.log"
log.level = "trace"
log.maxDays = 2

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
EOF
    fi
    
    echo -e "${Green}已创建 ${config_ext^^} 格式配置文件，使用 TCP 类型代理${Font}"
}

# 创建系统服务
create_service() {
    local version=$1
    local config_ext=$(get_config_extension "$version")
    
    cat >/lib/systemd/system/${FRP_NAME}.service <<EOF
[Unit]
Description=Frp Client Service
After=network.target syslog.target
Wants=network.target

[Service]
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/frp/${FRP_NAME} -c /usr/local/frp/${FRP_NAME}.${config_ext}
ExecReload=/bin/kill -s HUP \$MAINPID
KillMode=process

[Install]
WantedBy=multi-user.target
EOF
}

# 更新配置
update_config() {
    echo -e "${Green}=========================================================================${Font}"
    echo -e "${YellowBG}                         更新 FRPC 配置                                 ${Font}"
    echo -e "${Green}=========================================================================${Font}"
    
    if ! check_installed; then
        echo -e "${Red}frpc 未安装，请先安装！${Font}"
        echo -n -e "${Yellow}按任意键返回主菜单...${Font}"
        read -n 1
        return
    fi
    
    CONFIG_PATH=$(get_existing_config_path)
    
    if [ -n "$CONFIG_PATH" ]; then
        CONFIG_EXT="${CONFIG_PATH##*.}"
        echo -e "${Blue}当前配置文件: ${CONFIG_PATH} (${CONFIG_EXT^^} 格式)${Font}"
        echo -e "${Yellow}即将打开配置文件编辑器...${Font}"
        echo -n -e "${Yellow}按任意键继续...${Font}"
        read -n 1
        
        # 使用系统默认编辑器
        if command -v nano > /dev/null; then
            nano "$CONFIG_PATH"
        elif command -v vi > /dev/null; then
            vi "$CONFIG_PATH"
        else
            echo -e "${Red}未找到可用的编辑器！${Font}"
        fi
        
        echo -e "${Green}配置文件更新完成！${Font}"
        echo -n -e "${Yellow}是否要重启 frpc 服务使配置生效？[Y/n]: ${Font}"
        read -r restart_choice
        if [[ ! $restart_choice =~ ^[Nn]$ ]]; then
            restart_frpc
        fi
    else
        echo -e "${Red}配置文件不存在！${Font}"
    fi
    
    echo -n -e "${Yellow}按任意键返回主菜单...${Font}"
    read -n 1
}

# 重启服务
restart_frpc() {
    echo -e "${Green}=========================================================================${Font}"
    echo -e "${YellowBG}                         重启 FRPC 服务                                 ${Font}"
    echo -e "${Green}=========================================================================${Font}"
    
    if ! check_installed; then
        echo -e "${Red}frpc 未安装，请先安装！${Font}"
        echo -n -e "${Yellow}按任意键返回主菜单...${Font}"
        read -n 1
        return
    fi
    
    echo -e "${Blue}正在重启 frpc 服务...${Font}"
    systemctl restart ${FRP_NAME}
    
    echo -e "${Green}服务重启完成！等待 2 秒后查看状态...${Font}"
    sleep 2
    
    check_status
}

# 查看状态
check_status() {
    echo -e "${Green}=========================================================================${Font}"
    echo -e "${YellowBG}                         FRPC 服务状态                                  ${Font}"
    echo -e "${Green}=========================================================================${Font}"
    
    if ! check_installed; then
        echo -e "${Red}frpc 未安装！${Font}"
        echo -n -e "${Yellow}按任意键返回主菜单...${Font}"
        read -n 1
        return
    fi
    
    echo -e "${Blue}服务状态:${Font}"
    systemctl status ${FRP_NAME} --no-pager
    
    echo -e "\n${Blue}进程信息:${Font}"
    ps aux | grep ${FRP_NAME} | grep -v grep || echo -e "${Red}未找到 frpc 进程${Font}"
    
    echo -e "\n${Blue}端口监听:${Font}"
    netstat -tlnp 2>/dev/null | grep ${FRP_NAME} || echo -e "${Yellow}未检测到监听端口${Font}"
    
    echo -e "\n${Blue}配置文件:${Font}"
    CONFIG_PATH=$(get_existing_config_path)
    if [ -n "$CONFIG_PATH" ]; then
        CONFIG_EXT="${CONFIG_PATH##*.}"
        echo -e "${Green}配置文件: $CONFIG_PATH (${CONFIG_EXT^^} 格式)${Font}"
    else
        echo -e "${Red}未找到配置文件${Font}"
    fi
    
    echo -n -e "\n${Yellow}按任意键返回主菜单...${Font}"
    read -n 1
}

# 查看配置
view_config() {
    echo -e "${Green}=========================================================================${Font}"
    echo -e "${YellowBG}                         FRPC 配置文件                                  ${Font}"
    echo -e "${Green}=========================================================================${Font}"
    
    if ! check_installed; then
        echo -e "${Red}frpc 未安装！${Font}"
        echo -n -e "${Yellow}按任意键返回主菜单...${Font}"
        read -n 1
        return
    fi
    
    CONFIG_PATH=$(get_existing_config_path)
    
    if [ -n "$CONFIG_PATH" ]; then
        CONFIG_EXT="${CONFIG_PATH##*.}"
        echo -e "${Blue}配置文件: $CONFIG_PATH (${CONFIG_EXT^^} 格式)${Font}"
        echo -e "${Green}=========================================================================${Font}"
        cat "$CONFIG_PATH"
        echo -e "${Green}=========================================================================${Font}"
    else
        echo -e "${Red}配置文件不存在！${Font}"
    fi
    
    echo -n -e "${Yellow}按任意键返回主菜单...${Font}"
    read -n 1
}

# 卸载 frpc
uninstall_frpc() {
    echo -e "${Green}=========================================================================${Font}"
    echo -e "${RedBG}                           卸载 FRPC                                    ${Font}"
    echo -e "${Green}=========================================================================${Font}"
    
    if ! check_installed; then
        echo -e "${Yellow}frpc 未安装或已经被卸载！${Font}"
        echo -n -e "${Yellow}按任意键返回主菜单...${Font}"
        read -n 1
        return
    fi
    
    echo -e "${Red}警告：此操作将完全删除 frpc 及其配置文件！${Font}"
    echo -n -e "${Yellow}确定要卸载吗？[y/N]: ${Font}"
    read -r confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo -e "${Blue}正在停止服务...${Font}"
        systemctl stop ${FRP_NAME} 2>/dev/null
        systemctl disable ${FRP_NAME} 2>/dev/null
        
        echo -e "${Blue}正在删除文件...${Font}"
        rm -rf ${FRP_PATH}
        rm -rf /lib/systemd/system/${FRP_NAME}.service
        
        echo -e "${Blue}正在终止进程...${Font}"
        stop_frpc_process
        
        systemctl daemon-reload
        
        echo -e "${Green}frpc 卸载完成！${Font}"
    else
        echo -e "${Yellow}取消卸载操作。${Font}"
    fi
    
    echo -n -e "${Yellow}按任意键返回主菜单...${Font}"
    read -n 1
}

# 主循环
main() {
    while true; do
        show_menu
        read -r choice
        
        case $choice in
            1)
                install_frpc
                ;;
            2)
                update_config
                ;;
            3)
                change_frps_server
                ;;
            4)
                restart_frpc
                ;;
            5)
                check_status
                ;;
            6)
                view_config
                ;;
            7)
                uninstall_frpc
                ;;
            8)
                install_shortcut
                ;;
            9)
                uninstall_shortcut
                ;;
            0)
                echo -e "${Green}感谢使用！再见！${Font}"
                exit 0
                ;;
            *)
                echo -e "${Red}无效的选择，请重新输入！${Font}"
                sleep 1
                ;;
        esac
    done
}

# 检查是否为 root 用户
if [ $EUID -ne 0 ]; then
    echo -e "${Red}此脚本需要 root 权限运行！${Font}"
    echo -e "${Yellow}请使用 sudo 运行此脚本${Font}"
    exit 1
fi

# 启动主程序
main
