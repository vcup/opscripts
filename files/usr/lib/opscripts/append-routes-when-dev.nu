#! /usr/bin/nu
# read record from '/etc/opscripts/append-routes-when-dev.nuon'
# depends: nushell iproute2
use std log

let fact: record = open '/etc/opscripts/append-routes-when-dev.nuon'

def main []: nothing -> nothing {
  $fact | transpose a b | each {
    let dev = $in.a
    let routerule = $in.b
    while (ip link | lines | all { $in !~ $'($dev):' }) { sleep 1sec }

    ip route add $routerule
  }

  return
}
