# REQUIRES: x86
# RUN: llvm-mc -triple i686-windows-msvc %s -filetype=obj -o %t.obj
# RUN: lld-link %t.obj -safeseh -out:%t.exe -entry:main
# RUN: llvm-readobj -file-headers %t.exe | FileCheck %s

# This object lacks a _load_config_used global, so we set
# IMAGE_DLL_CHARACTERISTICS_NO_SEH even though there is an exception handler.
# This is a more secure default. If someone wants to use a CRT without a load
# config and they want to use 32-bit SEH, they will need to provide a
# safeseh-compatible load config.

# CHECK-LABEL: Characteristics [
# CHECK:   IMAGE_DLL_CHARACTERISTICS_NO_SEH
# CHECK: ]

# CHECK-LABEL:  DataDirectory {
# CHECK:    LoadConfigTableRVA: 0x0
# CHECK:    LoadConfigTableSize: 0x0
# CHECK:  }

# CHECK-NOT: LoadConfig
# CHECK-NOT: SEHTable

        .def     @feat.00;
        .scl    3;
        .type   0;
        .endef
        .globl  @feat.00
@feat.00 = 1

        .text
        .def     _main; .scl    2; .type   32; .endef
        .globl  _main
_main:
        pushl $_my_handler
        movl $42, %eax
        popl %ecx
        ret

        .def     _my_handler; .scl    3; .type   32; .endef
_my_handler:
        ret

.safeseh _my_handler
