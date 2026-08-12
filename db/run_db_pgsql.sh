#!/usr/bin/env bash
set -euo pipefail
echo '****************************************************************************'
echo '* 脚本名称：run_db_pgsql.sh                                                 *'
echo '* 维护人员：niuren.zhu                                                     *'
echo '* 创建日期：2017.08.24                                                      *'
echo '* 功能说明：启动或复用 PostgreSQL 容器，并持久化映射数据目录。             *'
echo '* 参数说明：-d 数据目录，-p 主机端口，-m 内存，-w 密码，-n 容器名。         *'
echo '****************************************************************************'
# 设置参数变量
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
NAME=ibas-db-pgsql
PORT=5432
MEM=512m
PASSWD=1q2w3e
DATA_FOLDER=${SCRIPT_DIR}/data/pgsql
while getopts ':d:p:m:w:n:h' OPTION; do
  case "${OPTION}" in
    d) DATA_FOLDER=${OPTARG};; p) PORT=${OPTARG};; m) MEM=${OPTARG};; w) PASSWD=${OPTARG};; n) NAME=${OPTARG};;
    h) echo "用法：$0 [-d 数据目录] [-p 主机端口] [-m 内存] [-w 密码] [-n 容器名]"; exit 0;;
    :) echo "选项 -${OPTARG} 缺少参数" >&2; exit 2;; \?) echo "未知选项：-${OPTARG}" >&2; exit 2;;
  esac
done
mkdir -p -- "${DATA_FOLDER}"

# 显示容器信息
echo "--容器名称：${NAME}"
echo "--映射端口：${PORT}"
echo "--限制内存：${MEM}"
echo "--数据目录：${DATA_FOLDER}"

if docker container inspect "${NAME}" >/dev/null 2>&1; then
  docker start "${NAME}"
else
  docker run \
    --name "${NAME}" \
    -p "${PORT}:5432" \
    -v "$(cd -- "${DATA_FOLDER}" && pwd):/var/lib/postgresql/data" \
    -m "${MEM}" \
    -e "POSTGRES_PASSWORD=${PASSWD}" \
    -d postgres:alpine
fi
