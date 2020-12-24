//===-- tsan_clock.h --------------------------------------------*- C++ -*-===//
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
#ifndef TSAN_CLOCK_H
#define TSAN_CLOCK_H

#include "tsan_defs.h"
#include "tsan_dense_alloc.h"

namespace __tsan {

typedef DenseSlabAlloc<ClockBlock, 1<<16, 1<<10> ClockAlloc;
typedef DenseSlabAllocCache ClockCache;

// The clock that lives in sync variables (mutexes, atomics, etc).
class SyncClock {
 public:
  SyncClock();
  ~SyncClock();

  uptr size() const;

  // These are used only in tests.
  u64 get(unsigned tid) const;
  u64 get_clean(unsigned tid) const;

  void Resize(ClockCache *c, uptr nclk);
  void Reset(ClockCache *c);

  void DebugDump(int(*printf)(const char *s, ...));

  // Clock element iterator.
  // Note: it iterates only over the table without regard to dirty entries.
  class Iter {
   public:
    explicit Iter(SyncClock* parent);
    Iter& operator++();
    bool operator!=(const Iter& other);
    ClockElem &operator*();

   private:
    SyncClock *parent_;
    // [pos_, end_) is the current continuous range of clock elements.
    ClockElem *pos_;
    ClockElem *end_;
    int block_;  // Current number of second level block.

    NOINLINE void Next();
  };

  Iter begin();
  Iter end();

 private:
  friend class ThreadClock;
  friend class Iter;
  static const uptr kDirtyTids = 2;

  struct Dirty {
    u64 epoch  : kClkBits;
    u64 tid : 64 - kClkBits;  // kInvalidId if not active
  };

  unsigned release_store_tid_;
  unsigned release_store_reused_;
  Dirty dirty_[kDirtyTids];
  // If size_ is 0, tab_ is nullptr.
  // If size <= 64 (kClockCount), tab_ contains pointer to an array with
  // 64 ClockElem's (ClockBlock::clock).
  // Otherwise, tab_ points to an array with up to 127 u32 elements,
  // each pointing to the second-level 512b block with 64 ClockElem's.
  // Unused space in the first level ClockBlock is used to store additional
  // clock elements.
  // The last u32 element in the first level ClockBlock is always used as
  // reference counter.
  //
  // See the following scheme for details.
  // All memory blocks are 512 bytes (allocated from ClockAlloc).
  // Clock (clk) elements are 64 bits.
  // Idx and ref are 32 bits.
  //
  // tab_
  //    |
  //    \/
  //    +----------------------------------------------------+
  //    | clk128 | clk129 | ...unused... | idx1 | idx0 | ref |
  //    +----------------------------------------------------+
  //                                        |      |
  //                                        |      \/
  //                                        |      +----------------+
  //                                        |      | clk0 ... clk63 |
  //                                        |      +----------------+
  //                                        \/
  //                                        +------------------+
  //                                        | clk64 ... clk127 |
  //                                        +------------------+
  //
  // Note: dirty entries, if active, always override what's stored in the clock.
  ClockBlock *tab_;
  u32 tab_idx_;
  u16 size_;
  u16 blocks_;  // Number of second level blocks.

  void Unshare(ClockCache *c);
  bool IsShared() const;
  bool Cachable() const;
  void ResetImpl();
  void FlushDirty();
  uptr capacity() const;
  u32 get_block(uptr bi) const;
  void append_block(u32 idx);
  ClockElem &elem(unsigned tid) const;
};

// The clock that lives in threads.
class ThreadClock {
 public:
  typedef DenseSlabAllocCache Cache;

  explicit ThreadClock(unsigned tid, unsigned reused = 0);

  u64 get(unsigned tid) const;
  void set(ClockCache *c, unsigned tid, u64 v);
  void set(u64 v);
  void tick();
  uptr size() const;

  void acquire(ClockCache *c, SyncClock *src);
  void releaseStoreAcquire(ClockCache *c, SyncClock *src);
  void release(ClockCache *c, SyncClock *dst);
  void acq_rel(ClockCache *c, SyncClock *dst);
  void ReleaseStore(ClockCache *c, SyncClock *dst);
  void ResetCached(ClockCache *c);
  void NoteGlobalAcquire(u64 v);

  void DebugReset();
  void DebugDump(int(*printf)(const char *s, ...));

 private:
  static const uptr kDirtyTids = SyncClock::kDirtyTids;
  // Index of the thread associated with he clock ("current thread").
  const unsigned tid_;
  const unsigned reused_;  // tid_ reuse count.
  // Current thread time when it acquired something from other threads.
  u64 last_acquire_;

  // Last time another thread has done a global acquire of this thread's clock.
  // It helps to avoid problem described in:
  // https://github.com/golang/go/issues/39186
  // See test/tsan/java_finalizer2.cpp for a regression test.
  // Note the failuire is _extremely_ hard to hit, so if you are trying
  // to reproduce it, you may want to run something like:
  // $ go get golang.org/x/tools/cmd/stress
  // $ stress -p=64 ./a.out
  //
  // The crux of the problem is roughly as follows.
  // A number of O(1) optimizations in the clocks algorithm assume proper
  // transitive cumulative propagation of clock values. The AcquireGlobal
  // operation may produce an inconsistent non-linearazable view of
  // thread clocks. Namely, it may acquire a later value from a thread
  // with a higher ID, but fail to acquire an earlier value from a thread
  // with a lower ID. If a thread that executed AcquireGlobal then releases
  // to a sync clock, it will spoil the sync clock with the inconsistent
  // values. If another thread later releases to the sync clock, the optimized
  // algorithm may break.
  //
  // The exact sequence of events that leads to the failure.
  // - thread 1 executes AcquireGlobal
  // - thread 1 acquires value 1 for thread 2
  // - thread 2 increments clock to 2
  // - thread 2 releases to sync object 1
  // - thread 3 at time 1
  // - thread 3 acquires from sync object 1
  // - thread 3 increments clock to 2
  // - thread 1 acquires value 2 for thread 3
  // - thread 1 releases to sync object 2
  // - sync object 2 clock has 1 for thread 2 and 2 for thread 3
  // - thread 3 releases to sync object 2
  // - thread 3 sees value 2 in the clock for itself
  //   and decides that it has already released to the clock
  //   and did not acquire anything from other threads after that
  //   (the last_acquire_ check in release operation)
  // - thread 3 does not update the value for thread 2 in the clock from 1 to 2
  // - thread 4 acquires from sync object 2
  // - thread 4 detects a false race with thread 2
  //   as it should have been synchronized with thread 2 up to time 2,
  //   but because of the broken clock it is now synchronized only up to time 1
  //
  // The global_acquire_ value helps to prevent this scenario.
  // Namely, thread 3 will not trust any own clock values up to global_acquire_
  // for the purposes of the last_acquire_ optimization.
  atomic_uint64_t global_acquire_;

  // Cached SyncClock (without dirty entries and release_store_tid_).
  // We reuse it for subsequent store-release operations without intervening
  // acquire operations. Since it is shared (and thus constant), clock value
  // for the current thread is then stored in dirty entries in the SyncClock.
  // We host a refernece to the table while it is cached here.
  u32 cached_idx_;
  u16 cached_size_;
  u16 cached_blocks_;

  // Number of active elements in the clk_ table (the rest is zeros).
  uptr nclk_;
  u64 clk_[kMaxTidInClock];  // Fixed size vector clock.

  bool IsAlreadyAcquired(const SyncClock *src) const;
  bool HasAcquiredAfterRelease(const SyncClock *dst) const;
  void UpdateCurrentThread(ClockCache *c, SyncClock *dst) const;
};

ALWAYS_INLINE u64 ThreadClock::get(unsigned tid) const {
  DCHECK_LT(tid, kMaxTidInClock);
  return clk_[tid];
}

ALWAYS_INLINE void ThreadClock::set(u64 v) {
  DCHECK_GE(v, clk_[tid_]);
  clk_[tid_] = v;
}

ALWAYS_INLINE void ThreadClock::tick() {
  clk_[tid_]++;
}

ALWAYS_INLINE uptr ThreadClock::size() const {
  return nclk_;
}

ALWAYS_INLINE void ThreadClock::NoteGlobalAcquire(u64 v) {
  // Here we rely on the fact that AcquireGlobal is protected by
  // ThreadRegistryLock, thus only one thread at a time executes it
  // and values passed to this function should not go backwards.
  CHECK_LE(atomic_load_relaxed(&global_acquire_), v);
  atomic_store_relaxed(&global_acquire_, v);
}

ALWAYS_INLINE SyncClock::Iter SyncClock::begin() {
  return Iter(this);
}

ALWAYS_INLINE SyncClock::Iter SyncClock::end() {
  return Iter(nullptr);
}

ALWAYS_INLINE uptr SyncClock::size() const {
  return size_;
}

ALWAYS_INLINE SyncClock::Iter::Iter(SyncClock* parent)
    : parent_(parent)
    , pos_(nullptr)
    , end_(nullptr)
    , block_(-1) {
  if (parent)
    Next();
}

ALWAYS_INLINE SyncClock::Iter& SyncClock::Iter::operator++() {
  pos_++;
  if (UNLIKELY(pos_ >= end_))
    Next();
  return *this;
}

ALWAYS_INLINE bool SyncClock::Iter::operator!=(const SyncClock::Iter& other) {
  return parent_ != other.parent_;
}

ALWAYS_INLINE ClockElem &SyncClock::Iter::operator*() {
  return *pos_;
}
}  // namespace __tsan

#endif  // TSAN_CLOCK_H
