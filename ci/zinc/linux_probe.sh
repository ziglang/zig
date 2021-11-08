#!/bin/sh

. ./ci/zinc/linux_base.sh

# Probe CPU/brand details.
echo "lscpu:"
(lscpu | sed 's,^,  : ,') 1>&2

# Explicit exit helps show last command duration.
exit
