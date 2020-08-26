# 授予slave账号连接和复制权限
GRANT REPLICATION CLIENT, REPLICATION SLAVE ON *.* to 'slave'@'%' identified by 'slave';
