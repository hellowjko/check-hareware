#!/bin/bash
#
echo -e " Locator\tSize\tSpeed\tManufacturer\tPart_Number" > disk_info
function nvme_output(){
    NVME_disk=($(ls /sys/class/nvme/ 2>/dev/null))
    for nv in ${NVME_disk[*]}
    do
        disordered_comparison="$(ls -l /sys/block/${nv}n1|awk '{print $NF}'|xargs dirname|xargs basename)"
        NNN=$(cat /sys/class/nvme/${nv}/device/numa_node 2>/dev/null)
        [ -z ${NNN} ] && NNN=0
        if [ "${nv}" != "${disordered_comparison}" ]; then
            disordered_comparison="${disordered_comparison}"
        fi
        echo -e "dev_name\tnuma_node\tdisordered_comparison"
        echo -e "${nv}\t${NNN}\t${disordered_comparison:-N/A}"
    done|column -t|sort|uniq >>disk_info
}
# disk
all=($(lsblk -d -n -o NAME|sort -V))
nvme_num=$(printf '%s\n' ${all[*]}|grep -i 'nvme'|wc -l)
if [ ${nvme_num} -eq 1 ]; then
    echo -e "NVME NUMA Check: OK" >>disk_info
    nvme_output
elif [ ${nvme_num} -eq 2 ]; then
    N1=$(cat /sys/class/nvme/*/device/numa_node 2>/dev/null|sort|uniq -c|wc -l)
    if [ ${N1} -eq 2 ]; then
        echo -e "NVME NUMA Check: OK" >>disk_info
    else
        echo -e "NVME NUMA Check: Please check." >>disk_info
    fi
    nvme_output
elif [ ${nvme_num} -gt 2 ]; then
    N1=$(cat /sys/class/nvme/*/device/numa_node 2>/dev/null|sort|uniq -c|wc -l)
    if [ ${N1} -eq 2 ]; then
        echo -e "NVME NUMA Check: OK." >>disk_info
    else
        echo -e "NVME NUMA Check: Please check." >>disk_info
    fi
    nvme_output
fi
