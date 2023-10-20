#!/bin/bash
#
####################function######################
tar_cmd(){
    tar --version > /dev/null
    if [ $? -eq 0 ];then
        echo "tar installed" > /dev/null
        tar zxf cmd.tar.gz
    else
        rpm -ivh tar*
        tar zxf cmd.tar.gz
    fi
}
env_tool(){
    ARCH=$(uname -p)
    if [ "${OS_VER}" == "centos" ] && [ "${ARCH}" == "x86_64" ]; then
        tar_cmd
        rpm -ivh cmd/x86_64/lshw/lshw-B.02.18-17.el7.x86_64.rpm
        rpm -ivh cmd/x86_64/lspci/pciutils-3.5.1-3.el7.x86_64.rpm
        rpm -ivh cmd/x86_64/raid/*.rpm
    elif [ "${OS_VER}" == "ctyunos" ] && [ "${ARCH}" == "x86_64" ]; then
        tar_cmd
        rpm -ivh cmd/x86_64/raid/*.rpm
    elif [ "${OS_VER}" == "centos" ] && [ "${ARCH}" == "aarch64" ]; then
        tar_cmd
        rpm -ivh cmd/aarch64/lshw/lshw-B.02.18-17.el7.aarch64.rpm
        rpm -ivh cmd/aarch64/raid/*.rpm
    elif [ "${OS_VER}" == "ctyunos" ] && [ "${ARCH}" == "aarch64" ]; then
        tar_cmd
        rpm -ivh cmd/aarch64/raid/*.rpm
    fi
}

env_tool_uninstall(){
    if [ "${OS_VER}" == "centos" ] && [ "${ARCH}" == "x86_64" ]; then
        rpm -e pciutils mailx smartmontools storcli ssacli lshw
        rm -rf /opt/*
    elif [ "${OS_VER}" == "ctyunos" ] && [ "${ARCH}" == "x86_64" ]; then
        rpm -e mailx smartmontools storcli ssacli
        rm -rf /opt/*
#    elif [ "${OS_VER}" == "centos" ] && [ "${ARCH}" == "aarch64" ]; then
#        rpm -e pciutils mailx smartmontools storcli ssacli && rm -rf /opt/*
#    elif [ "${OS_VER}" == "ctyunos" ] && [ "${ARCH}" == "aarch64" ]; then
#        rpm -e mailx smartmontools storcli ssacli && rm -rf /opt/*
    fi
}

check_server_brand(){
    echo -e 'Brand Check:' > check_brand
    Manufacturer="$(dmidecode -t system|grep -E -w 'Manufacturer:')"
    Product_Name="$(dmidecode -t system|grep -E -w 'Product Name:')"
    Manufacturer="$(echo ${Manufacturer})"
    Product_Name="$(echo ${Product_Name})"

    echo -e "${Manufacturer}\n${Product_Name}" >> check_brand
}

x86_server_cpu_check(){
    cpu_num=($(cat /proc/cpuinfo|grep '^physical id'|sort|uniq|awk '{print $NF}'))
    # all_cpu_MHz_num="$(cat /proc/cpuinfo|grep -A 16 -B 9  "^physical id"|grep '^cpu MHz'|awk '{print $NF}'|egrep '[0-9]'|sort|uniq|wc -l)"
    echo -e "ID\tmodel_name\tcpu_cores\tprocessor_num\tcpu_MHz\tvendor_id" > check_cpu.txt
    for info in ${cpu_num[*]};do
        processor_num="$(cat /proc/cpuinfo|grep -A 16 -B 9  "physical id.*${info}"|grep '^processor'|wc -l)"
        cpu_model="$(cat /proc/cpuinfo|grep -A 16 -B 9  "physical id.*${info}"|grep '^model name'|sort|uniq|awk -F: '{print $NF}')"
        cpu_model="$(echo ${cpu_model}|sed 's# #_#g')"
        cpu_cores="$(cat /proc/cpuinfo|grep -A 16 -B 9  "physical id.*${info}"|grep '^cpu cores'|awk '{print $NF}'|sort|uniq)"

        Actual_cpu_MHz=($(cat /proc/cpuinfo|grep -A 16 -B 9  "physical id.*${info}"|grep '^cpu MHz'|awk '{print $NF}'|egrep '[0-9]'|sort|uniq|sed -r 's#[a-Z]##g'|awk -F. '{print $1}'))
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

        vendor_id="$(cat /proc/cpuinfo|grep -A 16 -B 9  "physical id.*${info}"|grep '^vendor_id'|awk '{print $NF}'|sort|uniq)"
        ## CPU Maximum Performance Open State
        snum=$(hostnamectl | grep -w 'Chassis'|awk '{print $NF}'|grep -w server|wc -l)
        if [ ${snum} -eq 1 ]; then
            cpum=($(cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null|uniq))
            if [ ${#cpum[*]} -eq 1 ]; then
                MAX_PEF_state=${cpum[*]}
            else
                MAX_PEF_state=($(cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null|uniq -c|awk '{print $2"("$1"cores)"}' |xargs printf '%s,'|sed 's/,$//g'))
            fi
        else
            MAX_PEF_state="$(hostnamectl | grep -w 'Chassis'|awk '{print $NF}')"
        fi
        [ -z ${processor_num} ] && processor_num=none
        [ -z ${cpu_model} ] && cpu_model=none
        [ -z ${cpu_cores} ] && cpu_cores=none
        [ -z ${cpu_MHz} ] && cpu_MHz=none
        [ -z ${vendor_id} ] && vendor_id=none

        echo -e "CPU${info}\t${cpu_model}\t${cpu_cores}\t${processor_num}\t${cpu_MHz}\t${vendor_id}" >> check_cpu.txt
    done
    cat check_cpu.txt|column -t > check_cpu
    cpu_total=${#cpu_num[*]}
    Performance_Mode=${MAX_PEF_state:-none}

    echo -e "\"$(cat check_cpu)\"" > local_cpu_info
    cpu_info=$(cat local_cpu_info)
}

arm_server_cpu_check(){
    cpu_num=($(dmidecode -t processor |grep -w 'Socket Designation:'|awk -F: '{print $2}'|sed 's/ //g'))
    # all_cpu_MHz_num="$(cat /proc/cpuinfo|grep -A 16 -B 9  "^physical id"|grep '^cpu MHz'|awk '{print $NF}'|egrep '[0-9]'|sort|uniq|wc -l)"
    echo -e "ID\tmodel_name\tcpu_cores\tprocessor_num\tcpu_MHz\tManufacturer" > check_cpu.txt
    for info in ${cpu_num[*]};do
        processor_num="$(dmidecode -t processor |sed -r -n "/Socket Designation:.*${info}/,/Thread Count:/p"|grep -w 'Thread Count:'|cut -d: -f2|xargs)"
        cpu_model="$(dmidecode -t processor |sed -r -n "/Socket Designation:.*${info}/,/Version:/p"|grep -w "Version:"|awk -F: '{print $2}')"
        cpu_model="$(echo ${cpu_model}|sed 's# #_#g')"
        cpu_cores="$(dmidecode -t processor |sed -r -n "/Socket Designation:.*${info}/,/Core Count:/p"|grep -w 'Core Count:'|awk -F: '{print $2}'|xargs)"

        Actual_cpu_MHz=($(dmidecode -t processor |sed -r -n "/Socket Designation:.*${info}/,/Characteristics:/p"|grep -w "Current Speed:"|awk -F: '{print $2}'|xargs |sed -r 's#[a-Z]##g'))
        cpu_MHz="$(echo $cpu_model|sed 's/_/ /g'|xargs printf '%s\n'|grep 'GHz'|sed -r 's/[a-Z]//g')"
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

        Manufacturer="$(dmidecode -t processor |sed -r -n "/Socket Designation:.*${info}/,/Characteristics:/p"|grep -w "Manufacturer:"|awk -F: '{print $2}'|xargs|sed 's/ /_/g')"
        ## CPU Maximum Performance Open State
        snum=$(hostnamectl | grep -w 'Chassis'|awk '{print $NF}'|grep -w server|wc -l)
        if [ ${snum} -eq 1 ]; then
            cpum=($(cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null|uniq))
            if [ ${#cpum[*]} -eq 1 ]; then
                MAX_PEF_state=${cpum[*]}
            else
                MAX_PEF_state=($(cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null|uniq -c|awk '{print $2"("$1"cores)"}' |xargs printf '%s,'|sed 's/,$//g'))
            fi
        else
            MAX_PEF_state="$(hostnamectl | grep -w 'Chassis'|awk '{print $NF}')"
        fi

        [ -z ${processor_num} ] && processor_num=none
        [ -z ${cpu_model} ] && cpu_model=none
        [ -z ${cpu_cores} ] && cpu_cores=none
        [ -z ${cpu_MHz} ] && cpu_MHz=none
        [ -z ${Manufacturer} ] && Manufacturer=none

        echo -e "${info}\t${cpu_model}\t${cpu_cores}\t${processor_num}\t${cpu_MHz}\t${Manufacturer}" >> check_cpu.txt
    done
    cat check_cpu.txt|column -t check_cpu
    cpu_total=${#cpu_num[*]}
    Performance_Mode=${MAX_PEF_state:-none}

    echo -e "\"$(cat check_cpu)\"" > local_cpu_info
    cpu_info=$(cat local_cpu_info)
}

check_server_cpu(){
    if [ "${ARCH}" == "x86_64" ]; then
        x86_server_cpu_check
    elif [ "${ARCH}" == "x86_64" ]; then
        arm_server_cpu_check
    else
        echo "no support ${ARCH}"
    fi
}

check_cpu_numa(){
    numa_nodes=$(lscpu 2>/dev/null| grep '^NUMA'| head -n 1)
    numa_nodes_num=`echo $numa_nodes|  grep -owE "[0-9]+" | xargs `
    if [ "${CHIP_TYPE}" == 'kunpeng' ]  && [ "${numa_nodes_num}" != "2" ] ;then
        echo -e  "[${CHIP_TYPE}: NOT-OK]: ${numa_nodes}"   > cpu_numa_check
    elif [ "${CHIP_TYPE}" == 'hygon' ]  && [ "${numa_nodes_num}" != "8" ] ;then
        echo -e  "[${CHIP_TYPE}: NOT-OK]: ${numa_nodes}"   > cpu_numa_check
    elif [ "${CHIP_TYPE}" == 'Phytium' ] && [ "${numa_nodes_num}" != "16" ] ;then
        echo -e  "[${CHIP_TYPE}: NOT-OK]: ${numa_nodes}"   > cpu_numa_check
    else
        echo -e  "[${CHIP_TYPE}: OK]: ${numa_nodes}"   > cpu_numa_check
    fi
    echo -e "\"$(cat cpu_numa_check)\"" > local_cpu_numa
    cpu_numa=$(cat local_cpu_numa)
}

check_cpu_state(){
    #pstate
    if [ "${CHIP_TYPE}" == 'Intel' ] ;then
        cpupower_driver=$(cpupower frequency-info|grep -wE '^[ ]+driver:'|awk '{print $2}'|xargs)
        cpupower_Supported=$(cpupower frequency-info|grep -wE '^[ ]+Supported:'|awk '{print $2}'|xargs)
        cpupower_Active=$(cpupower frequency-info|grep -wE '^[ ]+Active:'|awk '{print $2}'|xargs)

        if [ -z "${cpupower_driver}" ]; then
            cpupower_driver="N/A"
        elif [ "${cpupower_driver}" == 'intel_pstate' ]; then
            cpupower_driver="${cpupower_driver}"
        else
            cpupower_driver="${cpupower_driver}"
        fi


        if [ -z "${cpupower_Supported}" ]; then
            cpupower_Supported="N/A"
        elif [ "${cpupower_Supported}" == 'yes' ]; then
            cpupower_Supported="${cpupower_Supported}"
        else
            cpupower_Supported="${cpupower_Supported}"
        fi

        if [ -z "${cpupower_Active}" ]; then
            cpupower_Active="N/A"
        elif [ "${cpupower_Active}" == 'yes' ]; then
            cpupower_Active="${cpupower_Active}"
        else
            cpupower_Active="${cpupower_Active}"
        fi
        pstate_info="driver[${cpupower_driver}]/Supported[${cpupower_Supported}]/Active[${cpupower_Active}]"
    elif [ "${CHIP_TYPE}" == 'hygon' ] ;then
        cpupower_avail=$(cpupower frequency-info | grep -i "available frequency steps: " )
        cpupower_pstate=$(cpupower frequency-info | grep  -iE "Pstate-P" | xargs)
        cpupower_pstate_num=$(cpupower frequency-info | grep  -iE "Pstate-P" | wc -l)
        if [ -n "${cpupower_avail}" ]  && [ ${cpupower_pstate_num} > 1 ] ; then
            pstate_info="is-enabled: [${cpupower_avail} | ${cpupower_pstate}]"
        else
            pstate_info="is-enabled: [disbaled]"
        fi
    elif [ "${CHIP_TYPE}" == 'kunpeng' ] ;then
        cpupower_frequency=$(cpupower frequency-info | grep  "current CPU frequency"  |  grep -i Hz | xargs)
        if [ -z $cpupower_frequency ]; then
             pstate_info="is-enabled: [disbaled]"
        else
             pstate_info="is-enabled: [${cpupower_frequency}]"
        fi
    else
        pstate_info="${CHIP_TYPE} not support pstate."
    fi

    #cstate
    if [ "${CHIP_TYPE}" == 'hygon' ] ; then
        cpu_idle_driver=$( cpupower idle-info | grep "CPUidle driver" | awk -F: '{print $NF}' |xargs)
        idle_state=$(cpupower idle-info | grep "No idle states" |xargs)
        if [ "${cpu_idle_driver}" == 'none' ]  && [[ "${idle_state}" =~ 'No idle states' ]]; then
            cstate_info="${cpu_idle_driver}/${idle_state}"
        else
            cstate_info="${cpu_idle_driver}/${idle_state}"
        fi
    elif [ "${CHIP_TYPE}" == 'Intel' ]; then
        cstate_info=$(cat /sys/devices/system/cpu/cpuidle/current_driver|head -1)
        if [ -z "${cstate_info}" ]; then
            cstate_info="N/A"
        elif [ "${cstate_info}" == 'intel_idle' ]; then
              cstate_info="${cstate_info}"
        else
            cstate_info="${cstate_info}"
        fi
    else
        cstate_info="${CHIP_TYPE} not support cstate."
    fi

    #c1 state
    if [ "${CHIP_TYPE}" == 'Intel' ]; then
        if [ $(cpupower monitor| grep -iw "C6" | wc -l ) != 0 ]; then
            c6_state_count=$(cpupower monitor | awk 'NR>2{print $NF}' | sort| uniq | wc -l)
            if [ $c6_state_count == 1 ]; then
                is_cstate_c1="is-enabled[enabled]"
            else
                is_cstate_c1="is-enabled[disabled]"
            fi
        else
            is_cstate_c1="is-enabled[N/A]"
        fi
    else
        is_cstate_c1="is-enabled[disabled]"
    fi

    ## vt-d state
    if grep -iE 'dmar|smmu|AMD-Vi' /proc/interrupts &>/dev/null; then
        vt_d='open'
    else
        vt_d='close'
    fi
}

check_server_mem(){
    MenT="$(free -h 2>/dev/null|grep '^Mem:'|awk '{print $2}')"
    Slot_Mark=($(dmidecode -t memory|grep -B 1 '^Memory Device'|grep '^Handle'|awk '{print $2}'|sed 's#,##g'))
    echo -e " Locator\tSize\tSpeed\tManufacturer\tPart_Number" > check_mem.txt

    for Handle in ${Slot_Mark[*]};do
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
        echo -e " ${Locator}\t${Size}\t${Speed}\t${Manufacturer}\t${Part_Number}" >> check_mem.txt
    done
    sed -i '/Unknown/d' check_mem.txt
    cat check_mem.txt|column -t > check_mem
    MBN=$(( $(cat $check_mem.txt 2>/dev/null|wc -l) - 1 ))
    mem_total=${MenT}
    sed -i "3i Memory bar Number: ${MBN}" check_mem
    numa_nodes=$(lscpu 2>/dev/null| grep '^NUMA'| head -n 1)
    numa_nodes_num=`echo $numa_nodes|  grep -owE "[0-9]+"`
    first_numa_mem=$(ls /sys/devices/system/node/node0 | grep -iP 'memory\d+' | wc -l)
    numa_mem_check="OK"
    if [ -n "${first_numa_mem}" ] ; then
        for i in `seq 0  $((numa_nodes_num - 1))`;do
            numa_mem=$(ls /sys/devices/system/node/node$i | grep -iP 'memory\d+' | wc -l)
            [ "${numa_mem}" != "${first_numa_mem}" ] && numa_mem_check="NOT-OK"
        done
    fi
    mem_num=$(($(cat check_mem | wc -l) -1))
    echo -e "\"$(cat check_mem)\"" > local_mem_info
    mem_info=$(cat local_mem_info)
}

check_disk_raid(){
    [ "$(uname -p)" != "x86_64" ] && return 0
    echo -e "DISK RAID LEVEL CHECK:" > disk_check_tfile0
    ## H3C ---
    manufacturer=$(dmidecode -t system|grep Manufacturer|grep -wi 'h3c'|wc -l)
    if [ ${manufacturer} -eq 1 ]; then
        ssacli ctrl all show config 2>/dev/null|grep -E 'logicaldrive'|xargs > disk_check_tfile0
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
        done >> disk_check_tfile0
    else
        /opt/MegaRAID/storcli/storcli64 /call/vall show|sed -rn '/^Virtual Drives/,/Cac=/p'|sed -r '/Cac=|^===|^$|^--|Virtual Drives|^DG/d'|awk '{print $2,$9$10}'|column -t 2>/dev/null > disk_check_tfile0
        /opt/MegaRAID/storcli/storcli64 /call/eall/sall show|sed -rn '/^Drive Information/,/EID-Enclosure/p'|sed -r '/EID-Enclosure|^===|^$|^--|Drive Information|^EID/d'|awk '{print "->",$3,$5$6,$8,$12}'|column -t >> disk_check_tfile0

        num=$(cat disk_check_tfile0 2>/dev/null|wc -l)
        if [ ${num} -le 2 ]; then
            echo -e "DISK RAID LEVEL CHECK:" > disk_check_tfile0
            DISK_NUM=($(lsblk -d -n -o NAME|sort -V))
            for i in ${DISK_NUM[*]};do
                rlevel="$(udevadm info -a /dev/${i} 2>/dev/null|grep 'ATTRS{raid_level}=='|awk -F= '{print $NF}'|sed 's/"//g'|xargs)"
                [ -z "${rlevel}" ] && continue
                echo "$i - ${rlevel}"  >> disk_check_tfile0
            done
        fi
    fi
    echo  >> disk_check_tfile0
    cat disk_check_tfile0 > check_disk_raid

    echo -e "\"$(cat check_disk_raid)\"" > local_disk_raid
    disk_raid=$(cat local_disk_raid) 
}

nvme_output(){
    > check_disk_nvme
    NVME_disk=($(ls /sys/class/nvme/ 2>/dev/null))
    for nv in ${NVME_disk[*]};do
        disordered_comparison="$(ls -l /sys/block/${nv}n1|awk '{print $NF}'|xargs dirname|xargs basename)"
        NNN=$(cat /sys/class/nvme/${nv}/device/numa_node 2>/dev/null)
        [ -z ${NNN} ] && NNN=0
        if [ "${nv}" != "${disordered_comparison}" ]; then
            disordered_comparison="${disordered_comparison}"
        fi
        echo -e "dev_name\tnuma_node\tdisordered_comparison"
        echo -e "${nv}\t${NNN}\t${disordered_comparison:-N/A}"
    done|column -t|sort|uniq >> check_disk_nvme
}

check_system_disk(){
    echo -e "System Partition Check:" > check_disk_sys
    sd=$(df -h|awk '$NF=="/" {print $1}'|sed 's/[0-9]//g' 2>/dev/null)
    if [ -e "$sd" ]; then
        lsblk -l ${sd} >> check_disk_sys
    fi

    echo -e "\"$(cat check_disk_sys)\"" > local_disk_sys
    disk_sys=$(cat local_disk_sys)
}

check_disk(){
    all=($(lsblk -d -n -o NAME|sort -V))
    echo -e 'DISK\tSIZE\tDevice_Model\tRotation_Rate\tForm_Factor' > check_disk.txt
    for d in ${all[*]};do
        DSIZE="$(lsblk -d -n -o NAME,SIZE,ROTA 2>/dev/null|grep -w "${d}"|awk '{print $2}')"
        DTYPE="$(smartctl --info /dev/${d} | grep -w "^Rotation Rate:"|awk -F: '{print $NF}'|xargs |sed 's/ /_/g')"
        DModel_Number="$(smartctl --info /dev/${d} | grep -wE "^Device Model:|^Model Number:|Vendor:|Product:"|awk -F: '{print $NF}'|xargs |sed 's/ /_/g')"
        Form_Factor="$(smartctl --info /dev/${d} | grep -w "^Form Factor:"|awk -F: '{print $NF}'|xargs |sed 's/ /_/g')"
        echo -e "${d}\t${DSIZE:-none}\t${DModel_Number:-none}\t${DTYPE:-none}\t${Form_Factor:-none}" >> check_disk.txt
    done
    ## 获取系统盘
    system_disk=$(df -h|grep -w '/'|awk '{print $1}'|sed 's#/dev/##g'|sed 's/[0-9]//g' 2>/dev/null)
    cat check_disk.txt 2>/dev/null|column -t > check_disk
    Disk_Total=${#all[*]}
    System_Disk=${system_disk:-none}

    nvme_num=$(printf '%s\n' ${all[*]}|grep -i 'nvme'|wc -l)
    if [ ${nvme_num} -eq 1 ]; then
        echo -e "NVME NUMA Check: OK" >> check_disk
        nvme_output
    elif [ ${nvme_num} -eq 2 ]; then
        N1=$(cat /sys/class/nvme/*/device/numa_node 2>/dev/null|sort|uniq -c|wc -l)
        if [ ${N1} -eq 2 ]; then
            echo -e "NVME NUMA Check: OK." >> check_disk
        else
            echo -e "NVME NUMA Check: Please check." >> check_disk
        fi
        nvme_output

    elif [ ${nvme_num} -gt 2 ]; then
        N1=$(cat /sys/class/nvme/*/device/numa_node 2>/dev/null|sort|uniq -c|wc -l)
        if [ ${N1} -eq 2 ]; then
            echo -e "NVME NUMA Check: OK." >> check_disk
        else
            echo -e "NVME NUMA Check: Please check." >> check_disk
        fi
        nvme_output
    fi

    check_disk_raid
    check_system_disk

    echo -e "\"$(cat check_disk)\"" > local_check_disk
    disk_info=$(cat local_check_disk)
}

check_network(){
    net_all=($(cat /proc/net/dev|sed '1,2d'|awk -F: '{print $1}'|sed 's#:##g'|sed 's# ##g'|egrep -v 'lo|bond'))
    > check_network
    lshw -C network 2>/dev/null > tmp_check_network.txt
    ## lshw命令将网卡相关信息输出到一个文件中
    for net in ${net_all[*]};do
        bus_info="$(ethtool -i ${net}|grep -w '^bus-info:'|awk '{print $NF}')"
        numa_node="$(cat /sys/class/net/${net}/device/numa_node 2>/dev/null)"
        Vendor="$(grep -A 4 -B 5 -w "${net}" tmp_check_network.txt |grep -w "vendor:"|awk -F: '{print $2}')"
        Vendor=$(echo ${Vendor}|sed 's/ /_/g')
        Product="$(grep -A 4 -B 5 -w "${net}" tmp_check_network.txt |grep -w "product:"|awk -F: '{print $2}')"
        Product=$(echo ${Product}|sed 's/ /_/g')
        Now_Speed="$(ethtool ${net}|grep -w 'Speed:'|awk '{print $NF}')"
        [ "${Now_Speed}" == 'Unknown!' ] && Now_Speed=none
        Net_Speed=$(grep -A 4 -B 5 -w "${net}" tmp_check_network.txt |grep -wE "size:|capacity:"|awk -F: '{print $2}'|head -1)
        Net_Speed=$(echo ${Net_Speed}|sed 's/ /_/g')
            if [ "${Net_Speed:-none}" = "none" ]; then
                Net_Speed="$(printf '%s\n' $(lspci -s ${bus_info} 2>/dev/null|awk -F: '{print $NF}')|egrep 'GbE|Gigabit')"
                if [ "${Net_Speed:-none}" = "none" ]; then
                    TEM=($(ethtool ${net}|egrep 'Half|Full'|egrep '[0-9]'|awk -F: '{print $NF}'))
                    Net_Speed=$(printf '%s\n' ${TEM[*]}|sort|uniq|sed -r 's/[a-Z]|\///g'|sort|uniq|sort -n|tail -1)
                fi
            fi
        Net_mtu="$(ip a show ${net}|awk -F"mtu" '/mtu/{print $2}'|awk '{print $1}'|xargs)"
        echo -e "${bus_info:-none}\t${net}\t${numa_node:-none}\t${Now_Speed:-none}\t${Net_Speed:-none}\t${Net_mtu:-N\A}\t${Vendor:-none}\t${Product:-none}" >> check_network
    done
    cat check_network|column -t > tmp_check_network
    netcard_num=$(echo ${net_all} | wc -l)
    echo -e "\"$(cat tmp_check_network)\"" > local_check_network
    net_info=$(cat local_check_network)
}

check_kvm_intel(){  ## 检查服务器是否开启虚拟化
    judge_num=$(ls /dev/kvm 2>/dev/null|wc -l)

    if [ ${judge_num} -eq 1 ]; then
        kvm_state=opened
        echo -e "kvm intel state is:${kvm_state}" > virtualization_check
    elif [ ${judge_num} -eq 0 ]; then
        kvm_state=closed
        echo -e "kvm intel state is:${kvm_state}" > virtualization_check
    else
        kvm_state=uncertain
        echo -e "kvm intel state is:${kvm_state}" > virtualization_check
    fi
}
check_system(){
    Product_Serial=$(dmidecode -s system-serial-number)
    manufacturer=$(dmidecode -s system-manufacturer | sed "s/,//g")
    product_name=$(dmidecode -s system-product-name)
    Kernel_Version=$(uname -r)

    RPM_SYSTEM_NUM=$(/usr/bin/yum history list 1 2>/dev/null | grep -Ew '^[ ]+1 ' | awk -F "|" '{print $NF}'|xargs)
    RPM_INSTALL_NUM=$(rpm -qa|wc -l 2>/dev/null)

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
    # network
    if [ $(systemctl status network 2>/dev/null|wc -l) != 0 ]; then
        is_enabled=$(systemctl is-enabled network 2>/dev/null)
        is_active=$(systemctl is-active network 2>/dev/null)
        network_state="is-enabled[${is_enabled}]/is-active[${is_active}]"
    else
        network_state='No_service'
    fi
    if [ $(systemctl status NetworkManager 2>/dev/null|wc -l) != 0 ]; then
        is_enabled=$(systemctl is-enabled NetworkManager 2>/dev/null)
        is_active=$(systemctl is-active NetworkManager 2>/dev/null)
        NetworkManager_state="is-enabled[${is_enabled}]/is-active[${is_active}]"
    else
        NetworkManager_state='No_service'
    fi
}
output_file(){
echo -e "${Product_Serial},${host_net},${host_ip},${manufacturer},${product_name},${RPM_SYSTEM_NUM},${RPM_INSTALL_NUM},${Kernel_Version},${BOOT_MODE},${CHAS},${network_state},${NetworkManager_state},${cpu_num},${cpu_info},${cpu_numa},${kvm_state},${vt_d},${Performance_Mode},${pstate_info},${cstate_info},${is_cstate_c1},${disk_raid},${System_Disk},${disk_sys},${disk_info},${mem_total},${mem_num},${mem_info},${netcard_num},${net_info}" >> ${host_ip_file}_check.csv
}
######################start#######################
if [ $(grep -ic centos /etc/os-release | wc -l) -ge 1 ]; then
    OS_VER="centos"
elif [ $(grep -ic ctyunos /etc/os-release | wc -l) -ge 1 ]; then
    OS_VER="ctyunos"
elif [ $(grep -ic kylin /etc/os-release) -ge 1 ]; then
    OS_VER="kylin"
else
    OS_VER="other"
fi

echo "${OS_VER}"

if [ $(lscpu | awk -F':' '$1=="Model name"{print $NF}'|grep -ic 'kunpeng') -ge 1 ] ;then
    CHIP_TYPE="kunpeng"
elif [ $(lscpu | awk -F':' '$1=="Model name"{print $NF}'|grep -ic 'Hygon') -ge 1 ] ;then
    CHIP_TYPE="hygon"
elif [ $(lscpu | awk -F':' '$1=="Vendor ID"{print $NF}'|grep -ic 'Phytium' ) -ge 1 ] ;then
    CHIP_TYPE="Phytium"
elif [ $(lscpu | awk -F':' '$1=="Model name"{print $NF}'|grep -ic 'Intel') -ge 1 ] ;then
    CHIP_TYPE="Intel"
else
    CHIP_TYPE="mismatch"
fi

server_ip=192.168.21.105
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

echo -e "Product_Serial,Network_card,IP,manufacturer,product_name,RPM_System_count,RPM_Install_total,Kernel_Version,System_boot_mode,Character,network,NetworkManager,CPU_NUM,CPU_INFO,CPU_NUMA,kvm-state,Vt-d,Performance_Mode,P-state,C-state,C1-state,Disk_Raid,Disk_Sys,Disk_Sys_Part,Disk_Info,Mem_Total,Mem_Num,Mem_Info,Net_Card_Num,Net_Info" > ${host_ip_file}_check.csv
main(){
    env_tool
    check_server_brand
    check_server_cpu
    check_cpu_numa
    check_cpu_state
    check_kvm_intel
    check_server_mem
    check_disk
    check_network
    check_kvm_intel
    check_system
    output_file

    env_tool_uninstall
}

main
exit
