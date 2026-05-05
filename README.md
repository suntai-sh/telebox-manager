# TeleBox Manager

TeleBox 多开管理脚本，适合一台机器管理多个 TeleBox 实例。

支持功能：

- 多实例安装
- 首次初始化保护
- 启动 / 停止 / 重启
- 更新镜像
- 数据备份
- 安全删除（移入回收区）
- Docker 自动安装

---

## 下载并运行

```bash
curl -fsSL -o telebox-manager.sh https://raw.githubusercontent.com/suntai-sh/telebox-manager/main/telebox-manager.sh && chmod +x telebox-manager.sh && sudo bash telebox-manager.sh
```

运行后会进入数字菜单，按提示选择功能即可。

> 备注：
>
> - 脚本默认安装目录为 `/opt/telebox-multi`
> - 建议使用 root 或 sudo 运行
> - 某些系统不支持 `bash <(curl ...)` 这种写法，所以上面这套更兼容

---

## 首次使用

### 推荐方式：一条命令进入菜单

```bash
curl -fsSL -o telebox-manager.sh https://raw.githubusercontent.com/suntai-sh/telebox-manager/main/telebox-manager.sh && chmod +x telebox-manager.sh && sudo bash telebox-manager.sh
```

运行后可直接通过菜单选择：

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
13. 删除实例

安装实例时会提示你输入：

- `api_id`
- `api_hash`
- 手机号
- 验证码
- 二步验证密码（如果有）

如果中途输错了参数，按 `Ctrl+C` 退出当前登录流程，然后在菜单里选择：

- `4. 重新初始化实例`

即可重新进入登录流程，无需删除实例重装。

### 如果你更喜欢命令行模式

```bash
sudo bash telebox-manager.sh install-docker
sudo bash telebox-manager.sh uninstall-docker
sudo bash telebox-manager.sh install tg1
sudo bash telebox-manager.sh relogin tg1
sudo bash telebox-manager.sh install tg2
```

---

## 常用命令

### 查看所有实例

```bash
sudo bash telebox-manager.sh list
```

### 启动实例

```bash
sudo bash telebox-manager.sh start tg1
```

### 停止实例

```bash
sudo bash telebox-manager.sh stop tg1
```

### 重启实例

```bash
sudo bash telebox-manager.sh restart tg1
```

### 查看状态

```bash
sudo bash telebox-manager.sh status tg1
```

### 查看日志

```bash
sudo bash telebox-manager.sh logs tg1
```

### 更新镜像并重启

```bash
sudo bash telebox-manager.sh update tg1
```

### 备份实例数据

```bash
sudo bash telebox-manager.sh backup tg1
```

### 删除实例（移入回收区）

```bash
sudo bash telebox-manager.sh remove tg1
```

---

## 目录说明

默认工作目录：

```bash
/opt/telebox-multi
```

每个实例结构大致如下：

```bash
/opt/telebox-multi/
  ├── tg1/
  │   ├── workspace/
  │   ├── data/
  │   └── docker-compose.yml
  ├── tg2/
  │   ├── workspace/
  │   ├── data/
  │   └── docker-compose.yml
  ├── backups/
  └── .trash/
```

说明：

- `workspace/`：TeleBox 代码目录
- `data/`：账号会话、配置、日志等数据目录
- `backups/`：备份文件目录
- `.trash/`：删除实例后的回收区

---

## 注意事项

- 第一次安装必须完成 Telegram 登录初始化
- 如果未检测到会话文件，脚本不会误判为初始化成功
- 删除实例不会直接永久删除，而是移动到回收区
- 如果镜像后续需要开放端口，多开时应给不同实例分配不同端口

---

## 仓库内容

- `telebox-manager.sh`：多开管理脚本
- `telebox-clean/`：干净版 TeleBox Docker 运行时文件
  - `Dockerfile`
  - `docker-compose.yml`
  - `entrypoint.sh`
  - `README.md`

## 项目地址

- GitHub 仓库：<https://github.com/suntai-sh/telebox-manager>
- 原始脚本：<https://raw.githubusercontent.com/suntai-sh/telebox-manager/main/telebox-manager.sh>
