; RUN: opt -module-hash -module-summary %s -o %t.o
; RUN: opt -module-hash -module-summary %p/Inputs/cache.ll -o %t2.o
; NetBSD: noatime mounts currently inhibit 'touch' from updating atime
; UNSUPPORTED: system-netbsd

; RUN: rm -Rf %t.cache && mkdir %t.cache
; Create two files that would be removed by cache pruning due to age.
; We should only remove files matching the pattern "llvmcache-*".
; RUN: touch -t 197001011200 %t.cache/llvmcache-foo %t.cache/foo
; RUN: wasm-ld --thinlto-cache-dir=%t.cache --thinlto-cache-policy prune_after=1h:prune_interval=0s -o %t.wasm %t2.o %t.o

; Two cached objects, plus a timestamp file and "foo", minus the file we removed.
; RUN: ls %t.cache | count 4

; Create a file of size 64KB.
; RUN: %python -c "print(' ' * 65536)" > %t.cache/llvmcache-foo

; This should leave the file in place.
; RUN: wasm-ld --thinlto-cache-dir=%t.cache --thinlto-cache-policy cache_size_bytes=128k:prune_interval=0s -o %t.wasm %t2.o %t.o
; RUN: ls %t.cache | count 5

; Increase the age of llvmcache-foo, which will give it the oldest time stamp
; so that it is processed and removed first.
; RUN: %python -c 'import os,sys,time; t=time.time()-120; os.utime(sys.argv[1],(t,t))' %t.cache/llvmcache-foo

; This should remove it.
; RUN: wasm-ld --thinlto-cache-dir=%t.cache --thinlto-cache-policy cache_size_bytes=32k:prune_interval=0s -o %t.wasm %t2.o %t.o
; RUN: ls %t.cache | count 4

; Setting max number of files to 0 should disable the limit, not delete everything.
; RUN: wasm-ld --thinlto-cache-dir=%t.cache --thinlto-cache-policy prune_after=0s:cache_size=0%:cache_size_files=0:prune_interval=0s -o %t.wasm %t2.o %t.o
; RUN: ls %t.cache | count 4

; Delete everything except for the timestamp, "foo" and one cache file.
; RUN: wasm-ld --thinlto-cache-dir=%t.cache --thinlto-cache-policy prune_after=0s:cache_size=0%:cache_size_files=1:prune_interval=0s -o %t.wasm %t2.o %t.o
; RUN: ls %t.cache | count 3

target datalayout = "e-m:e-p:32:32-i64:64-n32:64-S128"
target triple = "wasm32-unknown-unknown-wasm"

define void @globalfunc() #0 {
entry:
  ret void
}
