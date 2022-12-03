#!/bin/bash
if [[ $1 == --enable-fixed-behavior ]]; then
    declare -A offsets
    git g -n stage2_c test/behavior | while read -r match; do
        printf '\e[36mTrying to enable... %s\e[m\n' "$match"
        file=`cut -d: -f1 <<<"$match"`
        offset=${offsets[$file]:=0}
        let line=`cut -d: -f2 <<<"$match"`-$offset
        contents=`cut -d: -f3- <<<"$match"`
        sed --in-place "${line}d" "$file"
        if zigd test -Itest test/behavior.zig -fno-stage1 -fno-LLVM -ofmt=c; then
            printf '\e[32mTest was enabled! :)\e[m\n'
            let offsets[$file]+=1
        else
            printf '\e[31mTest kept disabled. :(\e[m\n'
            sed --in-place "${line}i\\
$contents" "$file"
        fi
    done
fi
