# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: ld.lld %t -plugin-opt=/foo/bar -plugin-opt=-fresolution=zed \
# RUN:   -plugin-opt=-pass-through=-lgcc -plugin-opt=-function-sections \
# RUN:   -plugin-opt=-data-sections -o /dev/null

# RUN: not ld.lld %t -plugin-opt=-data-sectionssss \
# RUN:   -plugin-opt=-function-sectionsss 2>&1 | FileCheck %s
# CHECK: unknown option: -data-sectionsss
# CHECK: unknown option: -function-sectionsss
