#!/bin/bash

# frpc一键安装脚本 - 适用于Debian系统
# 作者: 自动生成
# 版本: 1.0
# 描述: 支持多实例frpc服务的安装、管理和配置

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 全局变量
FRP_BASE_DIR="/usr/local/frp"
GITHUB_API="https://api.github.com/repos/fatedier/frp/releases"
GLOBAL_COMMAND_PATH="/usr/local/bin/frp"

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_blue() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        exit 1
    fi
}

# 检查系统架构
detect_arch() {
    local arch=$(uname -m)
    case $arch in
        x86_64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        armv7l)
            echo "arm"
            ;;
        *)
            log_error "不支持的系统架构: $arch"
            exit 1
            ;;
    esac
}

# 检查系统类型
detect_os() {
    if [[ -f /etc/debian_version ]]; then
        echo "linux"
    else
        log_error "此脚本仅支持Debian系统"
        exit 1
    fi
}

# 获取frp版本列表
get_frp_versions() {
    curl -s "$GITHUB_API" | grep -o '"tag_name": "[^"]*"' | sed 's/"tag_name": "//g' | sed 's/"//g' | head -10
}

# 下载frp
download_frp() {
    local version=$1
    local arch=$2
    local os=$3
    
    # 移除版本号中的v前缀用于文件名
    local version_no_v=${version#v}
    local filename="frp_${version_no_v}_${os}_${arch}.tar.gz"
    local download_url="https://github.com/fatedier/frp/releases/download/${version}/${filename}"
    local temp_dir="/tmp/frp_download_$$"
    local current_dir=$(pwd)
    
    log_info "开始下载 frp ${version}..." >&2
    
    # 创建临时目录
    if ! mkdir -p "$temp_dir"; then
        log_error "无法创建临时目录: $temp_dir" >&2
        return 1
    fi
    
    # 进入临时目录
    if ! cd "$temp_dir"; then
        log_error "无法进入临时目录: $temp_dir" >&2
        rm -rf "$temp_dir"
        return 1
    fi
    
    # 下载文件
    log_info "正在下载 frp ${version}..." >&2
    log_info "下载地址: $download_url" >&2
    
    # 尝试wget下载
    if wget -q --show-progress "$download_url" >&2; then
        log_info "wget下载成功" >&2
    # 如果wget失败，尝试curl
    elif curl -L -o "$filename" "$download_url" >&2; then
        log_info "curl下载成功" >&2
    else
        log_error "下载失败，请检查网络连接" >&2
        log_error "尝试的下载地址: $download_url" >&2
        cd "$current_dir"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # 检查下载的文件是否存在
    if [[ ! -f "$filename" ]]; then
        log_error "下载的文件不存在: $filename" >&2
        cd "$current_dir"
        rm -rf "$temp_dir"
        return 1
    fi
    
    log_info "下载完成" >&2
    
    # 解压文件
    log_info "正在解压..." >&2
    if ! tar -xzf "$filename" >&2; then
        log_error "解压失败" >&2
        cd "$current_dir"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # 检查解压目录和文件
    local extract_dir="frp_${version_no_v}_${os}_${arch}"
    if [[ ! -d "$extract_dir" ]]; then
        log_error "解压失败，找不到目录: $extract_dir" >&2
        cd "$current_dir"
        rm -rf "$temp_dir"
        return 1
    fi
    
    if [[ ! -f "$extract_dir/frpc" ]]; then
        log_error "找不到frpc可执行文件" >&2
        cd "$current_dir"
        rm -rf "$temp_dir"
        return 1
    fi
    
    log_info "解压成功" >&2
    cd "$current_dir"
    echo "$temp_dir/$extract_dir"
}

# 生成随机5位数字
generate_random_suffix() {
    printf "%05d" $((RANDOM % 100000))
}

# 创建默认配置文件
create_default_config() {
    local service_name=$1
    local config_file="$FRP_BASE_DIR/$service_name/frpc.toml"
    local random_suffix=$(generate_random_suffix)
    
    cat > "$config_file" << EOF
serverAddr = "your.frp.server.com"
serverPort = 7000
# auth.token = "your_token_here"

transport.tcpMux = true
# transport.poolCount = 1

log.to = "./frpc.log"
log.level = "trace"
log.maxDays = 2

[[proxies]]
name = "tcp_$random_suffix"
type = "tcp"
localIP = "127.0.0.1"
localPort = 1122
remotePort = 1122
EOF
    
    log_info "已创建默认配置文件: $config_file"
}

# 创建systemd服务文件
create_systemd_service() {
    local service_name=$1
    local service_file="/etc/systemd/system/frpc-${service_name}.service"
    
    cat > "$service_file" << EOF
[Unit]
Description=frp client service ($service_name)
After=network.target

[Service]
Type=simple
User=root
Restart=on-failure
RestartSec=5s
ExecStart=$FRP_BASE_DIR/$service_name/frpc -c $FRP_BASE_DIR/$service_name/frpc.toml
WorkingDirectory=$FRP_BASE_DIR/$service_name
StandardOutput=append:$FRP_BASE_DIR/$service_name/frpc.log
StandardError=append:$FRP_BASE_DIR/$service_name/frpc.log

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    log_info "已创建systemd服务: frpc-${service_name}"
}

# 安装frpc
install_frpc() {
    local arch=$(detect_arch)
    local os=$(detect_os)
    
    # 创建基础目录
    mkdir -p "$FRP_BASE_DIR"
    
    # 获取版本列表
    local versions
    log_info "正在获取frp版本列表..."
    if ! versions=$(get_frp_versions); then
        log_error "无法获取版本列表，请检查网络连接"
        return 1
    fi
    
    echo
    log_blue "可用的frp版本列表:"
    echo "$versions" | nl -w2 -s'. '
    echo
    log_blue "安装选项:"
    echo "1. 输入数字选择上述版本 (默认选择第1个版本)"
    echo "2. 直接输入版本号 (如: v0.52.3)"
    echo
    
    read -p "请选择安装方式或直接输入版本号: " version_input
    
    local selected_version
    
    # 检查输入是否为数字
    if [[ "$version_input" =~ ^[0-9]+$ ]]; then
        # 数字选择模式
        local version_choice=${version_input:-1}
        selected_version=$(echo "$versions" | sed -n "${version_choice}p")
        if [[ -z "$selected_version" ]]; then
            log_error "无效的版本选择，请输入1到$(echo "$versions" | wc -l)之间的数字"
            return 1
        fi
    elif [[ -z "$version_input" ]]; then
        # 默认选择第一个版本
        selected_version=$(echo "$versions" | sed -n "1p")
        log_info "使用默认版本: $selected_version"
    elif [[ "$version_input" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        # 直接输入版本号模式
        selected_version="$version_input"
        log_info "使用指定版本: $selected_version"
    else
        log_error "无效的输入格式，请输入数字或版本号 (如: v0.52.3)"
        return 1
    fi
    
    echo
    log_info "选择的版本: $selected_version"
    echo
    read -p "请输入服务名称 (默认: default): " service_name
    service_name=${service_name:-default}
    
    # 检查服务是否已存在
    if [[ -d "$FRP_BASE_DIR/$service_name" ]]; then
        log_error "服务 '$service_name' 已存在"
        return 1
    fi
    
    # 确认安装信息
    echo
    log_blue "安装确认信息:"
    echo "版本: $selected_version"
    echo "服务名称: $service_name"
    echo "系统架构: $arch"
    echo "安装路径: $FRP_BASE_DIR/$service_name"
    echo "服务名: frpc-$service_name"
    echo
    
    read -p "确认开始安装? (Y/n): " install_confirm
    if [[ "$install_confirm" =~ ^[Nn]$ ]]; then
        log_info "用户取消安装"
        return 0
    fi
    
    log_info "用户确认安装，开始执行安装流程..."
    log_info "安装参数: 版本=$selected_version, 架构=$arch, 系统=$os"
    
    # 环境检查
    log_info "环境检查..."
    
    # 检查必需工具
    local missing_tools=()
    for tool in wget curl tar; do
        if ! command -v $tool > /dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "缺少必需工具: ${missing_tools[*]}"
        log_error "请先安装: apt-get install ${missing_tools[*]}"
        return 1
    fi
    log_info "✓ 必需工具检查完成"
    
    # 下载并解压
    log_info "步骤1: 下载frp程序..."
    local temp_extract_dir
    if ! temp_extract_dir=$(download_frp "$selected_version" "$arch" "$os"); then
        log_error "下载步骤失败，安装终止"
        return 1
    fi
    
    log_info "下载完成，临时目录: $temp_extract_dir"
    
    # 创建服务目录
    log_info "步骤2: 创建服务目录..."
    local service_dir="$FRP_BASE_DIR/$service_name"
    if ! mkdir -p "$service_dir"; then
        log_error "无法创建服务目录: $service_dir"
        rm -rf "$(dirname "$temp_extract_dir")"
        return 1
    fi
    log_info "服务目录创建成功: $service_dir"
    log_info "目录权限: $(ls -ld "$service_dir")"
    
    # 复制文件
    log_info "步骤3: 复制frpc可执行文件..."
    if ! cp "$temp_extract_dir/frpc" "$service_dir/"; then
        log_error "复制frpc文件失败"
        rm -rf "$(dirname "$temp_extract_dir")"
        return 1
    fi
    
    if ! chmod +x "$service_dir/frpc"; then
        log_error "设置frpc文件权限失败"
        rm -rf "$(dirname "$temp_extract_dir")"
        return 1
    fi
    log_info "frpc文件复制完成"
    
    # 清理临时文件
    log_info "步骤4: 清理临时文件..."
    rm -rf "$(dirname "$temp_extract_dir")"
    
    # 创建配置文件
    log_info "步骤5: 创建配置文件..."
    create_default_config "$service_name"
    
    # 创建systemd服务
    log_info "步骤6: 创建systemd服务..."
    create_systemd_service "$service_name"
    
    # 启动服务
    log_info "步骤7: 启动服务..."
    if ! systemctl enable "frpc-${service_name}"; then
        log_error "启用服务失败"
        return 1
    fi
    
    if ! systemctl start "frpc-${service_name}"; then
        log_error "启动服务失败"
        return 1
    fi
    
    log_info "frpc服务 '$service_name' 安装完成！"
    log_info "配置文件位置: $service_dir/frpc.toml"
    log_info "日志文件位置: $service_dir/frpc.log"
    log_info "服务名称: frpc-${service_name}"
    
    echo
    log_warn "请记得修改配置文件中的服务器地址和端口！"
}

# 获取所有frpc服务列表
get_frpc_services() {
    if [[ ! -d "$FRP_BASE_DIR" ]]; then
        return 1
    fi
    
    find "$FRP_BASE_DIR" -maxdepth 1 -type d -not -path "$FRP_BASE_DIR" -exec basename {} \;
}


# 选择服务
select_service() {
    local services
    services=$(get_frpc_services)
    
    echo >&2
    log_blue "已安装的frpc服务:" >&2
    echo "$services" | nl -w2 -s'. ' >&2
    echo >&2
    
    read -p "请选择服务 (输入数字): " service_choice
    
    local selected_service=$(echo "$services" | sed -n "${service_choice}p")
    if [[ -z "$selected_service" ]]; then
        log_error "无效的服务选择" >&2
        return 1
    fi
    
    echo "$selected_service"
}

# 重启服务
restart_service() {
    local service_name
    if ! service_name=$(select_service); then
        return 1
    fi
    
    log_info "正在重启服务 frpc-${service_name}..."
    systemctl restart "frpc-${service_name}"
    
    log_info "等待服务启动..."
    sleep 3
    
    log_info "服务状态:"
    systemctl status "frpc-${service_name}" --no-pager -l
    
    echo
    log_info "最近的日志:"
    tail -n 20 "$FRP_BASE_DIR/$service_name/frpc.log" 2>/dev/null || log_warn "无法读取日志文件"
}

# 编辑配置
edit_config() {
    local service_name
    if ! service_name=$(select_service); then
        return 1
    fi
    
    log_info "选择的服务名称: '$service_name'"
    local config_file="$FRP_BASE_DIR/$service_name/frpc.toml"
    log_info "配置文件路径: '$config_file'"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "配置文件不存在: $config_file"
        return 1
    fi
    
    log_info "正在编辑配置文件: $config_file"
    nano "$config_file"
    
    read -p "是否重启服务使配置生效? (y/N): " restart_choice
    if [[ "$restart_choice" =~ ^[Yy]$ ]]; then
        systemctl restart "frpc-${service_name}"
        log_info "服务已重启"
    fi
}

# 快速更改服务器地址
change_server() {
    local service_name
    if ! service_name=$(select_service); then
        return 1
    fi
    
    log_info "选择的服务名称: '$service_name'"
    local config_file="$FRP_BASE_DIR/$service_name/frpc.toml"
    log_info "配置文件路径: '$config_file'"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "配置文件不存在: $config_file"
        return 1
    fi
    
    # 显示当前服务器地址
    local current_server=$(grep -o 'serverAddr = "[^"]*"' "$config_file" 2>/dev/null | sed 's/serverAddr = "//g' | sed 's/"//g' || echo "未设置")
    log_info "当前服务器地址: $current_server"
    
    echo
    read -p "请输入新的服务器地址: " new_server
    
    if [[ -z "$new_server" ]]; then
        log_error "服务器地址不能为空"
        return 1
    fi
    
    # 更新配置文件
    sed -i "s/serverAddr = \".*\"/serverAddr = \"$new_server\"/" "$config_file"
    
    log_info "服务器地址已更新为: $new_server"
    
    read -p "是否重启服务使配置生效? (y/N): " restart_choice
    if [[ "$restart_choice" =~ ^[Yy]$ ]]; then
        systemctl restart "frpc-${service_name}"
        log_info "服务已重启"
    fi
}

# 查看配置
view_config() {
    local service_name
    if ! service_name=$(select_service); then
        return 1
    fi
    
    log_info "选择的服务名称: '$service_name'"
    local config_file="$FRP_BASE_DIR/$service_name/frpc.toml"
    log_info "配置文件路径: '$config_file'"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "配置文件不存在: $config_file"
        return 1
    fi
    
    echo
    log_blue "配置文件内容 ($config_file):"
    echo "----------------------------------------"
    cat "$config_file"
    echo "----------------------------------------"
}

# 查看服务状态
view_status() {
    local service_name
    if ! service_name=$(select_service); then
        return 1
    fi
    
    echo
    log_blue "服务状态 (frpc-${service_name}):"
    systemctl status "frpc-${service_name}" --no-pager -l
    
    echo
    log_blue "最近日志:"
    tail -n 30 "$FRP_BASE_DIR/$service_name/frpc.log" 2>/dev/null || log_warn "无法读取日志文件"
}

# 卸载服务
uninstall_service() {
    local service_name
    if ! service_name=$(select_service); then
        return 1
    fi
    
    echo
    log_warn "即将卸载服务: frpc-${service_name}"
    read -p "确定要卸载吗? 此操作不可恢复 (y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "取消卸载"
        return 0
    fi
    
    # 停止并禁用服务
    systemctl stop "frpc-${service_name}" 2>/dev/null || true
    systemctl disable "frpc-${service_name}" 2>/dev/null || true
    
    # 删除systemd服务文件
    rm -f "/etc/systemd/system/frpc-${service_name}.service"
    systemctl daemon-reload
    
    # 删除服务目录
    rm -rf "$FRP_BASE_DIR/$service_name"
    
    log_info "服务 frpc-${service_name} 已成功卸载"
}

# 安装全局命令
install_global_command() {
    if [[ -f "$GLOBAL_COMMAND_PATH" ]]; then
        log_warn "全局命令已存在"
        return 0
    fi
    
    # 创建全局命令脚本
    cat > "$GLOBAL_COMMAND_PATH" << 'EOF'
#!/bin/bash
# frp全局命令快捷方式

SCRIPT_PATH="/usr/local/bin/frpc_installer.sh"

if [[ -f "$SCRIPT_PATH" ]]; then
    "$SCRIPT_PATH" "$@"
else
    echo "错误: 找不到frpc安装脚本"
    exit 1
fi
EOF
    
    chmod +x "$GLOBAL_COMMAND_PATH"
    
    # 复制当前脚本到系统路径
    cp "$0" "/usr/local/bin/frpc_installer.sh"
    chmod +x "/usr/local/bin/frpc_installer.sh"
    
    log_info "全局命令已安装，现在可以在任何位置使用 'frp' 命令"
}

# 移除全局命令
remove_global_command() {
    if [[ ! -f "$GLOBAL_COMMAND_PATH" ]]; then
        log_warn "全局命令未安装"
        return 0
    fi
    
    rm -f "$GLOBAL_COMMAND_PATH"
    rm -f "/usr/local/bin/frpc_installer.sh"
    
    log_info "全局命令已移除"
}

# 显示主菜单
show_menu() {
    clear
    echo -e "${BLUE}"
    echo "================================================================"
    echo "                    frpc 一键安装管理脚本"
    echo "================================================================"
    echo -e "${NC}"
    echo "1. 安装 frpc 服务"
    echo "2. 重启服务"
    echo "3. 配置管理"
    echo "   3.1 编辑配置"
    echo "   3.2 更改服务器地址"
    echo "   3.3 查看配置"
    echo "4. 查看服务状态"
    echo "5. 卸载服务"
    echo "6. 其他功能"
    echo "   6.1 安装全局命令"
    echo "   6.2 移除全局命令"
    echo "0. 退出"
    echo
}

# 配置管理子菜单
config_menu() {
    
    while true; do
        clear
        echo -e "${BLUE}配置管理${NC}"
        echo "1. 编辑配置"
        echo "2. 更改服务器地址"
        echo "3. 查看配置"
        echo "0. 返回主菜单"
        echo
        
        read -p "请选择操作: " config_choice
        
        case $config_choice in
            1)
                edit_config
                read -p "按回车键继续..."
                ;;
            2)
                change_server
                read -p "按回车键继续..."
                ;;
            3)
                view_config
                read -p "按回车键继续..."
                ;;
            0)
                break
                ;;
            *)
                log_error "无效选择，请重新输入"
                sleep 2
                ;;
        esac
    done
}

# 其他功能子菜单
other_menu() {
    while true; do
        clear
        echo -e "${BLUE}其他功能${NC}"
        echo "1. 安装全局命令"
        echo "2. 移除全局命令"
        echo "0. 返回主菜单"
        echo
        
        read -p "请选择操作: " other_choice
        
        case $other_choice in
            1)
                install_global_command
                read -p "按回车键继续..."
                ;;
            2)
                remove_global_command
                read -p "按回车键继续..."
                ;;
            0)
                break
                ;;
            *)
                log_error "无效选择，请重新输入"
                sleep 2
                ;;
        esac
    done
}

# 主函数
main() {
    check_root
    
    # 安装必要的依赖
    if ! command -v wget &> /dev/null; then
        log_info "正在安装wget..."
        apt-get update && apt-get install -y wget
    fi
    
    if ! command -v curl &> /dev/null; then
        log_info "正在安装curl..."
        apt-get update && apt-get install -y curl
    fi
    
    if ! command -v nano &> /dev/null; then
        log_info "正在安装nano..."
        apt-get update && apt-get install -y nano
    fi
    
    while true; do
        show_menu
        read -p "请选择操作: " choice
        
        case $choice in
            1)
                install_frpc
                read -p "按回车键继续..."
                ;;
            2)
                local services
                if services=$(get_frpc_services) && [[ -n "$services" ]]; then
                    restart_service
                    read -p "按回车键继续..."
                else
                    log_error "没有找到已安装的frpc服务"
                    log_info "请先使用选项1安装frpc服务"
                    read -p "按回车键继续..."
                fi
                ;;
            3)
                local services
                if services=$(get_frpc_services) && [[ -n "$services" ]]; then
                    config_menu
                else
                    log_error "没有找到已安装的frpc服务"
                    log_info "请先使用选项1安装frpc服务"
                    read -p "按回车键继续..."
                fi
                ;;
            4)
                local services
                if services=$(get_frpc_services) && [[ -n "$services" ]]; then
                    view_status
                    read -p "按回车键继续..."
                else
                    log_error "没有找到已安装的frpc服务"
                    log_info "请先使用选项1安装frpc服务"
                    read -p "按回车键继续..."
                fi
                ;;
            5)
                local services
                if services=$(get_frpc_services) && [[ -n "$services" ]]; then
                    uninstall_service
                    read -p "按回车键继续..."
                else
                    log_error "没有找到已安装的frpc服务"
                    log_info "请先使用选项1安装frpc服务"
                    read -p "按回车键继续..."
                fi
                ;;
            6)
                other_menu
                ;;
            0)
                log_info "感谢使用，再见！"
                exit 0
                ;;
            *)
                log_error "无效选择，请重新输入"
                sleep 2
                ;;
        esac
    done
}

# 如果脚本被直接执行，运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
