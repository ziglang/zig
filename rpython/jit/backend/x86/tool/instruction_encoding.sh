#!/bin/bash

# Tool to quickly see how the GNU assembler encodes an instruction
# (AT&T syntax only for now)

# Command line options are passed on to "as"

# Provide readline if available
if which rlwrap > /dev/null && [ "$INSIDE_RLWRAP" = "" ]; then
    export INSIDE_RLWRAP=1
    exec rlwrap "$0" "$@"
fi

while :; do
    echo -n '? '
    read instruction
    echo "$instruction" | as "$@"
    objdump --disassemble ./a.out | grep '^ *[0-9a-f]\+:'
    rm -f ./a.out
done
