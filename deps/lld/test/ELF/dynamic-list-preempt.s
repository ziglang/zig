# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "{ foo; zed; };" > %t.list
# RUN: echo "{ global: foo; bar; local: *; };" > %t.vers
# RUN: ld.lld --hash-style=sysv -fatal-warnings -dynamic-list %t.list -version-script %t.vers -shared %t.o -o %t.so
# RUN: llvm-readobj -r %t.so | FileCheck --check-prefix=RELOCS %s
# RUN: llvm-readobj -dyn-symbols  %t.so | FileCheck --check-prefix=DYNSYMS %s

# RELOCS:      Relocations [
# RELOCS-NEXT:   Section ({{.*}}) .rela.plt {
# RELOCS-NEXT:     R_X86_64_JUMP_SLOT foo 0x0
# RELOCS-NEXT:     R_X86_64_JUMP_SLOT ext 0x0
# RELOCS-NEXT:   }
# RELOCS-NEXT: ]

# DYNSYMS:      DynamicSymbols [
# DYNSYMS-NEXT:   Symbol {
# DYNSYMS-NEXT:     Name:
# DYNSYMS-NEXT:     Value: 0x0
# DYNSYMS-NEXT:     Size: 0
# DYNSYMS-NEXT:     Binding: Local
# DYNSYMS-NEXT:     Type: None
# DYNSYMS-NEXT:     Other: 0
# DYNSYMS-NEXT:     Section: Undefined
# DYNSYMS-NEXT:   }
# DYNSYMS-NEXT:   Symbol {
# DYNSYMS-NEXT:     Name: bar
# DYNSYMS-NEXT:     Value:
# DYNSYMS-NEXT:     Size:
# DYNSYMS-NEXT:     Binding: Global
# DYNSYMS-NEXT:     Type:
# DYNSYMS-NEXT:     Other:
# DYNSYMS-NEXT:     Section:
# DYNSYMS-NEXT:   }
# DYNSYMS-NEXT:   Symbol {
# DYNSYMS-NEXT:     Name: ext
# DYNSYMS-NEXT:     Value:
# DYNSYMS-NEXT:     Size:
# DYNSYMS-NEXT:     Binding: Global
# DYNSYMS-NEXT:     Type:
# DYNSYMS-NEXT:     Other:
# DYNSYMS-NEXT:     Section:
# DYNSYMS-NEXT:   }
# DYNSYMS-NEXT:   Symbol {
# DYNSYMS-NEXT:     Name: foo
# DYNSYMS-NEXT:     Value:
# DYNSYMS-NEXT:     Size:
# DYNSYMS-NEXT:     Binding: Global
# DYNSYMS-NEXT:     Type:
# DYNSYMS-NEXT:     Other:
# DYNSYMS-NEXT:     Section:
# DYNSYMS-NEXT:   }
# DYNSYMS-NEXT: ]

        .globl foo
foo:
        ret

        .globl bar
bar:
        ret

        .globl baz
baz:
        ret

        .globl zed
zed:
        ret

        call   foo@PLT
        call   bar@PLT
        call   baz@PLT
        call   zed@PLT
        call   ext@PLT
