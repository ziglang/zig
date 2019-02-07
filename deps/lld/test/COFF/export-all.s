# REQUIRES: x86

# RUN: llvm-mc -triple=i686-windows-gnu %s -filetype=obj -o %t.obj

# RUN: lld-link -lldmingw -dll -out:%t.dll -entry:DllMainCRTStartup@12 %t.obj -implib:%t.lib
# RUN: llvm-readobj -coff-exports %t.dll | grep Name: | FileCheck %s
# RUN: llvm-readobj %t.lib | FileCheck -check-prefix=IMPLIB %s

# CHECK: Name:
# CHECK-NEXT: Name: dataSym
# CHECK-NEXT: Name: foobar
# CHECK-EMPTY:

# IMPLIB: Symbol: __imp__dataSym
# IMPLIB-NOT: Symbol: _dataSym
# IMPLIB: Symbol: __imp__foobar
# IMPLIB: Symbol: _foobar

.global _foobar
.global _DllMainCRTStartup@12
.global _dataSym
.global _unexported
.global __imp__unexported
.global .refptr._foobar
.text
_DllMainCRTStartup@12:
  ret
_foobar:
  ret
_unexported:
  ret
.data
_dataSym:
  .int 4
__imp__unexported:
  .int _unexported
.refptr._foobar:
  .int _foobar

# Test specifying -export-all-symbols, on an object file that contains
# dllexport directive for some of the symbols.

# RUN: yaml2obj < %p/Inputs/export.yaml > %t.obj
#
# RUN: lld-link -out:%t.dll -dll %t.obj -lldmingw -export-all-symbols -output-def:%t.def
# RUN: llvm-readobj -coff-exports %t.dll | FileCheck -check-prefix=CHECK2 %s
# RUN: cat %t.def | FileCheck -check-prefix=CHECK2-DEF %s

# Note, this will actually export _DllMainCRTStartup as well, since
# it uses the standard spelling in this object file, not the MinGW one.

# CHECK2: Name: exportfn1
# CHECK2: Name: exportfn2
# CHECK2: Name: exportfn3

# CHECK2-DEF: EXPORTS
# CHECK2-DEF: exportfn1 @3
# CHECK2-DEF: exportfn2 @4
# CHECK2-DEF: exportfn3 @5

# Test ignoring certain object files and libs.

# RUN: echo -e ".global foobar\n.global DllMainCRTStartup\n.text\nDllMainCRTStartup:\nret\nfoobar:\ncall mingwfunc\ncall crtfunc\nret\n" > %t.main.s
# RUN: llvm-mc -triple=x86_64-windows-gnu %t.main.s -filetype=obj -o %t.main.obj
# RUN: mkdir -p %T/libs
# RUN: echo -e ".global mingwfunc\n.text\nmingwfunc:\nret\n" > %T/libs/mingwfunc.s
# RUN: llvm-mc -triple=x86_64-windows-gnu %T/libs/mingwfunc.s -filetype=obj -o %T/libs/mingwfunc.o
# RUN: rm -f %T/libs/libmingwex.a
# RUN: llvm-ar rcs %T/libs/libmingwex.a %T/libs/mingwfunc.o
# RUN: echo -e ".global crtfunc\n.text\ncrtfunc:\nret\n" > %T/libs/crtfunc.s
# RUN: llvm-mc -triple=x86_64-windows-gnu %T/libs/crtfunc.s -filetype=obj -o %T/libs/crt2.o
# RUN: lld-link -out:%t.dll -dll -entry:DllMainCRTStartup %t.main.obj -lldmingw %T/libs/crt2.o %T/libs/libmingwex.a -output-def:%t.def
# RUN: echo "EOF" >> %t.def
# RUN: cat %t.def | FileCheck -check-prefix=CHECK-EXCLUDE %s

# CHECK-EXCLUDE: EXPORTS
# CHECK-EXCLUDE-NEXT: foobar @1
# CHECK-EXCLUDE-NEXT: EOF

# Test that libraries included with -wholearchive: are autoexported, even if
# they are in a library that otherwise normally would be excluded.

# RUN: lld-link -out:%t.dll -dll -entry:DllMainCRTStartup %t.main.obj -lldmingw %T/libs/crt2.o -wholearchive:%T/libs/libmingwex.a -output-def:%t.def
# RUN: echo "EOF" >> %t.def
# RUN: cat %t.def | FileCheck -check-prefix=CHECK-WHOLEARCHIVE %s

# CHECK-WHOLEARCHIVE: EXPORTS
# CHECK-WHOLEARCHIVE-NEXT: foobar @1
# CHECK-WHOLEARCHIVE-NEXT: mingwfunc @2
# CHECK-WHOLEARCHIVE-NEXT: EOF

# Test that we handle import libraries together with -opt:noref.

# RUN: yaml2obj < %p/Inputs/hello32.yaml > %t.obj
# RUN: lld-link -lldmingw -dll -out:%t.dll -entry:main@0 %t.obj -implib:%t.lib -opt:noref %p/Inputs/std32.lib -output-def:%t.def
# RUN: echo "EOF" >> %t.def
# RUN: cat %t.def | FileCheck -check-prefix=CHECK-IMPLIB %s

# CHECK-IMPLIB: EXPORTS
# CHECK-IMPLIB-NEXT: main@0 @1
# CHECK-IMPLIB-NEXT: EOF
