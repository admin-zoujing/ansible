#!/bin/bash
##安装mariadb之mysqldump备份脚本
sourceinstall=/usr/local/src/mariadb10.2
chmod -R 777 $sourceinstall

##1、每天凌晨一次的全备份 
mkdir -pv /home/mariadb/dump/mysqldump
chown -R mariadb:mariadb /home/mariadb

echo '#!/bin/bash
DIR=/home/mariadb/dump/mysqldump
PASSWD=Root_123456*0987
HOST=localhost
time=`date +"%Y%m%d"`

cd "$DIR"
/usr/local/mariadb/bin/mysql -u$USER -p$PASSWD -e "show databases" | sed "1d"
echo "Begin backup all Single Database........"
for Database in `/usr/local/mariadb/bin/mysql -u$USER -p$PASSWD -e "show databases" | sed "1d"`
do
        echo "Databases  backup Need wait...."
        /usr/local/mariadb/bin/mysqldump  -u$USER -p$PASSWD -h$HOST $Database --lock-all-tables  --flush-logs  > $Database-"$time".sql
done
echo "single database ok............"

echo "Database Full table backup............."
for db in `/usr/local/mariadb/bin/mysql -u$USER -p$PASSWD -h$HOST -e "show databases"|sed "1d"`
do
        mkdir -pv $db
        for tables in `/usr/local/mariadb/bin/mysql -u$USER -p$PASSWD $db -e "show tables"|sed "1d"`
        do
                /usr/local/mariadb/bin/mysqldump  -h$HOST -u$USER -p$PASSWD $db $tables > $db/$tables
        done
done

echo "Full databases backup............."
/usr/local/mariadb/bin/mysqldump  -u$USER -p$PASSWD -h$HOST --all-databases --lock-all-tables  --flush-logs --events  > all-"$time".sql
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
' > /home/mariadb/mysqldump.sh
chmod a+x /home/mariadb/mysqldump.sh

###2、开启定时任务  
cat >> /etc/crontab <<EOF
#每天凌晨一次的全备份 
30 1 * * * root /home/mariadb/mysqldump.sh > /dev/null 2>&1 
EOF
crontab /etc/crontab
crontab -l


