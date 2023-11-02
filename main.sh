#!/bin/bash
#
if [ -d /tmp/work_home ];then
  echo "/tmp/work_home is exists!" > /dev/null
else
  mkdir /tmp/work_home
fi

ip_all=$(ansible servers -i hosts --list-hosts | sed 1d)
local_ip=`ip add | grep -w "inet" | grep -v "127.0.0.1" | awk -F" " '{print $2}' | awk -F/ '{print $1}'`
for i in ${ip_all};do
    for a in ${local_ip};do
        ping -n -I ${a} -c 1 ${i} > /dev/null
        if [ $? -eq 0 ];then
            server_ip=${a}
            sed -i "s/\(^server_ip=\).*/\1${server_ip}/" scripts/check-hardware.sh
            break 2
        else
            echo "No!" > /dev/null
        fi
    done
done

echo -e "序列号,网卡,IP地址,制造商,型号,系统安装包数量,安装包总数量,内核版本,启动模式,字符集,network服务,NetworkManager服务,CPU数量,CPU信息,CPU_NUMA平和,kvm-state,Vt-d,cpu最大性能,P-state,C-state,C1-state,Raid盘,系统盘,系统盘分区信息,所有磁盘信息,总内存大小,内存数量,内存信息,物理网卡数量,物理网卡信息" > report/check_info.csv

ansible-playbook check_hardware.yaml -i hosts
file_all=`ls /tmp/work_home | grep "csv" | sort`
for i in ${file_all};do
    cat /tmp/work_home/${i} | sed 1d >> report/check_info.csv
done
rm -rf /tmp/work_home
echo "The report has been imported into the report/check_info.csv"
