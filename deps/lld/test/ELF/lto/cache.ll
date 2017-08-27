; REQUIRES: x86

; RUN: opt -module-hash -module-summary %s -o %t.o
; RUN: opt -module-hash -module-summary %p/Inputs/cache.ll -o %t2.o

; RUN: rm -Rf %t.cache && mkdir %t.cache
; Create two files that would be removed by cache pruning due to age.
; We should only remove files matching the pattern "llvmcache-*".
; RUN: touch -t 197001011200 %t.cache/llvmcache-foo %t.cache/foo
; RUN: ld.lld --thinlto-cache-dir=%t.cache --thinlto-cache-policy prune_after=1h -o %t3 %t2.o %t.o

; Two cached objects, plus a timestamp file and "foo", minus the file we removed.
; RUN: ls %t.cache | count 4

; Create a file of size 64KB.
; RUN: %python -c "print(' ' * 65536)" > %t.cache/llvmcache-foo

; This should leave the file in place.
; RUN: ld.lld --thinlto-cache-dir=%t.cache --thinlto-cache-policy cache_size_bytes=128k -o %t3 %t2.o %t.o
; RUN: ls %t.cache | count 5

; This should remove it.
; RUN: ld.lld --thinlto-cache-dir=%t.cache --thinlto-cache-policy cache_size_bytes=32k -o %t3 %t2.o %t.o
; RUN: ls %t.cache | count 4

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

define void @globalfunc() #0 {
entry:
  ret void
}
