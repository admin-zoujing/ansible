#!/bin/bash
##安装mysql之mysqldump备份脚本
sourceinstall=/usr/local/src/mysql5.7
chmod -R 777 $sourceinstall

##1、每天凌晨一次的全备份 
mkdir -pv /home/mysql/dump/mysqldump
chown -R mysql:mysql /home/mysql

echo '#!/bin/bash
DIR=/home/mysql/dump/mysqldump
PASSWD=Root_123456*0987
HOST=localhost
time=`date +"%Y%m%d"`

cd "$DIR"
/usr/local/mysql/bin/mysql -u$USER -p$PASSWD -e "show databases" | sed "1d"
echo "Begin backup all Single Database........"
for Database in `/usr/local/mysql/bin/mysql -u$USER -p$PASSWD -e "show databases" | sed "1d"`
do
        echo "Databases  backup Need wait...."
        /usr/local/mysql/bin/mysqldump  -u$USER -p$PASSWD -h$HOST $Database --lock-all-tables  --flush-logs  > $Database-"$time".sql
done
echo "single database ok............"

echo "Database Full table backup............."
for db in `/usr/local/mysql/bin/mysql -u$USER -p$PASSWD -h$HOST -e "show databases"|sed "1d"`
do
        mkdir -pv $db
        for tables in `/usr/local/mysql/bin/mysql -u$USER -p$PASSWD $db -e "show tables"|sed "1d"`
        do
                /usr/local/mysql/bin/mysqldump  -h$HOST -u$USER -p$PASSWD $db $tables > $db/$tables
        done
done

echo "Full databases backup............."
/usr/local/mysql/bin/mysqldump  -u$USER -p$PASSWD -h$HOST --all-databases --lock-all-tables  --flush-logs --events  > all-"$time".sql
if [[ $? == 0 ]];then
        echo "mysql backup Success"
else
        echo "mysql backup Fail"
fi

#***********需要修改要删除的数据库开头名称************#
before=`date -d "2 day ago" +"%Y%m%d"`
mysqlsql="$DIR"/mysql-$before.sql
testsql="$DIR"/test-$before.sql
performance_schemasql="$DIR"/performance_schema-$before.sql

if [ -f $mysqlsql ] ;then
        rm -rf $mysqlsql
        rm -rf $testsql
        rm -rf $performance_schemasql
        exit 1
fi
' > /home/mysql/mysqldump.sh
chmod a+x /home/mysql/mysqldump.sh

###2、开启定时任务  
cat >> /etc/crontab <<EOF
#每天凌晨一次的全备份 
30 1 * * * root /home/mysql/mysqldump.sh > /dev/null 2>&1 
EOF
crontab /etc/crontab
crontab -l