#!/bin/bash
# ============================================================
# 智慧工地 - 生产环境部署脚本
# 支持: systemd / nohup / Docker 三种部署方式
# ============================================================

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SERVICE_NAME="smart-site-monitor"
GPS_SERVICE_NAME="smart-site-gps"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ============================================================
# 1. 检查环境
# ============================================================
check_env() {
    info "检查运行环境..."

    # Python
    if ! command -v python3 &>/dev/null; then
        error "Python3 未安装"
        exit 1
    fi
    echo "  Python: $(python3 --version)"

    # pip
    if ! command -v pip3 &>/dev/null; then
        error "pip3 未安装"
        exit 1
    fi

    # 依赖
    if ! python3 -c "import ultralytics" 2>/dev/null; then
        warn "ultralytics 未安装, 正在安装..."
        pip3 install ultralytics opencv-python flask
    fi

    # GPU
    if command -v nvidia-smi &>/dev/null; then
        echo "  GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)"
    else
        warn "  GPU: 未检测到 (将使用CPU模式, 推理会较慢)"
    fi

    # 模型
    if [ ! -f "$PROJECT_DIR/runs/train" ]; then
        warn "  未找到训练好的模型, 请先训练或指定模型路径"
    fi

    echo ""
    info "环境检查完成"
}

# ============================================================
# 2. 创建 systemd 服务
# ============================================================
install_systemd() {
    info "安装 systemd 服务..."

    MODEL_PATH="${1:-runs/train/s_exp/weights/best.pt}"
    CAMERAS_CONFIG="${2:-configs/cameras.json}"

    # 摄像头监控服务
    cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=智慧工地多路摄像头监控
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${PROJECT_DIR}
ExecStart=/usr/bin/python3 scripts/camera_monitor.py \\
    --model ${MODEL_PATH} \\
    --cameras ${CAMERAS_CONFIG} \\
    --zones configs/danger_zones.json \\
    --notify \\
    --sample_interval 5
Restart=always
RestartSec=10
StandardOutput=append:${PROJECT_DIR}/runs/logs/camera_monitor.log
StandardError=append:${PROJECT_DIR}/runs/logs/camera_monitor_error.log

[Install]
WantedBy=multi-user.target
EOF

    # GPS 定位服务
    cat > /etc/systemd/system/${GPS_SERVICE_NAME}.service << EOF
[Unit]
Description=智慧工地手机定位服务
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${PROJECT_DIR}
ExecStart=/usr/bin/python3 scripts/gps_server.py \\
    --port 8090 \\
    --notify
Restart=always
RestartSec=10
StandardOutput=append:${PROJECT_DIR}/runs/logs/gps_server.log
StandardError=append:${PROJECT_DIR}/runs/logs/gps_server_error.log

[Install]
WantedBy=multi-user.target
EOF

    # 创建日志目录
    mkdir -p "${PROJECT_DIR}/runs/logs"

    # 启用服务
    systemctl daemon-reload
    systemctl enable ${SERVICE_NAME}
    systemctl enable ${GPS_SERVICE_NAME}

    info "systemd 服务安装完成"
    echo ""
    echo "  启停命令:"
    echo "    systemctl start ${SERVICE_NAME}       # 启动摄像头监控"
    echo "    systemctl start ${GPS_SERVICE_NAME}   # 启动GPS服务"
    echo "    systemctl status ${SERVICE_NAME}      # 查看状态"
    echo "    systemctl stop ${SERVICE_NAME}        # 停止"
    echo "    journalctl -u ${SERVICE_NAME} -f      # 查看日志"
}

# ============================================================
# 3. nohup 后台运行
# ============================================================
start_nohup() {
    info "使用 nohup 后台启动..."

    MODEL_PATH="${1:-runs/train/s_exp/weights/best.pt}"
    CAMERAS_CONFIG="${2:-configs/cameras.json}"

    mkdir -p "${PROJECT_DIR}/runs/logs"

    # 启动摄像头监控
    nohup python3 scripts/camera_monitor.py \
        --model "${MODEL_PATH}" \
        --cameras "${CAMERAS_CONFIG}" \
        --zones configs/danger_zones.json \
        --notify \
        --sample_interval 5 \
        > "${PROJECT_DIR}/runs/logs/camera_monitor.log" 2>&1 &
    echo $! > "${PROJECT_DIR}/runs/logs/camera_monitor.pid"
    info "摄像头监控已启动 (PID: $(cat ${PROJECT_DIR}/runs/logs/camera_monitor.pid))"

    # 启动 GPS 服务
    nohup python3 scripts/gps_server.py \
        --port 8090 \
        --notify \
        > "${PROJECT_DIR}/runs/logs/gps_server.log" 2>&1 &
    echo $! > "${PROJECT_DIR}/runs/logs/gps_server.pid"
    info "GPS服务已启动 (PID: $(cat ${PROJECT_DIR}/runs/logs/gps_server.pid))"

    echo ""
    echo "  日志查看:"
    echo "    tail -f runs/logs/camera_monitor.log"
    echo "    tail -f runs/logs/gps_server.log"
}

# ============================================================
# 4. 停止 nohup 服务
# ============================================================
stop_nohup() {
    info "停止 nohup 服务..."

    for svc in camera_monitor gps_server; do
        pid_file="${PROJECT_DIR}/runs/logs/${svc}.pid"
        if [ -f "$pid_file" ]; then
            pid=$(cat "$pid_file")
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid"
                info "已停止 ${svc} (PID: $pid)"
            fi
            rm -f "$pid_file"
        fi
    done
    info "全部服务已停止"
}

# ============================================================
# 5. Docker 部署
# ============================================================
generate_docker() {
    info "生成 Docker 部署文件..."

    cat > "${PROJECT_DIR}/Dockerfile" << 'DOCKERFILE'
FROM nvidia/cuda:12.1-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y \
    python3 python3-pip python3-opencv \
    libgl1-mesa-glx libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8090

CMD ["python3", "scripts/camera_monitor.py", \
     "--model", "runs/train/s_exp/weights/best.pt", \
     "--cameras", "configs/cameras.json", \
     "--zones", "configs/danger_zones.json", \
     "--notify"]
DOCKERFILE

    cat > "${PROJECT_DIR}/docker-compose.yml" << 'COMPOSE'
version: "3.8"

services:
  camera-monitor:
    build: .
    container_name: smart-site-camera
    restart: always
    volumes:
      - ./runs:/app/runs
      - ./configs:/app/configs
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
    logging:
      driver: json-file
      options:
        max-size: "100m"
        max-file: "3"

  gps-server:
    build: .
    container_name: smart-site-gps
    restart: always
    command: python3 scripts/gps_server.py --port 8090 --notify
    ports:
      - "8090:8090"
    volumes:
      - ./runs:/app/runs
      - ./configs:/app/configs
    logging:
      driver: json-file
      options:
        max-size: "50m"
        max-file: "3"
COMPOSE

    info "Docker 文件已生成: Dockerfile, docker-compose.yml"
    echo ""
    echo "  使用方式:"
    echo "    docker-compose up -d          # 启动所有服务"
    echo "    docker-compose logs -f        # 查看日志"
    echo "    docker-compose down           # 停止"
}

# ============================================================
# 6. 定时任务 (日报/周报)
# ============================================================
install_crontab() {
    info "安装定时任务..."

    cat > /tmp/smart_site_cron << CRON
# 智慧工地 - 定时任务
# 每天 17:30 生成安全日报
30 17 * * * cd ${PROJECT_DIR} && python3 scripts/site_stats.py --model runs/train/s_exp/weights/best.pt --source 0 --notify --output runs/daily_report/$(date +\%Y\%m\%d) >> runs/logs/daily_report.log 2>&1

# 每天 00:00 重置工人每日统计
0 0 * * * cd ${PROJECT_DIR} && python3 -c "from utils.positioning import get_tracker; get_tracker().reset_daily()" >> runs/logs/reset_daily.log 2>&1

# 每周一 08:00 发送周报
0 8 * * 1 cd ${PROJECT_DIR} && python3 scripts/review_report.py --report-dir runs/daily_report --html >> runs/logs/weekly_report.log 2>&1
CRON

    crontab /tmp/smart_site_cron 2>/dev/null || {
        warn "无法安装 crontab (可能无权限), 手动添加:"
        cat /tmp/smart_site_cron
    }
    rm -f /tmp/smart_site_cron
    info "定时任务已安装"
}

# ============================================================
# 主菜单
# ============================================================
main() {
    echo ""
    echo "============================================"
    echo "  智慧工地 - 生产环境部署工具"
    echo "============================================"
    echo ""

    ACTION="${1:-help}"
    MODEL="${2:-runs/train/s_exp/weights/best.pt}"
    CAMERAS="${3:-configs/cameras.json}"

    case "$ACTION" in
        check)
            check_env
            ;;
        systemd)
            check_env
            install_systemd "$MODEL" "$CAMERAS"
            ;;
        nohup)
            check_env
            start_nohup "$MODEL" "$CAMERAS"
            ;;
        stop)
            stop_nohup
            ;;
        docker)
            check_env
            generate_docker
            ;;
        cron)
            install_crontab
            ;;
        all)
            check_env
            start_nohup "$MODEL" "$CAMERAS"
            install_crontab
            info "全部部署完成!"
            echo ""
            echo "  运行中的服务:"
            ps aux | grep -E "camera_monitor|gps_server" | grep -v grep
            ;;
        help|*)
            echo "用法: bash scripts/deploy.sh <command> [model_path] [cameras_config]"
            echo ""
            echo "命令:"
            echo "  check      检查运行环境"
            echo "  systemd    安装 systemd 服务 (开机自启)"
            echo "  nohup      后台启动 (nohup)"
            echo "  stop       停止 nohup 服务"
            echo "  docker     生成 Docker 部署文件"
            echo "  cron       安装定时任务 (日报/周报)"
            echo "  all        一键部署 (nohup + cron)"
            echo ""
            echo "示例:"
            echo "  bash scripts/deploy.sh check"
            echo "  bash scripts/deploy.sh nohup runs/train/s_exp/weights/best.pt"
            echo "  bash scripts/deploy.sh systemd best.pt configs/cameras.json"
            ;;
    esac
}

main "$@"