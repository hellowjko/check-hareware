#!/bin/bash
#
echo -e "kvm-state\tVt-d\tMAX_PEF_state\tp-state\tc-state" > cpu_state
# cpu number
cpu_num=`cat /proc/cpuinfo | grep "^physical id" | sort | uniq | wc -l`
# numa
numa=`lscpu | grep "NUMA"`
# cpu p-stats c-stats
cpupower_driver=$(cpupower frequency-info|grep -wE '^[ ]+driver:'|awk '{print $2}'|xargs)
cpupower_Supported=$(cpupower frequency-info|grep -wE '^[ ]+Supported:'|awk '{print $2}'|xargs)
cpupower_Active=$(cpupower frequency-info|grep -wE '^[ ]+Active:'|awk '{print $2}'|xargs)

if [ -z "${cpupower_driver}" ]; then
    cpupower_driver="none"
elif [ "${cpupower_driver}" == 'intel_pstate' ]; then
    cpupower_driver="${cpupower_driver}"
else
    cpupower_driver="${cpupower_driver}"
fi
if [ -z "${cpupower_Supported}" ]; then
    cpupower_Supported="none"
elif [ "${cpupower_Supported}" == 'yes' ]; then
    cpupower_Supported="${cpupower_Supported}"
else
    cpupower_Supported="${cpupower_Supported}"
fi
if [ -z "${cpupower_Active}" ]; then
    cpupower_Active="none"
elif [ "${cpupower_Active}" == 'yes' ]; then
    cpupower_Active="${cpupower_Active}"
else
    cpupower_Active="${cpupower_Active}"
fi

if [ -f /sys/devices/system/cpu/cpuidle/current_driver ]; then
    ctstate_state=$(cat /sys/devices/system/cpu/cpuidle/current_driver|head -1)
    if [ -z "${ctstate_state}" ]; then
        ctstate_state="N/A"
    elif [ "${ctstate_state}" == 'intel_idle' ]; then
        ctstate_state="${ctstate_state}"
    else
        ctstate_state="${ctstate_state}"
    fi
else
    ctstate_state="no current_driver file."
fi
# vt-d state
if grep -iE 'dmar|smmu|AMD-Vi' /proc/interrupts &>/dev/null; then
    vt_d='open'
else
    vt_d='close'
fi

judge_num=$(ls /dev/kvm 2>/dev/null|wc -l)
if [ ${judge_num} -eq 1 ]; then
    kvm_state=opened
    echo -e "kvm intel state is ${kvm_state}" > /dev/null
elif [ ${judge_num} -eq 0 ]; then
    kvm_state=closed
    echo -e "kvm intel state is ${kvm_state}" > /dev/null
else
    kvm_state=uncertain
    echo -e "kvm intel state is ${kvm_state}" > /dev/null
fi

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

echo -e "${kvm_state}\t${vt_d}\t${MAX_PEF_state}\t${cpupower_driver}/${cpupower_Supported}/${cpupower_Active}\t${ctstate_state}" > cpu_state