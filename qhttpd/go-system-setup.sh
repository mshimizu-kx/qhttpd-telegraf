#!/bin/bash
#
# You may need to run some of this on the docker host (not container)
#

export TZ=Etc/UTC

echo tsc >/sys/devices/system/clocksource/clocksource0/current_clocksource

echo 0 | sudo tee /proc/sys/kernel/randomize_va_space

echo 1000000 >/proc/sys/fs/aio-max-nr
echo 2000000 >/proc/sys/fs/nr_open
ulimit -n 2000000

echo always > /sys/kernel/mm/transparent_hugepage/enabled

echo 0 > /proc/sys/vm/zone_reclaim_mode

echo 1 > /proc/sys/net/ipv4/tcp_tw_recycle
sysctl -w net.ipv4.ip_local_port_range="500   65535"
sysctl -w net.ipv4.tcp_mem="383865   511820   2303190"
sysctl -w net.ipv4.tcp_rmem="1024   4096   16384"
sysctl -w net.ipv4.tcp_wmem="1024   4096   16384"
sysctl -w net.ipv4.tcp_moderate_rcvbuf="0"
sysctl -w net.ipv4.ip_local_port_range='1024 65535'
sysctl -w net.ipv4.tcp_syncookies=1
sysctl -w net.ipv4.tcp_tw_reuse=1
sysctl -w net.ipv4.tcp_fin_timeout=30
sysctl -w net.ipv4.tcp_slow_start_after_idle=0

pkill irqbalance

# egrep -c processor /proc/cpuinfo
# echo fff >/proc/irq/default_smp_affinity

#grep eth0 /proc/interrupts 
#echo "1" >/proc/irq/77/smp_affinity
#echo "2" >/proc/irq/78/smp_affinity
#echo "4" >/proc/irq/79/smp_affinity
#echo "8" >/proc/irq/80/smp_affinity
#echo "10" >/proc/irq/81/smp_affinity
#echo "20" >/proc/irq/82/smp_affinity
#echo "40" >/proc/irq/83/smp_affinity
#echo "80" >/proc/irq/84/smp_affinity
#echo "100" >/proc/irq/85/smp_affinity
#echo "200" >/proc/irq/86/smp_affinity
#echo "400" >/proc/irq/87/smp_affinity
#echo "800" >/proc/irq/88/smp_affinity
#echo "1000" >/proc/irq/89/smp_affinity
#echo "2000" >/proc/irq/90/smp_affinity
#echo "4000" >/proc/irq/91/smp_affinity
#echo "8000" >/proc/irq/92/smp_affinity
#echo "10000" >/proc/irq/93/smp_affinity
#echo "20000" >/proc/irq/94/smp_affinity
#echo "40000" >/proc/irq/95/smp_affinity
#echo "80000" >/proc/irq/96/smp_affinity
#echo "100000" >/proc/irq/97/smp_affinity
#echo "200000" >/proc/irq/98/smp_affinity
#echo "400000" >/proc/irq/99/smp_affinity
#echo "800000" >/proc/irq/100/smp_affinity

