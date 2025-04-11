//===-- tsan_interface_atomic.cpp -----------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file is a part of ThreadSanitizer (TSan), a race detector.
//
//===----------------------------------------------------------------------===//

// ThreadSanitizer atomic operations are based on C++11/C1x standards.
// For background see C++11 standard.  A slightly older, publicly
// available draft of the standard (not entirely up-to-date, but close enough
// for casual browsing) is available here:
// http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2011/n3242.pdf
// The following page contains more background information:
// http://www.hpl.hp.com/personal/Hans_Boehm/c++mm/

#include "sanitizer_common/sanitizer_mutex.h"
#include "sanitizer_common/sanitizer_placement_new.h"
#include "sanitizer_common/sanitizer_stacktrace.h"
#include "tsan_flags.h"
#include "tsan_interface.h"
#include "tsan_rtl.h"

using namespace __tsan;

#if !SANITIZER_GO && __TSAN_HAS_INT128
// Protects emulation of 128-bit atomic operations.
static StaticSpinMutex mutex128;
#endif

#if SANITIZER_DEBUG
static bool IsLoadOrder(morder mo) {
  return mo == mo_relaxed || mo == mo_consume || mo == mo_acquire ||
         mo == mo_seq_cst;
}

static bool IsStoreOrder(morder mo) {
  return mo == mo_relaxed || mo == mo_release || mo == mo_seq_cst;
}
#endif

static bool IsReleaseOrder(morder mo) {
  return mo == mo_release || mo == mo_acq_rel || mo == mo_seq_cst;
}

static bool IsAcquireOrder(morder mo) {
  return mo == mo_consume || mo == mo_acquire || mo == mo_acq_rel ||
         mo == mo_seq_cst;
}

static bool IsAcqRelOrder(morder mo) {
  return mo == mo_acq_rel || mo == mo_seq_cst;
}

template <typename T>
T func_xchg(volatile T *v, T op) {
  T res = __sync_lock_test_and_set(v, op);
  // __sync_lock_test_and_set does not contain full barrier.
  __sync_synchronize();
  return res;
}

template <typename T>
T func_add(volatile T *v, T op) {
  return __sync_fetch_and_add(v, op);
}

template <typename T>
T func_sub(volatile T *v, T op) {
  return __sync_fetch_and_sub(v, op);
}

template <typename T>
T func_and(volatile T *v, T op) {
  return __sync_fetch_and_and(v, op);
}

template <typename T>
T func_or(volatile T *v, T op) {
  return __sync_fetch_and_or(v, op);
}

template <typename T>
T func_xor(volatile T *v, T op) {
  return __sync_fetch_and_xor(v, op);
}

template <typename T>
T func_nand(volatile T *v, T op) {
  // clang does not support __sync_fetch_and_nand.
  T cmp = *v;
  for (;;) {
    T newv = ~(cmp & op);
    T cur = __sync_val_compare_and_swap(v, cmp, newv);
    if (cmp == cur)
      return cmp;
    cmp = cur;
  }
}

template <typename T>
T func_cas(volatile T *v, T cmp, T xch) {
  return __sync_val_compare_and_swap(v, cmp, xch);
}

// clang does not support 128-bit atomic ops.
// Atomic ops are executed under tsan internal mutex,
// here we assume that the atomic variables are not accessed
// from non-instrumented code.
#if !defined(__GCC_HAVE_SYNC_COMPARE_AND_SWAP_16) && !SANITIZER_GO && \
    __TSAN_HAS_INT128
a128 func_xchg(volatile a128 *v, a128 op) {
  SpinMutexLock lock(&mutex128);
  a128 cmp = *v;
  *v = op;
  return cmp;
}

a128 func_add(volatile a128 *v, a128 op) {
  SpinMutexLock lock(&mutex128);
  a128 cmp = *v;
  *v = cmp + op;
  return cmp;
}

a128 func_sub(volatile a128 *v, a128 op) {
  SpinMutexLock lock(&mutex128);
  a128 cmp = *v;
  *v = cmp - op;
  return cmp;
}

a128 func_and(volatile a128 *v, a128 op) {
  SpinMutexLock lock(&mutex128);
  a128 cmp = *v;
  *v = cmp & op;
  return cmp;
}

a128 func_or(volatile a128 *v, a128 op) {
  SpinMutexLock lock(&mutex128);
  a128 cmp = *v;
  *v = cmp | op;
  return cmp;
}

a128 func_xor(volatile a128 *v, a128 op) {
  SpinMutexLock lock(&mutex128);
  a128 cmp = *v;
  *v = cmp ^ op;
  return cmp;
}

a128 func_nand(volatile a128 *v, a128 op) {
  SpinMutexLock lock(&mutex128);
  a128 cmp = *v;
  *v = ~(cmp & op);
  return cmp;
}

a128 func_cas(volatile a128 *v, a128 cmp, a128 xch) {
  SpinMutexLock lock(&mutex128);
  a128 cur = *v;
  if (cur == cmp)
    *v = xch;
  return cur;
}
#endif

template <typename T>
static int AccessSize() {
  if (sizeof(T) <= 1)
    return 1;
  else if (sizeof(T) <= 2)
    return 2;
  else if (sizeof(T) <= 4)
    return 4;
  else
    return 8;
  // For 16-byte atomics we also use 8-byte memory access,
  // this leads to false negatives only in very obscure cases.
}

#if !SANITIZER_GO
static atomic_uint8_t *to_atomic(const volatile a8 *a) {
  return reinterpret_cast<atomic_uint8_t *>(const_cast<a8 *>(a));
}

static atomic_uint16_t *to_atomic(const volatile a16 *a) {
  return reinterpret_cast<atomic_uint16_t *>(const_cast<a16 *>(a));
}
#endif

static atomic_uint32_t *to_atomic(const volatile a32 *a) {
  return reinterpret_cast<atomic_uint32_t *>(const_cast<a32 *>(a));
}

static atomic_uint64_t *to_atomic(const volatile a64 *a) {
  return reinterpret_cast<atomic_uint64_t *>(const_cast<a64 *>(a));
}

static memory_order to_mo(morder mo) {
  switch (mo) {
    case mo_relaxed:
      return memory_order_relaxed;
    case mo_consume:
      return memory_order_consume;
    case mo_acquire:
      return memory_order_acquire;
    case mo_release:
      return memory_order_release;
    case mo_acq_rel:
      return memory_order_acq_rel;
    case mo_seq_cst:
      return memory_order_seq_cst;
  }
  DCHECK(0);
  return memory_order_seq_cst;
}

namespace {

template <typename T, T (*F)(volatile T *v, T op)>
static T AtomicRMW(ThreadState *thr, uptr pc, volatile T *a, T v, morder mo) {
  MemoryAccess(thr, pc, (uptr)a, AccessSize<T>(), kAccessWrite | kAccessAtomic);
  if (LIKELY(mo == mo_relaxed))
    return F(a, v);
  SlotLocker locker(thr);
  {
    auto s = ctx->metamap.GetSyncOrCreate(thr, pc, (uptr)a, false);
    RWLock lock(&s->mtx, IsReleaseOrder(mo));
    if (IsAcqRelOrder(mo))
      thr->clock.ReleaseAcquire(&s->clock);
    else if (IsReleaseOrder(mo))
      thr->clock.Release(&s->clock);
    else if (IsAcquireOrder(mo))
      thr->clock.Acquire(s->clock);
    v = F(a, v);
  }
  if (IsReleaseOrder(mo))
    IncrementEpoch(thr);
  return v;
}

struct OpLoad {
  template <typename T>
  static T NoTsanAtomic(morder mo, const volatile T *a) {
    return atomic_load(to_atomic(a), to_mo(mo));
  }

#if __TSAN_HAS_INT128 && !SANITIZER_GO
  static a128 NoTsanAtomic(morder mo, const volatile a128 *a) {
    SpinMutexLock lock(&mutex128);
    return *a;
  }
#endif

  template <typename T>
  static T Atomic(ThreadState *thr, uptr pc, morder mo, const volatile T *a) {
    DCHECK(IsLoadOrder(mo));
    // This fast-path is critical for performance.
    // Assume the access is atomic.
    if (!IsAcquireOrder(mo)) {
      MemoryAccess(thr, pc, (uptr)a, AccessSize<T>(),
                   kAccessRead | kAccessAtomic);
      return NoTsanAtomic(mo, a);
    }
    // Don't create sync object if it does not exist yet. For example, an atomic
    // pointer is initialized to nullptr and then periodically acquire-loaded.
    T v = NoTsanAtomic(mo, a);
    SyncVar *s = ctx->metamap.GetSyncIfExists((uptr)a);
    if (s) {
      SlotLocker locker(thr);
      ReadLock lock(&s->mtx);
      thr->clock.Acquire(s->clock);
      // Re-read under sync mutex because we need a consistent snapshot
      // of the value and the clock we acquire.
      v = NoTsanAtomic(mo, a);
    }
    MemoryAccess(thr, pc, (uptr)a, AccessSize<T>(),
                 kAccessRead | kAccessAtomic);
    return v;
  }
};

struct OpStore {
  template <typename T>
  static void NoTsanAtomic(morder mo, volatile T *a, T v) {
    atomic_store(to_atomic(a), v, to_mo(mo));
  }

#if __TSAN_HAS_INT128 && !SANITIZER_GO
  static void NoTsanAtomic(morder mo, volatile a128 *a, a128 v) {
    SpinMutexLock lock(&mutex128);
    *a = v;
  }
#endif

  template <typename T>
  static void Atomic(ThreadState *thr, uptr pc, morder mo, volatile T *a, T v) {
    DCHECK(IsStoreOrder(mo));
    MemoryAccess(thr, pc, (uptr)a, AccessSize<T>(),
                 kAccessWrite | kAccessAtomic);
    // This fast-path is critical for performance.
    // Assume the access is atomic.
    // Strictly saying even relaxed store cuts off release sequence,
    // so must reset the clock.
    if (!IsReleaseOrder(mo)) {
      NoTsanAtomic(mo, a, v);
      return;
    }
    SlotLocker locker(thr);
    {
      auto s = ctx->metamap.GetSyncOrCreate(thr, pc, (uptr)a, false);
      Lock lock(&s->mtx);
      thr->clock.ReleaseStore(&s->clock);
      NoTsanAtomic(mo, a, v);
    }
    IncrementEpoch(thr);
  }
};

struct OpExchange {
  template <typename T>
  static T NoTsanAtomic(morder mo, volatile T *a, T v) {
    return func_xchg(a, v);
  }
  template <typename T>
  static T Atomic(ThreadState *thr, uptr pc, morder mo, volatile T *a, T v) {
    return AtomicRMW<T, func_xchg>(thr, pc, a, v, mo);
  }
};

struct OpFetchAdd {
  template <typename T>
  static T NoTsanAtomic(morder mo, volatile T *a, T v) {
    return func_add(a, v);
  }

  template <typename T>
  static T Atomic(ThreadState *thr, uptr pc, morder mo, volatile T *a, T v) {
    return AtomicRMW<T, func_add>(thr, pc, a, v, mo);
  }
};

struct OpFetchSub {
  template <typename T>
  static T NoTsanAtomic(morder mo, volatile T *a, T v) {
    return func_sub(a, v);
  }

  template <typename T>
  static T Atomic(ThreadState *thr, uptr pc, morder mo, volatile T *a, T v) {
    return AtomicRMW<T, func_sub>(thr, pc, a, v, mo);
  }
};

struct OpFetchAnd {
  template <typename T>
  static T NoTsanAtomic(morder mo, volatile T *a, T v) {
    return func_and(a, v);
  }

  template <typename T>
  static T Atomic(ThreadState *thr, uptr pc, morder mo, volatile T *a, T v) {
    return AtomicRMW<T, func_and>(thr, pc, a, v, mo);
  }
};

struct OpFetchOr {
  template <typename T>
  static T NoTsanAtomic(morder mo, volatile T *a, T v) {
    return func_or(a, v);
  }

  template <typename T>
  static T Atomic(ThreadState *thr, uptr pc, morder mo, volatile T *a, T v) {
    return AtomicRMW<T, func_or>(thr, pc, a, v, mo);
  }
};

struct OpFetchXor {
  template <typename T>
  static T NoTsanAtomic(morder mo, volatile T *a, T v) {
    return func_xor(a, v);
  }

  template <typename T>
  static T Atomic(ThreadState *thr, uptr pc, morder mo, volatile T *a, T v) {
    return AtomicRMW<T, func_xor>(thr, pc, a, v, mo);
  }
};

struct OpFetchNand {
  template <typename T>
  static T NoTsanAtomic(morder mo, volatile T *a, T v) {
    return func_nand(a, v);
  }

  template <typename T>
  static T Atomic(ThreadState *thr, uptr pc, morder mo, volatile T *a, T v) {
    return AtomicRMW<T, func_nand>(thr, pc, a, v, mo);
  }
};

struct OpCAS {
  template <typename T>
  static bool NoTsanAtomic(morder mo, morder fmo, volatile T *a, T *c, T v) {
    return atomic_compare_exchange_strong(to_atomic(a), c, v, to_mo(mo));
  }

#if __TSAN_HAS_INT128
  static bool NoTsanAtomic(morder mo, morder fmo, volatile a128 *a, a128 *c,
                           a128 v) {
    a128 old = *c;
    a128 cur = func_cas(a, old, v);
    if (cur == old)
      return true;
    *c = cur;
    return false;
  }
#endif

  template <typename T>
  static T NoTsanAtomic(morder mo, morder fmo, volatile T *a, T c, T v) {
    NoTsanAtomic(mo, fmo, a, &c, v);
    return c;
  }

  template <typename T>
  static bool Atomic(ThreadState *thr, uptr pc, morder mo, morder fmo,
                     volatile T *a, T *c, T v) {
    // 31.7.2.18: "The failure argument shall not be memory_order_release
    // nor memory_order_acq_rel". LLVM (2021-05) fallbacks to Monotonic
    // (mo_relaxed) when those are used.
    DCHECK(IsLoadOrder(fmo));

    MemoryAccess(thr, pc, (uptr)a, AccessSize<T>(),
                 kAccessWrite | kAccessAtomic);
    if (LIKELY(mo == mo_relaxed && fmo == mo_relaxed)) {
      T cc = *c;
      T pr = func_cas(a, cc, v);
      if (pr == cc)
        return true;
      *c = pr;
      return false;
    }
    SlotLocker locker(thr);
    bool release = IsReleaseOrder(mo);
    bool success;
    {
      auto s = ctx->metamap.GetSyncOrCreate(thr, pc, (uptr)a, false);
      RWLock lock(&s->mtx, release);
      T cc = *c;
      T pr = func_cas(a, cc, v);
      success = pr == cc;
      if (!success) {
        *c = pr;
        mo = fmo;
      }
      if (success && IsAcqRelOrder(mo))
        thr->clock.ReleaseAcquire(&s->clock);
      else if (success && IsReleaseOrder(mo))
        thr->clock.Release(&s->clock);
      else if (IsAcquireOrder(mo))
        thr->clock.Acquire(s->clock);
    }
    if (success && release)
      IncrementEpoch(thr);
    return success;
  }

  template <typename T>
  static T Atomic(ThreadState *thr, uptr pc, morder mo, morder fmo,
                  volatile T *a, T c, T v) {
    Atomic(thr, pc, mo, fmo, a, &c, v);
    return c;
  }
};

#if !SANITIZER_GO
struct OpFence {
  static void NoTsanAtomic(morder mo) { __sync_synchronize(); }

  static void Atomic(ThreadState *thr, uptr pc, morder mo) {
    // FIXME(dvyukov): not implemented.
    __sync_synchronize();
  }
};
#endif

}  // namespace

// Interface functions follow.
#if !SANITIZER_GO

// C/C++

static morder convert_morder(morder mo) {
  return flags()->force_seq_cst_atomics ? mo_seq_cst : mo;
}

static morder to_morder(int mo) {
  // Filter out additional memory order flags:
  // MEMMODEL_SYNC        = 1 << 15
  // __ATOMIC_HLE_ACQUIRE = 1 << 16
  // __ATOMIC_HLE_RELEASE = 1 << 17
  //
  // HLE is an optimization, and we pretend that elision always fails.
  // MEMMODEL_SYNC is used when lowering __sync_ atomics,
  // since we use __sync_ atomics for actual atomic operations,
  // we can safely ignore it as well. It also subtly affects semantics,
  // but we don't model the difference.
  morder res = static_cast<morder>(static_cast<u8>(mo));
  DCHECK_LE(res, mo_seq_cst);
  return res;
}

template <class Op, class... Types>
ALWAYS_INLINE auto AtomicImpl(morder mo, Types... args) {
  ThreadState *const thr = cur_thread();
  ProcessPendingSignals(thr);
  if (UNLIKELY(thr->ignore_sync || thr->ignore_interceptors))
    return Op::NoTsanAtomic(mo, args...);
  return Op::Atomic(thr, GET_CALLER_PC(), convert_morder(mo), args...);
}

extern "C" {
SANITIZER_INTERFACE_ATTRIBUTE
a8 __tsan_atomic8_load(const volatile a8 *a, int mo) {
  return AtomicImpl<OpLoad>(to_morder(mo), a);
}

SANITIZER_INTERFACE_ATTRIBUTE
a16 __tsan_atomic16_load(const volatile a16 *a, int mo) {
  return AtomicImpl<OpLoad>(to_morder(mo), a);
}

SANITIZER_INTERFACE_ATTRIBUTE
a32 __tsan_atomic32_load(const volatile a32 *a, int mo) {
  return AtomicImpl<OpLoad>(to_morder(mo), a);
}

SANITIZER_INTERFACE_ATTRIBUTE
a64 __tsan_atomic64_load(const volatile a64 *a, int mo) {
  return AtomicImpl<OpLoad>(to_morder(mo), a);
}

#  if __TSAN_HAS_INT128
SANITIZER_INTERFACE_ATTRIBUTE
a128 __tsan_atomic128_load(const volatile a128 *a, int mo) {
  return AtomicImpl<OpLoad>(to_morder(mo), a);
}
#  endif

SANITIZER_INTERFACE_ATTRIBUTE
void __tsan_atomic8_store(volatile a8 *a, a8 v, int mo) {
  return AtomicImpl<OpStore>(to_morder(mo), a, v);
}

SANITIZER_INTERFACE_ATTRIBUTE
void __tsan_atomic16_store(volatile a16 *a, a16 v, int mo) {
  return AtomicImpl<OpStore>(to_morder(mo), a, v);
}

SANITIZER_INTERFACE_ATTRIBUTE
void __tsan_atomic32_store(volatile a32 *a, a32 v, int mo) {
  return AtomicImpl<OpStore>(to_morder(mo), a, v);
}

SANITIZER_INTERFACE_ATTRIBUTE
void __tsan_atomic64_store(volatile a64 *a, a64 v, int mo) {
  return AtomicImpl<OpStore>(to_morder(mo), a, v);
}

#  if __TSAN_HAS_INT128
SANITIZER_INTERFACE_ATTRIBUTE
void __tsan_atomic128_store(volatile a128 *a, a128 v, int mo) {
  return AtomicImpl<OpStore>(to_morder(mo), a, v);
}
#  endif

SANITIZER_INTERFACE_ATTRIBUTE
a8 __tsan_atomic8_exchange(volatile a8 *a, a8 v, int mo) {
  return AtomicImpl<OpExchange>(to_morder(mo), a, v);
}

SANITIZER_INTERFACE_ATTRIBUTE
a16 __tsan_atomic16_exchange(volatile a16 *a, a16 v, int mo) {
  return AtomicImpl<OpExchange>(to_morder(mo), a, v);
}

SANITIZER_INTERFACE_ATTRIBUTE
a32 __tsan_atomic32_exchange(volatile a32 *a, a32 v, int mo) {
  return AtomicImpl<OpExchange>(to_morder(mo), a, v);
}

SANITIZER_INTERFACE_ATTRIBUTE
a64 __tsan_atomic64_exchange(volatile a64 *a, a64 v, int mo) {
  return AtomicImpl<OpExchange>(to_morder(mo), a, v);
}

#  if __TSAN_HAS_INT128
SANITIZER_INTERFACE_ATTRIBUTE
a128 __tsan_atomic128_exchange(volatile a128 *a, a128 v, int mo) {
  return AtomicImpl<OpExchange>(to_morder(mo), a, v);
}
#  endif

SANITIZER_INTERFACE_ATTRIBUTE
a8 __tsan_atomic8_fetch_add(volatile a8 *a, a8 v, int mo) {
  return AtomicImpl<OpFetchAdd>(to_morder(mo), a, v);
}

SANITIZER_INTERFACE_ATTRIBUTE
a16 __tsan_atomic16_fetch_add(volatile a16 *a, a16 v, int mo) {
  return AtomicImpl<OpFetchAdd>(to_morder(mo), a, v);
}

SANITIZER_INTERFACE_ATTRIBUTE
a32 __tsan_atomic32_fetch_add(volatile a32 *a, a32 v, int mo) {
  return AtomicImpl<OpFetchAdd>(to_morder(mo), a, v);
}

SANITIZER_INTERFACE_ATTRIBUTE
a64 __tsan_atomic64_fetch_add(volatile a64 *a, a64 v, int mo) {
  return AtomicImpl<OpFetchAdd>(to_morder(mo), a, v);
}

#  if __TSAN_HAS_INT128
SANITIZER_INTERFACE_ATTRIBUTE
a128 __tsan_atomic128_fetch_add(volatile a128 *a, a128 v, int mo) {
  return AtomicImpl<OpFetchAdd>(to_morder(mo), a, v);
}
#  endif

SANITIZER_INTERFACE_ATTRIBUTE
a8 __tsan_atomic8_fetch_sub(volatile a8 *a, a8 v, int mo) {
  return AtomicImpl<OpFetchSub>(to_morder(mo), a, v);
}

SANITIZER_INTERFACE_ATTRIBUTE
a16 __tsan_atomic16_fetch_sub(volatile a16 *a, a16 v, int mo) {
  return AtomicImpl<OpFetchSub>(to_morder(mo), a, v);
}

SANITIZER_INTERFACE_ATTRIBUTE
a32 __tsan_atomic32_fetch_sub(volatile a32 *a, a32 v, int mo) {
  return AtomicImpl<OpFetchSub>(to_morder(mo), a, v);
}

SANITIZER_INTERFACE_ATTRIBUTE
a64 __tsan_atomic64_fetch_sub(volatile a64 *a, a64 v, int mo) {
  return AtomicImpl<OpFetchSub>(to_morder(mo), a, v);
}

#  if __TSAN_HAS_INT128
SANITIZER_INTERFACE_ATTRIBUTE
a128 __tsan_atomic128_fetch_sub(volatile a128 *a, a128 v, int mo) {
  return AtomicImpl<OpFetchSub>(to_morder(mo), a, v);
}
#  endif

SANITIZER_INTERFACE_ATTRIBUTE
a8 __tsan_atomic8_fetch_and(volatile a8 *a, a8 v, int mo) {
  return AtomicImpl<OpFetchAnd>(to_morder(mo), a, v);
}

SANITIZER_INTERFACE_ATTRIBUTE
a16 __tsan_atomic16_fetch_and(volatile a16 *a, a16 v, int mo) {
  return AtomicImpl<OpFetchAnd>(to_morder(mo), a, v);
}

SANITIZER_INTERFACE_ATTRIBUTE
a32 __tsan_atomic32_fetch_and(volatile a32 *a, a32 v, int mo) {
  return AtomicImpl<OpFetchAnd>(to_morder(mo), a, v);
}

SANITIZER_INTERFACE_ATTRIBUTE
a64 __tsan_atomic64_fetch_and(volatile a64 *a, a64 v, int mo) {
  return AtomicImpl<OpFetchAnd>(to_morder(mo), a, v);
}

#  if __TSAN_HAS_INT128
SANITIZER_INTERFACE_ATTRIBUTE
a128 __tsan_atomic128_fetch_and(volatile a128 *a, a128 v, int mo) {
  return AtomicImpl<OpFetchAnd>(to_morder(mo), a, v);
}
#  endif

SANITIZER_INTERFACE_ATTRIBUTE
a8 __tsan_atomic8_fetch_or(volatile a8 *a, a8 v, int mo) {
  return AtomicImpl<OpFetchOr>(to_morder(mo), a, v);
}

SANITIZER_INTERFACE_ATTRIBUTE
a16 __tsan_atomic16_fetch_or(volatile a16 *a, a16 v, int mo) {
  return AtomicImpl<OpFetchOr>(to_morder(mo), a, v);
}

SANITIZER_INTERFACE_ATTRIBUTE
a32 __tsan_atomic32_fetch_or(volatile a32 *a, a32 v, int mo) {
  return AtomicImpl<OpFetchOr>(to_morder(mo), a, v);
}

SANITIZER_INTERFACE_ATTRIBUTE
a64 __tsan_atomic64_fetch_or(volatile a64 *a, a64 v, int mo) {
  return AtomicImpl<OpFetchOr>(to_morder(mo), a, v);
}

#  if __TSAN_HAS_INT128
SANITIZER_INTERFACE_ATTRIBUTE
a128 __tsan_atomic128_fetch_or(volatile a128 *a, a128 v, int mo) {
  return AtomicImpl<OpFetchOr>(to_morder(mo), a, v);
}
#  endif

SANITIZER_INTERFACE_ATTRIBUTE
a8 __tsan_atomic8_fetch_xor(volatile a8 *a, a8 v, int mo) {
  return AtomicImpl<OpFetchXor>(to_morder(mo), a, v);
}

SANITIZER_INTERFACE_ATTRIBUTE
a16 __tsan_atomic16_fetch_xor(volatile a16 *a, a16 v, int mo) {
  return AtomicImpl<OpFetchXor>(to_morder(mo), a, v);
}

SANITIZER_INTERFACE_ATTRIBUTE
a32 __tsan_atomic32_fetch_xor(volatile a32 *a, a32 v, int mo) {
  return AtomicImpl<OpFetchXor>(to_morder(mo), a, v);
}

SANITIZER_INTERFACE_ATTRIBUTE
a64 __tsan_atomic64_fetch_xor(volatile a64 *a, a64 v, int mo) {
  return AtomicImpl<OpFetchXor>(to_morder(mo), a, v);
}

#  if __TSAN_HAS_INT128
SANITIZER_INTERFACE_ATTRIBUTE
a128 __tsan_atomic128_fetch_xor(volatile a128 *a, a128 v, int mo) {
  return AtomicImpl<OpFetchXor>(to_morder(mo), a, v);
}
#  endif

SANITIZER_INTERFACE_ATTRIBUTE
a8 __tsan_atomic8_fetch_nand(volatile a8 *a, a8 v, int mo) {
  return AtomicImpl<OpFetchNand>(to_morder(mo), a, v);
}

SANITIZER_INTERFACE_ATTRIBUTE
a16 __tsan_atomic16_fetch_nand(volatile a16 *a, a16 v, int mo) {
  return AtomicImpl<OpFetchNand>(to_morder(mo), a, v);
}

SANITIZER_INTERFACE_ATTRIBUTE
a32 __tsan_atomic32_fetch_nand(volatile a32 *a, a32 v, int mo) {
  return AtomicImpl<OpFetchNand>(to_morder(mo), a, v);
}

SANITIZER_INTERFACE_ATTRIBUTE
a64 __tsan_atomic64_fetch_nand(volatile a64 *a, a64 v, int mo) {
  return AtomicImpl<OpFetchNand>(to_morder(mo), a, v);
}

#  if __TSAN_HAS_INT128
SANITIZER_INTERFACE_ATTRIBUTE
a128 __tsan_atomic128_fetch_nand(volatile a128 *a, a128 v, int mo) {
  return AtomicImpl<OpFetchNand>(to_morder(mo), a, v);
}
#  endif

SANITIZER_INTERFACE_ATTRIBUTE
int __tsan_atomic8_compare_exchange_strong(volatile a8 *a, a8 *c, a8 v, int mo,
                                           int fmo) {
  return AtomicImpl<OpCAS>(to_morder(mo), to_morder(fmo), a, c, v);
}

SANITIZER_INTERFACE_ATTRIBUTE
int __tsan_atomic16_compare_exchange_strong(volatile a16 *a, a16 *c, a16 v,
                                            int mo, int fmo) {
  return AtomicImpl<OpCAS>(to_morder(mo), to_morder(fmo), a, c, v);
}

SANITIZER_INTERFACE_ATTRIBUTE
int __tsan_atomic32_compare_exchange_strong(volatile a32 *a, a32 *c, a32 v,
                                            int mo, int fmo) {
  return AtomicImpl<OpCAS>(to_morder(mo), to_morder(fmo), a, c, v);
}

SANITIZER_INTERFACE_ATTRIBUTE
int __tsan_atomic64_compare_exchange_strong(volatile a64 *a, a64 *c, a64 v,
                                            int mo, int fmo) {
  return AtomicImpl<OpCAS>(to_morder(mo), to_morder(fmo), a, c, v);
}

#  if __TSAN_HAS_INT128
SANITIZER_INTERFACE_ATTRIBUTE
int __tsan_atomic128_compare_exchange_strong(volatile a128 *a, a128 *c, a128 v,
                                             int mo, int fmo) {
  return AtomicImpl<OpCAS>(to_morder(mo), to_morder(fmo), a, c, v);
}
#  endif

SANITIZER_INTERFACE_ATTRIBUTE
int __tsan_atomic8_compare_exchange_weak(volatile a8 *a, a8 *c, a8 v, int mo,
                                         int fmo) {
  return AtomicImpl<OpCAS>(to_morder(mo), to_morder(fmo), a, c, v);
}

SANITIZER_INTERFACE_ATTRIBUTE
int __tsan_atomic16_compare_exchange_weak(volatile a16 *a, a16 *c, a16 v,
                                          int mo, int fmo) {
  return AtomicImpl<OpCAS>(to_morder(mo), to_morder(fmo), a, c, v);
}

SANITIZER_INTERFACE_ATTRIBUTE
int __tsan_atomic32_compare_exchange_weak(volatile a32 *a, a32 *c, a32 v,
                                          int mo, int fmo) {
  return AtomicImpl<OpCAS>(to_morder(mo), to_morder(fmo), a, c, v);
}

SANITIZER_INTERFACE_ATTRIBUTE
int __tsan_atomic64_compare_exchange_weak(volatile a64 *a, a64 *c, a64 v,
                                          int mo, int fmo) {
  return AtomicImpl<OpCAS>(to_morder(mo), to_morder(fmo), a, c, v);
}

#  if __TSAN_HAS_INT128
SANITIZER_INTERFACE_ATTRIBUTE
int __tsan_atomic128_compare_exchange_weak(volatile a128 *a, a128 *c, a128 v,
                                           int mo, int fmo) {
  return AtomicImpl<OpCAS>(to_morder(mo), to_morder(fmo), a, c, v);
}
#  endif

SANITIZER_INTERFACE_ATTRIBUTE
a8 __tsan_atomic8_compare_exchange_val(volatile a8 *a, a8 c, a8 v, int mo,
                                       int fmo) {
  return AtomicImpl<OpCAS>(to_morder(mo), to_morder(fmo), a, c, v);
}

SANITIZER_INTERFACE_ATTRIBUTE
a16 __tsan_atomic16_compare_exchange_val(volatile a16 *a, a16 c, a16 v, int mo,
                                         int fmo) {
  return AtomicImpl<OpCAS>(to_morder(mo), to_morder(fmo), a, c, v);
}

SANITIZER_INTERFACE_ATTRIBUTE
a32 __tsan_atomic32_compare_exchange_val(volatile a32 *a, a32 c, a32 v, int mo,
                                         int fmo) {
  return AtomicImpl<OpCAS>(to_morder(mo), to_morder(fmo), a, c, v);
}

SANITIZER_INTERFACE_ATTRIBUTE
a64 __tsan_atomic64_compare_exchange_val(volatile a64 *a, a64 c, a64 v, int mo,
                                         int fmo) {
  return AtomicImpl<OpCAS>(to_morder(mo), to_morder(fmo), a, c, v);
}

#  if __TSAN_HAS_INT128
SANITIZER_INTERFACE_ATTRIBUTE
a128 __tsan_atomic128_compare_exchange_val(volatile a128 *a, a128 c, a128 v,
                                           int mo, int fmo) {
  return AtomicImpl<OpCAS>(to_morder(mo), to_morder(fmo), a, c, v);
}
#  endif

SANITIZER_INTERFACE_ATTRIBUTE
void __tsan_atomic_thread_fence(int mo) {
  return AtomicImpl<OpFence>(to_morder(mo));
}

SANITIZER_INTERFACE_ATTRIBUTE
void __tsan_atomic_signal_fence(int mo) {}
}  // extern "C"

#else  // #if !SANITIZER_GO

// Go

template <class Op, class... Types>
void AtomicGo(ThreadState *thr, uptr cpc, uptr pc, Types... args) {
  if (thr->ignore_sync) {
    (void)Op::NoTsanAtomic(args...);
  } else {
    FuncEntry(thr, cpc);
    (void)Op::Atomic(thr, pc, args...);
    FuncExit(thr);
  }
}

template <class Op, class... Types>
auto AtomicGoRet(ThreadState *thr, uptr cpc, uptr pc, Types... args) {
  if (thr->ignore_sync) {
    return Op::NoTsanAtomic(args...);
  } else {
    FuncEntry(thr, cpc);
    auto ret = Op::Atomic(thr, pc, args...);
    FuncExit(thr);
    return ret;
  }
}

extern "C" {
SANITIZER_INTERFACE_ATTRIBUTE
void __tsan_go_atomic32_load(ThreadState *thr, uptr cpc, uptr pc, u8 *a) {
  *(a32 *)(a + 8) = AtomicGoRet<OpLoad>(thr, cpc, pc, mo_acquire, *(a32 **)a);
}

SANITIZER_INTERFACE_ATTRIBUTE
void __tsan_go_atomic64_load(ThreadState *thr, uptr cpc, uptr pc, u8 *a) {
  *(a64 *)(a + 8) = AtomicGoRet<OpLoad>(thr, cpc, pc, mo_acquire, *(a64 **)a);
}

SANITIZER_INTERFACE_ATTRIBUTE
void __tsan_go_atomic32_store(ThreadState *thr, uptr cpc, uptr pc, u8 *a) {
  AtomicGo<OpStore>(thr, cpc, pc, mo_release, *(a32 **)a, *(a32 *)(a + 8));
}

SANITIZER_INTERFACE_ATTRIBUTE
void __tsan_go_atomic64_store(ThreadState *thr, uptr cpc, uptr pc, u8 *a) {
  AtomicGo<OpStore>(thr, cpc, pc, mo_release, *(a64 **)a, *(a64 *)(a + 8));
}

SANITIZER_INTERFACE_ATTRIBUTE
void __tsan_go_atomic32_fetch_add(ThreadState *thr, uptr cpc, uptr pc, u8 *a) {
  *(a32 *)(a + 16) = AtomicGoRet<OpFetchAdd>(thr, cpc, pc, mo_acq_rel,
                                             *(a32 **)a, *(a32 *)(a + 8));
}

SANITIZER_INTERFACE_ATTRIBUTE
void __tsan_go_atomic64_fetch_add(ThreadState *thr, uptr cpc, uptr pc, u8 *a) {
  *(a64 *)(a + 16) = AtomicGoRet<OpFetchAdd>(thr, cpc, pc, mo_acq_rel,
                                             *(a64 **)a, *(a64 *)(a + 8));
}

SANITIZER_INTERFACE_ATTRIBUTE
void __tsan_go_atomic32_fetch_and(ThreadState *thr, uptr cpc, uptr pc, u8 *a) {
  *(a32 *)(a + 16) = AtomicGoRet<OpFetchAnd>(thr, cpc, pc, mo_acq_rel,
                                             *(a32 **)a, *(a32 *)(a + 8));
}

SANITIZER_INTERFACE_ATTRIBUTE
void __tsan_go_atomic64_fetch_and(ThreadState *thr, uptr cpc, uptr pc, u8 *a) {
  *(a64 *)(a + 16) = AtomicGoRet<OpFetchAnd>(thr, cpc, pc, mo_acq_rel,
                                             *(a64 **)a, *(a64 *)(a + 8));
}

SANITIZER_INTERFACE_ATTRIBUTE
void __tsan_go_atomic32_fetch_or(ThreadState *thr, uptr cpc, uptr pc, u8 *a) {
  *(a32 *)(a + 16) = AtomicGoRet<OpFetchOr>(thr, cpc, pc, mo_acq_rel,
                                            *(a32 **)a, *(a32 *)(a + 8));
}

SANITIZER_INTERFACE_ATTRIBUTE
void __tsan_go_atomic64_fetch_or(ThreadState *thr, uptr cpc, uptr pc, u8 *a) {
  *(a64 *)(a + 16) = AtomicGoRet<OpFetchOr>(thr, cpc, pc, mo_acq_rel,
                                            *(a64 **)a, *(a64 *)(a + 8));
}

SANITIZER_INTERFACE_ATTRIBUTE
void __tsan_go_atomic32_exchange(ThreadState *thr, uptr cpc, uptr pc, u8 *a) {
  *(a32 *)(a + 16) = AtomicGoRet<OpExchange>(thr, cpc, pc, mo_acq_rel,
                                             *(a32 **)a, *(a32 *)(a + 8));
}

SANITIZER_INTERFACE_ATTRIBUTE
void __tsan_go_atomic64_exchange(ThreadState *thr, uptr cpc, uptr pc, u8 *a) {
  *(a64 *)(a + 16) = AtomicGoRet<OpExchange>(thr, cpc, pc, mo_acq_rel,
                                             *(a64 **)a, *(a64 *)(a + 8));
}

SANITIZER_INTERFACE_ATTRIBUTE
void __tsan_go_atomic32_compare_exchange(ThreadState *thr, uptr cpc, uptr pc,
                                         u8 *a) {
  a32 cmp = *(a32 *)(a + 8);
  a32 cur = AtomicGoRet<OpCAS>(thr, cpc, pc, mo_acq_rel, mo_acquire, *(a32 **)a,
                               cmp, *(a32 *)(a + 12));
  *(bool *)(a + 16) = (cur == cmp);
}

SANITIZER_INTERFACE_ATTRIBUTE
void __tsan_go_atomic64_compare_exchange(ThreadState *thr, uptr cpc, uptr pc,
                                         u8 *a) {
  a64 cmp = *(a64 *)(a + 8);
  a64 cur = AtomicGoRet<OpCAS>(thr, cpc, pc, mo_acq_rel, mo_acquire, *(a64 **)a,
                               cmp, *(a64 *)(a + 16));
  *(bool *)(a + 24) = (cur == cmp);
}
}  // extern "C"
#endif  // #if !SANITIZER_GO
