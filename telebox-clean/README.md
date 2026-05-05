# TeleBox clean runtime image

目标：
- 镜像里不带任何个人配置、session、插件、日志
- 首次启动时自动拉取官方仓库
- **首次登录保留官方交互方式**
- 后续继续用官方 `.update` 更新代码
- 容器本身长期不用重建

## 结构

- `./workspace` → 官方仓库工作目录（代码、git 历史、在线更新都在这里）
- `./data` → 运行数据
  - `config.json`
  - `plugins/`
  - `assets/`
  - `logs/`
  - `temp/`
  - `my_session/`

## 首次初始化（官方交互方式）

第一次不要直接 `up -d`，先运行：

```bash
docker compose run --rm telebox npm start
```

这一步会：
1. 自动 clone 官方仓库到 `./workspace`
2. 自动创建 `./data/config.json`
3. 自动安装依赖
4. 进入 TeleBox 官方首次配置流程

然后按官方提示填写：
- `api_id`
- `api_hash`
- 手机号 / 验证码 / 2FA（如果需要）

初始化成功后，session 和配置会保存在 `./data`。

## 正式后台运行

初始化完成后再启动常驻容器：

```bash
docker compose up -d
```

## 查看日志

```bash
docker compose logs -f
```

## 停止

```bash
docker compose down
```

## 更新方式

容器内代码是 `./workspace` 的真实 git 工作树，所以官方 `.update` 仍然可用。

如果 `.update` 改了 `package-lock.json`，容器下次重启时会自动重新安装依赖。

## 初始状态说明

这个方案不会带入你的旧：
- `config.json`
- session
- plugins
- assets
- logs
- temp

只要 `./workspace` 和 `./data` 是空目录，首次启动就是干净初始状态。
