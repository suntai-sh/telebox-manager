# TeleBox Manager

多开 TeleBox 的管理脚本，支持：

- 多实例安装
- 首次初始化保护
- 启动 / 停止 / 重启
- 更新镜像
- 数据备份
- 安全删除（移入回收区）
- Docker 自动安装

## 用法

```bash
bash telebox-manager.sh install-docker
bash telebox-manager.sh install tg1
bash telebox-manager.sh start tg1
bash telebox-manager.sh stop tg1
bash telebox-manager.sh restart tg1
bash telebox-manager.sh update tg1
bash telebox-manager.sh backup tg1
bash telebox-manager.sh logs tg1
bash telebox-manager.sh status tg1
bash telebox-manager.sh list
bash telebox-manager.sh remove tg1
```

## 默认目录

```bash
/opt/telebox-multi
```

## 说明

- 首次安装会要求你手动输入 Telegram 登录信息
- 如果未检测到会话文件，脚本不会误判为初始化成功
- 删除实例时会移动到 `.trash/`，而不是直接永久删除
