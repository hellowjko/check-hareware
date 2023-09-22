#!/bin/bash
#
#服务器序列号
serial_num=`dmidecode -s system-serial-number`
# disk
disk_nvme(){
disk=`lsblk -P | grep -v "sr0" | awk -F" " '{print $1}' | sed 's/\"//g' | awk -F= '{print $2}' | sort | uniq`
for i in ${disk};do
    disk_num=`ls /dev/nvme* | grep -w "${disk}" | wc -l`
    if [ ${disk_num} -gt 3 ];then
        disk_sys=/dev/${i}
        break 2
    else
        echo "NO" > /dev/null
    fi
done
}

lsblk | grep "/boot" | grep "sd"
if [ $? -eq 0 ];then
    disk_sys=`df -h|awk '$NF=="/" {print $1}'|sed 's/[0-9]//g'`
else
    lsblk | grep "/boot" | grep "nvme"
    if [ $? -eq 0 ];then
        disk_nvme
    else
        echo "No" > /dev/null
    fi
fi       

disk_sys_part=`lsblk -P ${disk_sys} | sort`
echo -e "${disk_sys}\n${disk_sys_part}" > disk_sys
sed -i 's/\"//g' disk_sys
file=`cat disk_sys`
echo -e "${file}\"" | column -t > disk_sys
