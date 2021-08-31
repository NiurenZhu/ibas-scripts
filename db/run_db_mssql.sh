#!/bin/bash
echo '****************************************************************************'
echo '     run_mssql.sh                                                           '
echo '            by niuren.zhu                                                   '
echo '               2017.08.24                                                   '
echo '  说明：                                                                    '
echo '    1. 尝试运行MSSQL容器。                                                  '
echo '    2. 去除数据库密码复杂要求。                                             '
echo '         ALTER LOGIN [sa] WITH CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF;      '
echo '    3. 修改数据库密码。                                                     '
echo '         ALTER LOGIN [sa] WITH PASSWORD = '\'1q2w3e\'';                       '
echo '****************************************************************************'
# 设置参数变量
WORK_FOLDER=$PWD
NAME=ibas-db-mssql
PORT=1433
MEM=2g
PASSWD=Aa123456

# 显示容器信息
echo --容器名称：${NAME}
echo --映射端口：${PORT}
echo --限制内存：${MEM}
echo --用户密码：${PASSWD}

docker start ${NAME} ||
   docker run \
      --name ${NAME} \
      -m ${MEM} \
      -p ${PORT}:1433 \
      -e ACCEPT_EULA=Y \
      -e MSSQL_SA_PASSWORD=${PASSWD} \
      -e MSSQL_PID=Developer \
      -d mcr.microsoft.com/mssql/server:2017-latest
