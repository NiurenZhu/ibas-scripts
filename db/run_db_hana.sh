#!/bin/bash
echo '****************************************************************************'
echo '     run_db_hana.sh                                                           '
echo '            by niuren.zhu                                                   '
echo '               2022.11.29                                                   '
echo '  说明：                                                                    '
echo '    1. 尝试运行HANA容器。                                                  '
echo '****************************************************************************'
# 设置参数变量
WORK_FOLDER=$PWD
NAME=ibas-db-hana
MEM=8g
PORT=39017
PASSWD='1q2w#E$R'
# 数据目录
DATA_FOLDER=$1
if [ "${DATA_FOLDER}" = "" ]; then
  DATA_FOLDER=${WORK_FOLDER}
fi

# 显示容器信息
echo --容器名称：${NAME}
echo --限制内存：${MEM}
echo --映射端口：${PORT}
echo --用户密码：${PASSWD}
echo --数据目录：${DATA_FOLDER}

# 检查主机配置
if [ ! -e /etc/sysctl.d/hana.conf ]; then
  cat >/etc/sysctl.d/hana.conf <<EOF
fs.file-max=20000000
fs.aio-max-nr=262144
vm.memory_failure_early_kill=1
vm.max_map_count=135217728
net.ipv4.ip_local_port_range=40000 60999
EOF
fi
# 初始化数据目录
if [ ! -e ${DATA_FOLDER} ]; then
  mkdir -p ${DATA_FOLDER}
  chown 12000:79 ${DATA_FOLDER}
fi
if [ ! -e ${DATA_FOLDER}/init.json ]; then
  cat >${DATA_FOLDER}/init.json <<EOF
{
  "master_password" : "${PASSWD}"
}
EOF
  chmod 600 ${DATA_FOLDER}/init.json
  chown 12000:79 ${DATA_FOLDER}/init.json
fi
docker start ${NAME} ||
  docker run \
    -p 39013:39013 -p ${PORT}:39017 -p 39041-39045:39041-39045 -p 1128-1129:1128-1129 -p 59013-59014:59013-59014 \
    -v ${DATA_FOLDER}:/hana/mounts \
    -m ${MEM} \
    --ulimit nofile=1048576:1048576 \
    --sysctl kernel.shmmax=1073741824 \
    --sysctl net.ipv4.ip_local_port_range='40000 60999' \
    --sysctl kernel.shmmni=4096 \
    --sysctl kernel.shmall=8388608 \
    --name ${NAME} \
    saplabs/hanaexpress:2.00.061.00.20220519.1 \
    --passwords-url file:///hana/mounts/init.json \
    --agree-to-sap-license
