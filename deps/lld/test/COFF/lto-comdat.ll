; RUN: llvm-as -o %T/comdat-main.lto.obj %s
; RUN: llvm-as -o %T/comdat1.lto.obj %S/Inputs/lto-comdat1.ll
; RUN: llvm-as -o %T/comdat2.lto.obj %S/Inputs/lto-comdat2.ll
; RUN: rm -f %T/comdat.lto.lib
; RUN: llvm-ar cru %T/comdat.lto.lib %T/comdat1.lto.obj %T/comdat2.lto.obj

; RUN: llc -filetype=obj -o %T/comdat-main.obj %s
; RUN: llc -filetype=obj -o %T/comdat1.obj %S/Inputs/lto-comdat1.ll
; RUN: llc -filetype=obj -o %T/comdat2.obj %S/Inputs/lto-comdat2.ll
; RUN: rm -f %T/comdat.lib
; RUN: llvm-ar cru %T/comdat.lib %T/comdat1.obj %T/comdat2.obj

; Check that, when we use an LTO main with LTO objects, we optimize away all
; of f1, f2, and comdat.
; RUN: lld-link /out:%T/comdat-main.exe /entry:main /subsystem:console %T/comdat-main.lto.obj %T/comdat1.lto.obj %T/comdat2.lto.obj
; RUN: llvm-readobj -file-headers %T/comdat-main.exe | FileCheck -check-prefix=HEADERS-11 %s
; RUN: llvm-objdump -d %T/comdat-main.exe | FileCheck -check-prefix=TEXT-11 %s
; RUN: lld-link /out:%T/comdat-main.exe /entry:main /subsystem:console %T/comdat-main.lto.obj %T/comdat.lto.lib
; RUN: llvm-readobj -file-headers %T/comdat-main.exe | FileCheck -check-prefix=HEADERS-11 %s
; RUN: llvm-objdump -d %T/comdat-main.exe | FileCheck -check-prefix=TEXT-11 %s

; Check that, when we use a non-LTO main with LTO objects, we pick the comdat
; implementation in LTO, elide calls to it from inside LTO, and retain the
; call to comdat from main.
; RUN: lld-link /out:%T/comdat-main.exe /entry:main /subsystem:console %T/comdat-main.obj %T/comdat1.lto.obj %T/comdat2.lto.obj
; RUN: llvm-readobj -file-headers %T/comdat-main.exe | FileCheck -check-prefix=HEADERS-01 %s
; RUN: llvm-objdump -d %T/comdat-main.exe | FileCheck -check-prefix=TEXT-01 %s
; RUN: lld-link /out:%T/comdat-main.exe /entry:main /subsystem:console %T/comdat-main.obj %T/comdat.lto.lib
; RUN: llvm-readobj -file-headers %T/comdat-main.exe | FileCheck -check-prefix=HEADERS-01 %s
; RUN: llvm-objdump -d %T/comdat-main.exe | FileCheck -check-prefix=TEXT-01 %s

; Check that, when we use an LTO main with non-LTO objects, we pick the comdat
; implementation in LTO, elide the call to it from inside LTO, and keep the
; calls to comdat from the non-LTO objects.
; RUN: lld-link /out:%T/comdat-main.exe /entry:main /subsystem:console %T/comdat-main.lto.obj %T/comdat1.obj %T/comdat2.obj
; RUN: llvm-readobj -file-headers %T/comdat-main.exe | FileCheck -check-prefix=HEADERS-10 %s
; RUN: llvm-objdump -d %T/comdat-main.exe | FileCheck -check-prefix=TEXT-10 %s
; RUN: lld-link /out:%T/comdat-main.exe /entry:main /subsystem:console %T/comdat-main.lto.obj %T/comdat.lib
; RUN: llvm-readobj -file-headers %T/comdat-main.exe | FileCheck -check-prefix=HEADERS-10 %s
; RUN: llvm-objdump -d %T/comdat-main.exe | FileCheck -check-prefix=TEXT-10 %s

; HEADERS-11: AddressOfEntryPoint: 0x1000
; TEXT-11: Disassembly of section .text:
; TEXT-11-NEXT: .text:
; TEXT-11-NEXT: xorl	%eax, %eax
; TEXT-11-NEXT: retq

; HEADERS-01: AddressOfEntryPoint: 0x2000
; TEXT-01: Disassembly of section .text:
; TEXT-01-NEXT: .text:
; TEXT-01-NEXT: subq	$40, %rsp
; TEXT-01-NEXT: callq	39
; TEXT-01-NEXT: callq	50
; TEXT-01-NEXT: callq	13
; TEXT-01-NEXT: xorl	%eax, %eax
; TEXT-01-NEXT: addq	$40, %rsp
; TEXT-01: retq
; TEXT-01-NOT: callq
; TEXT-01: retq
; TEXT-01-NOT: callq
; TEXT-01: retq
; TEXT-01-NOT: callq
; TEXT-01: retq
; TEXT-01-NOT: {{.}}

; HEADERS-10: AddressOfEntryPoint: 0x2020
; TEXT-10: Disassembly of section .text:
; TEXT-10-NEXT: .text:
; TEXT-10-NEXT: subq	$40, %rsp
; TEXT-10-NEXT: callq	55
; TEXT-10-NEXT: nop
; TEXT-10-NEXT: addq	$40, %rsp
; TEXT-10-NEXT: retq
; TEXT-10-NEXT: int3
; TEXT-10-NEXT: subq	$40, %rsp
; TEXT-10-NEXT: callq	39
; TEXT-10-NEXT: nop
; TEXT-10-NEXT: addq	$40, %rsp
; TEXT-10-NEXT: retq
; TEXT-10-NEXT: int3
; TEXT-10-NEXT: subq	$40, %rsp
; TEXT-10-NEXT: callq	-41
; TEXT-10-NEXT: callq	-30
; TEXT-10-NEXT: xorl	%eax, %eax
; TEXT-10-NEXT: addq	$40, %rsp
; TEXT-10-NEXT: retq
; TEXT-10-NOT: callq
; TEXT-10: retq
; TEXT-10-NOT: {{.}}

target datalayout = "e-m:w-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc"

$comdat = comdat any

define i32 @main() {
  call void @f1()
  call void @f2()
  call void @comdat()
  ret i32 0
}

define linkonce_odr void @comdat() comdat {
  ret void
}

declare void @f1()
declare void @f2()
