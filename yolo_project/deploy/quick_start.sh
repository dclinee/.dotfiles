#!/usr/bin/env bash
# deploy/quick_start.sh — 非交互一键"铺目录 + 安装服务模板"到本机 (Linux + systemd --user 模式)
#
# 用法:
#   cd /opt/smart_sites/yolo_project  # 或者 ~/yolo_project
#   bash deploy/quick_start.sh
#
# 脚本只做三件事:
#   1) 创建运行目录 (runs/data runs/logs runs/recordings datasets/raw_videos datasets/uploaded ...)
#   2) 拷贝 4 个 .service 到 ~/.config/systemd/user/, 把模板里的 %h/yolo_project
#      以及 python 解释器路径换成你当前机器的真实路径
#   3) echo 出下一步 systemctl --user start/enable 的命令 (不会自动 start, 避免误操作)
#
# 不做:
#   - 不装系统依赖 / pip 依赖 (项目自己的 pip install -r requirements.txt 单独跑)
#   - 不动 /etc/systemd/system (那要 sudo, 风险大)
#   - 不跑任何需要联网的命令

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

YELLOW=$'\033[33m'; GREEN=$'\033[32m'; RED=$'\033[31m'; RESET=$'\033[m'
info(){ echo -e "${GREEN}[INFO]${RESET} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${RESET} $*"; }

# ---- 1. 目录 ----
info "1) 创建运行目录..."
for d in \
  runs/data runs/logs runs/recordings runs/video_verify runs/auto_train \
  datasets/raw_videos datasets/uploaded datasets/reviewed datasets/training_pool \
  configs
do
  mkdir -p "$d"
  echo "   + $d"
done

# 如果默认 DB 不存在先创建 (空的 SiteDatabase 会自动建表)
if [ ! -f runs/data/site.db ]; then
  python - <<PY 2>/dev/null || true
import sys; sys.path.insert(0,'.')
from utils.storage import SiteDatabase
SiteDatabase('runs/data/site.db')
PY
  [ -f runs/data/site.db ] && info "   + 空 site.db 已创建 (含所有表结构)"
fi

# ---- 2. 检查关键依赖 ----
PY_EXE="${PYTHON:-$(command -v python3 || command -v python || true)}"
if [ -z "$PY_EXE" ]; then
  echo -e "${RED}[ERR]${RESET} 找不到 python3 解释器. 先装好 pyenv / 系统 python 再跑."; exit 1
fi
PY_ABS="$($PY_EXE -c 'import sys; print(sys.executable)')"
info "2) Python 解释器: $PY_ABS"

for file in \
  scripts/gps_server.py scripts/dashboard_api.py scripts/auto_retrain.py \
  scripts/multi_cam_dispatch.py \
  configs/site_geofence.json configs/personnel.json configs/cameras.json \
  configs/dataset.yaml
do
  if [ ! -f "$file" ]; then
    warn "   可选文件未找到: $file (首次部署通常会缺, 复制样例或先跑单路验证即可)"
  fi
done

# ---- 3. 拷贝 systemd user unit ----
info "3) 安装 systemd --user unit 到 ~/.config/systemd/user/"
SYSD_USER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
mkdir -p "$SYSD_USER_DIR"

for svc in deploy/*.service; do
  name="$(basename "$svc")"
  dest="$SYSD_USER_DIR/$name"
  # 把 unit 文件中的占位符替换成真实值
  #   %h/yolo_project → PROJECT_ROOT
  #   %h/.pyenv/versions/.../python → 当前 PY_ABS
  # 注意: 原始 .service 中 WorkingDirectory=%h/yolo_project
  #       我们改成实际 PROJECT_ROOT (这样即使项目不是放在 ~/yolo_project 也能用)
  sed -e "s#%h/yolo_project#$PROJECT_ROOT#g" \
      -e "s#%h/.pyenv/versions/[^[:space:]]*/bin/python#$PY_ABS#g" \
      "$svc" > "$dest.tmp"
  mv "$dest.tmp" "$dest"
  echo "   + $dest"
done

# 没有 systemd 的环境 (比如容器/macOS) 只是静默跳过 reload
if command -v systemctl >/dev/null 2>&1; then
  if systemctl --user --version >/dev/null 2>&1; then
    systemctl --user daemon-reload 2>/dev/null || true
    info "   systemctl --user daemon-reload OK"
  else
    warn "   检测到 systemctl, 但 systemctl --user 不可用 (不是 user session 模式?)"
  fi
else
  warn "   未检测到 systemctl (非 systemd 发行版? macOS? 容器?)。跳过 unit 安装，直接在 shell 里跑脚本即可。"
fi

# ---- 4. 打印下一步 ----
echo
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━ 启动指南 ━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo
echo "# 1) 安装 pip 依赖 (在项目目录)"
echo "   cd $PROJECT_ROOT"
echo "   $PY_ABS -m pip install -U pip"
echo "   $PY_ABS -m pip install ultralytics torch torchvision opencv-python-headless \\"
echo "       flask pyyaml numpy"
echo
echo "# 2) (可选) 单路摄像头先跑通 (3~5 分钟确认模型+DB+告警 OK)"
echo "   $PY_ABS scripts/video_verify.py \\"
echo "       --model runs/syn_train/syn_exp1/weights/best.pt \\"
echo "       --source datasets/raw_videos/entrance.mp4 \\"
echo "       --zones configs/site_geofence.json \\"
echo "       --mode all --no-display --no-video --storage \\"
echo "       --camera-id cam_entrance --db runs/data/site.db"
echo
echo "# 3) 4 个服务启动 (有 systemd --user 环境)"
echo "   systemctl --user start site-gps.service"
echo "   systemctl --user start site-dashboard.service"
echo "   systemctl --user start site-auto-train.service"
echo "   systemctl --user start site-multi-cam.service"
echo
echo "# 4) 开机自启 (user 模式需要先开启 linger)"
echo "   sudo loginctl enable-linger \$USER   # 需要 sudo, 只执行一次"
echo "   systemctl --user enable site-gps site-dashboard site-auto-train site-multi-cam"
echo
echo "# 5) 实时看日志"
echo "   journalctl --user -u site-gps         -f"
echo "   journalctl --user -u site-dashboard   -f"
echo "   journalctl --user -u site-auto-train  -f"
echo "   journalctl --user -u site-multi-cam   -f"
echo "   # 单路摄像头的子进程日志另写文件:"
echo "   tail -f $PROJECT_ROOT/runs/logs/cam_entrance.log"
echo
echo "# 6) 打开 Dashboard"
echo "   http://<服务器IP>:5001/"
echo
echo -e "${GREEN}完成 ✅  先跑第 2 步，再开 4 个服务，第 6 步去浏览器看效果吧。${RESET}"
