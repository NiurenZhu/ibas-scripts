#!/usr/bin/env bash
set -euo pipefail
echo '****************************************************************************'
echo '* 脚本名称：run_db_hana.sh                                                  *'
echo '* 维护人员：niuren.zhu                                                     *'
echo '* 创建日期：2022.11.29                                                      *'
echo '* 功能说明：启动或复用 SAP HANA Express 容器，并持久化映射数据目录。       *'
echo '* 参数说明：-d 数据目录，-p 主机端口，-m 内存，-w 密码，-n 容器名。         *'
echo '****************************************************************************'
# 设置参数变量
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
NAME=ibas-db-hana
MEM=8g
PORT=39017
PASSWD='1q2w#E$R'
while getopts ':d:p:m:w:n:h' OPTION; do
  case "${OPTION}" in
    d) DATA_FOLDER=${OPTARG};; p) PORT=${OPTARG};; m) MEM=${OPTARG};; w) PASSWD=${OPTARG};; n) NAME=${OPTARG};;
    h) echo "用法：$0 [-d 数据目录] [-p 主机端口] [-m 内存] [-w 密码] [-n 容器名]"; exit 0;;
    :) echo "选项 -${OPTARG} 缺少参数" >&2; exit 2;; \?) echo "未知选项：-${OPTARG}" >&2; exit 2;;
  esac
done
# 数据目录
DATA_FOLDER=${SCRIPT_DIR}/data/hana
DATA_FOLDER=$(mkdir -p -- "${DATA_FOLDER}" && cd -- "${DATA_FOLDER}" && pwd)

# 显示容器信息
echo "--容器名称：${NAME}"
echo "--限制内存：${MEM}"
echo "--映射端口：${PORT}"
echo "--数据目录：${DATA_FOLDER}"

# 检查主机配置
if [ "$(uname -s)" = Linux ] && [ ! -e /etc/sysctl.d/hana.conf ]; then
  cat >/etc/sysctl.d/hana.conf <<EOF
fs.file-max=20000000
fs.aio-max-nr=262144
vm.memory_failure_early_kill=1
vm.max_map_count=135217728
net.ipv4.ip_local_port_range=40000 60999
EOF
fi
# 初始化数据目录
if [ ! -e ${DATA_FOLDER}/init.json ]; then
  cat >${DATA_FOLDER}/init.json <<EOF
{
  "master_password" : "${PASSWD}"
}
EOF
  chmod 600 ${DATA_FOLDER}/init.json
  if [ "$(uname -s)" = Linux ]; then chown 12000:79 "${DATA_FOLDER}/init.json"; fi
fi
if docker container inspect "${NAME}" >/dev/null 2>&1; then
  docker start "${NAME}"
else
  docker run \
    -p 39013:39013 -p "${PORT}:39017" -p 39041-39045:39041-39045 -p 1128-1129:1128-1129 -p 59013-59014:59013-59014 \
    -v "${DATA_FOLDER}:/hana/mounts" \
    -m "${MEM}" \
    --ulimit nofile=1048576:1048576 \
    --sysctl kernel.shmmax=1073741824 \
    --sysctl net.ipv4.ip_local_port_range='40000 60999' \
    --sysctl kernel.shmmni=4096 \
    --sysctl kernel.shmall=8388608 \
    --name "${NAME}" \
    saplabs/hanaexpress:2.00.061.00.20220519.1 \
    --passwords-url file:///hana/mounts/init.json \
    --agree-to-sap-license
fi
