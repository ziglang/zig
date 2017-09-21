// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t
//
// RUN: ld.lld %t -shared -o %tout.so
// RUN: llvm-readobj -dyn-symbols %tout.so | FileCheck -check-prefix=GNU %s
//
// RUN: ld.lld %t -shared -o %tout.so --no-gnu-unique
// RUN: llvm-readobj -dyn-symbols %tout.so | FileCheck -check-prefix=NO %s

// Check that STB_GNU_UNIQUE is treated as a global and ends up in the dynamic
// symbol table as STB_GNU_UNIQUE.

.global _start
.text
_start:

.data
.type symb, @gnu_unique_object
symb:

# GNU:        Name: symb@
# GNU-NEXT:   Value:
# GNU-NEXT:   Size: 0
# GNU-NEXT:   Binding: Unique
# GNU-NEXT:   Type: Object
# GNU-NEXT:   Other: 0
# GNU-NEXT:   Section: .data
# GNU-NEXT: }

# NO:        Name: symb@
# NO-NEXT:   Value:
# NO-NEXT:   Size: 0
# NO-NEXT:   Binding: Global
# NO-NEXT:   Type: Object
# NO-NEXT:   Other: 0
# NO-NEXT:   Section: .data
# NO-NEXT: }
