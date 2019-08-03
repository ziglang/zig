# REQUIRES: x86

# Tests handling of several comdats with "largest" selection type that each
# has an associative comdat.

# Create obj files.
# RUN: sed -e s/TYPE/.byte/  -e s/SIZE/1/ %s | llvm-mc -triple x86_64-pc-win32 -filetype=obj -o %t.1.obj
# RUN: sed -e s/TYPE/.short/ -e s/SIZE/2/ %s | llvm-mc -triple x86_64-pc-win32 -filetype=obj -o %t.2.obj
# RUN: sed -e s/TYPE/.long/  -e s/SIZE/4/ %s | llvm-mc -triple x86_64-pc-win32 -filetype=obj -o %t.4.obj

        .section .text$ac, "", associative, symbol
assocsym:
        .long SIZE

        .section .text$nm, "", largest, symbol
        .globl symbol
symbol:
        TYPE SIZE

# Pass the obj files in different orders and check that only the associative
# comdat of the largest obj file makes it into the output, independent of
# the order of the obj files on the command line.

# FIXME: Make these pass when /opt:noref is passed.

# RUN: lld-link /include:symbol /dll /noentry /nodefaultlib %t.1.obj %t.2.obj %t.4.obj /out:%t.exe
# RUN: llvm-objdump -s %t.exe | FileCheck --check-prefix=ALL124 %s
# ALL124: Contents of section .text:
# ALL124:   180001000 04000000 04000000 ....

# RUN: lld-link /include:symbol /dll /noentry /nodefaultlib %t.4.obj %t.2.obj %t.1.obj /out:%t.exe
# RUN: llvm-objdump -s %t.exe | FileCheck --check-prefix=ALL421 %s
# ALL421: Contents of section .text:
# ALL421:   180001000 04000000 04000000 ....

# RUN: lld-link /include:symbol /dll /noentry /nodefaultlib %t.2.obj %t.4.obj %t.1.obj /out:%t.exe
# RUN: llvm-objdump -s %t.exe | FileCheck --check-prefix=ALL241 %s
# ALL241: Contents of section .text:
# ALL241:   180001000 04000000 04000000 ....

# RUN: lld-link /include:symbol /dll /noentry /nodefaultlib %t.2.obj %t.1.obj /out:%t.exe
# RUN: llvm-objdump -s %t.exe | FileCheck --check-prefix=JUST21 %s
# JUST21: Contents of section .text:
# JUST21:   180001000 02000000 0200 ....

