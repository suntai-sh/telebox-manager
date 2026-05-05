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

docker_ready() {
  if ! command -v docker >/dev/null 2>&1; then
    return 1
  fi

  if ! docker compose version >/dev/null 2>&1; then
    return 1
  fi

  if command -v systemctl >/dev/null 2>&1; then
    if ! systemctl is-enabled docker >/dev/null 2>&1 && ! systemctl is-active docker >/dev/null 2>&1; then
      return 1
    fi
  fi

  if ! docker info >/dev/null 2>&1; then
    return 1
  fi

  return 0
}

DOCKER_DETECT_REASON=""

docker_present_or_residue() {
  DOCKER_DETECT_REASON=""

  if command -v docker >/dev/null 2>&1; then
    DOCKER_DETECT_REASON="检测到 docker 命令仍存在"
    return 0
  fi

  if command -v systemctl >/dev/null 2>&1; then
    if systemctl is-active docker >/dev/null 2>&1; then
      DOCKER_DETECT_REASON="docker 服务仍处于 active 状态"
      return 0
    fi
    if systemctl is-enabled docker >/dev/null 2>&1; then
      DOCKER_DETECT_REASON="docker 服务仍处于 enabled 状态"
      return 0
    fi
    if systemctl is-active docker.socket >/dev/null 2>&1; then
      DOCKER_DETECT_REASON="docker.socket 仍处于 active 状态"
      return 0
    fi
    if systemctl is-enabled docker.socket >/dev/null 2>&1; then
      DOCKER_DETECT_REASON="docker.socket 仍处于 enabled 状态"
      return 0
    fi
    if systemctl is-active containerd >/dev/null 2>&1; then
      DOCKER_DETECT_REASON="containerd 服务仍处于 active 状态"
      return 0
    fi
    if systemctl is-enabled containerd >/dev/null 2>&1; then
      DOCKER_DETECT_REASON="containerd 服务仍处于 enabled 状态"
      return 0
    fi
  fi

  if command -v dpkg >/dev/null 2>&1; then
    local dpkg_match
    dpkg_match="$(dpkg -l 2>/dev/null | awk '/^ii/ && $2 ~ /^(docker-ce|docker-ce-cli|docker-buildx-plugin|docker-compose-plugin|containerd.io|docker.io)$/ {print $2; exit}')"
    if [[ -n "$dpkg_match" ]]; then
      DOCKER_DETECT_REASON="检测到已安装软件包：$dpkg_match"
      return 0
    fi
  fi

  if command -v rpm >/dev/null 2>&1; then
    local rpm_match
    rpm_match="$(rpm -qa 2>/dev/null | grep -E '^(docker-ce|docker-ce-cli|docker-buildx-plugin|docker-compose-plugin|containerd.io|docker)$' | head -n 1 || true)"
    if [[ -n "$rpm_match" ]]; then
      DOCKER_DETECT_REASON="检测到已安装软件包：$rpm_match"
      return 0
    fi
  fi

  if [[ -S /var/run/docker.sock ]]; then
    DOCKER_DETECT_REASON="检测到 /var/run/docker.sock 仍存在"
    return 0
  fi

  if [[ -S /var/run/containerd/containerd.sock ]]; then
    DOCKER_DETECT_REASON="检测到 /var/run/containerd/containerd.sock 仍存在"
    return 0
  fi

  if [[ -d /var/lib/docker ]] && [[ -n "$(find /var/lib/docker -mindepth 1 -maxdepth 1 2>/dev/null | head -n 1)" ]]; then
    DOCKER_DETECT_REASON="检测到 /var/lib/docker 中仍有数据"
    return 0
  fi

  if [[ -d /var/lib/containerd ]] && [[ -n "$(find /var/lib/containerd -mindepth 1 -maxdepth 1 2>/dev/null | head -n 1)" ]]; then
    DOCKER_DETECT_REASON="检测到 /var/lib/containerd 中仍有数据"
    return 0
  fi

  return 1
}

check_docker() {
  if ! docker_ready; then
    err "未检测到可用的 Docker 环境，请先安装 Docker，或执行：bash $0 install-docker"
    exit 1
  fi
}

install_docker() {
  if docker_ready; then
    ok "Docker 和 Docker Compose 已安装且可用，无需重复安装"
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

uninstall_docker() {
  if docker_ready; then
    info "检测到可用的 Docker 环境，将执行完整卸载"
  elif docker_present_or_residue; then
    warn "未检测到可用的 Docker 环境，但发现 Docker 残留，将继续清理"
    warn "残留原因：$DOCKER_DETECT_REASON"
  else
    info "未检测到 Docker 或残留，无需卸载"
    return 0
  fi

  warn "该操作会删除整台机器的全部 Docker 内容，包括："
  warn "- 所有容器"
  warn "- 所有镜像"
  warn "- 所有卷"
  warn "- 所有自定义网络"
  warn "- Docker 程序与数据目录"
  echo
  read -r -p "确认卸载 Docker 并删除全部 Docker 数据请输入 yes: " confirm

  if [[ "$confirm" != "yes" ]]; then
    info "已取消"
    return 0
  fi

  info "停止并删除所有容器..."
  local ids imgs vols
  ids="$(docker ps -aq 2>/dev/null || true)"
  if [[ -n "$ids" ]]; then
    docker rm -f $ids || true
  else
    info "没有容器需要删除"
  fi

  info "删除所有镜像..."
  imgs="$(docker images -aq 2>/dev/null | sort -u || true)"
  if [[ -n "$imgs" ]]; then
    docker rmi -f $imgs || true
  else
    info "没有镜像需要删除"
  fi

  info "删除所有卷..."
  vols="$(docker volume ls -q 2>/dev/null || true)"
  if [[ -n "$vols" ]]; then
    docker volume rm -f $vols || true
  else
    info "没有卷需要删除"
  fi

  info "删除自定义网络..."
  local net
  for net in $(docker network ls --format '{{.Name}}' 2>/dev/null | grep -Ev '^(bridge|host|none)$' || true); do
    docker network rm "$net" || true
  done

  info "停止 Docker 服务..."
  systemctl stop docker docker.socket containerd 2>/dev/null || true
  systemctl disable docker docker.socket containerd 2>/dev/null || true

  info "卸载 Docker 软件包..."
  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    local apt_remove_pkgs=()
    local candidate
    for candidate in docker-ce docker-ce-cli docker-buildx-plugin docker-compose-plugin containerd.io docker-ce-rootless-extras docker.io docker-doc docker-compose podman-docker; do
      if dpkg -s "$candidate" >/dev/null 2>&1; then
        apt_remove_pkgs+=("$candidate")
      fi
    done
    if [[ ${#apt_remove_pkgs[@]} -gt 0 ]]; then
      apt-get purge -y "${apt_remove_pkgs[@]}" || true
    else
      info "没有已安装的 Docker 软件包需要卸载"
    fi
    apt-get autoremove -y --purge || true
  elif command -v dnf >/dev/null 2>&1; then
    dnf -y remove docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine || true
  elif command -v yum >/dev/null 2>&1; then
    yum -y remove docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine || true
  fi

  info "删除 Docker 数据目录..."
  rm -rf /var/lib/docker /var/lib/containerd /etc/docker /var/run/docker.sock /var/run/containerd/containerd.sock

  ok "Docker 及全部 Docker 数据已卸载/清理完成"
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
    restart: "no"
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

LOGIN_SESSION_READY=0

run_instance_login() {
  local name="$1"
  ensure_instance_exists "$name"

  local dir session_file login_code
  dir="$(instance_dir "$name")"
  session_file="$dir/data/my_session.session"
  LOGIN_SESSION_READY=0

  warn "即将进入实例登录/初始化流程：$name"
  warn "如果输错了 api_id、api_hash 或手机号，可按 Ctrl+C 退出后重新进入本功能"
  echo

  set +e
  (
    cd "$dir"
    docker compose run --rm telebox npm start
  )
  login_code=$?
  set -e

  if [[ "$login_code" -ne 0 ]]; then
    warn "登录/初始化流程已退出，退出码：$login_code"
  fi

  if [[ ! -f "$session_file" ]]; then
    warn "未检测到会话文件：$session_file"
    warn "如果刚才中途输错或主动退出，这是正常的；重新执行“重新初始化实例”即可"
    return 0
  fi

  LOGIN_SESSION_READY=1
  ok "实例登录/初始化完成：$name"
  return 0
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

  run_instance_login "$name"

  if [[ "$LOGIN_SESSION_READY" -ne 1 ]]; then
    warn "首次初始化未完成，实例目录已保留：$dir"
    warn "你可以稍后通过“重新初始化实例”继续登录"
    return 0
  fi

  info "启动后台服务：$name"
  (
    cd "$dir"
    docker compose up -d
  )

  ok "实例已启动：$name"
  echo
  echo "查看日志：sudo bash $0 logs $name"
}

container_is_running() {
  local name="$1"
  docker ps --format '{{.Names}}' | grep -qx "telebox-$name"
}

start_instance() {
  local name="$1"
  ensure_instance_exists "$name"

  local dir attempt
  dir="$(instance_dir "$name")"

  for attempt in 1 2 3; do
    info "启动实例：$name（第 ${attempt}/3 次尝试）"
    (
      cd "$dir"
      docker compose up -d
    )

    sleep 2
    if container_is_running "$name"; then
      ok "已启动：$name"
      return 0
    fi

    warn "实例启动失败：$name（第 ${attempt}/3 次）"
  done

  err "实例连续 3 次启动失败，已停止自动重试：$name"
  warn "请使用“查看日志”排查问题"
  return 1
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
  )
  start_instance "$name"
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

  local found=0 idx=1
  for dir in "$BASE_DIR"/*; do
    [[ -d "$dir" ]] || continue
    local name
    name="$(basename "$dir")"
    [[ "$name" == "backups" || "$name" == ".trash" ]] && continue
    found=1
    echo "$idx. $name"
    idx=$((idx + 1))
  done

  if [[ "$found" -eq 0 ]]; then
    warn "暂无实例"
  fi
}

choose_instance() {
  local prompt_text="${1:-请选择实例编号}"
  local instances=()
  local dir name idx choice max_index

  for dir in "$BASE_DIR"/*; do
    [[ -d "$dir" ]] || continue
    name="$(basename "$dir")"
    [[ "$name" == "backups" || "$name" == ".trash" ]] && continue
    instances+=("$name")
  done

  if [[ ${#instances[@]} -eq 0 ]]; then
    warn "暂无实例"
    return 1
  fi

  info "实例列表："
  for idx in "${!instances[@]}"; do
    echo "$((idx + 1)). ${instances[$idx]}"
  done

  max_index=${#instances[@]}
  while true; do
    read -r -p "$prompt_text (1-$max_index, 0返回): " choice
    if [[ "$choice" == "0" ]]; then
      return 1
    fi
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= max_index )); then
      PROMPT_RESULT="${instances[$((choice - 1))]}"
      return 0
    fi
    warn "请输入有效编号"
  done
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

migrate_restart_policy() {
  mkdir -p "$BASE_DIR"

  local found=0 updated=0 dir compose name
  for dir in "$BASE_DIR"/*; do
    [[ -d "$dir" ]] || continue
    name="$(basename "$dir")"
    [[ "$name" == "backups" || "$name" == ".trash" ]] && continue
    compose="$dir/docker-compose.yml"
    [[ -f "$compose" ]] || continue
    found=1

    if grep -q 'restart: unless-stopped' "$compose"; then
      sed -i 's/restart: unless-stopped/restart: "no"/' "$compose"
      ok "已修复实例重启策略：$name"
      updated=$((updated + 1))
    elif grep -q 'restart: "no"' "$compose"; then
      info "实例已是新策略：$name"
    else
      warn "实例 compose 中未找到可识别的 restart 配置：$name"
    fi
  done

  if [[ "$found" -eq 0 ]]; then
    warn "暂无可修复的实例"
    return 0
  fi

  ok "统一修复完成，共更新 $updated 个实例"
}

fix_persistence_links() {
  local name="$1"
  ensure_instance_exists "$name"

  local dir ws data backup item f bn
  dir="$(instance_dir "$name")"
  ws="$dir/workspace"
  data="$dir/data"
  backup="$ws/_persist_fix_backup_$(date +%Y%m%d-%H%M%S)"

  mkdir -p "$backup" "$data/plugins" "$data/assets" "$data/assets/tpm" "$data/logs" "$data/temp" "$data/my_session"

  info "停止实例以修复持久化目录：$name"
  (
    cd "$dir"
    docker compose down || true
  )

  for item in plugins assets logs temp my_session config.json; do
    if [[ -e "$ws/$item" && ! -L "$ws/$item" ]]; then
      mv "$ws/$item" "$backup/$item"
      info "已备份 workspace/$item 到 $backup/$item"
    fi
  done

  if [[ -d "$backup/plugins" ]]; then
    while IFS= read -r f; do
      bn="$(basename "$f")"
      if [[ ! -e "$data/plugins/$bn" ]]; then
        mv "$f" "$data/plugins/$bn"
        ok "已迁移插件：$bn"
      else
        warn "data/plugins 已存在同名插件，保留备份中的文件：$bn"
      fi
    done < <(find "$backup/plugins" -maxdepth 1 -type f 2>/dev/null)
  fi

  ln -sfn "$data/plugins" "$ws/plugins"
  ln -sfn "$data/assets" "$ws/assets"
  ln -sfn "$data/logs" "$ws/logs"
  ln -sfn "$data/temp" "$ws/temp"
  ln -sfn "$data/my_session" "$ws/my_session"
  ln -sfn "$data/config.json" "$ws/config.json"

  if [[ -f "$data/assets/tpm/plugins.json" ]]; then
    ok "已检测到远程插件记录数据库：$data/assets/tpm/plugins.json"
  else
    warn "未检测到远程插件记录数据库：$data/assets/tpm/plugins.json"
    warn "若插件显示为“本地插件”，请检查是否曾覆盖/清空 assets/tpm/plugins.json"
  fi

  ok "持久化链接已修复：$name"
  warn "备份目录：$backup"
  warn "请启动实例后检查插件是否正常"
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
  warn "实例目录：$dir"
  warn "实例目录将移动到回收区：$target"
  warn "回收区不会自动过期删除，会一直保留，除非你手动清理 $trash_dir"
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
  bash $0 uninstall-docker        卸载 Docker 并删除全部 Docker 数据
  bash $0 install <实例名>        安装并初始化新实例
  bash $0 relogin <实例名>        重新进入实例登录/初始化流程
  bash $0 start <实例名>          启动实例
  bash $0 stop <实例名>           停止实例
  bash $0 restart <实例名>        重启实例
  bash $0 update <实例名>         拉取新镜像并重启实例
  bash $0 backup <实例名>         备份实例 data 和 compose 文件
  bash $0 logs <实例名>           查看日志
  bash $0 status <实例名>         查看状态
  bash $0 list                    查看所有实例
  bash $0 migrate-restart         统一修复旧实例的重启策略
  bash $0 fix-persistence <实例名> 修复实例插件/配置持久化链接
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
2. 卸载 Docker
3. 安装 TeleBox 实例
4. 重新初始化实例
5. 查看实例列表
6. 启动实例
7. 停止实例
8. 重启实例
9. 查看实例状态
10. 查看实例日志
11. 更新实例
12. 备份实例
13. 统一修复旧实例重启策略
14. 修复实例插件/配置持久化
15. 删除实例
16. 查看命令帮助
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
        uninstall_docker
        pause_wait
        ;;
      3)
        check_docker
        prompt_instance_name '请输入要安装的实例名'
        install_instance "$PROMPT_RESULT"
        pause_wait
        ;;
      4)
        check_docker
        if choose_instance '请选择要重新初始化的实例'; then
          run_instance_login "$PROMPT_RESULT"
        fi
        pause_wait
        ;;
      5)
        list_instances
        pause_wait
        ;;
      6)
        check_docker
        if choose_instance '请选择要启动的实例'; then
          start_instance "$PROMPT_RESULT"
        fi
        pause_wait
        ;;
      7)
        check_docker
        if choose_instance '请选择要停止的实例'; then
          stop_instance "$PROMPT_RESULT"
        fi
        pause_wait
        ;;
      8)
        check_docker
        if choose_instance '请选择要重启的实例'; then
          restart_instance "$PROMPT_RESULT"
        fi
        pause_wait
        ;;
      9)
        check_docker
        if choose_instance '请选择要查看状态的实例'; then
          status_instance "$PROMPT_RESULT"
        fi
        pause_wait
        ;;
      10)
        check_docker
        if choose_instance '请选择要查看日志的实例'; then
          logs_instance "$PROMPT_RESULT"
        fi
        ;;
      11)
        check_docker
        if choose_instance '请选择要更新的实例'; then
          update_instance "$PROMPT_RESULT"
        fi
        pause_wait
        ;;
      12)
        if choose_instance '请选择要备份的实例'; then
          backup_instance "$PROMPT_RESULT"
        fi
        pause_wait
        ;;
      13)
        migrate_restart_policy
        pause_wait
        ;;
      14)
        check_docker
        if choose_instance '请选择要修复持久化的实例'; then
          fix_persistence_links "$PROMPT_RESULT"
        fi
        pause_wait
        ;;
      15)
        check_docker
        warn "上面是当前可删除的实例列表"
        if choose_instance '请选择要删除的实例'; then
          remove_instance "$PROMPT_RESULT"
        fi
        pause_wait
        ;;
      16)
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
    uninstall-docker)
      uninstall_docker
      ;;
    install)
      check_docker
      mkdir -p "$BASE_DIR"
      validate_name "$name"
      install_instance "$name"
      ;;
    relogin)
      check_docker
      mkdir -p "$BASE_DIR"
      validate_name "$name"
      run_instance_login "$name"
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
    migrate-restart)
      mkdir -p "$BASE_DIR"
      migrate_restart_policy
      ;;
    fix-persistence)
      check_docker
      mkdir -p "$BASE_DIR"
      validate_name "$name"
      fix_persistence_links "$name"
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
