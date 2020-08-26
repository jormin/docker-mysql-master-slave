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
