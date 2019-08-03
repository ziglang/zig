# RUN: echo "\"" > %/terr1.script
# RUN: not ld.lld --vs-diagnostics --version-script %/terr1.script 2>&1 | \
# RUN: FileCheck %s -DSCRIPT="%/terr1.script"

# CHECK: [[SCRIPT]](1): error: [[SCRIPT]]:1: unclosed quote
