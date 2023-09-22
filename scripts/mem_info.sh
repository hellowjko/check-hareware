#!/bin/bash
#
#服务器序列号
serial_num=`dmidecode -s system-serial-number`
echo -e "Locator Size Speed Manufacturer Part_Number" > mem_info
# mem
mem_total=`free -h | grep "Mem:" | awk '{print $2}'`
Slot_Mark=($(dmidecode -t memory|grep -B 1 '^Memory Device'|grep '^Handle'|awk '{print $2}'|sed 's#,##g'))
for Handle in ${Slot_Mark[*]}
    do
        Locator="$(dmidecode -t memory|grep -A 23 "${Handle}"|grep 'Locator:'|grep -v 'Bank Locator:'|awk -F: '{print $NF}')"
        Locator="$(echo ${Locator}|sed 's# #_#g')"
        Size="$(dmidecode -t memory|grep -A 23 "${Handle}"|grep 'Size:'|awk -F: '{print $NF}'|sed 's# ##g')"
        [ -z "${Size}" ] && Size='Unknown'
        snum="$(echo ${Size}|grep -E '[0-9]'|wc -l)"
        if [ ${snum} -eq 0 ]; then
            continue
        fi
        Speed="$(dmidecode -t memory|grep -A 23 "${Handle}"|expand|grep -E '^[ ]+Speed:'|grep -v 'Configured Clock'|awk -F: '{print $NF}'|sed 's# ##g')"
        [ "${Speed}" = 'Unknown' ] && Speed=none
        Manufacturer="$(dmidecode -t memory|grep -A 23 "${Handle}"|grep 'Manufacturer:'|awk -F: '{print $NF}')"
        Manufacturer="$(echo ${Manufacturer}|sed 's# #_#g')"
        Part_Number="$(dmidecode -t memory|grep -A 23 "${Handle}"|grep 'Part Number'|awk -F: '{print $NF}')"
        Part_Number="$(echo ${Part_Number}|sed 's# #_#g')"
        echo -e " ${Locator} ${Size} ${Speed} ${Manufacturer} ${Part_Number}" >> mem_info
done
sed -i '/Unknown/d' mem_info

file=`cat mem_info`
echo -e "\"${file}\"" | column -t > mem_info

echo -e "Total\tNumber" > mem_num
# mem
mem_total=`free -h | grep "Mem:" | awk '{print $2}'`
mem_count=$(($(cat mem_info | wc -l) -1))
echo -e "${mem_total}\t${mem_count}" >> mem_num
