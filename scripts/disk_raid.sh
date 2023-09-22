#!/bin/bash
#
# 序列号
serial_num=`dmidecode -s system-serial-number`
>disk_raid
## H3C ---
manufacturer=$(dmidecode -t system|grep Manufacturer|grep -wi 'h3c'|wc -l)
if [ ${manufacturer} -eq 1 ]; then
    ssacli ctrl all show config 2>/dev/null|grep -E 'logicaldrive'|xargs >>disk_raid
    ## 物理磁盘序列号
    DISK_NUM=$(ssacli ctrl all show config 2>/dev/null|awk '/physicaldrive/{print $2}' )
    ## 查看驱动器RAID卡
    SLOT=($(ssacli ctrl all show 2>/dev/null|grep -w Slot|awk -F"Slot" '{print $2}'))
    ## 查看单块磁盘
    for s in ${SLOT[*]};do
        for n in ${DISK_NUM[*]}; do
            controller="$(ssacli ctrl slot=${s} physicaldrive $n show 2>/dev/null|awk '/in Slot/{print $(NF-1),$NF}')"
            model="$(ssacli ctrl slot=${s} physicaldrive $n show 2>/dev/null| awk -F: '/Model:/{print $2}'|xargs |sed 's/ /-/g')"
            size="$(ssacli ctrl slot=${s} physicaldrive $n show 2>/dev/null|grep -E '^[ ]+Size:'|awk -F: '{print $2}'|xargs)"
            echo "-> ${controller}, ${n}, ${model}, ${size}"
        done
    done >> disk_raid
else
    /opt/MegaRAID/storcli/storcli64 /call/vall show|sed -rn '/^Virtual Drives/,/Cac=/p'|sed -r '/Cac=|^===|^$|^--|Virtual Drives|^DG/d'|awk '{print $2,$9$10}'|column -t 2>/dev/null >>disk_raid
    /opt/MegaRAID/storcli/storcli64 /call/eall/sall show|sed -rn '/^Drive Information/,/EID-Enclosure/p'|sed -r '/EID-Enclosure|^===|^$|^--|Drive Information|^EID/d'|awk '{print "->",$3,$5$6,$8,$12}'|column -t >>disk_raid
    num=$(cat disk_raid 2>/dev/null|wc -l)
    if [ ${num} -le 2 ]; then
        DISK_NUM=($(lsblk -d -n -o NAME|sort -V))
        for i in ${DISK_NUM[*]};do
            rlevel="$(udevadm info -a /dev/${i} 2>/dev/null|grep 'ATTRS{raid_level}=='|awk -F= '{print $NF}'|sed 's/"//g'|xargs)"
            [ -z "${rlevel}" ] && continue
            echo "$i - ${rlevel}"  >> disk_raid
        done
    fi
fi
file=`cat disk_raid`
echo -e "\"${file}\"" | column -t > disk_raid
