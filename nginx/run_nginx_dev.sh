#!/usr/bin/env bash
set -euo pipefail
echo '****************************************************************************'
echo '     run_nginx_dev.sh                                                       '
echo '            by niuren.zhu                                                   '
echo '               2019.09.12                                                   '
echo '  说明：                                                                     '
echo '    1. 尝试运行Nginx容器。                                                    '
echo '    2. 参数1，用户文件目录。                                                   '
echo '****************************************************************************'
# 设置参数变量
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
NAME=${NGINX_NAME:-ibas-nginx-dev}
PORT_V1=${NGINX_PORT_V1:-15386}
PORT_V2=${NGINX_PORT_V2:-15486}
MEM=${NGINX_MEMORY:-32m}
CONFIG_FOLDER=${SCRIPT_DIR}/conf.d

# 参数赋值
CODE_FOLDER=${1:-}
if [ -z "${CODE_FOLDER}" ] || [ ! -d "${CODE_FOLDER}" ]; then
    echo "用法：$0 <包含 Codes 和 Workspaces 的工作区目录>" >&2
    exit 1
fi;
CODE_FOLDER=$(cd -- "${CODE_FOLDER}" && pwd)
for folder in Codes Workspaces; do
  if [ ! -d "${CODE_FOLDER}/${folder}" ]; then
    echo "目录不存在：${CODE_FOLDER}/${folder}" >&2
    exit 1
  fi
done

# 显示容器信息
echo "--容器名称：${NAME}"
echo "--限制内存：${MEM}"
echo "--映射端口：${PORT_V1} & ${PORT_V2}"
echo "--用户目录：${CODE_FOLDER}"

# 删除已经存在
docker rm -vf "${NAME}" 2>/dev/null || true
# 创建新的
docker run \
   --name "${NAME}" \
   -m "${MEM}" \
   -p "${PORT_V1}:80" \
   -p "${PORT_V2}:90" \
   -v "${CODE_FOLDER}/Codes:${CODE_FOLDER}/Codes" \
   -v "${CODE_FOLDER}/Workspaces:${CODE_FOLDER}/Workspaces" \
   -v "${CONFIG_FOLDER}:/etc/nginx/conf.d" \
   -d colorcoding/nginx:alpine
# 显示创建结果
docker ps -n 1
