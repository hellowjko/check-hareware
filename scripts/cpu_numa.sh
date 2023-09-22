#!/bin/bash
# numa
numa=`lscpu | grep "NUMA" | column -t`
echo -e "\"${numa}\"" | column -t > cpu_numa
