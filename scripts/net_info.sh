#!/bin/bash
#
serial_num=`dmidecode -s system-serial-number`
echo -e "bus_info netcard numa_node Now_Speed Net_Speed Net_mtu Vendor Product" > net_info
net_all=($(cat /proc/net/dev|sed '1,2d'|awk -F: '{print $1}'|sed 's#:##g'|sed 's# ##g'|egrep -v 'lo|bond'))
## lshw命令将网卡相关信息输出到一个文件中
lshw -C network 2>/dev/null > net_card_all
for net in ${net_all[*]}
do
    bus_info="$(ethtool -i ${net}|grep -w '^bus-info:'|awk '{print $NF}')"
    numa_node="$(cat /sys/class/net/${net}/device/numa_node 2>/dev/null)"
    Vendor="$(grep -A 4 -B 5 -w "${net}" net_card_all |grep -w "vendor:"|awk -F: '{print $2}')"
    Vendor=$(echo ${Vendor}|sed 's/ /_/g')
    Product="$(grep -A 4 -B 5 -w "${net}" net_card_all |grep -w "product:"|awk -F: '{print $2}')"
    Product=$(echo ${Product}|sed 's/ /_/g')

    Now_Speed="$(ethtool ${net}|grep -w 'Speed:'|awk '{print $NF}')"
    [ "${Now_Speed}" == 'Unknown!' ] && Now_Speed=none

    Net_Speed=$(grep -A 4 -B 5 -w "${net}" net_card_all |grep -wE "size:|capacity:"|awk -F: '{print $2}'|head -1)
    Net_Speed=$(echo ${Net_Speed}|sed 's/ /_/g')
    if [ "${Net_Speed:-none}" = "none" ]; then
        Net_Speed="$(printf '%s\n' $(${LSPCI_CMD} -s ${bus_info} 2>/dev/null|awk -F: '{print $NF}')|egrep 'GbE|Gigabit')"
        if [ "${Net_Speed:-none}" = "none" ]; then
            TEM=($(ethtool ${net}|egrep 'Half|Full'|egrep '[0-9]'|awk -F: '{print $NF}'))
            Net_Speed=$(printf '%s\n' ${TEM[*]}|sort|uniq|sed -r 's/[a-Z]|\///g'|sort|uniq|sort -n|tail -1)
        fi
    fi

    Net_mtu="$(ip a show ${net}|awk -F"mtu" '/mtu/{print $2}'|awk '{print $1}'|xargs)"
    echo -e "${bus_info:-none} ${net} ${numa_node:-none} ${Now_Speed:-none} ${Net_Speed:-none} ${Net_mtu:-N\A} ${Vendor:-none} ${Product:-none}" >> net_info
done
rm -rf net_card_all
file=`cat net_info`
echo -e "\"${file}\"" | column -t > net_info
