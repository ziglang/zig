# REQUIRES: x86
# RUN: rm -rf %t && mkdir -p %t && cd %t
# RUN: llvm-mc -filetype=obj -triple=i686-windows-msvc %s -o foo.obj
# RUN: llc %S/Inputs/bar.ll -filetype=obj -mtriple=i686-windows-msvc -o bar.obj
# RUN: llvm-lib bar.obj -out:bar.lib
# RUN: lld-link -debug -pdb:foo.pdb foo.obj bar.lib -out:foo.exe -entry:main
# RUN: llvm-pdbutil dump -modules %t/foo.pdb | FileCheck %s

# Make sure that the PDB has module descriptors. foo.obj and bar.lib should be
# absolute paths, and bar.obj should be the relative path passed to llvm-lib.

# CHECK:                               Modules
# CHECK-NEXT: ============================================================
# CHECK-NEXT:   Mod 0000 | `{{.*pdb-lib.s.tmp[/\\]foo.obj}}`:
# CHECK-NEXT:              Obj: `{{.*pdb-lib.s.tmp[/\\]foo.obj}}`:
# CHECK-NEXT:              debug stream: 9, # files: 0, has ec info: false
# CHECK-NEXT:              pdb file ni: 0 ``, src file ni: 0 ``
# CHECK-NEXT:   Mod 0001 | `bar.obj`:
# CHECK-NEXT:              Obj: `{{.*pdb-lib.s.tmp[/\\]bar.lib}}`:
# CHECK-NEXT:              debug stream: 10, # files: 0, has ec info: false
# CHECK-NEXT:              pdb file ni: 0 ``, src file ni: 0 ``
# CHECK-NEXT:   Mod 0002 | `* Linker *`:
# CHECK-NEXT:              Obj: ``:
# CHECK-NEXT:              debug stream: 11, # files: 0, has ec info: false
# CHECK-NEXT:              pdb file ni: 1 `{{.*foo.pdb}}`, src file ni: 0 ``

        .def     _main;
        .scl    2;
        .type   32;
        .endef
        .globl  _main
_main:
        calll _bar
        xor %eax, %eax
        retl

