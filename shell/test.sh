#!/bin/bash

# 主库创建数据库和表
docker cp ./master/init.sh master:/mysql/init.sh
docker cp ./master/init.sql master:/mysql/init.sql
docker exec master /bin/sh /mysql/init.sh