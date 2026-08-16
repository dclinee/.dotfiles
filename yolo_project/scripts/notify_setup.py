#!/usr/bin/env python3
"""
飞书通知配置向导
交互式引导用户完成飞书应用的创建、授权、人员配置全流程

步骤:
  1. 飞书开放平台创建应用
  2. lark-cli 安装与授权
  3. 搜索获取人员 open_id
  4. 写入 personnel.json
  5. 发送测试消息验证
"""

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_DIR = SCRIPT_DIR.parent


def print_step(step_num, title):
    print(f"\n{'='*60}")
    print(f"  步骤 {step_num}: {title}")
    print(f"{'='*60}")


def confirm(msg):
    """交互确认"""
    try:
        ans = input(f"\n{msg} (y/n, 默认y): ").strip().lower()
        return ans != "n"
    except (EOFError, KeyboardInterrupt):
        return True


def check_lark_cli():
    """检查 lark-cli 是否已安装"""
    try:
        result = subprocess.run(["lark-cli", "--version"], capture_output=True, text=True, timeout=5)
        return result.returncode == 0
    except FileNotFoundError:
        return False


def check_lark_auth():
    """检查飞书授权状态"""
    try:
        result = subprocess.run(
            ["lark-cli", "auth", "status", "--as", "bot"],
            capture_output=True, text=True, timeout=10,
        )
        return result.returncode == 0
    except Exception:
        return False


def search_user(name):
    """搜索飞书用户"""
    try:
        result = subprocess.run(
            ["lark-cli", "contact", "+search-user", "--query", name, "--as", "user"],
            capture_output=True, text=True, timeout=15,
        )
        if result.returncode != 0:
            return None

        # 解析输出, 提取 open_id
        for line in result.stdout.split("\n"):
            if "open_id" in line:
                parts = line.split()
                for i, p in enumerate(parts):
                    if p == "open_id:" and i + 1 < len(parts):
                        return parts[i + 1].strip('"')
        return None
    except Exception:
        return None


def run_lark_cmd(cmd, desc=""):
    """运行 lark-cli 命令"""
    print(f"  执行: {desc}")
    print(f"  命令: {' '.join(cmd)}")
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        if result.returncode == 0:
            print(f"  成功")
            return result.stdout
        else:
            print(f"  失败: {result.stderr.strip()}")
            return None
    except Exception as e:
        print(f"  错误: {e}")
        return None


def setup_wizard():
    """配置向导主流程"""

    print("\n" + "#" * 60)
    print("  智慧工地 - 飞书通知配置向导")
    print("#" * 60)

    # ===== 步骤 1: 飞书开放平台创建应用 =====
    print_step(1, "创建飞书应用")

    print("""
  在飞书开放平台创建应用:
  1. 打开 https://open.feishu.cn/app
  2. 点击「创建企业自建应用」
  3. 填写应用名称: 智慧工地安全监控
  4. 应用图标: 上传工地相关图标

  添加应用能力:
  5. 左侧菜单 → 添加应用能力 → 开启「机器人」
  6. 左侧菜单 → 权限管理 → 搜索并开通以下权限:
     - 获取用户信息 (contact:user:readonly)
     - 获取用户统一ID (contact:user.email:readonly)
     - 发送单聊消息 (im:message:send_as_bot)
     - 获取群组信息 (im:chat:readonly)
  7. 左侧菜单 → 安全设置 → 添加 IP 白名单 (可选)
  8. 点击「创建版本」→「申请发布」→ 管理员审批通过
""")

    if not confirm("是否已完成上述步骤?"):
        print("请先完成飞书应用创建后再运行本向导")
        return

    # ===== 步骤 2: lark-cli 安装 =====
    print_step(2, "安装 lark-cli")

    if check_lark_cli():
        print("  lark-cli 已安装")
    else:
        print("  lark-cli 未安装, 正在安装...")
        install_cmd = "pip install lark-cli -U"
        result = subprocess.run(install_cmd, shell=True, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"  安装失败: {result.stderr}")
            print("  请手动安装: pip install lark-cli -U")
            return
        print("  lark-cli 安装成功")

    # ===== 步骤 3: 获取应用凭证 =====
    print_step(3, "获取飞书应用凭证")

    print("""
  在飞书开放平台获取凭证:
  1. 打开 https://open.feishu.cn/app
  2. 点击你的应用 → 左侧「凭证与基础信息」
  3. 复制「App ID」和「App Secret」
""")

    app_id = input("  请输入 App ID: ").strip()
    app_secret = input("  请输入 App Secret: ").strip()

    if not app_id or not app_secret:
        print("  App ID 和 App Secret 不能为空")
        return

    # ===== 步骤 4: lark-cli 授权 =====
    print_step(4, "lark-cli 授权")

    # 设置环境变量
    os.environ["LARK_APP_ID"] = app_id
    os.environ["LARK_APP_SECRET"] = app_secret

    print("  正在授权...")
    result = run_lark_cmd(
        ["lark-cli", "auth", "login", "--app-id", app_id, "--app-secret", app_secret, "--as", "bot"],
        "飞书机器人授权",
    )

    if not result:
        print("  授权失败，请检查 App ID 和 App Secret 是否正确")
        return

    if not check_lark_auth():
        print("  授权状态检查失败，请重新运行")
        return

    print("  授权成功!")

    # ===== 步骤 5: 搜索人员 open_id =====
    print_step(5, "获取人员 open_id")

    print("""
  现在需要获取每个通知对象的飞书 open_id。
  输入姓名搜索 (支持模糊搜索)，系统会自动匹配。
""")

    roles_config = {
        "project_manager": {"name": "项目经理", "members": []},
        "safety_officer": {"name": "安全员", "members": []},
        "team_leader": {"name": "班组长", "members": []},
    }

    for role_key, role_info in roles_config.items():
        print(f"\n  --- {role_info['name']} ---")
        member_count = {"project_manager": 1, "safety_officer": 1, "team_leader": 3}
        count = member_count.get(role_key, 1)

        for i in range(count):
            if role_key == "team_leader" and i > 0:
                if not confirm(f"  是否继续添加班组长?"):
                    break

            name = input(f"  请输入{role_info['name']}姓名 (跳过按回车): ").strip()
            if not name:
                break

            print(f"  正在搜索: {name}...")
            open_id = search_user(name)

            if open_id:
                team = ""
                if role_key == "team_leader":
                    team = input(f"  该班组长所属班组: ").strip()

                member = {"name": name, "open_id": open_id}
                if team:
                    member["team"] = team

                roles_config[role_key]["members"].append(member)
                print(f"  找到: {name} → open_id={open_id}")
            else:
                print(f"  未搜索到用户: {name}")
                print(f"  请确认: 1) 姓名正确 2) 你和该用户有飞书聊天记录")
                manual_id = input(f"  或手动输入 open_id (跳过按回车): ").strip()
                if manual_id and manual_id.startswith("ou_"):
                    roles_config[role_key]["members"].append({
                        "name": name, "open_id": manual_id,
                    })

    # ===== 步骤 6: 写入配置文件 =====
    print_step(6, "写入配置文件")

    # 加载模板
    personnel_path = PROJECT_DIR / "configs" / "personnel.json"
    with open(personnel_path, "r") as f:
        config = json.load(f)

    # 更新人员
    for role_key, role_info in roles_config.items():
        if role_info["members"]:
            config["roles"][role_key]["members"] = role_info["members"]

    # 备份原文件
    backup_path = personnel_path.with_suffix(".json.bak")
    if personnel_path.exists():
        with open(personnel_path, "r") as src, open(backup_path, "w") as dst:
            dst.write(src.read())
        print(f"  已备份原配置: {backup_path}")

    with open(personnel_path, "w") as f:
        json.dump(config, f, indent=2, ensure_ascii=False)

    print(f"  配置已写入: {personnel_path}")

    # ===== 步骤 7: 发送测试消息 =====
    print_step(7, "发送测试消息")

    if not confirm("是否发送测试消息验证通知通道?"):
        print("配置完成! 可稍后手动测试:")
        print("  python utils/notify.py --test --alarm-type no_helmet")
        return

    print("\n  正在发送测试消息...")
    result = run_lark_cmd(
        ["python", "utils/notify.py", "--test", "--alarm-type", "no_helmet"],
        "发送测试告警",
    )

    if result:
        print("\n  测试消息已发送! 请检查飞书消息。")
    else:
        print("\n  测试消息发送失败，请检查配置。")

    # ===== 完成 =====
    print(f"\n{'#'*60}")
    print(f"  配置完成!")
    print(f"{'#'*60}")
    print(f"")
    print(f"  下一步:")
    print(f"    # 带通知的安全检测")
    print(f"    python scripts/video_verify.py --model best.pt --source video.mp4 --notify")
    print(f"")
    print(f"    # 发送每日安全报告")
    print(f"    python scripts/notify_test.py --daily-report")
    print(f"")
    print(f"  如遇问题，可重新运行本向导: python scripts/notify_setup.py")
    print(f"{'#'*60}")


def main():
    parser = argparse.ArgumentParser(description="飞书通知配置向导")
    parser.add_argument("--check", action="store_true",
                        help="仅检查当前配置状态")
    args = parser.parse_args()

    if args.check:
        print("飞书通知配置状态检查\n")

        # lark-cli
        if check_lark_cli():
            print("  lark-cli: 已安装")
        else:
            print("  lark-cli: 未安装 (pip install lark-cli -U)")

        # 授权
        if check_lark_auth():
            print("  飞书授权: 已授权")
        else:
            print("  飞书授权: 未授权 (运行 lark-cli auth login)")

        # 配置文件
        personnel_path = PROJECT_DIR / "configs" / "personnel.json"
        if personnel_path.exists():
            with open(personnel_path, "r") as f:
                config = json.load(f)
            for role_name, role in config.get("roles", {}).items():
                members = role.get("members", [])
                valid = [m for m in members if m.get("open_id", "").startswith("ou_")]
                print(f"  {role['name']}: {len(valid)}/{len(members)} 已配置")
        else:
            print("  personnel.json: 不存在")
        return

    setup_wizard()


if __name__ == "__main__":
    main()