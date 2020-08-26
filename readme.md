
## 前沿

现在的web开发中，数据库的主从备份、读写分离已经是一个必备的服务，无论从数据安全角度还是性能角度考虑，这都是必须增加的功能，如果开发使用的是阿里云或者腾讯云的数据库，基本上都有现成的服务可以使用，而本文要实现的是自建的基于docker来做的主从服务。

本文所有代码都已提交 [github](https://github.com/jormin/docker_mysql_master_slave)

## 原理

同步操作通过 3 个线程实现，其基本步骤如下：

1. 主库在数据更新提交事务之前，将事件异步记录到binlog二进制日志文件中，日志记录完成后存储引擎提交本次事务
2. 从库启动一个I/O线程与主库建立连接，用来请求主库中要更新的binlog。这时主库创建的binlog dump线程，这是二进制转储线程，如果有新更新的事件，就通知I/O线程；当该线程转储二进制日志完成，没有新的日志时，该线程进入sleep状态。
3. 从库的I/O线程接收到新的事件日志后，保存到自己的relay log（中继日志）中
4. 从库的SQL线程读取中继日志中的事件，并执行更新保存。

![](https://blog.cdn.lerzen.com/d1a917e8ee09dcf5b0ef7755f1fc31f7.jpg)

## 配置

1. 主库

    - server-id：服务器设置唯一ID，默认为1，推荐取IP最后部分；
    - log-bin：设置二进制日志文件的基本名，默认不开启，配置后表示开启日志；
    - log-bin-index：设置二进制日志索引文件名；
    - binlog_format：控制二进制日志格式，进而控制了复制类型，三个可选值
        - STATEMENT：SQL语句复制，优点：占用空间少，缺点：误删则无法恢复数据，在某些情况下，可能造成主备不一致
        - ROW：行复制，优点：可以找回误删的信息，可以避免主备不一致的情况，缺点：占用空间大
        - MIXED：混和复制，默认选项，混合statement,row。 Mysql 会判断哪些语句执行可能引起主备不一致，这些语句采用row 格式记录，其他的使用statement格式记录，当然这种形式的日志也没有办法恢复误删的数据。
    - sync-binlog：默认为0，表示MySQL不控制binlog的刷新，由文件系统自己控制它的缓存的刷新。这时候的性能是最好的，但是风险也是最大的。一旦系统崩溃, binlog_cache中的所有binlog信息都会被丢失。为保证不会丢失数据，需设置为1，用于强制每次提交事务时，同步二进制日志到磁盘上。
    - expire_logs_days：设置binlog保存时间，默认为0，也就是随着服务器运行，binlog会越来越大。看业务需求来配置binlog保存时间吧。结合每日的数据库备份功能，通过binlog，可以支持将数据库回溯到N天的任意时间点。
    - max_binlog_size：binlog日志文件大小 默认大小1G 
    - binlog-do-db：binlog记录的数据库
    - binlog-ignore-db：binlog 不记录的数据库
   
2. 从库
 
    - server-id：服务器设置唯一ID
    - relay-log：中继日志
    - relay-log-index：中继日志的索引文件
    - read-only：是否只读，默认为0，为1表示只读
    - replicate-do-db：同步的数据库
    - replicate-ignore-db：不同步的数据库
    - replicate-wild-do-table：同步的数据表
    - replicate-wild-ignore-table：不同步的数据表

## 命令

1. 从库配置主库账号密码

    ```
    mysql> CHANGE MASTER TO 
            MASTER_HOST='master',
            MASTER_PORT=3306,
            MASTER_USER='slave',
            MASTER_PASSWORD='slave';
    ```
   
2. 重置从库

    ```
    mysql> RESET SLAVE;
    ```
   
3. 启动从库

    ```
    mysql> START SLAVE;
    ```
   
4. 停止从库

    ```
    mysql> STOP SLAVE;
    ```
  
5. 查询状态

    ```
    mysql> show slave status \G
    *************************** 1. row ***************************
                   Slave_IO_State: Waiting for master to send event
                      Master_Host: master
                      Master_User: slave
                      Master_Port: 3306
                    Connect_Retry: 60
                  Master_Log_File: mysql-bin.000031
              Read_Master_Log_Pos: 3146
                   Relay_Log_File: 1ab49ece5ea5-relay-bin.000033
                    Relay_Log_Pos: 3359
            Relay_Master_Log_File: mysql-bin.000031
                 Slave_IO_Running: Yes
                Slave_SQL_Running: Yes
                  Replicate_Do_DB:
              Replicate_Ignore_DB:
               Replicate_Do_Table:
           Replicate_Ignore_Table:
          Replicate_Wild_Do_Table: data.%
      Replicate_Wild_Ignore_Table:
                       Last_Errno: 0
                       Last_Error:
                     Skip_Counter: 0
              Exec_Master_Log_Pos: 3146
                  Relay_Log_Space: 5580
                  Until_Condition: None
                   Until_Log_File:
                    Until_Log_Pos: 0
               Master_SSL_Allowed: No
               Master_SSL_CA_File:
               Master_SSL_CA_Path:
                  Master_SSL_Cert:
                Master_SSL_Cipher:
                   Master_SSL_Key:
            Seconds_Behind_Master: 0
    Master_SSL_Verify_Server_Cert: No
                    Last_IO_Errno: 0
                    Last_IO_Error:
                   Last_SQL_Errno: 0
                   Last_SQL_Error:
      Replicate_Ignore_Server_Ids:
                 Master_Server_Id: 1
                      Master_UUID: 0c77048c-e77d-11ea-9ba9-0242ac110002
                 Master_Info_File: /var/lib/mysql/master.info
                        SQL_Delay: 0
              SQL_Remaining_Delay: NULL
          Slave_SQL_Running_State: Slave has read all relay log; waiting for more updates
               Master_Retry_Count: 86400
                      Master_Bind:
          Last_IO_Error_Timestamp:
         Last_SQL_Error_Timestamp:
                   Master_SSL_Crl:
               Master_SSL_Crlpath:
               Retrieved_Gtid_Set:
                Executed_Gtid_Set:
                    Auto_Position: 0
             Replicate_Rewrite_DB:
                     Channel_Name:
               Master_TLS_Version:
    1 row in set (0.00 sec)
    ```
    
    上面标记的输出信息Slave_IO_Running: Yes和Slave_SQL_Running: Yes可以看到I/O线程和SQL线程已启动运行中。

## 核心代码说明

代码结构如下所示：

```
.
├── build                       # 构建镜像文件目录
│   ├── master.dockerfile       # 主库镜像文件
│   ├── master.sh               # 主库脚本
│   ├── master.sql              # 主库sql
│   ├── slave.dockerfile        # 从库镜像文件
│   └── slave.sh                # 从库脚本
├── master                      # 主库目录
│   ├── data                    # 主库数据文件
│   ├── mysqld                  # 主库sock文件
│   ├── init.sh                 # 主库初始化脚本
│   ├── init.sql                # 主库初始化sql
│   └── my.cnf                  # 主库配置文件
├── shell                       # 脚本目录
│   ├── destroy.sh              # 销毁重置脚本
│   ├── init.log                # 初始化日志
│   ├── init.sh                 # 初始化脚本
│   └── test.sh                 # 测试脚本
├── slave1                      # 从库1目录
│   ├── data                    # 从库1数据文件
│   ├── mysqld                  # 从库1sock文件
│   └── my.cnf                  # 从库1配置文件
└── slave2                      # 从库2目录
    ├── data                    # 从库2数据文件
│   ├── mysqld                  # 从库2sock文件
    └── my.cnf                  # 从库2配置文件
```

### 构建镜像

主从镜像都是基于 mysql 5.7.13 版本进行构建，区别在于：

1. 主库镜像会在创建容器后生成一个用于同步数据的账号`slave`,密码和账号一致
2. 从库镜像在创建容器后会配置下连接主库的账号密码并重置以及启动同步

#### 主库镜像代码

1. master.dockerfile

```
# mysql 版本
FROM mysql:5.7.13

# 设置root密码
ENV MYSQL_ROOT_PASSWORD master

# 拷贝文件
COPY master.sh /mysql/master.sh
COPY master.sql /mysql/master.sql

# 使用端口
EXPOSE 3306

# 执行命令
CMD ["sh", "/mysql/master.sh"]
```

2. master.sh

```
#!/bin/sh

echo '启动mysql服务'
service mysql start

echo '创建从库账号并授权'
# 授予slave账号连接和复制权限
mysql -uroot -pmaster < /mysql/master.sql
echo '创建并授权完成'

tail -f /dev/null
```

3. master.sql

- REPLICATION CLIENT：连接主库的权限
- REPLICATION SLAVE：复制数据的权限

```
# 授予slave账号连接和复制权限
GRANT REPLICATION CLIENT, REPLICATION SLAVE ON *.* to 'slave'@'%' identified by 'slave';
```

#### 从库镜像代码

1. slave.dockerfile

```
# mysql 版本
FROM mysql:5.7.13

# 设置root密码
ENV MYSQL_ROOT_PASSWORD slave

# 拷贝文件
COPY slave.sh /mysql/slave.sh

# 使用端口
EXPOSE 3306

# 执行命令
CMD ["sh", "/mysql/slave.sh"]
```

2. slave.sh

```
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
```

### 数据及配置

master、slave1、slave2 三个为主从数据库的数据及配置目录，为1主2从架构

- data 子目录为数据目录，启动容器后会将该目录下的数据映射到容器中
- my.cnf 为数据库配置文件，这里也是配置主从的核心部分

    ```
    # 主库配置
    log-bin=mysql-bin
    server-id=1
    # 同步黑名单
    # binlog_ignore_db = information_schema,mysql,performance_schema,sys
    ```
    
    ```
    # 从库配置
    log-bin = mysql-bin
    server-id = 2
    # 当从库作为其他从库的主库时，该项需要配置为1，主要目的是将从主库复制的数据写入到bin-log中
    log-slave-updates = 1
    # 配置只读
    read-only = 1
    # 同步白名单
    replicate_wild_do_table = data.%
    # 同步黑名单
    # replicate_wild_ignore_table = information_schema.%,mysql.%,performance_schema.%,sys.%
    ```

- master/init.* 为主库初始化数据脚本

    ```
    # 创建数据库
    
    create database if not exists data default charset=utf8mb4 collate=utf8mb4_general_ci;
    
    # 切换数据库
    
    use data;
    
    # 用户表
    
    create table if not exists user(
    	id int(11) unsigned auto_increment comment 'ID',
    	nickname varchar(15) not null comment '昵称',
    	gender tinyint(1) unsigned not null default 0 comment '性别 0:未设定 1:男 2:女',
    	phone char(11) not null comment '注册手机号',
    	status tinyint(1) not null default 1 comment '账号状态 0:未激活 1:启用 -1:禁用',
    	create_time int (10) unsigned not null comment '注册时间',
    	update_time int (10) unsigned not null comment '更新时间',
    	primary key (`id`),
    	unique index index_phone (`phone`),
    	index index_create_time (`create_time`)
    )engine=innodb default charset=utf8mb4 collate=utf8mb4_general_ci comment '用户表';
    
    # 添加测试数据
    
    INSERT INTO user VALUES (1, 'test', 1, '18698277354', 1, 1598445824, 1598445824);
    ```

### 脚本(shell目录)

#### 初始化(init.sh)

该脚本的作用是构建主库和从库镜像，并基于主库镜像启动一个容器，基于从库镜像启动两个从库容器，映射宿主机的端口分别为：3307、3308、3309

创建容器后会创建网络，将三个容器连接到一个网络中，之后容器内部连接使用的是容器别名

**需要修改本脚本中的docker run参数的绝对路径地址**

```
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
```

#### 测试(test.sh)

测试脚本会将主库的初始化脚本和sql复制到主库容器中，然后导入到数据库中

```
#!/bin/bash

# 主库创建数据库和表
docker cp ./master/init.sh master:/mysql/init.sh
docker cp ./master/init.sql master:/mysql/init.sql
docker exec master /bin/sh /mysql/init.sh
```

#### 销毁(destroy.sh)

销毁脚本会删掉网络、容器和所有镜像，但不会删除数据，可以自行手动删除，或者更改此脚本，增加删除data子目录部分

```
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
```

## 使用

1. 拷贝代码到本地指定目录

```
git clone https://github.com/jormin/docker_mysql_master_slave ~/docker/mysql
```

2. 执行初始化脚本

```
➜  mysql git:(master) cd ~/docker/mysql
➜  mysql git:(master) bash shell/init.sh > shell/init.log
➜  mysql git:(master) ✗ docker images
REPOSITORY                         TAG                 IMAGE ID            CREATED             SIZE
mysql                              slave               54879b48fd42        25 seconds ago      380MB
mysql                              master              29d46194f749        26 seconds ago      380MB
➜  mysql git:(master) ✗ docker ps -a
CONTAINER ID        IMAGE                COMMAND                  CREATED             STATUS              PORTS                                      NAMES
10055bf5d66c        mysql:slave          "docker-entrypoint.s…"   48 seconds ago      Up 46 seconds       0.0.0.0:3309->3306/tcp                     slave2
1cd8f06831d2        mysql:slave          "docker-entrypoint.s…"   49 seconds ago      Up 47 seconds       0.0.0.0:3308->3306/tcp                     slave1
bd6489500985        mysql:master         "docker-entrypoint.s…"   50 seconds ago      Up 48 seconds       0.0.0.0:3307->3306/tcp                     master
```

执行完毕后可以看到已经创建好了主库和从库的镜像以及一个主容器和两个从容器，创建日志为 `shell/init.log`

```
Sending build context to Docker daemon  6.144kB

Step 1/6 : FROM mysql:5.7.13
 ---> 1195b21c3a45
Step 2/6 : ENV MYSQL_ROOT_PASSWORD master
 ---> Running in 749dad09e4f3
Removing intermediate container 749dad09e4f3
 ---> 066d4cc36d47
Step 3/6 : COPY master.sh /mysql/master.sh
 ---> e81a07be4ed4
Step 4/6 : COPY master.sql /mysql/master.sql
 ---> 591f221deebc
Step 5/6 : EXPOSE 3306
 ---> Running in 0d7ca504f38a
Removing intermediate container 0d7ca504f38a
 ---> 15c5adb884dd
Step 6/6 : CMD ["sh", "/mysql/master.sh"]
 ---> Running in 850da439cec0
Removing intermediate container 850da439cec0
 ---> 29d46194f749
Successfully built 29d46194f749
Successfully tagged mysql:master
Sending build context to Docker daemon  6.144kB

Step 1/5 : FROM mysql:5.7.13
 ---> 1195b21c3a45
Step 2/5 : ENV MYSQL_ROOT_PASSWORD slave
 ---> Running in b88f05ef59ce
Removing intermediate container b88f05ef59ce
 ---> 5093968902c5
Step 3/5 : COPY slave.sh /mysql/slave.sh
 ---> cc90a6f1d033
Step 4/5 : EXPOSE 3306
 ---> Running in bd4024b02706
Removing intermediate container bd4024b02706
 ---> 8db6b251efb6
Step 5/5 : CMD ["sh", "/mysql/slave.sh"]
 ---> Running in 8b210f24168b
Removing intermediate container 8b210f24168b
 ---> 54879b48fd42
Successfully built 54879b48fd42
Successfully tagged mysql:slave
bd64895009851daf3556fcb7595a9566e91a8663b79831683636ba306633f851
1cd8f06831d2b39fd8436559cf124477ead438c5d2c6ceee7a80c20fd2214832
10055bf5d66cd23c24c49512e0f34b7d2cce03afb8b6319c4b74abb62b4c460e
1dc3197202bc7085a5974e598784e30b94646322250e2c3dce14286c78d2aa32
```

这个时候还没有执行测试脚本，三个容器中都没有data数据库，截图如下：

![](https://blog.cdn.lerzen.com/dc240bd6fe0f1203c7e6b963e5823429.png)

3. 执行测试脚本

```
mysql git:(master) ✗ bash shell/test.sh
```
测试脚本会往主库中新建数据库data、数据表user以及一条数据，查看从库可以看到数据已经同步过来，至此主从同步已完成

![](https://blog.cdn.lerzen.com/c194e0e0b90437ed5dda760fda70ca5f.png)

4. 执行销毁脚本

```
➜  mysql git:(master) ✗ bash shell/destroy.sh
从网络中移除容器
删除网络
mysql
停止所有容器
master
slave1
slave2
删掉所有容器
master
slave1
slave2
删掉所有镜像
Untagged: mysql:master
Deleted: sha256:3550f356aca6260f2f285f5bad06a64b2f808758c334ee1b50be3c5e45040024
Deleted: sha256:0cb71bef3eb46e80bccc90ec1506aaf46d2f99d7bf34d0d8da450b935c8f30be
Deleted: sha256:1954ed3d46e7484c55491928a761958bf169e3c87bcbef831140de1f7540b1d7
Deleted: sha256:30a9d08c9ce9a740b8611fc651f4d3781e183299ccc9ec901e10932230864be2
Deleted: sha256:ec3415b868195263cc40e6eff0dec1b2b47fd9058cc313772f2675f6ec006c0b
Deleted: sha256:744f2f77a36b25ec41dc6431c31b0b8376af2e13022dba2ff77f87d2b4c18fb2
Deleted: sha256:a26937a9fa52b5a5aba1c172edb733fd2ed2f95938b5034a125448ae999c08d8
Untagged: mysql:slave
Deleted: sha256:3da35a18083dcb6baf819b140d48373d2ef5d68171dcf176b707803d2fd406e7
Deleted: sha256:e0123e8ea99af57a58c2f7b566b69dc03c4d206319cd5be1d8274f2ff053cbc5
Deleted: sha256:7069c1a41e9956789b56d563f1b6a22bc7832be2af2caaf75ea842c15a5ba9f6
Deleted: sha256:ff684f292d29ade6cdf8a38084d45c04b819a061fc18bf8068fdf0ddb5561c62
Deleted: sha256:7058d5218aa02e79fcac174dbdaccc6b03c0483e7b94abbf3d6b4afccc0bd52c
```
