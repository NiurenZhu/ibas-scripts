#!/bin/bash
echo '****************************************************************************'
echo '     run_pgsql.sh                                                           '
echo '            by niuren.zhu                                                   '
echo '               2017.08.24                                                   '
echo '  说明：                                                                    '
echo '    1. 尝试运行MYSQL容器。                                                  '
echo '****************************************************************************'
# 设置参数变量
WORK_FOLDER=$PWD
NAME=ibas-db-pgsql
PORT=5432
MEM=512m
PASSWD=1q2w3e

# 显示容器信息
echo --容器名称：${NAME}
echo --映射端口：${PORT}
echo --限制内存：${MEM}
echo --用户密码：${PASSWD}

docker start ${NAME} ||
  docker run \
    --name ${NAME} \
    -p ${PORT}:5432 \
    -m ${MEM} \
    -e POSTGRES_PASSWORD=${PASSWD} \
    -d postgres:alpine
