#!/bin/sh
objdump -D -M reg-names-std --architecture=arm --target=binary ${1}
