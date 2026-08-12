# ibas-scripts

IBAS 本地开发辅助脚本，当前包含两类工具：

- `db/`：启动 MySQL、PostgreSQL、SQL Server、SAP HANA 容器，以及导入 MySQL 备份。
- `nginx/`：启动同时提供 v1/v2 前端入口的 Nginx 开发容器。

## 前置条件

- macOS/Linux 或可运行 Bash 的环境
- Docker Desktop / Docker Engine，并确保当前用户可以执行 `docker`
- HANA 脚本还需要 Linux 主机具备写入 `/etc/sysctl.d` 的权限；Docker Desktop 通常不适合直接运行 HANA Express

脚本会复用同名容器；容器存在但已停止时执行 `docker start`，不存在时创建新容器。运行参数通过命令行选项传入：`-d` 数据目录、`-p` 主机端口、`-m` 内存、`-w` 密码、`-n` 容器名。

## 数据库

```sh
./db/run_db_mysql.sh
./db/run_db_mysql.sh -d /path/to/mysql-data -p 13306 -m 2g -w secret
./db/run_db_pgsql.sh -d /path/to/pgsql-data
./db/run_db_mssql.sh -d /path/to/mssql-data
./db/run_db_hana.sh -d /path/to/hana-data
```

默认连接信息：

| 数据库 | 容器 | 主机端口 | 用户 | 默认密码 |
| --- | --- | ---: | --- | --- |
| MySQL | `ibas-db-mysql` | 3306 | `root` | `1q2w3e` |
| PostgreSQL | `ibas-db-pgsql` | 5432 | `postgres` | `1q2w3e` |
| SQL Server | `ibas-db-mssql` | 1433 | `sa` | `Aa123456` |
| HANA Express | `ibas-db-hana` | 39017 | `SYSTEM` | `1q2w#E$R` |

例如：`./db/run_db_mysql.sh -d /path/to/mysql-data -p 13306 -w secret`。密码仅用于启动容器，不建议把生产密码写入脚本或命令历史。

## 导入 MySQL 备份

```sh
./db/import_mysql.sh /path/to/backup.sql
./db/import_mysql.sh /path/to/backup-directory
```

目录参数会交互选择 `.sql` 或 `.sql.gz` 文件。压缩备份会先解压并保留原始 `.gz` 文件；导入前会生成 `.bak`，脚本默认创建 `ibas_demo_YYYYMMDD_HHMM` 数据库。导入依赖 `colorcoding/mysql-cli` 镜像和可访问的 MySQL 容器。

## MySQL 转 HANA

```sh
python3 db/mysql_to_hana.py backup.sql backup-hana.sql
python3 db/mysql_to_hana.py backup.sql backup-hana.sql --include-logs
python3 db/mysql_to_hana.py backup.sql backup-hana.sql --keep-table-case
```

转换器面向 IBAS 控制台备份，处理表结构、索引和 INSERT；默认跳过 `*_SYS_BOLOGST` 与 `*_SYS_USERACTLOG` 日志表。它不是通用 SQL 迁移器，执行前仍应在目标 HANA 环境检查类型、约束和大字段。

默认将表名转换为大写，字段名保持原样；使用 `--keep-table-case` 可保留原表名大小写。

转换时会始终在重建对象前生成删除语句，避免目标库已有结构导致数据插入失败。支持表、视图、存储过程、函数、触发器、序列和类型；执行前请确认目标 schema 和对象范围。

## Nginx 开发代理

```sh
./nginx/run_nginx_dev.sh /path/to/workspace-root
```

`workspace-root` 下应包含 `Codes/` 和 `Workspaces/`；脚本将它们挂载到容器中，并把配置目录挂载到 `/etc/nginx/conf.d`。v1 默认访问 `http://localhost:15386`，v2 默认访问 `http://localhost:15486`。可用 `NGINX_PORT_V1`、`NGINX_PORT_V2` 和 `NGINX_NAME` 覆盖容器名称与端口。

## 约定

脚本按仓库相对位置定位配置，因此可以从任意当前目录执行。生成的备份、压缩包和 SQL 文件默认被 `.gitignore` 忽略；`.DS_Store` 也不会纳入版本库。
