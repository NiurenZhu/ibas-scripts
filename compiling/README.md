# ibas编译相关

## 主要内容 | content
* compile_order.txt          编译的模块
* git_clones.sh              从github下载代码
* builds.sh                  构建前端
* compiles.sh                构建后端及打war包
* deploy_wars.sh             发布war包到Maven仓库
* copy_wars.sh               拷贝war包到[./ibas_packages]目录
* docker_compile.sh          启动容器执行以上脚本

## 使用说明 | instruction
* 使用[colorcoding/compiling:ibas-alpine]镜像
~~~
./docker_compile.sh
~~~
* 使用[colorcoding/compiling:ibas]镜像
~~~
./docker_compile.sh colorcoding/compiling:ibas
~~~

### 鸣谢 | thanks
[牛加人等于朱](http://baike.baidu.com/view/1769.htm "NiurenZhu")<br>
[Color-Coding](http://colorcoding.org/ "咔啦工作室")<br>
