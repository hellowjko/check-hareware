#!/bin/bash
#
echo -e "DISK SIZE Device_Model Rotation_Rate Form_Factor" > disk_info
# disk
all=($(lsblk -d -n -o NAME|sort -V))
for d in ${all[*]}
do
    DSIZE="$(lsblk -d -n -o NAME,SIZE,ROTA 2>/dev/null|grep -w "${d}"|awk '{print $2}')"
    DTYPE="$(smartctl  info /dev/${d} | grep -w "^Rotation Rate:"|awk -F: '{print $NF}'|xargs |sed 's/ /_/g')"
    DModel_Number="$(smartctl  info /dev/${d} | grep -wE "^Device Model:|^Model Number:|Vendor:|Product:"|awk -F: '{print $NF}'|xargs |sed 's/ /_/g')"
    Form_Factor="$(smartctl  info /dev/${d} | grep -w "^Form Factor:"|awk -F: '{print $NF}'|xargs |sed 's/ /_/g')"
    echo -e "${d} ${DSIZE:-none} ${DModel_Number:-none} ${DTYPE:-none} ${Form_Factor:-none}" >> disk_info
done
file=$(cat disk_info)
echo -e "\"${file}\"" | column -t > disk_info