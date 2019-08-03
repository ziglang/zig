# REQUIRES: x86

# RUN: llvm-mc -triple=i686-windows-gnu %s -filetype=obj -o %t.obj

# RUN: lld-link -lldmingw -exclude-all-symbols -dll -out:%t.dll -entry:DllMainCRTStartup@12 %t.obj
# RUN: llvm-readobj --coff-exports %t.dll | FileCheck %s -check-prefix=NO-EXPORTS

# NO-EXPORTS-NOT: Name:

.global _foobar
.global _DllMainCRTStartup@12
.global _dataSym
.text
_DllMainCRTStartup@12:
  ret
_foobar:
  ret
.data
_dataSym:
  .int 4

# Test specifying -exclude-all-symbols, on an object file that contains
# dllexport directive for some of the symbols. In this case, the dllexported
# symbols are still exported.

# RUN: yaml2obj < %p/Inputs/export.yaml > %t.obj
#
# RUN: lld-link -safeseh:no -out:%t.dll -dll %t.obj -lldmingw -exclude-all-symbols -output-def:%t.def
# RUN: llvm-readobj --coff-exports %t.dll | FileCheck -check-prefix=DLLEXPORT %s

# DLLEXPORT: Name: exportfn3
