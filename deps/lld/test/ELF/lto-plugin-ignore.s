# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: ld.lld %t -plugin-opt=/foo/bar -plugin-opt=-fresolution=zed \
# RUN:   -plugin-opt=-pass-through=-lgcc -plugin-opt=-function-sections \
# RUN:   -plugin-opt=-data-sections -plugin-opt=thinlto -o /dev/null

# RUN: not ld.lld %t -plugin-opt=-abc -plugin-opt=-xyz 2>&1 | FileCheck %s
# CHECK: error: --plugin-opt: ld.lld{{.*}}: Unknown command line argument '-abc'
# CHECK: error: --plugin-opt: ld.lld{{.*}}: Unknown command line argument '-xyz'
