#!/bin/bash
echo '****************************************************************************'
echo '     run_nginx_dev.sh                                                       '
echo '            by niuren.zhu                                                   '
echo '               2019.09.12                                                   '
echo '  说明：                                                                     '
echo '    1. 尝试运行Nginx容器。                                                    '
echo '    2. 参数1，Nginx的html目录，默认当前目录下的html目录。                         '
echo '****************************************************************************'
# 设置参数变量
WORK_FOLDER=$PWD
NAME=ibas-nginx-dev
PORT=15386
MEM=128m
CONFIG_FOLDER=${WORK_FOLDER}/conf.d

# 参数赋值
HTML_FOLDER=$1
if [ "${HTML_FOLDER}" = "" ];then HTML_FOLDER=${WORK_FOLDER}/html; fi;

# 检查环境
if [ ! -e "${HTML_FOLDER}" ];then
    echo HTML目录不存在
    exit 1
fi;

# 显示容器信息
echo --容器名称：${NAME}
echo --映射端口：${PORT}
echo --限制内存：${MEM}
echo --数据目录：${HTML_FOLDER}
echo --配置目录：${CONFIG_FOLDER}

# 删除已经存在
docker rm -vf ${NAME}
# 创建新的
docker run \
   --name ${NAME} \
   -m ${MEM} \
   -p ${PORT}:80 \
   -v ${HTML_FOLDER}:/home/niurenzhu/Codes/ \
   -v ${CONFIG_FOLDER}:/etc/nginx/conf.d \
   -d nginx:alpine
# 显示创建结果
docker ps -n 1
