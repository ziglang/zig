# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t£.o

# RUN: ld.lld -o %t.elf %t£.o --format=binary %t£.o
# RUN: llvm-readobj -symbols %t.elf | FileCheck %s

# CHECK: Name: _binary_{{[a-zA-Z0-9_]+}}test_ELF_Output_format_binary_non_ascii_s_tmp___o_start
# CHECK: Name: _binary_{{[a-zA-Z0-9_]+}}test_ELF_Output_format_binary_non_ascii_s_tmp___o_end
# CHECK: Name: _binary_{{[a-zA-Z0-9_]+}}test_ELF_Output_format_binary_non_ascii_s_tmp___o_size

.text
.align 4
.globl _start
_start:
    nop
