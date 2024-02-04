#!/bin/bash

function printInfo()
{
    echo -e "======================== $1 ========================="
}

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi
exec > i915_info.log 2>&1
set -x
# Display info
printInfo "print display info"
find  /sys/kernel/debug/ -name i915_display_info | xargs cat

# i915 capability
printInfo "print i195 capbility"
find  /sys/kernel/debug/ -name i915_capabilities | xargs cat

# DDI
printInfo "print_ddi_port"
dmesg | grep 'print_ddi_port'

# MST
printInfo "print dp mst info"
find  /sys/kernel/debug/ -name i915_dp_mst_info | xargs cat
dmesg | grep 'intel_dp_detect'


# mode set
printInfo "print mode set"
dmesg | grep 'drm_mode_debug_printmodeline'
dmesg | grep 'drm_client_modeset_probe'


# HBR
printInfo "print dp rates"
dmesg | grep 'intel_dp_print_rates'

# DSC
printInfo "DSC Info"
dmesg | grep 'drm:intel_dp_get_dsc_sink_cap [i915]]'
find  /sys/kernel/debug/ -name i915_dsc_fec_support | xargs cat

# PSR
printInfo "PSR Info"
cat /sys/kernel/debug/dri/0/i915_edp_psr_status

