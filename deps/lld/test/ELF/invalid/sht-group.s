## sht-group.elf contains SHT_GROUP section with invalid sh_info.
# RUN: not ld.lld %p/Inputs/sht-group.elf -o /dev/null 2>&1 | FileCheck %s
# CHECK: invalid symbol index
