#!/bin/sh

echo '启动mysql服务'
service mysql start

echo '配置主库信息并启动从服务器'
mysql -uroot -pslave -e "
# 设置主库连接信息
CHANGE MASTER TO 
MASTER_HOST='master',
MASTER_PORT=3306,
MASTER_USER='slave',
MASTER_PASSWORD='slave';
# 重置从库
RESET SLAVE;
# 启动从库
START SLAVE;
quit" 

tail -f /dev/null