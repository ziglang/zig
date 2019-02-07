; REQUIRES: x86
; RUN: llvm-as %s -o %t.o

; RUN: rm -f %t.yaml
; RUN: ld.lld --opt-remarks-filename %t.yaml %t.o -o %t -shared -save-temps
; RUN: llvm-dis %t.0.4.opt.bc -o - | FileCheck %s
; RUN: ld.lld --opt-remarks-with-hotness --opt-remarks-filename %t.hot.yaml \
; RUN:  %t.o -o %t -shared
; RUN: cat %t.yaml | FileCheck %s -check-prefix=YAML
; RUN: cat %t.hot.yaml | FileCheck %s -check-prefix=YAML-HOT

; Check that @tinkywinky is inlined after optimizations.
; CHECK-LABEL: define i32 @main
; CHECK-NEXT:  %a.i = call i32 @patatino()
; CHECK-NEXT:  ret i32 %a.i
; CHECK-NEXT: }

; YAML:      --- !Passed
; YAML-NEXT: Pass:            inline
; YAML-NEXT: Name:            Inlined
; YAML-NEXT: Function:        main
; YAML-NEXT: Args:
; YAML-NEXT:   - Callee:          tinkywinky
; YAML-NEXT:   - String:          ' inlined into '
; YAML-NEXT:   - Caller:          main
; YAML-NEXT:   - String:          ' with '
; YAML-NEXT:   - String:          '(cost='
; YAML-NEXT:   - Cost:            '0'
; YAML-NEXT:   - String:          ', threshold='
; YAML-NEXT:   - Threshold:       '337'
; YAML-NEXT:   - String:          ')'
; YAML-NEXT: ...

; YAML-HOT:      --- !Passed
; YAML-HOT-NEXT: Pass:            inline
; YAML-HOT-NEXT: Name:            Inlined
; YAML-HOT-NEXT: Function:        main
; YAML-HOT-NEXT: Hotness:         300
; YAML-HOT-NEXT: Args:
; YAML-HOT-NEXT:   - Callee:          tinkywinky
; YAML-HOT-NEXT:   - String:          ' inlined into '
; YAML-HOT-NEXT:   - Caller:          main
; YAML-HOT-NEXT:   - String:          ' with '
; YAML-HOT-NEXT:   - String:          '(cost='
; YAML-HOT-NEXT:   - Cost:            '0'
; YAML-HOT-NEXT:   - String:          ', threshold='
; YAML-HOT-NEXT:   - Threshold:       '337'
; YAML-HOT-NEXT:   - String:          ')'
; YAML-HOT-NEXT: ...

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-scei-ps4"

declare i32 @patatino()

define i32 @tinkywinky() {
  %a = call i32 @patatino()
  ret i32 %a
}

define i32 @main() !prof !0 {
  %i = call i32 @tinkywinky()
  ret i32 %i
}

!0 = !{!"function_entry_count", i64 300}
