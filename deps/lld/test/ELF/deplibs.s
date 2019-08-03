# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/deplibs-lib_foo.s -o %tfoo.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/deplibs-lib_bar.s -o %tbar.o
# RUN: rm -rf %t.dir %t.cwd
# RUN: mkdir -p %t.dir

# error if dependent libraries cannot be found
# RUN: not ld.lld %t.o -o /dev/null 2>&1 | FileCheck %s -DOBJ=%t.o --check-prefix MISSING
# MISSING: error: [[OBJ]]: unable to find library from dependent library specifier: foo.a
# MISSING-NEXT: error: [[OBJ]]: unable to find library from dependent library specifier: bar

# can ignore dependent libraries
# RUN: not ld.lld %t.o -o /dev/null --no-dependent-libraries 2>&1 | FileCheck %s --check-prefix IGNORE
# IGNORE: error: undefined symbol: foo
# IGNORE: error: undefined symbol: bar

# -r links preserve dependent libraries
# RUN: ld.lld %t.o %t.o -r -o %t-r.o
# RUN: not ld.lld %t-r.o -o /dev/null 2>&1 | sort | FileCheck %s -DOBJ=%t-r.o --check-prefixes MINUSR
# MINUSR: error: [[OBJ]]: unable to find library from dependent library specifier: bar
# MINUSR-NEXT: error: [[OBJ]]: unable to find library from dependent library specifier: foo.a
# MINUSR-NOT: unable to find library from dependent library specifier

# static archives located relative to library search paths
# RUN: llvm-ar rc %t.dir/foo.a %tfoo.o
# RUN: llvm-ar rc %t.dir/libbar.a %tbar.o
# RUN: ld.lld %t.o -o /dev/null -L %t.dir

# shared objects located relative to library search paths
# RUN: rm %t.dir/libbar.a
# RUN: ld.lld -shared -o %t.dir/libbar.so %tbar.o
# RUN: ld.lld -Bdynamic %t.o -o /dev/null -L %t.dir

# dependent libraries searched for symbols after libraries on the command line
# RUN: mkdir -p %t.cwd
# RUN: cd %t.cwd
# RUN: cp %t.dir/foo.a %t.cwd/libcmdline.a
# RUN: ld.lld %t.o libcmdline.a -o /dev/null -L %t.dir --trace 2>&1 | FileCheck %s -DOBJ=%t.o -DSO=%t.dir --check-prefix CMDLINE --implicit-check-not foo.a
# CMDLINE: [[OBJ]]
# CMDLINE-NEXT: {{^libcmdline\.a}}
# CMDLINE-NEXT: [[SO]]{{[\\/]}}libbar.so

# libraries can be found from specifiers as if the specifiers were listed on on the command-line.
# RUN: cp %t.dir/foo.a %t.cwd/foo.a
# RUN: ld.lld %t.o -o /dev/null -L %t.dir --trace 2>&1 | FileCheck %s -DOBJ=%t.o -DSO=%t.dir --check-prefix ASIFCMDLINE --implicit-check-not foo.a
# ASIFCMDLINE: [[OBJ]]
# ASIFCMDLINE-NEXT: {{^foo\.a}}
# ASIFCMDLINE-NEXT: [[SO]]{{[\\/]}}libbar.so

    call foo
    call bar
.section ".deplibs","MS",@llvm_dependent_libraries,1
    .asciz  "foo.a"
    .asciz  "bar"
