# REQUIRES: x86

# Extracting the tar archive can get over the path limit on windows.
# REQUIRES: shell

# RUN: rm -rf %t.dir
# RUN: mkdir -p %t.dir/build1
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.dir/build1/foo.o
# RUN: cd %t.dir
# RUN: ld.lld --hash-style=gnu build1/foo.o -o bar -shared --as-needed --reproduce repro.tar
# RUN: tar xf repro.tar
# RUN: diff build1/foo.o repro/%:t.dir/build1/foo.o

# RUN: FileCheck %s --check-prefix=RSP < repro/response.txt
# RSP: {{^}}--hash-style gnu{{$}}
# RSP-NOT: repro{{[/\\]}}
# RSP-NEXT: {{[/\\]}}foo.o
# RSP-NEXT: -o bar
# RSP-NEXT: -shared
# RSP-NEXT: --as-needed

# RUN: FileCheck %s --check-prefix=VERSION < repro/version.txt
# VERSION: LLD

# RUN: mkdir -p %t.dir/build2/a/b/c
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.dir/build2/foo.o
# RUN: cd %t.dir/build2/a/b/c
# RUN: env LLD_REPRODUCE=repro.tar ld.lld ./../../../foo.o -o bar -shared --as-needed
# RUN: tar xf repro.tar
# RUN: diff %t.dir/build2/foo.o repro/%:t.dir/build2/foo.o

# RUN: echo "{ local: *; };" >  ver
# RUN: echo "{};" > dyn
# RUN: echo > file
# RUN: echo > file2
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o 'foo bar'
# RUN: ld.lld --reproduce repro2.tar 'foo bar' -L"foo bar" -Lfile -Tfile2 \
# RUN:   --dynamic-list dyn -rpath file --script=file --version-script ver \
# RUN:   --dynamic-linker "some unusual/path" -soname 'foo bar' -soname='foo bar'
# RUN: tar xf repro2.tar
# RUN: FileCheck %s --check-prefix=RSP2 < repro2/response.txt
# RSP2:      "{{.*}}foo bar"
# RSP2-NEXT: -L "{{.*}}foo bar"
# RSP2-NEXT: -L {{.+}}file
# RSP2-NEXT: --script {{.+}}file2
# RSP2-NEXT: --dynamic-list {{.+}}dyn
# RSP2-NEXT: -rpath {{.+}}file
# RSP2-NEXT: --script {{.+}}file
# RSP2-NEXT: --version-script [[PATH:.*]]ver
# RSP2-NEXT: --dynamic-linker "some unusual/path"
# RSP2-NEXT: -soname="foo bar"
# RSP2-NEXT: -soname="foo bar"

# RUN: tar tf repro2.tar | FileCheck %s
# CHECK:      repro2/response.txt
# CHECK-NEXT: repro2/version.txt
# CHECK-NEXT: repro2/{{.*}}/dyn
# CHECK-NEXT: repro2/{{.*}}/ver
# CHECK-NEXT: repro2/{{.*}}/foo bar
# CHECK-NEXT: repro2/{{.*}}/file2
# CHECK-NEXT: repro2/{{.*}}/file

## Check that directory path is stripped from -o <file-path>
# RUN: mkdir -p %t.dir/build3/a/b/c
# RUN: cd %t.dir
# RUN: ld.lld build1/foo.o -o build3/a/b/c/bar -shared --as-needed --reproduce=repro3.tar
# RUN: tar xf repro3.tar
# RUN: FileCheck %s --check-prefix=RSP3 < repro3/response.txt
# RSP3: -o bar

.globl _start
_start:
  mov $60, %rax
  mov $42, %rdi
  syscall
