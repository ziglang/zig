# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

## Take some valid script with multiline comments
## and check it actually works:
# RUN: echo "SECTIONS {" > %t.script
# RUN: echo ".text : { *(.text) }" >> %t.script
# RUN: echo ".keep : { *(.keep) } /*" >> %t.script
# RUN: echo "comment line 1" >> %t.script
# RUN: echo "comment line 2 */" >> %t.script
# RUN: echo ".temp : { *(.temp) } }" >> %t.script
# RUN: ld.lld -shared %t -o %t1 --script %t.script

## Change ":" to "+" at line 2, check that error
## message starts from correct line number:
# RUN: echo "SECTIONS {" > %t.script
# RUN: echo ".text + { *(.text) }" >> %t.script
# RUN: echo ".keep : { *(.keep) } /*" >> %t.script
# RUN: echo "comment line 1" >> %t.script
# RUN: echo "comment line 2 */" >> %t.script
# RUN: echo ".temp : { *(.temp) } }" >> %t.script
# RUN: not ld.lld -shared %t -o %t1 --script %t.script 2>&1 | FileCheck -check-prefix=ERR1 %s
# ERR1: {{.*}}.script:2:

## Change ":" to "+" at line 3 now, check correct error line number:
# RUN: echo "SECTIONS {" > %t.script
# RUN: echo ".text : { *(.text) }" >> %t.script
# RUN: echo ".keep + { *(.keep) } /*" >> %t.script
# RUN: echo "comment line 1" >> %t.script
# RUN: echo "comment line 2 */" >> %t.script
# RUN: echo ".temp : { *(.temp) } }" >> %t.script
# RUN: not ld.lld -shared %t -o %t1 --script %t.script 2>&1 | FileCheck -check-prefix=ERR2 %s
# ERR2: {{.*}}.script:3:

## Change ":" to "+" at line 6, after multiline comment,
## check correct error line number:
# RUN: echo "SECTIONS {" > %t.script
# RUN: echo ".text : { *(.text) }" >> %t.script
# RUN: echo ".keep : { *(.keep) } /*" >> %t.script
# RUN: echo "comment line 1" >> %t.script
# RUN: echo "comment line 2 */" >> %t.script
# RUN: echo ".temp + { *(.temp) } }" >> %t.script
# RUN: not ld.lld -shared %t -o %t1 --script %t.script 2>&1 | FileCheck -check-prefix=ERR5 %s
# ERR5: {{.*}}.script:6:

## Check that text of lines and pointer to 'bad' token are working ok.
# RUN: echo "UNKNOWN_TAG {" > %t.script
# RUN: echo ".text : { *(.text) }" >> %t.script
# RUN: echo ".keep : { *(.keep) }" >> %t.script
# RUN: echo ".temp : { *(.temp) } }" >> %t.script
# RUN: not ld.lld -shared %t -o %t1 --script %t.script 2>&1 | \
# RUN:   FileCheck -check-prefix=ERR6 -strict-whitespace %s
# ERR6:      error: {{.*}}.script:1: unknown directive: UNKNOWN_TAG
# ERR6-NEXT: >>> UNKNOWN_TAG {
# ERR6-NEXT: >>> ^

## One more check that text of lines and pointer to 'bad' token are working ok.
# RUN: echo "SECTIONS {" > %t.script
# RUN: echo ".text : { *(.text) }" >> %t.script
# RUN: echo ".keep : { *(.keep) }" >> %t.script
# RUN: echo "boom .temp : { *(.temp) } }" >> %t.script
# RUN: not ld.lld -shared %t -o %t1 --script %t.script 2>&1 | \
# RUN:   FileCheck -check-prefix=ERR7 -strict-whitespace %s
# ERR7:      error: {{.*}}.script:4: malformed number: .temp
# ERR7-NEXT: >>> boom .temp : { *(.temp) } }
# ERR7-NEXT: >>>      ^

## Check tokenize() error
# RUN: echo "SECTIONS {}" > %t.script
# RUN: echo "\"" >> %t.script
# RUN: not ld.lld -shared %t -o %t1 --script %t.script 2>&1 | \
# RUN:   FileCheck -check-prefix=ERR8 -strict-whitespace %s
# ERR8: {{.*}}.script:2: unclosed quote

## Check tokenize() error in included script file
# RUN: echo "SECTIONS {}" > %t.script.inc
# RUN: echo "\"" >> %t.script.inc
# RUN: echo "INCLUDE \"%t.script.inc\"" > %t.script
# RUN: not ld.lld -shared %t -o %t1 --script %t.script 2>&1 | \
# RUN:   FileCheck -check-prefix=ERR9 -strict-whitespace %s
# ERR9: {{.*}}.script.inc:2: unclosed quote

## Check error reporting correctness for included files.
# RUN: echo "SECTIONS {" > %t.script.inc
# RUN: echo ".text : { *(.text) }" >> %t.script.inc
# RUN: echo ".keep : { *(.keep) }" >> %t.script.inc
# RUN: echo "boom .temp : { *(.temp) } }" >> %t.script.inc
# RUN: echo "INCLUDE \"%t.script.inc\"" > %t.script
# RUN: not ld.lld -shared %t -o %t1 --script %t.script 2>&1 | \
# RUN:   FileCheck -check-prefix=ERR10 -strict-whitespace %s
# ERR10:      error: {{.*}}.script.inc:4: malformed number: .temp
# ERR10-NEXT: >>> boom .temp : { *(.temp) } }
# ERR10-NEXT: >>>      ^

## Check error reporting in script with INCLUDE directive.
# RUN: echo "SECTIONS {" > %t.script.inc
# RUN: echo ".text : { *(.text) }" >> %t.script.inc
# RUN: echo ".keep : { *(.keep) }" >> %t.script.inc
# RUN: echo ".temp : { *(.temp) } }" >> %t.script.inc
# RUN: echo "/* One line before INCLUDE */" > %t.script
# RUN: echo "INCLUDE \"%t.script.inc\"" >> %t.script
# RUN: echo "/* One line ater INCLUDE */" >> %t.script
# RUN: echo "Error" >> %t.script
# RUN: not ld.lld -shared %t -o %t1 --script %t.script 2>&1 | \
# RUN:   FileCheck -check-prefix=ERR11 -strict-whitespace %s
# ERR11: error: {{.*}}.script:4: unexpected EOF
