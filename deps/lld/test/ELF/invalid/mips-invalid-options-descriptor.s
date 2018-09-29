## mips-invalid-options-descriptor.elf has option descriptor in
## .MIPS.options with size of zero.
# RUN: not ld.lld %p/Inputs/mips-invalid-options-descriptor.elf -o /dev/null 2>&1 | \
# RUN:   FileCheck %s
# CHECK: error: {{.*}}: invalid section offset
