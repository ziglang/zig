//===-- tsan_dense_alloc.h --------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file is a part of ThreadSanitizer (TSan), a race detector.
//
// A DenseSlabAlloc is a freelist-based allocator of fixed-size objects.
// DenseSlabAllocCache is a thread-local cache for DenseSlabAlloc.
// The only difference with traditional slab allocators is that DenseSlabAlloc
// allocates/free indices of objects and provide a functionality to map
// the index onto the real pointer. The index is u32, that is, 2 times smaller
// than uptr (hense the Dense prefix).
//===----------------------------------------------------------------------===//
#ifndef TSAN_DENSE_ALLOC_H
#define TSAN_DENSE_ALLOC_H

#include "sanitizer_common/sanitizer_common.h"
#include "tsan_defs.h"

namespace __tsan {

class DenseSlabAllocCache {
  static const uptr kSize = 128;
  typedef u32 IndexT;
  uptr pos;
  IndexT cache[kSize];
  template <typename, uptr, uptr, u64>
  friend class DenseSlabAlloc;
};

template <typename T, uptr kL1Size, uptr kL2Size, u64 kReserved = 0>
class DenseSlabAlloc {
 public:
  typedef DenseSlabAllocCache Cache;
  typedef typename Cache::IndexT IndexT;

  static_assert((kL1Size & (kL1Size - 1)) == 0,
                "kL1Size must be a power-of-two");
  static_assert((kL2Size & (kL2Size - 1)) == 0,
                "kL2Size must be a power-of-two");
  static_assert((kL1Size * kL2Size) <= (1ull << (sizeof(IndexT) * 8)),
                "kL1Size/kL2Size are too large");
  static_assert(((kL1Size * kL2Size - 1) & kReserved) == 0,
                "reserved bits don't fit");
  static_assert(sizeof(T) > sizeof(IndexT),
                "it doesn't make sense to use dense alloc");

  explicit DenseSlabAlloc(LinkerInitialized, const char *name) {
    freelist_ = 0;
    fillpos_ = 0;
    name_ = name;
  }

  explicit DenseSlabAlloc(const char *name)
      : DenseSlabAlloc(LINKER_INITIALIZED, name) {
    // It can be very large.
    // Don't page it in for linker initialized objects.
    internal_memset(map_, 0, sizeof(map_));
  }

  ~DenseSlabAlloc() {
    for (uptr i = 0; i < kL1Size; i++) {
      if (map_[i] != 0)
        UnmapOrDie(map_[i], kL2Size * sizeof(T));
    }
  }

  IndexT Alloc(Cache *c) {
    if (c->pos == 0)
      Refill(c);
    return c->cache[--c->pos];
  }

  void Free(Cache *c, IndexT idx) {
    DCHECK_NE(idx, 0);
    if (c->pos == Cache::kSize)
      Drain(c);
    c->cache[c->pos++] = idx;
  }

  T *Map(IndexT idx) {
    DCHECK_NE(idx, 0);
    DCHECK_LE(idx, kL1Size * kL2Size);
    return &map_[idx / kL2Size][idx % kL2Size];
  }

  void FlushCache(Cache *c) {
    SpinMutexLock lock(&mtx_);
    while (c->pos) {
      IndexT idx = c->cache[--c->pos];
      *(IndexT*)Map(idx) = freelist_;
      freelist_ = idx;
    }
  }

  void InitCache(Cache *c) {
    c->pos = 0;
    internal_memset(c->cache, 0, sizeof(c->cache));
  }

 private:
  T *map_[kL1Size];
  SpinMutex mtx_;
  IndexT freelist_;
  uptr fillpos_;
  const char *name_;

  void Refill(Cache *c) {
    SpinMutexLock lock(&mtx_);
    if (freelist_ == 0) {
      if (fillpos_ == kL1Size) {
        Printf("ThreadSanitizer: %s overflow (%zu*%zu). Dying.\n",
            name_, kL1Size, kL2Size);
        Die();
      }
      VPrintf(2, "ThreadSanitizer: growing %s: %zu out of %zu*%zu\n",
          name_, fillpos_, kL1Size, kL2Size);
      T *batch = (T*)MmapOrDie(kL2Size * sizeof(T), name_);
      // Reserve 0 as invalid index.
      IndexT start = fillpos_ == 0 ? 1 : 0;
      for (IndexT i = start; i < kL2Size; i++) {
        new(batch + i) T;
        *(IndexT*)(batch + i) = i + 1 + fillpos_ * kL2Size;
      }
      *(IndexT*)(batch + kL2Size - 1) = 0;
      freelist_ = fillpos_ * kL2Size + start;
      map_[fillpos_++] = batch;
    }
    for (uptr i = 0; i < Cache::kSize / 2 && freelist_ != 0; i++) {
      IndexT idx = freelist_;
      c->cache[c->pos++] = idx;
      freelist_ = *(IndexT*)Map(idx);
    }
  }

  void Drain(Cache *c) {
    SpinMutexLock lock(&mtx_);
    for (uptr i = 0; i < Cache::kSize / 2; i++) {
      IndexT idx = c->cache[--c->pos];
      *(IndexT*)Map(idx) = freelist_;
      freelist_ = idx;
    }
  }
};

}  // namespace __tsan

#endif  // TSAN_DENSE_ALLOC_H
