#! /usr/bin/bash
# depends: iproute2 awk sipcalc tcpdump
set -e

listening_dev=$1
shift
ipv6_prefix=$@
rt_table=lanhosts

irtd='/etc/iproute2'
irtc='/etc/iproute2/rt_tables'
irtt='/usr/lib/iproute2/rt_tables'

# wait device create
if [ -n "$UNTIL_DEV_EXIST" ]; then
  until [ -L "/sys/class/net/$listening_dev" ]; do
    echo "waiting '$listening_dev' create..."
    sleep 1
  done
else
  if [ ! -L "/sys/class/net/$listening_dev" ]; then
    echo "device '$listening_dev' doesn't exist"
    exit 1
  fi
fi

# getting ipv6 prefixes
if [ -z "$ipv6_prefix" ]; then
  expr_prefix=
  while :; do
    ipv6_addrs=$(ip -6 addr show dev $listening_dev | awk '/inet6/ && !/fe80::/ { print $2 }')
    [ -z "$ipv6_addrs" ] || break
    echo 'Failed to get ipv6 prefix, sleep 5sec...'
    sleep 5
  done

  ipv6_prefixes=$(sipcalc $ipv6_addrs | awk '/Subnet prefix/ { if (!seen[$5]++) print $5 }')
fi

for ipv6_prefix in $ipv6_prefixes; do
  if [ -z "$expr_prefix" ]; then
    expr_prefix="src net $ipv6_prefix"
  else
    expr_prefix="$expr_prefix or src net $ipv6_prefix"
  fi
done

# creating route table
if [ ! -d $irtd ]; then
  mkdir $irtd
fi
if [ ! -f $irtc ]; then
  [ -f $irtt ] && cp $irtt $irtc || touch $irtc
fi

# add route table 'lanhost'
awk 'BEGIN { maxid=1 }
  /'"$rt_table"'/ { found = 1; exit}
  /^[0-9]+/ { if($1 >= maxid) maxid=$1+1 }
END { if(!found) print maxid " '"$rt_table"'" }' $irtc >> $irtc

# add route rule per prefix, make them use the $rt_table
#for ipv6_prefix in $ipv6_prefixes; do
#  if [ -z "$(ip -6 rule list to "$ipv6_prefix" lookup $rt_table)" ]; then
#    ip -6 rule add to "$ipv6_prefix" lookup $rt_table
#  fi
#done
if [ -z "$(ip -6 rule list lookup $rt_table)" ]; then
  ip -6 rule add lookup $rt_table
fi


ip -6 route flush dev "$listening_dev" table $rt_table || :
echo "listening $listening_dev with prefixes $(echo $ipv6_prefixes)"

awk_expr='{split($3, arr, "."); if (!seen[arr[1]]++) print arr[1]}'

tcpdump -i "$listening_dev" -n -l -Qin $expr_prefix 2>/dev/null |\
stdbuf -oL awk "$awk_expr" |\
while read addr; do
  echo "discover new address '$addr' on '$listening_dev'"
  ip -6 route add $addr dev "$listening_dev" table $rt_table
#  if [ -z "$(ip -6 rule list to $addr/128 lookup $rt_table)" ]; then
#    ip -6 rule add to $addr lookup $rt_table
#  fi
done &

# get tcpdump pid
# tcpdump must be first command, otherwise use {print $1}
tcpdump_pid=$(jobs -l | awk '/tcpdump/ {print $2}')
while :; do
  kill -STOP $tcpdump_pid || break; sleep 5
  kill -CONT $tcpdump_pid || break; sleep 1
done

