# REQUIRES: x86

# RUN: echo -e ".globl libfunc\n.text\nlibfunc:\nret" > %t.lib.s
# RUN: llvm-mc -triple=x86_64-windows-gnu %t.lib.s -filetype=obj -o %t.lib.o
# RUN: lld-link -lldmingw -dll -out:%t.lib.dll -entry:libfunc %t.lib.o -implib:%t.lib.dll.a

# RUN: echo -e ".globl helper1\n.text\nhelper1:\ncall libfunc\nret" > %t.helper1.s
# RUN: echo -e ".globl helper2\n.text\nhelper2:\nret\n.globl libfunc\n.globl __imp_libfunc\nlibfunc:\nret\n.data\n__imp_libfunc:\n.quad libfunc" > %t.helper2.s
# RUN: llvm-mc -triple=x86_64-windows-gnu %t.helper1.s -filetype=obj -o %t.helper1.o
# RUN: llvm-mc -triple=x86_64-windows-gnu %t.helper2.s -filetype=obj -o %t.helper2.o

# RUN: llvm-ar rcs %t.helper.a %t.helper1.o %t.helper2.o

# RUN: llvm-mc -triple=x86_64-windows-gnu %s -filetype=obj -o %t.main.o

# Simulate a setup, where two libraries provide the same import function;
# %t.lib.dll.a is a pure import library which provides "libfunc".
# %t.helper.a is a static library which contains "helper1" and "helper2".
#
# helper1 contains an undefined reference to libfunc. helper2 contains a
# fake local implementation of libfunc, together with the __imp_libfunc
# stub.
#
# %t.lib.dll.a is listed before %t.helper.a on the command line. After
# including helper1, the library member that first declared the Lazy libfunc
# (%t.lib.dll.a) gets enqueued to be loaded. Before that gets done, helper2
# gets loaded, which also turns out to provide a definition of libfunc.
# Once the import library member from %t.lib.dll.a gets loaded, libfunc
# and __imp_libfunc already are defined.

# Just check that this fails cleanly (doesn't crash).
# RUN: not lld-link -lldmingw -out:%t.main.exe -entry:main %t.main.o %t.lib.dll.a %t.helper.a

# Test with %t.helper.a on the command line; in this case we won't try to
# include libfunc from %t.lib.dll.a and everything works fine.
# RUN: lld-link -lldmingw -out:%t.main.exe -entry:main %t.main.o %t.helper.a %t.lib.dll.a

    .globl main
    .text
main:
    call helper1
    call helper2
    ret
