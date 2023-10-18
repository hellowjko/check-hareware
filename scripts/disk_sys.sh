#!/bin/bash
#
# disk
disk_nvme(){
disk=$(lsblk -P | grep -v "sr0" | awk -F" " '{print $1}' | sed 's/\"//g' | awk -F= '{print $2}' | sort | uniq)
for i in ${disk};do
    disk_num=$(ls /dev/nvme* | grep -w "${disk}" | wc -l)
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
    disk_sys=$(df -h|grep -w '/'|awk '{print $1}'|sed 's#/dev/##g'|sed 's/[0-9]//g')
else
    lsblk | grep "/boot" | grep "nvme"
    if [ $? -eq 0 ];then
        disk_nvme
    else
        echo "No" > /dev/null
    fi
fi       

echo "${disk_sys}" > disk_sys
echo "$(lsblk -P ${disk_sys} | sort)" > disk_sys_part

