#!/bin/bash
# 1 Hz nvidia-smi sampler -> CSV: epoch,power_w,util_pct,mem_mib,sm_mhz,mem_mhz,temp_c
# usage: power_sampler.sh <out.csv>   (runs until killed)
OUT=$1
while true; do
  t=$(date +%s.%N | cut -c1-14)
  s=$(nvidia-smi --query-gpu=power.draw,utilization.gpu,memory.used,clocks.sm,clocks.mem,temperature.gpu --format=csv,noheader,nounits -i 0 | tr -d ' ')
  echo "$t,$s" >> "$OUT"
  sleep 1
done
