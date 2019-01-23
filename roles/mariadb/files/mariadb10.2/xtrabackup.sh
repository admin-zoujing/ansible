#!/bin/bash
##安装mariadb之xtrabackup备份脚本
##数据库出现故障，通过完整备份+到现在为止的所有增量备份+最后一次增量备份到现在的二进制日志来恢复。
sourceinstall=/usr/local/src/mariadb10.2
chmod -R 777 $sourceinstall
##时间时区同步，修改主机名
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

ntpdate ntp1.aliyun.com
hwclock -w
echo "*/30 * * * * root ntpdate -s ntp1.aliyun.com" >> /etc/crontab

sed -i 's|SELINUX=.*|SELINUX=disabled|' /etc/selinux/config
sed -i 's|SELINUXTYPE=.*|#SELINUXTYPE=targeted|' /etc/selinux/config
sed -i 's|SELINUX=.*|SELINUX=disabled|' /etc/sysconfig/selinux 
sed -i 's|SELINUXTYPE=.*|#SELINUXTYPE=targeted|' /etc/sysconfig/selinux 
setenforce 0 && systemctl stop firewalld && systemctl disable firewalld

rm -rf /var/run/yum.pid 
rm -rf /var/run/yum.pid

yum -y install percona-xtrabackup-24-2.4.12-1.el7.x86_64.rpm

# yum -y install epel-release
# yum -y install wget
# wget https://www.percona.com/downloads/XtraBackup/Percona-XtraBackup-2.4.12/binary/redhat/7/x86_64/percona-xtrabackup-24-2.4.12-1.el7.x86_64.rpm
# yum -y install percona-xtrabackup-24-2.4.12-1.el7.x86_64.rpm


##1、数据库全备份的脚本,每周六凌晨一次的全备份
mkdir -pv /home/mariadb/dump/full
chown -R mariadb:mariadb /home/mariadb

echo '#!/bin/bash
User=root
PassWord=Root_123456*0987
dateformat=`date +"%Y%m%d"`

fulldir=/home/mariadb/dump/full

if [[ ! -d $fulldir/$dateformat ]]; then
        mkdir -pv $fulldir/$dateformat
fi

cd "$fulldir/$dateformat"
echo "Begin backup full Database........"
 innobackupex --defaults-file=/usr/local/mariadb/conf/my.cnf --user=$User --password=$PassWord --no-timestamp --host=127.0.0.1 $fulldir/$dateformat > $fulldir/$dateformat/fullbackup.log 2>&1 &
 sleep 5
echo "full database ok............" 

#***********需要修改要删除的数据库开头名称************#
before=`date -d "2 day ago" +"%Y%m%d"`
fullbackupdata="$fulldir"/"$before"

if [ -d $fullbackupdata ] ;then
        rm -rf $fullbackupdata
        exit 1
fi
' >  /home/mariadb/innobackupex_fullbackupdata.sh
chmod a+x  /home/mariadb/innobackupex_fullbackupdata.sh

##2、每天一次的全增量（以全备份为基础的增量），每两个小时一次的增量备份（以全增量为基础的增量）
echo '#!/bin/bash
# define some variables
User=root
PassWord=Root_123456*0987
dateFull=`date +"%Y%m%d"`
dateIncre=`date +"%Y%m%d_%H%M%S"`

fulldir=/home/mariadb/dump/full
Increment=/home/mariadb/dump/increment

# The first incremental backup of a week is full backup.
if [ ! -d $Increment/$dateFull ]; then
        mkdir -pv $Increment/$dateFull
        fullfilename=`ls -lt $fulldir | sed -n 2p | cut -d" " -f9`
        cd "$Increment/$dateFull"
        echo "Begin The first incremental backup of a week is full backup........"
        innobackupex --defaults-file=/usr/local/mariadb/conf/my.cnf --user=$User --password=$PassWord --use-memory=1024MB --no-timestamp --host=127.0.0.1 --incremental $Increment/$dateFull --incremental-basedir=$fulldir/$fullfilename > $Increment/$dateFull/incre-oneday.log 2>&1 &
        sleep 5
        echo "The first incremental backup of a week is full backup ok............" 
fi

# Incremental backups from the first incremental backups.
if [ -d $Increment/$dateFull/$datetime ]; then
        cd $Increment/$dateFull
        fileName=`ls -lt $Increment | sed -n 2p | cut -d" " -f9`
        echo "Begin Incremental backups from the first incremental backups........."
        innobackupex --defaults-file=/usr/local/mariadb/conf/my.cnf --user=$User --password=$PassWord --use-memory=1024MB --no-timestamp --host=127.0.0.1 --incremental $Increment/$fileName/$dateIncre --incremental-basedir=$Increment/$fileName >> $Increment/$fileName/incre-twohour.log  2>&1 &
        sleep 5
        echo "Incremental backups from the first incremental backups ok............" 
fi

#***********需要修改要删除的数据库开头名称************#
before=`date -d "2 day ago" +"%Y%m%d"`
Incrementdata="$Increment"/"$before"

if [ -d $Incrementdata ] ;then
        rm -rf $Incrementdata
        exit 1
fi
' > /home/mariadb/innobackupex_incrementbackupdata.sh
chmod a+x  /home/mariadb/innobackupex_incrementbackupdata.sh

###3、开启定时任务  
cat >> /etc/crontab <<EOF
#每周六凌晨一次的全备份 
10 2 * * 6 root /home/mariadb/innobackupex_fullbackupdata.sh > /dev/null 2>&1 
#每天一次的全增量（以全备份为基础的增量），每两个小时一次的增量备份（以全增量为基础的增量）
50 1-23/2 * * * root /home/mariadb/innobackupex_incrementbackupdata.sh > /dev/null 2>&1 
EOF
crontab /etc/crontab
crontab -l


#RHEL7使用xtrbackup还原增量备份:https://www.percona.com/downloads/
#chmod -R 777  $sourceinstall/percona-xtrabackup-24-2.4.12-1.el7.x86_64.rpm
#yum -y install percona-xtrabackup-24-2.4.12-1.el7.x86_64.rpm
#做一次完整备份
#innobackupex --password=Root_123456*0987 /data/db_backup/
#ls -ld /data/db_backup/2017-08-02_13-43-38/
#mysql -uroot -pRoot_123456*0987 -e 'select * from Yang.T1;'
#mysql -uroot -pRoot_123456*0987 -e 'insert into Yang.T1 values(1000);'
#第一次增量备份：第一次备份的–incremental-basedir参数应指向完整备份的时间戳目录
#innobackupex --password=Root_123456*0987 --incremental /data/db_backup/ --incremental-basedir=/data/db_backup/2017-08-02_13-43-38/
#ls -ld /data/db_backup/2017-08-02_13-49-29/
#mysql -uroot -pRoot_123456*0987 -e 'insert into Yang.T1 values(2000);'
#第二次增量备份：第二次备份的–incremental-basedir参数应指向第一次增量备份的时间戳目录
#innobackupex --password=Root_123456*0987 --incremental /data/db_backup/ --incremental-basedir=/data/db_backup/2017-08-02_13-49-29/
#还原数据
#systemctl daemon-reload && systemctl stop mysqld && netstat -lanput |grep 3306
#rm -rf /var/lib/mysql/*
#整合完整备份和增量备份：注意：一定要按照完整备份、第一次增量备份、第二次增量备份的顺序进行整合，在整合最后一次增量备份时不要使用–redo-only参数
#innobackupex --apply-log --redo-only /data/db_backup/2017-08-02_13-43-38/
#innobackupex --apply-log --redo-only /data/db_backup/2017-08-02_13-43-38/ --incremental-dir=/data/db_backup/2017-08-02_13-49-29/
#innobackupex --apply-log /data/db_backup/2017-08-02_13-43-38/ --incremental-dir=/data/db_backup/2017-08-02_13-52-59/ 
#innobackupex --apply-log /data/db_backup/2017-08-02_13-43-38/
#开始还原
#innobackupex --copy-back /data/db_backup/2017-08-02_13-43-38/
#chown -R mysql.mysql /var/lib/mysql 
#systemctl daemon-reload && systemctl restart mysqld && netstat -lanput |grep 3306
#mysql -uroot -pRoot_123456*0987 -e 'select * from Yang.T1;'
