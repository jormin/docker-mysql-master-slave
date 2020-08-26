#!/bin/sh

echo '启动mysql服务'
service mysql start

echo '创建从库账号并授权'
# 授予slave账号连接和复制权限
mysql -uroot -pmaster < /mysql/master.sql
echo '创建并授权完成'

tail -f /dev/null
