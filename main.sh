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
            sed -i "s/\(^server_ip=\).*/\1${server_ip}/" scripts/sys_info.sh
            break 2
        else
            echo "No!" > /dev/null
        fi
    done
done

echo -e "Product_Serial\tNetwork_card\tIP\tmanufacturer\tproduct_name\tRPM_System_count\tRPM_Install_total\tKernel_Version\tSystem_boot_mode\tCharacter\tnetwork\tNetworkManager\tCPU_NUM\tCPU_INFO\tCPU_NUMA\tkvm-state\tVt-d\tMAX_PEF_state\tp-state\tc-state\tDisk_Raid\tDisk_Sys\tDisk_Sys_Part\tDisk_Info\tMem_Total\tMem_Num\tMem_Info\tNet_Card_Num\tNet_Info" > report/check_info.csv
ansible-playbook check_hardware.yaml -i hosts
file_all=`ls /tmp/work_home | grep "csv" | sort`
for i in ${file_all};do
    cat /tmp/work_home/${i} | sed 1d >> report/check_info.csv
done
sed -i 's/\t/,/g' report/check_info.csv
rm -rf /tmp/work_home
echo "The report has been imported into the report/check_info.csv"
