#!/usr/bin/env python3
"""
智慧工地 - 单路视频端到端验证
整合: 安全装备检测 + 入侵检测 + 统计报表 → 一次运行全部验证

输出:
  - 带标注的视频
  - 违规截图 (存入 runs/video_verify/captures/)
  - 统计报告 (CSV/JSON)
  - 事件日志

用法:
  # 完整验证
  python scripts/video_verify.py --model best.pt --source site_video.mp4

  # 仅安全检测
  python scripts/video_verify.py --model best.pt --source video.mp4 --mode safety

  # 安全+入侵
  python scripts/video_verify.py --model best.pt --source video.mp4 --zones configs/danger_zones.json --mode all
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path
from datetime import datetime
from collections import defaultdict, deque
import cv2
import numpy as np
from ultralytics import YOLO

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from utils.common import point_in_polygon, CLASS_NAMES, CLASS_COLORS, SAFETY_VIOLATION_CLASSES
from utils.logger import get_logger


# ============================================================
# 配置
# ============================================================

# 使用 common 模块中的统一常量
SAFETY_VIOLATIONS = SAFETY_VIOLATION_CLASSES
COLORS = CLASS_COLORS


# ============================================================
# 视频验证器
# ============================================================

class VideoVerifier:
    """单路视频端到端验证器"""

    def __init__(self, model_path, source,
                 danger_zones=None, conf=0.3, iou=0.5,
                 mode="all", device="cpu",
                 output_dir="runs/video_verify",
                 save_video=True, show_display=True,
                 skip_frames=1, alert_cooldown=5):
        """
        Args:
            model_path: 模型权重路径
            source: 视频源 (文件/摄像头/RTSP)
            danger_zones: 危险区域多边形 [{name, points}, ...]
            conf: 置信度阈值
            iou: NMS IoU 阈值
            mode: 检测模式 (safety / intrusion / all)
            device: 设备
            output_dir: 输出目录
            save_video: 是否保存视频
            show_display: 是否显示画面
            skip_frames: 跳帧 (1=不跳, 2=隔一帧)
            alert_cooldown: 告警冷却时间 (秒)
        """
        self.model = YOLO(model_path)
        self.source = source
        self.danger_zones = danger_zones or []
        self.conf = conf
        self.iou = iou
        self.mode = mode
        self.device = device
        self.output_dir = Path(output_dir)
        self.save_video = save_video
        self.show_display = show_display
        self.skip_frames = skip_frames
        self.alert_cooldown = alert_cooldown

        # 创建输出目录
        self.output_dir.mkdir(parents=True, exist_ok=True)
        (self.output_dir / "captures").mkdir(exist_ok=True)
        (self.output_dir / "violations").mkdir(exist_ok=True)

        # 统计
        self.stats = {
            "total_frames": 0,
            "processed_frames": 0,
            "total_persons": 0,
            "total_helmets": 0,
            "total_no_helmets": 0,
            "total_vests": 0,
            "total_no_vests": 0,
            "total_vehicles": 0,
            "violations_captured": 0,
            "intrusions_detected": 0,
            "start_time": time.time(),
        }

        # 告警冷却
        self._last_alert = defaultdict(float)

        # 事件日志
        self.events = []
        self._event_log_path = self.output_dir / "events.jsonl"

        # 入侵追踪
        self._intrusion_tracker = defaultdict(int)  # track_id -> count

        # 视频属性
        self._fps = 30
        self._width = 1280
        self._height = 720

    # ============================================================
    # 核心: 处理单帧
    # ============================================================

    def process_frame(self, frame, frame_idx, timestamp):
        """
        处理单帧

        Returns:
            annotated_frame, violations, intrusions
        """
        h, w = frame.shape[:2]
        self.stats["processed_frames"] += 1

        # 运行 YOLO 推理
        results = self.model(frame, conf=self.conf, iou=self.iou,
                             device=self.device, verbose=False)

        violations = []
        intrusions = []
        annotated = frame.copy()

        if len(results) == 0 or results[0].boxes is None:
            return annotated, violations, intrusions

        boxes = results[0].boxes
        if boxes.xyxy is None or len(boxes.xyxy) == 0:
            return annotated, violations, intrusions

        for i in range(len(boxes.xyxy)):
            cls_id = int(boxes.cls[i])
            conf_val = float(boxes.conf[i])
            x1, y1, x2, y2 = boxes.xyxy[i].tolist()
            x1, y1, x2, y2 = int(x1), int(y1), int(x2), int(y2)

            cls_name = CLASS_NAMES.get(cls_id, f"cls_{cls_id}")
            color = COLORS.get(cls_id, (255, 255, 255))

            # 统计
            if cls_id == 0:
                self.stats["total_persons"] += 1
            elif cls_id == 1:
                self.stats["total_helmets"] += 1
            elif cls_id == 2:
                self.stats["total_no_helmets"] += 1
            elif cls_id == 3:
                self.stats["total_vests"] += 1
            elif cls_id == 4:
                self.stats["total_no_vests"] += 1
            elif cls_id == 5:
                self.stats["total_vehicles"] += 1

            # 违规检测
            if cls_id in SAFETY_VIOLATIONS and self.mode in ("safety", "all"):
                violation_type = SAFETY_VIOLATIONS[cls_id]
                ctime = time.time()

                # 冷却检查
                if ctime - self._last_alert[violation_type] > self.alert_cooldown:
                    violations.append({
                        "type": violation_type,
                        "cls_id": cls_id,
                        "conf": conf_val,
                        "bbox": (x1, y1, x2, y2),
                        "frame": frame_idx,
                        "timestamp": timestamp,
                    })
                    self._last_alert[violation_type] = ctime
                    self.stats["violations_captured"] += 1

                    # 保存违规截图
                    self._save_violation_capture(frame, violation_type, frame_idx)

                # 违规框用红色
                color = (0, 0, 255)

            # 入侵检测
            if cls_id == 0 and self.mode in ("intrusion", "all"):
                # 计算人员脚底位置
                foot_x = (x1 + x2) // 2
                foot_y = y2

                for zone in self.danger_zones:
                    if self._point_in_polygon(foot_x, foot_y, zone["points"]):
                        intrusions.append({
                            "zone": zone["name"],
                            "person_bbox": (x1, y1, x2, y2),
                            "frame": frame_idx,
                            "timestamp": timestamp,
                        })
                        self.stats["intrusions_detected"] += 1

                        # 画入侵警告
                        self._draw_intrusion_warning(annotated, zone["name"],
                                                     foot_x, foot_y)

            # 绘制检测框
            self._draw_box(annotated, x1, y1, x2, y2, cls_name, conf_val, color)

        return annotated, violations, intrusions

    # ============================================================
    # 运行
    # ============================================================

    def run(self, max_frames=0):
        """
        运行视频验证

        Args:
            max_frames: 最大处理帧数 (0=全部)
        """
        cap = cv2.VideoCapture(self.source)
        if not cap.isOpened():
            print(f"无法打开视频源: {self.source}")
            return

        self._fps = cap.get(cv2.CAP_PROP_FPS) or 30
        self._width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        self._height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

        print(f"视频源: {self.source}")
        print(f"分辨率: {self._width}x{self._height} | FPS: {self._fps:.1f}")
        print(f"总帧数: {total_frames} | 检测模式: {self.mode}")
        print(f"危险区域: {len(self.danger_zones)} 个")
        print(f"跳帧: {self.skip_frames} | 置信度: {self.conf}")
        print(f"{'='*60}")

        # 视频写入器
        video_writer = None
        if self.save_video:
            out_path = str(self.output_dir / "annotated_output.mp4")
            fourcc = cv2.VideoWriter_fourcc(*"mp4v")
            video_writer = cv2.VideoWriter(
                out_path, fourcc, self._fps / self.skip_frames,
                (self._width, self._height),
            )

        frame_idx = 0
        processed = 0
        start_time = time.time()
        all_violations = []
        all_intrusions = []

        while True:
            ret, frame = cap.read()
            if not ret:
                break

            frame_idx += 1
            self.stats["total_frames"] = frame_idx

            # 跳帧
            if frame_idx % self.skip_frames != 0:
                continue

            # 计算时间戳
            timestamp = frame_idx / self._fps

            # 处理
            annotated, violations, intrusions = self.process_frame(
                frame, frame_idx, timestamp
            )

            all_violations.extend(violations)
            all_intrusions.extend(intrusions)

            # 帧信息叠加
            self._draw_frame_info(annotated, frame_idx, total_frames, timestamp)

            # 保存
            if video_writer:
                video_writer.write(annotated)

            # 显示
            if self.show_display:
                cv2.imshow("Video Verifier", annotated)
                key = cv2.waitKey(1) & 0xFF
                if key == ord("q"):
                    break
                elif key == ord(" "):
                    while True:
                        if cv2.waitKey(0) & 0xFF == ord(" "):
                            break

            processed += 1

            # 进度
            if processed % 50 == 0:
                elapsed = time.time() - start_time
                fps = processed / elapsed if elapsed > 0 else 0
                pct = (frame_idx / total_frames * 100) if total_frames > 0 else 0
                print(f"  进度: {frame_idx}/{total_frames} ({pct:.0f}%) | "
                      f"FPS: {fps:.1f} | "
                      f"违规: {len(all_violations)} | "
                      f"入侵: {len(all_intrusions)}")

            if max_frames > 0 and processed >= max_frames:
                break

        # 清理
        cap.release()
        if video_writer:
            video_writer.release()
        cv2.destroyAllWindows()

        self.stats["end_time"] = time.time()

        # 保存事件日志
        self._save_events(all_violations, all_intrusions)

        # 打印报告
        self._print_report(all_violations, all_intrusions)

    # ============================================================
    # 报告
    # ============================================================

    def _print_report(self, violations, intrusions):
        """打印验证报告"""
        elapsed = self.stats["end_time"] - self.stats["start_time"]
        fps = self.stats["processed_frames"] / elapsed if elapsed > 0 else 0

        print(f"\n{'='*60}")
        print(f"  视频验证报告")
        print(f"{'='*60}")
        print(f"  处理帧数: {self.stats['processed_frames']}/{self.stats['total_frames']}")
        print(f"  耗时: {elapsed:.1f}s (实际 FPS: {fps:.1f})")
        print(f"")
        print(f"  检测统计:")
        print(f"    人员: {self.stats['total_persons']}")
        print(f"    安全帽: {self.stats['total_helmets']}")
        print(f"    未戴安全帽: {self.stats['total_no_helmets']}")
        print(f"    反光衣: {self.stats['total_vests']}")
        print(f"    未穿反光衣: {self.stats['total_no_vests']}")
        print(f"    车辆: {self.stats['total_vehicles']}")
        print(f"")

        # 合规率
        total_gear = (self.stats['total_helmets'] + self.stats['total_no_helmets'])
        total_vest = (self.stats['total_vests'] + self.stats['total_no_vests'])
        helmet_rate = (self.stats['total_helmets'] / total_gear * 100
                       if total_gear > 0 else 0)
        vest_rate = (self.stats['total_vests'] / total_vest * 100
                     if total_vest > 0 else 0)

        print(f"  安全合规率:")
        print(f"    安全帽佩戴率: {helmet_rate:.1f}%")
        print(f"    反光衣穿戴率: {vest_rate:.1f}%")
        print(f"")

        # 违规
        v_by_type = defaultdict(int)
        for v in violations:
            v_by_type[v["type"]] += 1

        print(f"  违规事件:")
        print(f"    安全帽违规: {v_by_type.get('no_helmet', 0)} 次")
        print(f"    反光衣违规: {v_by_type.get('no_vest', 0)} 次")
        print(f"    入侵事件: {len(intrusions)} 次")
        print(f"")

        # 入侵详情
        if intrusions:
            i_by_zone = defaultdict(int)
            for intr in intrusions:
                i_by_zone[intr["zone"]] += 1
            print(f"  入侵详情:")
            for zone, count in i_by_zone.items():
                print(f"    {zone}: {count} 次")

        print(f"")
        print(f"  输出文件:")
        print(f"    标注视频: {self.output_dir}/annotated_output.mp4")
        print(f"    违规截图: {self.output_dir}/violations/")
        print(f"    事件日志: {self._event_log_path}")
        print(f"    报表 JSON: {self.output_dir}/report.json")
        print(f"{'='*60}")

        # 保存 JSON 报告
        report = {
            "source": self.source,
            "model": self.model.model_name if hasattr(self.model, 'model_name') else "",
            "mode": self.mode,
            "stats": {
                "total_frames": self.stats["total_frames"],
                "processed_frames": self.stats["processed_frames"],
                "elapsed_s": round(elapsed, 1),
                "actual_fps": round(fps, 1),
                "total_persons": self.stats["total_persons"],
                "total_helmets": self.stats["total_helmets"],
                "total_no_helmets": self.stats["total_no_helmets"],
                "total_vests": self.stats["total_vests"],
                "total_no_vests": self.stats["total_no_vests"],
                "total_vehicles": self.stats["total_vehicles"],
                "helmet_compliance_rate": round(helmet_rate, 1),
                "vest_compliance_rate": round(vest_rate, 1),
                "violations": dict(v_by_type),
                "intrusions": len(intrusions),
            },
            "violations": violations[:100],  # 截断
            "intrusions": intrusions[:100],
            "generated_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        }

        with open(self.output_dir / "report.json", "w") as f:
            json.dump(report, f, indent=2, ensure_ascii=False)

    # ============================================================
    # 绘制
    # ============================================================

    def _draw_box(self, frame, x1, y1, x2, y2, label, conf, color):
        """绘制检测框"""
        cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)

        # 标签背景
        text = f"{label} {conf:.2f}"
        (tw, th), _ = cv2.getTextSize(text, cv2.FONT_HERSHEY_SIMPLEX, 0.5, 1)
        cv2.rectangle(frame, (x1, y1 - th - 6), (x1 + tw, y1), color, -1)
        cv2.putText(frame, text, (x1, y1 - 4),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 0), 1)

    def _draw_intrusion_warning(self, frame, zone_name, x, y):
        """绘制入侵警告"""
        # 闪烁警告圈
        if int(time.time() * 3) % 2:
            cv2.circle(frame, (x, y), 40, (0, 0, 255), 3)
            cv2.putText(frame, f"INTRUSION: {zone_name}",
                        (x + 45, y - 10),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)

    def _draw_frame_info(self, frame, frame_idx, total, timestamp):
        """绘制帧信息"""
        h, w = frame.shape[:2]

        # 顶部信息栏
        overlay = frame.copy()
        cv2.rectangle(overlay, (0, 0), (w, 40), (0, 0, 0), -1)
        frame = cv2.addWeighted(overlay, 0.4, frame, 0.6, 0)

        mins = int(timestamp // 60)
        secs = int(timestamp % 60)
        info = (f"Frame: {frame_idx}/{total} | "
                f"Time: {mins:02d}:{secs:02d} | "
                f"Mode: {self.mode} | "
                f"Violations: {self.stats['violations_captured']} | "
                f"Intrusions: {self.stats['intrusions_detected']}")

        cv2.putText(frame, info, (10, 28),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 1)

        # 画危险区域
        for zone in self.danger_zones:
            pts = np.array(zone["points"], np.int32).reshape((-1, 1, 2))
            cv2.polylines(frame, [pts], True, (0, 0, 255), 2)
            cv2.putText(frame, zone["name"],
                        tuple(zone["points"][0]),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 255), 1)

    # ============================================================
    # 工具
    # ============================================================

    def _point_in_polygon(self, x, y, polygon):
        """射线法判断点是否在多边形内 (委托给 common 模块)"""
        return point_in_polygon(x, y, polygon)

    def _save_violation_capture(self, frame, vtype, frame_idx):
        """保存违规截图"""
        filename = f"{vtype}_{frame_idx:06d}.jpg"
        path = self.output_dir / "violations" / filename
        cv2.imwrite(str(path), frame)

    def _save_events(self, violations, intrusions):
        """保存事件日志"""
        with open(self._event_log_path, "w") as f:
            for v in violations:
                event = {
                    "type": "violation",
                    "violation_type": v["type"],
                    "frame": v["frame"],
                    "timestamp": round(v["timestamp"], 2),
                    "conf": round(v["conf"], 3),
                }
                f.write(json.dumps(event, ensure_ascii=False) + "\n")

            for intr in intrusions:
                event = {
                    "type": "intrusion",
                    "zone": intr["zone"],
                    "frame": intr["frame"],
                    "timestamp": round(intr["timestamp"], 2),
                }
                f.write(json.dumps(event, ensure_ascii=False) + "\n")


# ============================================================
# 危险区域标注工具
# ============================================================

def annotate_danger_zones(image_path, output_path="configs/my_zones.json"):
    """交互式标注危险区域"""
    img = cv2.imread(image_path)
    if img is None:
        print(f"无法读取图片: {image_path}")
        return

    zones = []
    current_zone = []
    drawing = False

    def draw_callback(event, x, y, flags, param):
        nonlocal drawing, current_zone
        if event == cv2.EVENT_LBUTTONDOWN:
            current_zone.append([x, y])
            drawing = True
        elif event == cv2.EVENT_MOUSEMOVE and drawing:
            pass
        elif event == cv2.EVENT_LBUTTONUP:
            drawing = False

    print("\n危险区域标注工具")
    print("  点击左键: 添加顶点")
    print("  按 'n': 完成当前区域, 开始下一个")
    print("  按 's': 保存所有区域")
    print("  按 'q': 退出")
    print("  按 'u': 撤销上一个顶点")

    cv2.namedWindow("Annotate Danger Zones")
    cv2.setMouseCallback("Annotate Danger Zones", draw_callback)

    display = img.copy()

    while True:
        display = img.copy()

        # 画已完成的区域
        for i, zone in enumerate(zones):
            pts = np.array(zone["points"], np.int32).reshape((-1, 1, 2))
            cv2.polylines(display, [pts], True, (0, 0, 255), 2)
            cv2.putText(display, zone["name"],
                        tuple(zone["points"][0]),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 255), 1)

        # 画当前区域
        if len(current_zone) > 1:
            pts = np.array(current_zone, np.int32).reshape((-1, 1, 2))
            cv2.polylines(display, [pts], False, (0, 255, 255), 2)
        for pt in current_zone:
            cv2.circle(display, tuple(pt), 4, (0, 255, 255), -1)

        # 提示
        cv2.putText(display, f"Zones: {len(zones)} | Vertices: {len(current_zone)}",
                    (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
        cv2.putText(display, "n=next zone | s=save | u=undo | q=quit",
                    (10, 55), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)

        cv2.imshow("Annotate Danger Zones", display)
        key = cv2.waitKey(100) & 0xFF

        if key == ord("n") and len(current_zone) >= 3:
            name = input(f"  区域 {len(zones)+1} 名称: ").strip() or f"zone_{len(zones)+1}"
            zones.append({"name": name, "points": current_zone.copy()})
            current_zone = []
            print(f"  已添加区域: {name} ({len(zones[-1]['points'])} 个顶点)")
        elif key == ord("s"):
            break
        elif key == ord("q"):
            cv2.destroyAllWindows()
            return
        elif key == ord("u") and current_zone:
            current_zone.pop()

    cv2.destroyAllWindows()

    if zones:
        with open(output_path, "w") as f:
            json.dump(zones, f, indent=2, ensure_ascii=False)
        print(f"\n已保存 {len(zones)} 个危险区域到: {output_path}")
    else:
        print("未标注任何区域")


# ============================================================
# 主函数
# ============================================================

def main():
    parser = argparse.ArgumentParser(
        description="智慧工地 - 单路视频端到端验证",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  # 完整验证 (安全+入侵)
  python scripts/video_verify.py --model best.pt --source video.mp4 --zones configs/danger_zones.json

  # 仅安全装备检测
  python scripts/video_verify.py --model best.pt --source video.mp4 --mode safety

  # 交互式标注危险区域
  python scripts/video_verify.py --annotate scene.jpg --annotate-output configs/my_zones.json

  # 仅入侵检测
  python scripts/video_verify.py --model best.pt --source video.mp4 --zones configs/my_zones.json --mode intrusion

  # 无显示模式 (服务器)
  python scripts/video_verify.py --model best.pt --source video.mp4 --no-display
        """,
    )

    parser.add_argument("--model", type=str, default=None,
                        help="模型权重路径")
    parser.add_argument("--source", type=str, default=None,
                        help="视频源 (文件/摄像头/RTSP)")
    parser.add_argument("--zones", type=str, default=None,
                        help="危险区域 JSON 文件")
    parser.add_argument("--mode", type=str, default="all",
                        choices=["safety", "intrusion", "all"],
                        help="检测模式")
    parser.add_argument("--conf", type=float, default=0.3,
                        help="置信度阈值")
    parser.add_argument("--device", type=str, default="cpu",
                        help="设备")
    parser.add_argument("--output", type=str, default="runs/video_verify",
                        help="输出目录")
    parser.add_argument("--skip-frames", type=int, default=1,
                        help="跳帧 (1=不跳)")
    parser.add_argument("--no-display", action="store_true",
                        help="不显示画面")
    parser.add_argument("--no-video", action="store_true",
                        help="不保存视频")
    parser.add_argument("--max-frames", type=int, default=0,
                        help="最大处理帧数 (0=全部)")
    parser.add_argument("--annotate", type=str, default=None,
                        help="交互式标注危险区域 (输入图片路径)")
    parser.add_argument("--annotate-output", type=str, default="configs/my_zones.json",
                        help="标注输出路径")

    args = parser.parse_args()

    # 交互式标注模式
    if args.annotate:
        annotate_danger_zones(args.annotate, args.annotate_output)
        return

    if not args.model or not args.source:
        parser.error("需要 --model 和 --source 参数")

    # 加载危险区域
    danger_zones = []
    if args.zones:
        with open(args.zones, "r") as f:
            zones_data = json.load(f)
        if isinstance(zones_data, list):
            danger_zones = zones_data
        elif isinstance(zones_data, dict):
            # 兼容 site_geofence.json 格式
            for z in zones_data.get("sub_zones", []):
                if z.get("type") == "danger":
                    # GPS 坐标 → 像素坐标 (需要转换, 这里标记为 raw)
                    danger_zones.append({
                        "name": z["name"],
                        "points": z["boundary"],
                    })

    if danger_zones:
        print(f"加载 {len(danger_zones)} 个危险区域:")
        for z in danger_zones:
            print(f"  - {z['name']} ({len(z['points'])} 个顶点)")

    # 运行验证
    verifier = VideoVerifier(
        model_path=args.model,
        source=args.source,
        danger_zones=danger_zones,
        conf=args.conf,
        mode=args.mode,
        device=args.device,
        output_dir=args.output,
        save_video=not args.no_video,
        show_display=not args.no_display,
        skip_frames=args.skip_frames,
    )

    verifier.run(max_frames=args.max_frames)


if __name__ == "__main__":
    main()