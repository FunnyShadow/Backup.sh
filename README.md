# Backup.sh
一个简单好用的自动备份脚本

## 使用方法

#### 方法一:

1. 克隆本项目

2. 按照给出的样例文件写好一份 `config.env` 和一份 `backup.list`

3. 在你的 `cron` 中插入一条

   ```bash
   bash <你的 backup.sh 主文件位置> <config.env 文件位置>
   ```

4. Enjoy !

#### 方法二:

1. 执行以下命令

   ```bash
   mkdir -p /usr/local/share/Backup.sh
   wget "$(curl -sS https://api.github.com/repos/FunnyShadow/Backup.sh/releases/latest | grep browser_download_url | cut -d'"' -f4)" -O /usr/local/share/Backup.sh/main
   chmod +x /usr/local/share/Backup.sh/main
   ln -s /usr/local/share/Backup.sh/main /usr/bin/baksh
   ```

2. 按照给出的样例文件写好一份 `config.env` 和一份 `backup.list` 并存储于 `/usr/local/share/Backup.sh/` 目录中

3. 在你的 `cron` 中插入一条

   ```bash
   baksh /usr/local/share/Backup.sh/config.env
   ```

4. Enjoy !

## 功能

- [x] 外置配置文件
- [x] 外置备份列表
- [x] 全自动备份
- [x] 错误自动处理
- [x] 传参处理
- [x] 本地化语言输出
- [x] 自动环境校验
- [x] 支持备份前/后执行脚本
- [x] 多槽位多版本备份
- [x] 槽位数量上限可控
- [x] 可以按照特定格式命名文件夹 (目前仅支持时间戳自动转换, 其他请自行设计命令)
- [ ] 内置定时器 (脱离 `cron` 依赖)
- [ ] 全自动还原
- [ ] 生成备份文件直链
- [ ] rlone 兼容性
- [ ] rsync 兼容性
- [ ] git 兼容性

## 协议

本项目使用 GPL 3.0 开源协议

