#!/bin/bash

# 构建镜像
cd ~/docker/mysql/build
# 构建主库镜像
docker build -f ./master.dockerfile -t mysql:master .
# 构建从库镜像
docker build -f ./slave.dockerfile -t mysql:slave .

# 启动容器
# 启动master容器
docker run --name master -p 3307:3306 -v /Users/Jormin/docker/mysql/master/data/:/var/lib/mysql -v /Users/Jormin/docker/mysql/master/mysqld/:/var/run/mysqld -v /Users/Jormin/docker/mysql/master/my.cnf:/etc/mysql/my.cnf -d mysql:master
# 启动slave1容器
docker run --name slave1 -p 3308:3306 -v /Users/Jormin/docker/mysql/slave1/data/:/var/lib/mysql -v /Users/Jormin/docker/mysql/master/mysqld/:/var/run/mysqld -v /Users/Jormin/docker/mysql/slave1/my.cnf:/etc/mysql/my.cnf -d mysql:slave
# 启动slave2容器
docker run --name slave2 -p 3309:3306 -v /Users/Jormin/docker/mysql/slave2/data/:/var/lib/mysql -v /Users/Jormin/docker/mysql/master/mysqld/:/var/run/mysqld -v /Users/Jormin/docker/mysql/slave2/my.cnf:/etc/mysql/my.cnf -d mysql:slave

# 创建网络
docker network create mysql
# 连接master
docker network connect mysql master
# 连接slave1
docker network connect mysql slave1
# 连接slave2
docker network connect mysql slave2
