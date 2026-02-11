#!/bin/bash
echo '****************************************************************************'
echo '     run_nginx_dev.sh                                                       '
echo '            by niuren.zhu                                                   '
echo '               2019.09.12                                                   '
echo '  说明：                                                                     '
echo '    1. 尝试运行Nginx容器。                                                    '
echo '    2. 参数1，用户文件目录。                                                   '
echo '****************************************************************************'
# 设置参数变量
WORK_FOLDER=$PWD
NAME=ibas-nginx-dev
PORT_V1=15386
PORT_V2=15486
MEM=32m
CONFIG_FOLDER=${WORK_FOLDER}/conf.d

# 参数赋值
CODE_FOLDER=$1
if [ ! -e "${CODE_FOLDER}" ];then
    echo 代码目录不存在
    exit 1
fi;
CODE_FOLDER=$((cd ${CODE_FOLDER} && pwd))

# 显示容器信息
echo --容器名称：${NAME}
echo --限制内存：${MEM}
echo --映射端口：${PORT_V1} '&' ${PORT_V2}
echo --用户目录：${CODE_FOLDER}
echo --用户目录-代码：${CODE_FOLDER}/Codes
echo --用户目录-工作：${CODE_FOLDER}/Workspaces

# 删除已经存在
docker rm -vf ${NAME}
# 创建新的
docker run \
   --name ${NAME} \
   -m ${MEM} \
   -p ${PORT_V1}:80 \
   -p ${PORT_V2}:90 \
   -v ${CODE_FOLDER}/Codes:${CODE_FOLDER}/Codes \
   -v ${CODE_FOLDER}/Workspaces:${CODE_FOLDER}/Workspaces \
   -v ${CONFIG_FOLDER}:/etc/nginx/conf.d \
   -d colorcoding/nginx:alpine
# 显示创建结果
docker ps -n 1
