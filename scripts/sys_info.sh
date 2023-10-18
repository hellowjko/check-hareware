#!/bin/bash
#
# gzip
tar_cmd(){
tar --version > /dev/null
if [ $? -eq 0 ];then
    echo "tar installed" > /dev/null
else
    rpm -ivh tar*
fi
}
# cpu架构
arch=$(uname -p)
if [ "$arch" == "x86_64" ];then
    which mailx 2> /dev/null && echo $? > /dev/null
    if [ $? -eq 0 ];then
        tar_cmd
        raid_cmd_state="yes"
        break
    else
        tar_cmd
        tar zxf raid_cmd.tar.gz
        rpm -ivh raid_cmd/x86_64/*.rpm > /dev/null
        raid_cmd_state="yes"
    fi
elif
    [ "$arch" == "aarch64" ];then
    which mailx 2> /dev/null && echo $? > /dev/null
    if [ $? -eq 0 ];then
        raid_cmd_state="yes"
        break
    else
        tar zxf raid_cmd.tar.gz
        rpm -ivh raid_cmd/aarch64/*.rpm > /dev/null
        raid_cmd_state="yes"
    fi
else
    echo "Unkown!"
    raid_cmd_state="no"
    exit
fi

server_ip=192.168.103.6
local_net=$(ip add | grep -w "inet" | grep -v "127.0.0.1" | awk '{print $NF}')
for i in ${local_net};do
    ping -n -I ${i} -c 2 ${server_ip} > /dev/null
    if [ $? -eq 0 ];then
        host_net=${i}
        host_ip=$(ip add | grep -w "inet" | grep "${i}" | awk -F" " '{print $2}')
        host_ip_file=$(ip add | grep -w "inet" | grep "${i}" | awk -F" " '{print $2}' | awk -F/ '{print $1}')
    else
        echo "No!" > /dev/null
    fi
done

product_name=$(dmidecode -s system-product-name)
Product_Serial=$(dmidecode -s system-serial-number)
manufacturer=$(dmidecode -s system-manufacturer | sed "s/,//g")
RPM_SYSTEM_NUM=$(/usr/bin/yum history list 1 2>/dev/null | grep -Ew '^[ ]+1 ' | awk -F "|" '{print $NF}'|xargs)
RPM_INSTALL_NUM=$(rpm -qa|wc -l 2>/dev/null)
Kernel_Version=$(uname -r)

echo -e "Product_Serial,Network_card,IP,manufacturer,product_name,RPM_System_count,RPM_Install_total,Kernel_Version,System_boot_mode,Character,network,NetworkManager,CPU_NUM,CPU_INFO,CPU_NUMA,kvm-state,Vt-d,MAX_PEF_state,P-state,C-state,Disk_Raid,Disk_Sys,Disk_Sys_Part,Disk_Info,Mem_Total,Mem_Num,Mem_Info,Net_Card_Num,Net_Info" > ${host_ip_file}_check.csv
if [ -d /sys/firmware/efi -a -d /boot/efi ]; then
    BOOT_MODE="UEFI"
else
    BOOT_MODE=BIOS
fi
if [ -f /etc/locale.conf ]; then
    csfile=/etc/locale.conf
    judge=$(awk -F= '/^LANG=/{print $2}' ${csfile}|grep en_US|wc -l)
    if [ ${judge} -ge 1 ]; then
        CHAS=$(awk -F= '/^LANG=/{print $2}' ${csfile}|sed  's/"//g')
    else
        CHAS="$(awk -F= '/^LANG=/{print $2}' ${csfile}|sed  's/"//g')"
    fi
elif [ -f /etc/sysconfig/i18n ]; then
    csfile=/etc/sysconfig/i18n
    judge=$(awk -F= '/^LANG=/{print $2}' ${csfile}|grep en_US|wc -l)
    if [ ${judge} -ge 1 ]; then
        CHAS=$(awk -F= '/^LANG=/{print $2}' ${csfile}|sed  's/"//g')
    else
        CHAS="$(awk -F= '/^LANG=/{print $2}' ${csfile}|sed  's/"//g')"
    fi
elif [ -f /etc/default/locale ]; then
    csfile=/etc/default/locale
    judge=$(awk -F= '/^LANG=/{print $2}' ${csfile}|grep en_US|wc -l)
    if [ ${judge} -ge 1 ]; then
        CHAS=$(awk -F= '/^LANG=/{print $2}' ${csfile}|sed  's/"//g')
    else
        CHAS="$(awk -F= '/^LANG=/{print $2}' ${csfile}|sed  's/"//g')"
    fi
else
    CHAS="N/A"
fi

if [ $(systemctl status network 2>/dev/null|wc -l) != 0 ]; then
    is_enabled=$(systemctl is-enabled network 2>/dev/null)
    is_active=$(systemctl is-active network 2>/dev/null)
    network_state="\"is-enabled: [${is_enabled}]\nis-active: [${is_active}]\""
else
    network_state='No_service'
fi
if [ $(systemctl status NetworkManager 2>/dev/null|wc -l) != 0 ]; then
    is_enabled=$(systemctl is-enabled NetworkManager 2>/dev/null)
    is_active=$(systemctl is-active NetworkManager 2>/dev/null)
    NetworkManager_state="\"is-enabled: [${is_enabled}]\nis-active: [${is_active}]\""
else
    NetworkManager_state='No_service'
fi

cpu_num=$(cat /proc/cpuinfo | grep "^physical id" | sort | uniq | wc -l)


sh cpu_info.sh
local_cpu_info=$(cat cpu_info)


numa=$(lscpu | grep "NUMA")
echo -e "\"${numa}\"" > cpu_numa
local_cpu_numa=$(cat cpu_numa)

sh cpu_state.sh
local_cpu_state=$(cat cpu_state)

sh disk_raid.sh
local_disk_raid=$(cat disk_raid)

sh disk_sys.sh
local_disk_sys=$(cat disk_sys)
local_disk_sys_part=$(cat disk_sys_part)

sh disk_info.sh
local_disk_info=$(cat disk_info)

sh mem_info.sh
local_mem_info=$(cat mem_info)
local_mem_count=$(cat mem_num | tail -1)

sh net_info.sh
local_net_info=$(cat net_info)
net_card_num=$(($(cat net_info | wc -l) -1))


echo -e "${Product_Serial},${host_net},${host_ip},${manufacturer},${product_name},${RPM_SYSTEM_NUM},${RPM_INSTALL_NUM},${Kernel_Version},${BOOT_MODE},${CHAS},${network_state},${NetworkManager_state},${cpu_num},${local_cpu_info},${local_cpu_numa},${local_cpu_state},${local_disk_raid},${local_disk_sys},${local_disk_sys_part},${local_disk_info},${local_mem_count},${local_mem_info},${net_card_num},${local_net_info}" >> ${host_ip_file}_check.csv


if [ "${raid_cmd_state}" == "yes" ];then
    rpm -e mailx smartmontools storcli ssacli && rm -rf /opt/*
else
    exit
fi
