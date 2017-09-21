; REQUIRES: x86
; RUN: opt -thinlto-bc %s -o %t.obj
; RUN: opt -thinlto-bc %S/Inputs/thinlto-mangled-qux.ll -o %T/thinlto-mangled-qux.obj
; RUN: lld-link -out:%t.exe -entry:main %t.obj %T/thinlto-mangled-qux.obj

target datalayout = "e-m:w-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc19.0.24215"

%"class.bar" = type { i32 (...)**, i8*, i8*, i8*, i32 }

define i32 @main() {
  ret i32 0
}

define available_externally zeroext i1 @"\01?x@bar@@UEBA_NXZ"(%"class.bar"* %this) unnamed_addr align 2 {
  ret i1 false
}
