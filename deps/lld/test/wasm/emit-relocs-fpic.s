# RUN: llvm-mc -triple=wasm32-unknown-unknown -filetype=obj -o %t.o < %s
# RUN: llc --relocation-model=pic -filetype=obj %p/Inputs/ret32.ll -o %t.ret32.o
# RUN: wasm-ld -pie --export-all --no-gc-sections --no-entry --emit-relocs -o %t.wasm %t.o %t.ret32.o
# RUN: obj2yaml %t.wasm | FileCheck %s

load_hidden_data:
    .functype   load_hidden_data () -> (i32)
    i32.const   .L.hidden_data@MBREL
    end_function

.section .rodata.hidden_data,"",@
.L.hidden_data:
    .int8 100
    .size .L.hidden_data, 1

# We just want to make sure that processing this relocation doesn't
# cause corrupt output. We get most of the way there, by just checking
# that obj2yaml doesn't fail. Here we just make sure that the relocation
# survived the trip.
# CHECK: R_WASM_MEMORY_ADDR_REL_SLEB
