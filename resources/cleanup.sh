#!/bin/sh

set -exu

minimize_disk() {
  dd if=/dev/zero of=/EMPTY bs=1M || :
  rm /EMPTY
}

minimize_swap() {
  local swap_device=$(swapctl -l | awk '!/^Device/ { print $1 }')
  swapctl -d "$swap_device"
  dd if=/dev/zero of="$swap_device" bs=1M || :
}

minimize_disk
minimize_swap
