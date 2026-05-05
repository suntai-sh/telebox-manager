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

## 拉取脚本

```bash
curl -fsSL -o telebox-manager.sh https://raw.githubusercontent.com/suntai-sh/telebox-manager/main/telebox-manager.sh
chmod +x telebox-manager.sh
```

> 备注：
>
> - 建议先 `cat telebox-manager.sh` 或 `less telebox-manager.sh` 看一下脚本内容再执行
> - 脚本默认安装目录为 `/opt/telebox-multi`
> - 需要 root 权限运行

---

## 首次使用

### 1. 如未安装 Docker，先自动安装

```bash
sudo bash telebox-manager.sh install-docker
```

### 2. 安装第一个 TeleBox 实例

```bash
sudo bash telebox-manager.sh install tg1
```

安装过程中会提示你输入：

- `api_id`
- `api_hash`
- 手机号
- 验证码
- 二步验证密码（如果有）

### 3. 安装第二个实例

```bash
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

## 项目地址

- GitHub 仓库：<https://github.com/suntai-sh/telebox-manager>
- 原始脚本：<https://raw.githubusercontent.com/suntai-sh/telebox-manager/main/telebox-manager.sh>
