## dynamic-section-sh_size.elf has incorrect sh_size of dynamic section.
# RUN: not ld.lld %p/Inputs/dynamic-section-sh_size.elf -o /dev/null 2>&1 | \
# RUN:   FileCheck %s
# CHECK: error: {{.*}}: invalid sh_entsize
