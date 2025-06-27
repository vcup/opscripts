#! /usr/bin/sh
# /usr/local/bin/mdns-ifonly.sh

set -e
ifnames_file='/etc/opscripts/mdns-ifonly.ifnames'
if [ ! -f "$ifnames_file" ]; then
  echo "$ifnames_file"' not exist, creating it.' >& 2
  touch "$ifnames_file"
fi
ifnames=$(cat "$ifnames_file")

if [ -n "$UNTIL_IF_EXISTS" ]; then
  for ifname in $ifnames; do
    until [ -L "/sys/class/net/$ifname" ]; do
      echo "waiting '$ifname' create..."
      sleep 15
    done
  done
fi

if [ "$(resolvectl mdns | head -n1)" != 'Global: yes' ]; then
  echo 'mDNS was not enable! set `MulticastDNS=yes` in your /etc/systemd/resolved.conf and restart it!' >& 2
  exit 1
fi

for ((i=2; i > 0;i++)); do
  resolvectl mdns $i off 2> /dev/null || break
done

for ifname in $ifnames; do
  resolvectl mdns $ifname on
done
