#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/telebox-multi"
IMAGE_NAME="yaobaobaoya/telebox-clean:latest"
BACKUP_DIR="$BASE_DIR/backups"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

ok() {
  echo -e "${GREEN}[OK]${NC} $1"
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

err() {
  echo -e "${RED}[ERROR]${NC} $1"
}

need_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    err "请用 root 运行此脚本"
    echo "例如：sudo bash telebox-manager.sh install tg1"
    exit 1
  fi
}

check_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    err "未检测到 Docker，请先安装 Docker，或执行：bash $0 install-docker"
    exit 1
  fi

  if ! docker compose version >/dev/null 2>&1; then
    err "未检测到 Docker Compose 插件，请先安装 docker compose"
    exit 1
  fi
}

install_docker() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    ok "Docker 和 Docker Compose 已安装，无需重复安装"
    return 0
  fi

  info "开始安装 Docker ..."

  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$(. /etc/os-release && echo \"$ID\") \
      $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | \
      tee /etc/apt/sources.list.d/docker.list >/dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker || true
  elif command -v dnf >/dev/null 2>&1; then
    dnf -y install dnf-plugins-core
    dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo || \
    dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker || true
  elif command -v yum >/dev/null 2>&1; then
    yum -y install yum-utils
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    yum -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker || true
  else
    err "未识别的系统包管理器，暂不支持自动安装 Docker"
    exit 1
  fi

  check_docker
  ok "Docker 安装完成"
}

validate_name() {
  local name="${1:-}"
  if [[ -z "$name" ]]; then
    err "实例名不能为空"
    exit 1
  fi

  if [[ ! "$name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    err "实例名只允许字母、数字、点、下划线、短横线"
    exit 1
  fi
}

instance_dir() {
  local name="$1"
  echo "$BASE_DIR/$name"
}

compose_file() {
  local name="$1"
  echo "$(instance_dir "$name")/docker-compose.yml"
}

ensure_instance_exists() {
  local name="$1"
  local dir
  dir="$(instance_dir "$name")"

  if [[ ! -d "$dir" ]]; then
    err "实例不存在：$name"
    exit 1
  fi

  if [[ ! -f "$(compose_file "$name")" ]]; then
    err "未找到 compose 文件：$(compose_file "$name")"
    exit 1
  fi
}

write_compose() {
  local name="$1"
  local dir
  dir="$(instance_dir "$name")"

  cat > "$dir/docker-compose.yml" <<EOF
services:
  telebox:
    image: $IMAGE_NAME
    container_name: telebox-$name
    restart: unless-stopped
    environment:
      TELEBOX_REPO: https://github.com/TeleBoxOrg/TeleBox.git
      TELEBOX_BRANCH: main
      TELEBOX_WORKSPACE: /workspace
      TELEBOX_DATA: /data
      NODE_PATH: /workspace/node_modules
      TZ: Asia/Shanghai
    volumes:
      - $dir/workspace:/workspace
      - $dir/data:/data
    command: ["npm", "start"]
EOF
}

install_instance() {
  local name="$1"
  local dir
  dir="$(instance_dir "$name")"

  if [[ -d "$dir" ]]; then
    err "实例已存在：$name"
    echo "目录：$dir"
    exit 1
  fi

  info "创建实例目录：$dir"
  mkdir -p "$dir/workspace" "$dir/data"

  info "写入 compose 文件"
  write_compose "$name"

  ok "实例已创建：$name"
  echo
  warn "接下来开始首次初始化：$name"
  warn "你需要按提示输入 api_id、api_hash、手机号、验证码、二步验证密码（如果有）"
  echo

  (
    cd "$dir"
    docker compose run --rm telebox npm start
  )

  local session_file="$dir/data/my_session.session"
  if [[ ! -f "$session_file" ]]; then
    err "首次初始化似乎未完成：未检测到会话文件 $session_file"
    warn "请重新执行安装，或进入实例目录手动运行：docker compose run --rm telebox npm start"
    exit 1
  fi

  ok "首次初始化完成：$name"

  info "启动后台服务：$name"
  (
    cd "$dir"
    docker compose up -d
  )

  ok "实例已启动：$name"
  echo
  echo "查看日志：sudo bash $0 logs $name"
}

start_instance() {
  local name="$1"
  ensure_instance_exists "$name"
  (
    cd "$(instance_dir "$name")"
    docker compose up -d
  )
  ok "已启动：$name"
}

stop_instance() {
  local name="$1"
  ensure_instance_exists "$name"
  (
    cd "$(instance_dir "$name")"
    docker compose down
  )
  ok "已停止：$name"
}

restart_instance() {
  local name="$1"
  ensure_instance_exists "$name"
  (
    cd "$(instance_dir "$name")"
    docker compose down
    docker compose up -d
  )
  ok "已重启：$name"
}

logs_instance() {
  local name="$1"
  ensure_instance_exists "$name"
  (
    cd "$(instance_dir "$name")"
    docker compose logs -f
  )
}

status_instance() {
  local name="$1"
  ensure_instance_exists "$name"
  (
    cd "$(instance_dir "$name")"
    docker compose ps
  )
}

list_instances() {
  mkdir -p "$BASE_DIR"
  info "实例列表："

  local found=0
  for dir in "$BASE_DIR"/*; do
    [[ -d "$dir" ]] || continue
    local name
    name="$(basename "$dir")"
    found=1
    echo "- $name"
  done

  if [[ "$found" -eq 0 ]]; then
    warn "暂无实例"
  fi
}

backup_instance() {
  local name="$1"
  ensure_instance_exists "$name"

  local dir ts archive_name archive_path
  dir="$(instance_dir "$name")"
  ts="$(date +%Y%m%d-%H%M%S)"
  archive_name="${name}-backup-${ts}.tar.gz"
  archive_path="$BACKUP_DIR/$archive_name"

  mkdir -p "$BACKUP_DIR"

  info "开始备份实例：$name"
  tar -C "$dir" -czf "$archive_path" data docker-compose.yml
  ok "备份完成：$archive_path"
}

update_instance() {
  local name="$1"
  ensure_instance_exists "$name"

  local dir
  dir="$(instance_dir "$name")"

  info "更新镜像：$name"
  (
    cd "$dir"
    docker compose pull
    docker compose up -d
  )
  ok "实例已更新并启动：$name"
}

remove_instance() {
  local name="$1"
  ensure_instance_exists "$name"

  local dir trash_dir ts target
  dir="$(instance_dir "$name")"
  trash_dir="$BASE_DIR/.trash"
  ts="$(date +%Y%m%d-%H%M%S)"
  target="$trash_dir/${name}-${ts}"

  warn "即将删除实例：$name"
  warn "实例目录将移动到回收区：$target"
  read -r -p "确认删除请输入 yes: " confirm

  if [[ "$confirm" != "yes" ]]; then
    info "已取消"
    exit 0
  fi

  (
    cd "$dir"
    docker compose down || true
  )

  mkdir -p "$trash_dir"
  mv "$dir" "$target"
  ok "实例已移入回收区：$target"
}

show_usage() {
  cat <<EOF
用法：
  bash $0                         打开交互菜单
  bash $0 install-docker          自动安装 Docker 与 Compose
  bash $0 install <实例名>        安装并初始化新实例
  bash $0 start <实例名>          启动实例
  bash $0 stop <实例名>           停止实例
  bash $0 restart <实例名>        重启实例
  bash $0 update <实例名>         拉取新镜像并重启实例
  bash $0 backup <实例名>         备份实例 data 和 compose 文件
  bash $0 logs <实例名>           查看日志
  bash $0 status <实例名>         查看状态
  bash $0 list                    查看所有实例
  bash $0 remove <实例名>         删除实例（移入回收区）

示例：
  sudo bash $0
  sudo bash $0 install tg1
  sudo bash $0 update tg1
EOF
}

PROMPT_RESULT=""

prompt_instance_name() {
  local prompt_text="${1:-请输入实例名}"
  local name
  while true; do
    read -r -p "$prompt_text: " name
    if [[ -z "$name" ]]; then
      warn "实例名不能为空"
      continue
    fi
    if [[ ! "$name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
      warn "实例名只允许字母、数字、点、下划线、短横线"
      continue
    fi
    PROMPT_RESULT="$name"
    return 0
  done
}

pause_wait() {
  echo
  read -r -p "按回车继续..." _
}

show_menu() {
  clear 2>/dev/null || true
  cat <<'EOF'
==============================
      TeleBox Manager
==============================
1. 安装 Docker
2. 安装 TeleBox 实例
3. 查看实例列表
4. 启动实例
5. 停止实例
6. 重启实例
7. 查看实例状态
8. 查看实例日志
9. 更新实例
10. 备份实例
11. 删除实例
12. 查看命令帮助
0. 退出
EOF
}

interactive_menu() {
  mkdir -p "$BASE_DIR"
  while true; do
    show_menu
    echo
    read -r -p "请选择功能编号: " choice
    echo
    case "$choice" in
      1)
        install_docker
        pause_wait
        ;;
      2)
        check_docker
        prompt_instance_name '请输入要安装的实例名'
        install_instance "$PROMPT_RESULT"
        pause_wait
        ;;
      3)
        list_instances
        pause_wait
        ;;
      4)
        check_docker
        prompt_instance_name '请输入要启动的实例名'
        start_instance "$PROMPT_RESULT"
        pause_wait
        ;;
      5)
        check_docker
        prompt_instance_name '请输入要停止的实例名'
        stop_instance "$PROMPT_RESULT"
        pause_wait
        ;;
      6)
        check_docker
        prompt_instance_name '请输入要重启的实例名'
        restart_instance "$PROMPT_RESULT"
        pause_wait
        ;;
      7)
        check_docker
        prompt_instance_name '请输入要查看状态的实例名'
        status_instance "$PROMPT_RESULT"
        pause_wait
        ;;
      8)
        check_docker
        prompt_instance_name '请输入要查看日志的实例名'
        logs_instance "$PROMPT_RESULT"
        ;;
      9)
        check_docker
        prompt_instance_name '请输入要更新的实例名'
        update_instance "$PROMPT_RESULT"
        pause_wait
        ;;
      10)
        prompt_instance_name '请输入要备份的实例名'
        backup_instance "$PROMPT_RESULT"
        pause_wait
        ;;
      11)
        check_docker
        prompt_instance_name '请输入要删除的实例名'
        remove_instance "$PROMPT_RESULT"
        pause_wait
        ;;
      12)
        show_usage
        pause_wait
        ;;
      0)
        ok "已退出"
        exit 0
        ;;
      *)
        warn "无效编号，请重新输入"
        pause_wait
        ;;
    esac
  done
}

run_action() {
  local action="$1"
  local name="${2:-}"

  case "$action" in
    install-docker)
      install_docker
      ;;
    install)
      check_docker
      mkdir -p "$BASE_DIR"
      validate_name "$name"
      install_instance "$name"
      ;;
    start)
      check_docker
      mkdir -p "$BASE_DIR"
      validate_name "$name"
      start_instance "$name"
      ;;
    stop)
      check_docker
      mkdir -p "$BASE_DIR"
      validate_name "$name"
      stop_instance "$name"
      ;;
    restart)
      check_docker
      mkdir -p "$BASE_DIR"
      validate_name "$name"
      restart_instance "$name"
      ;;
    update)
      check_docker
      mkdir -p "$BASE_DIR"
      validate_name "$name"
      update_instance "$name"
      ;;
    backup)
      mkdir -p "$BASE_DIR"
      validate_name "$name"
      backup_instance "$name"
      ;;
    logs)
      check_docker
      mkdir -p "$BASE_DIR"
      validate_name "$name"
      logs_instance "$name"
      ;;
    status)
      check_docker
      mkdir -p "$BASE_DIR"
      validate_name "$name"
      status_instance "$name"
      ;;
    list)
      mkdir -p "$BASE_DIR"
      list_instances
      ;;
    remove)
      check_docker
      mkdir -p "$BASE_DIR"
      validate_name "$name"
      remove_instance "$name"
      ;;
    help|-h|--help)
      show_usage
      ;;
    *)
      show_usage
      exit 1
      ;;
  esac
}

main() {
  need_root

  if [[ $# -eq 0 ]]; then
    interactive_menu
  fi

  run_action "$@"
}

main "$@"
