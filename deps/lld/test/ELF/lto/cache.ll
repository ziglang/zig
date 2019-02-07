; REQUIRES: x86
; NetBSD: noatime mounts currently inhibit 'touch' from updating atime
; UNSUPPORTED: system-netbsd

; RUN: opt -module-hash -module-summary %s -o %t.o
; RUN: opt -module-hash -module-summary %p/Inputs/cache.ll -o %t2.o

; RUN: rm -Rf %t.cache && mkdir %t.cache
; Create two files that would be removed by cache pruning due to age.
; We should only remove files matching the pattern "llvmcache-*".
; RUN: touch -t 197001011200 %t.cache/llvmcache-foo %t.cache/foo
; RUN: ld.lld --thinlto-cache-dir=%t.cache --thinlto-cache-policy prune_after=1h:prune_interval=0s -o %t3 %t2.o %t.o

; Two cached objects, plus a timestamp file and "foo", minus the file we removed.
; RUN: ls %t.cache | count 4

; Create a file of size 64KB.
; RUN: %python -c "print(' ' * 65536)" > %t.cache/llvmcache-foo

; This should leave the file in place.
; RUN: ld.lld --thinlto-cache-dir=%t.cache --thinlto-cache-policy cache_size_bytes=128k:prune_interval=0s -o %t3 %t2.o %t.o
; RUN: ls %t.cache | count 5

; Increase the age of llvmcache-foo, which will give it the oldest time stamp
; so that it is processed and removed first.
; RUN: %python -c 'import os,sys,time; t=time.time()-120; os.utime(sys.argv[1],(t,t))' %t.cache/llvmcache-foo

; This should remove it.
; RUN: ld.lld --thinlto-cache-dir=%t.cache --thinlto-cache-policy cache_size_bytes=32k:prune_interval=0s -o %t3 %t2.o %t.o
; RUN: ls %t.cache | count 4

; Setting max number of files to 0 should disable the limit, not delete everything.
; RUN: ld.lld --thinlto-cache-dir=%t.cache --thinlto-cache-policy prune_after=0s:cache_size=0%:cache_size_files=0:prune_interval=0s -o %t3 %t2.o %t.o
; RUN: ls %t.cache | count 4

; Delete everything except for the timestamp, "foo" and one cache file.
; RUN: ld.lld --thinlto-cache-dir=%t.cache --thinlto-cache-policy prune_after=0s:cache_size=0%:cache_size_files=1:prune_interval=0s -o %t3 %t2.o %t.o
; RUN: ls %t.cache | count 3

; Check that we remove the least recently used file first.
; RUN: rm -fr %t.cache
; RUN: mkdir %t.cache
; RUN: echo xyz > %t.cache/llvmcache-old
; RUN: touch -t 198002011200 %t.cache/llvmcache-old
; RUN: echo xyz > %t.cache/llvmcache-newer
; RUN: touch -t 198002021200 %t.cache/llvmcache-newer
; RUN: ld.lld --thinlto-cache-dir=%t.cache --thinlto-cache-policy prune_after=0s:cache_size=0%:cache_size_files=3:prune_interval=0s -o %t3 %t2.o %t.o
; RUN: ls %t.cache | FileCheck %s

; CHECK-NOT: llvmcache-old
; CHECK: llvmcache-newer
; CHECK-NOT: llvmcache-old

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

define void @globalfunc() #0 {
entry:
  ret void
}
