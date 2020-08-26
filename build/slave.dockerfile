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
