## symbol-index.elf has incorrect type of .symtab section.
## There is no symbol bodies because of that and any symbol index becomes incorrect.
## Section Headers:
##   [Nr] Name              Type            Address          Off    Size   ES Flg Lk Inf Al
##   [ 0]                   NULL            0000000000000000 000000 000000 00      0   0  0
## ...
##   [ 4] .symtab           RELA            0000000000000000 000048 000030 18      1   2  8
# RUN: not ld.lld %p/Inputs/symbol-index.elf -o /dev/null 2>&1 | \
# RUN:   FileCheck --check-prefix=INVALID-SYMBOL-INDEX %s
# INVALID-SYMBOL-INDEX: invalid symbol index
