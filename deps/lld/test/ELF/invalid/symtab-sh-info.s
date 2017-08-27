## sh_info contains zero value. First entry in a symbol table is always completely zeroed,
## so sh_info should be at least 1 in a valid ELF.
# RUN: not ld.lld %p/Inputs/symtab-sh_info2.elf -o %t2 2>&1 | FileCheck %s
# CHECK: invalid sh_info in symbol table

## sh_info contains invalid value saying non-local symbol is local.
# RUN: not ld.lld %p/Inputs/symtab-sh_info3.elf -o %t2 2>&1 | \
# RUN:   FileCheck --check-prefix=INVALID-SYMTAB-SHINFO %s
# INVALID-SYMTAB-SHINFO: broken object: getLocalSymbols returns a non-local symbol
