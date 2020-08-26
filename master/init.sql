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
