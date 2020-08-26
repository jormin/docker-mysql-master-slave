#!/bin/sh

# 从网络中移除容器
echo '从网络中移除容器'
docker network disconnect mysql master
docker network disconnect mysql slave1
docker network disconnect mysql slave2
# 删除网络
echo '删除网络'
docker network rm mysql
# 停止所有容器
echo '停止所有容器'
docker stop master slave1 slave2
# 删掉所有容器
echo '删掉所有容器'
docker rm master slave1 slave2
# 删掉所有镜像
echo '删掉所有镜像'
docker rmi mysql:master mysql:slave