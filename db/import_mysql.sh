#!/bin/sh
echo '****************************************************************************'
echo '                 import_mysql.sh                                           '
echo '                       by niuren.zhu                                        '
echo '                           2020.12.24                                       '
echo '  说明：                                                                     '
echo '    1. 解压工作目录sql.gz包。                                                  '
echo '    2. 检查sql文件表名及用户。                                                  '
echo '    3. 导入sql文件到数据库。                                                    '
echo '    4. 参数1，工作目录。                                                       '
echo '****************************************************************************'
# 工作目录
# 启动目录
STARTUP_FOLDER=$(pwd)
# 工作目录默认第一个参数
WORK_FOLDER=$1
# 修正相对目录为启动目录
if [ "${WORK_FOLDER}" = "./" ]; then
    WORK_FOLDER=${STARTUP_FOLDER}
fi
# 未提供工作目录，则取启动目录
if [ "${WORK_FOLDER}" = "" ]; then
    WORK_FOLDER=${STARTUP_FOLDER}
fi
if [ -f ${WORK_FOLDER} ]; then
    # 判断是否为文件
    SQL_FILE=${WORK_FOLDER}
else
    # 为目录则列示内容供选择
    echo --工作目录：${WORK_FOLDER}
    FILES=()
    INDEX=0
    for FILE in $(ls ${WORK_FOLDER}/*.{sql,gz}); do
        FILES[$INDEX]=$FILE
        INDEX=$(expr $INDEX + 1)
    done
    echo --检索到[${#FILES[@]}]个文件：
    for INDEX in "${!FILES[@]}"; do
        printf "  %s) %s\n" "$(expr $INDEX + 1)" "${FILES[$INDEX]}"
    done
    read -p "--请输入选择的文件序号: " INDEX
    if [ "${INDEX}" = "" ]; then
        SQL_FILE=
    else
        SQL_FILE=${FILES[$(expr $INDEX - 1)]}
    fi
fi
# 文件存在
if [ "${SQL_FILE:0-3}" = ".gz" ]; then
    # 压缩文件，先解压
    echo --解压文件，请稍后
    gunzip "${SQL_FILE}"
    SQL_FILE=${SQL_FILE:0:-3}
fi
echo --使用文件：${SQL_FILE}
if [ ! -f "${SQL_FILE}" ]; then
    exit 0
fi
# 输入数据库信息
echo --请确认数据库连接信息
echo "---数据库容器名称(ibas-db-mysql):"
read DB_SERVER
if [ "${DB_SERVER}" = "" ]; then DB_SERVER=ibas-db-mysql; fi
echo "---用户名(root):"
read DB_USER
if [ "${DB_USER}" = "" ]; then DB_USER=root; fi
echo "---用户密码(1q2w3e):"
read DB_PASSWD
if [ "${DB_PASSWD}" = "" ]; then DB_PASSWD=1q2w3e; fi
DB_NAME=ibas_demo_$(date +"%Y%m%d_%H%M")
echo "---数据库名称(${DB_NAME}):"
read DB_NAME
if [ "${DB_NAME}" = "" ]; then DB_NAME=ibas-demo-$(date +"%Y%m%d_%H%M"); fi

echo "---格式化脚本文件([y]es or no):"
read FORMAT_SQL
if [ "${FORMAT_SQL}" = "" ]; then FORMAT_SQL=y; fi

# 遍历脚本文件
for FILE in ${SQL_FILE}; do
    echo --格式化文件，请稍后
    cp ${FILE} ${FILE}.bak
    echo "-- Create and using Database" >${FILE}
    echo "CREATE SCHEMA IF NOT EXISTS \`${DB_NAME}\` DEFAULT CHARACTER SET utf8mb4;" >>${FILE}
    echo "USE \`${DB_NAME}\`;" >>${FILE}
    echo "" >>${FILE}
    if [ "${FORMAT_SQL}" = "y" ]; then
        sed -e 's/`ava_.*`/\U&/g;s/`.*`@`%`/`root`@`%`/g' ${FILE}.bak >>${FILE}
    fi
    echo --执行:${FILE}
    docker run \
        --rm \
        --link ${DB_SERVER}:${DB_SERVER} \
        -v ${FILE}:/sqls/import_mysql.sql \
        --privileged=true \
        -it colorcoding/mysql-cli \
        "mysql" "-h${DB_SERVER}" "-u${DB_USER}" "-p${DB_PASSWD}" -e "source /sqls/import_mysql.sql"
done
echo --操作完成
