#!/bin/bash
#
# cpu信息
echo -e "ID model_name cpu_cores processor_num cpu_MHz Manufacturer" > cpu_info
cpu_num=$(cat /proc/cpuinfo | grep "^physical id" | sort | uniq | wc -l)
for i in $(seq 1 $cpu_num);do
    cpu_processor_num=$(cat /proc/cpuinfo|grep -A 16 -B 9  "physical id.*${i}"|grep '^processor'|wc -l)
    cpu_model=$(cat /proc/cpuinfo|grep -A 16 -B 9  "physical id.*${i}"|grep '^model name'| uniq | awk -F: {'print $NF'})
    cpu_model=$(echo ${cpu_model} | sed 's# #_#g')
    cpu_cores=$(cat /proc/cpuinfo|grep -A 16 -B 9  "physical id.*${i}"|grep '^cpu core'| wc -l)

    Actual_cpu_MHz=$(cat /proc/cpuinfo|grep -A 16 -B 9  "physical id.*${i}"|grep '^cpu MHz'|awk '{print $NF}'|egrep '[0-9]'|sort|uniq|sed -r 's#[a-Z]##g'|awk -F. '{print $1}')
    cpu_MHz="$(echo $cpu_model|sed 's/_/ /g'|xargs printf '%s\n'|grep 'GHz'|sed -r 's/[a-Z]//g')"
    cpu_MHz=$(echo ${cpu_MHz} \* 1000|${BC_CMD} 2>/dev/null|awk -F. '{print $1}')
    cpu_MHz=$(awk "BEGIN{print ${cpu_MHz} * 1000}" 2>/dev/null|awk -F. '{print $1}')
    if [ ${#Actual_cpu_MHz[*]} -eq 1 ]; then
        if [ ${cpu_MHz} -eq ${Actual_cpu_MHz} ]; then
            cpu_MHz="${Actual_cpu_MHz}"
        elif [ $(( ${cpu_MHz} + 1 )) -eq ${Actual_cpu_MHz} ]; then
            cpu_MHz="${Actual_cpu_MHz}"
        elif [ $(( ${cpu_MHz} - 1 )) -eq ${Actual_cpu_MHz} ]; then
            cpu_MHz="${Actual_cpu_MHz}"
        else
            cpu_MHz="${Actual_cpu_MHz}"
        fi
    elif [ ${#Actual_cpu_MHz[*]} -gt 1 ]; then
            cpu_MHz="Unequal"
    else
        cpu_MHz="${Actual_cpu_MHz:-none}"
    fi

    vendor_id="$(cat /proc/cpuinfo|grep -A 16 -B 9  "physical id.*${i}"|grep '^vendor_id'|awk '{print $NF}'|sort|uniq)"

    [ -z ${cpu_processor_num} ] && cpu_processor_num=none
    [ -z ${cpu_model} ] && cpu_model=none
    [ -z ${cpu_cores} ] && cpu_cores=none
    [ -z ${cpu_MHz} ] && cpu_MHz=none
    [ -z ${vendor_id} ] && vendor_id=none

    echo -e "CPU${i} ${cpu_model} ${cpu_cores} ${cpu_processor_num} ${cpu_MHz} ${vendor_id}" >> cpu_info
done
file=$(cat cpu_info | column -t)
echo -e "\"${file}\"" > cpu_info
