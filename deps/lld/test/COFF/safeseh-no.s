# REQUIRES: x86
# RUN: llvm-mc -triple i686-windows-msvc %s -filetype=obj -o %t.obj
# RUN: not lld-link %t.obj -safeseh -out:%t.exe -entry:main 2>&1 | FileCheck %s --check-prefix=ERROR
# safe seh should be on by default.
# RUN: not lld-link %t.obj -out:%t.exe -entry:main 2>&1 | FileCheck %s --check-prefix=ERROR
# RUN: lld-link %t.obj -safeseh:no -out:%t.exe -entry:main
# RUN: llvm-readobj --file-headers --coff-load-config %t.exe | FileCheck %s
# -lldmingw should also turn off safeseh by default.
# RUN: lld-link %t.obj -lldmingw -out:%t.exe -entry:main
# RUN: llvm-readobj --file-headers --coff-load-config %t.exe | FileCheck %s

# ERROR: /safeseh: {{.*}}safeseh-no.s.tmp.obj is not compatible with SEH

# CHECK: Characteristics [
# CHECK-NOT:   IMAGE_DLL_CHARACTERISTICS_NO_SEH
# CHECK: ]
# CHECK: LoadConfig [
# CHECK:   Size: 0x48
# CHECK:   SEHandlerTable: 0x0
# CHECK:   SEHandlerCount: 0
# CHECK: ]
# CHECK-NOT: SEHTable


# Explicitly mark the object as not having safeseh. LLD should error unless
# -safeseh:no is passed.
        .def     @feat.00; .scl    3; .type   0; .endef
        .globl  @feat.00
@feat.00 = 0

        .def     _main;
        .scl    2;
        .type   32;
        .endef
        .section        .text,"xr",one_only,_main
        .globl  _main
_main:
        movl $42, %eax
        ret

# Add a handler to create an .sxdata section, which -safeseh:no should ignore.
        .def     _my_handler; .scl    3; .type   32;
        .endef
        .section        .text,"xr",one_only,_my_handler
_my_handler:
        ret
.safeseh _my_handler


        .section .rdata,"dr"
.globl __load_config_used
__load_config_used:
        .long 72
        .fill 60, 1, 0
        .long ___safe_se_handler_table
        .long ___safe_se_handler_count

