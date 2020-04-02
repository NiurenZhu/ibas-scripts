#!/bin/sh
echo '****************************************************************************'
echo '              git_clones.sh                                                 '
echo '                      by niuren.zhu                                         '
echo '                           2017.11.22                                       '
echo '  说明：                                                                    '
echo '    1. 根据compile_order.txt内容clone代码。                                 '
echo '    2. 若已存在目录则执行pull。                                             '
echo '****************************************************************************'
# 设置参数变量
# 工作目录
WORK_FOLDER=$(pwd)
# GIT根地址
GIT_ROOT_URL=$1
# GIT根地址，则Color-Coding
if [ "${GIT_ROOT_URL}" = "" ]; then
  GIT_ROOT_URL=https://github.com/color-coding
fi

echo --工作的目录：${WORK_FOLDER}
# 获取编译顺序
if [ ! -e ${WORK_FOLDER}/compile_order.txt ]; then
  ls -l ${WORK_FOLDER} | awk '/^d/{print $NF}' >${WORK_FOLDER}/compile_order.txt
fi
# 遍历当前目录存
while read line; do
  folder=${line%% *}
  others=${line#* }
  if [ "${folder}" = "${others}" ]; then
    others=
  fi
  echo --${folder}
  if [ -e "${WORK_FOLDER}/${folder}/.git" ]; then
    cd ${WORK_FOLDER}/${folder}
    git pull --depth 1
  else
    # 仅获取最新版本
    folder=${folder##* }
    git clone --depth 1 ${GIT_ROOT_URL}/${folder}.git ${others}
    echo ${folder} >>${WORK_FOLDER}/~compile_order.txt
  fi
  cd ${WORK_FOLDER}
done <${WORK_FOLDER}/compile_order.txt | sed 's/\r//g'
cd ${WORK_FOLDER}
# 使用新的顺序文件
if [ -e ~compile_order.txt ]; then
  mv -f ~compile_order.txt compile_order.txt
fi
