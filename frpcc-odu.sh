#!/bin/sh

echo "======================================"
echo "  frpcc 一键安装脚本"
echo "======================================"
echo ""

# 配置变量（可根据需要修改）
FRP_SERVER="frp.example.com"
FRP_PORT="7000"
FRP_TOKEN=""  # 留空则不使用token
PROXY_NAME="v_proxy"
LOCAL_IP="127.0.0.1"
LOCAL_PORT="7001"
REMOTE_PORT="7002"

# ========== 第一步：复制程序 ==========
echo "[1/4] 复制 frpc 程序为 frpcc..."

if [ ! -f /usr/bin/frpc ]; then
    echo "错误: /usr/bin/frpc 不存在，请先安装 frpc"
    exit 1
fi

cp /usr/bin/frpc /usr/bin/frpcc
chmod +x /usr/bin/frpcc

echo "✓ 程序复制完成"
echo ""

# ========== 第二步：创建配置文件 ==========
echo "[2/4] 创建配置文件 /etc/config/frpcc.toml..."

cat > /etc/config/frpcc.toml << EOF
serverAddr = "$FRP_SERVER"
serverPort = $FRP_PORT
EOF

# 如果设置了token则添加
if [ -n "$FRP_TOKEN" ]; then
    echo "auth.token = \"$FRP_TOKEN\"" >> /etc/config/frpcc.toml
    echo "# auth.token = \"$FRP_TOKEN\"" >> /etc/config/frpcc.toml
fi

cat >> /etc/config/frpcc.toml << EOF

transport.tcpMux = true
transport.protocol = "tcp"

[[proxies]]
type = "tcp"
name = "$PROXY_NAME"
localIP = "$LOCAL_IP"
localPort = $LOCAL_PORT
remotePort = $REMOTE_PORT
EOF

chmod 644 /etc/config/frpcc.toml

echo "✓ 配置文件创建完成"
echo ""

# ========== 第三步：创建启动脚本 ==========
echo "[3/4] 创建启动脚本 /etc/init.d/frpcc..."

cat > /etc/init.d/frpcc << 'EOF'
#!/bin/sh /etc/rc.common

START=99
USE_PROCD=1

NAME=frpcc
PROG=/usr/bin/$NAME
CONF=/etc/config/frpcc.toml

start_service() {
    # 检查配置文件是否存在
    [ ! -f "$CONF" ] && {
        echo "配置文件 $CONF 不存在"
        return 1
    }
    
    procd_open_instance
    procd_set_param command "$PROG" -c "$CONF"
    procd_set_param file "$CONF"
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param respawn
    procd_close_instance
}

service_triggers() {
    procd_add_reload_trigger "$NAME"
}
EOF

chmod +x /etc/init.d/frpcc

echo "✓ 启动脚本创建完成"
echo ""

# ========== 第四步：启动服务 ==========
echo "[4/4] 启动 frpcc 服务..."

# 停止服务（如果已运行）
/etc/init.d/frpcc stop 2>/dev/null

# 启动服务
/etc/init.d/frpcc start

# 设置开机自启
/etc/init.d/frpcc enable

sleep 2

echo "✓ 服务启动完成"
echo ""

# ========== 检查状态 ==========
echo "======================================"
echo "  安装完成！"
echo "======================================"
echo ""
echo "配置信息："
echo "  程序路径: /usr/bin/frpcc"
echo "  配置文件: /etc/config/frpcc.toml"
echo "  启动脚本: /etc/init.d/frpcc"
echo ""
echo "服务器配置："
echo "  服务器地址: $FRP_SERVER"
echo "  服务器端口: $FRP_PORT"
echo ""
echo "代理配置："
echo "  代理名称: $PROXY_NAME"
echo "  本地地址: $LOCAL_IP:$LOCAL_PORT"
echo "  远程端口: $REMOTE_PORT"
echo ""
echo "当前配置文件内容："
cat /etc/config/frpcc.toml
echo ""
echo "======================================"
echo "运行状态："
if ps | grep -v grep | grep frpcc > /dev/null; then
    echo "✓ frpcc 正在运行"
    ps -w | grep frpcc | grep -v grep
else
    echo "✗ frpcc 未运行"
fi
echo ""
echo "======================================"
echo "常用管理命令："
echo "  启动: /etc/init.d/frpcc start"
echo "  停止: /etc/init.d/frpcc stop"
echo "  重启: /etc/init.d/frpcc restart"
echo "  状态: /etc/init.d/frpcc status"
echo "  日志: logread -e frpcc"
echo "  编辑配置: vi /etc/config/frpcc.toml"
echo "======================================"
