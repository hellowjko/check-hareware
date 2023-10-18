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

echo -e "Product_Serial,Network_card,IP,manufacturer,product_name,RPM_System_count,RPM_Install_total,Kernel_Version,System_boot_mode,Character,network,NetworkManager,CPU_NUM,CPU_INFO,CPU_NUMA,kvm-state,Vt-d,MAX_PEF_state,P-state,C-state,Disk_Raid,Disk_Sys,Disk_Sys_Part,Disk_Info,Mem_Total,Mem_Num,Mem_Info,Net_Card_Num,Net_Info" > report/check_info.csv
ansible-playbook check_hardware.yaml -i hosts
file_all=`ls /tmp/work_home | grep "csv" | sort`
for i in ${file_all};do
    cat /tmp/work_home/${i} | sed 1d >> report/check_info.csv
done
sed -i 's/\t/,/g' report/check_info.csv
rm -rf /tmp/work_home
echo "The report has been imported into the report/check_info.csv"

ansible-playbook check_hardware.yaml -i hosts
file_all=`ls /tmp/work_home | grep "csv" | sort`
for i in ${file_all};do
    cat /tmp/work_home/${i} | sed 1d >> report/check_info.csv
done
rm -rf /tmp/work_home
echo "The report has been imported into the report/check_info.csv"
