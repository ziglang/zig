//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
#ifndef LIBCXXABI_SRC_INCLUDE_CXA_GUARD_IMPL_H
#define LIBCXXABI_SRC_INCLUDE_CXA_GUARD_IMPL_H

/* cxa_guard_impl.h - Implements the C++ runtime support for function local
 * static guards.
 * The layout of the guard object is the same across ARM and Itanium.
 *
 * The first "guard byte" (which is checked by the compiler) is set only upon
 * the completion of cxa release.
 *
 * The second "init byte" does the rest of the bookkeeping. It tracks if
 * initialization is complete or pending, and if there are waiting threads.
 *
 * If the guard variable is 64-bits and the platforms supplies a 32-bit thread
 * identifier, it is used to detect recursive initialization. The thread ID of
 * the thread currently performing initialization is stored in the second word.
 *
 *  Guard Object Layout:
 * -------------------------------------------------------------------------
 * |a: guard byte | a+1: init byte | a+2 : unused ... | a+4: thread-id ... |
 * ------------------------------------------------------------------------
 *
 *  Access Protocol:
 *    For each implementation the guard byte is checked and set before accessing
 *    the init byte.
 *
 *  Overall Design:
 *    The implementation was designed to allow each implementation to be tested
 *    independent of the C++ runtime or platform support.
 *
 */

#include "__cxxabi_config.h"
#include "include/atomic_support.h"
#include <unistd.h>
#if defined(__has_include)
# if __has_include(<sys/syscall.h>)
#   include <sys/syscall.h>
# endif
#endif

#include <stdlib.h>
#include <__threading_support>
#ifndef _LIBCXXABI_HAS_NO_THREADS
#if defined(__ELF__) && defined(_LIBCXXABI_LINK_PTHREAD_LIB)
#pragma comment(lib, "pthread")
#endif
#endif

// To make testing possible, this header is included from both cxa_guard.cpp
// and a number of tests.
//
// For this reason we place everything in an anonymous namespace -- even though
// we're in a header. We want the actual implementation and the tests to have
// unique definitions of the types in this header (since the tests may depend
// on function local statics).
//
// To enforce this either `BUILDING_CXA_GUARD` or `TESTING_CXA_GUARD` must be
// defined when including this file. Only `src/cxa_guard.cpp` should define
// the former.
#ifdef BUILDING_CXA_GUARD
# include "abort_message.h"
# define ABORT_WITH_MESSAGE(...) ::abort_message(__VA_ARGS__)
#elif defined(TESTING_CXA_GUARD)
# define ABORT_WITH_MESSAGE(...) ::abort()
#else
# error "Either BUILDING_CXA_GUARD or TESTING_CXA_GUARD must be defined"
#endif

#if __has_feature(thread_sanitizer)
extern "C" void __tsan_acquire(void*);
extern "C" void __tsan_release(void*);
#else
#define __tsan_acquire(addr) ((void)0)
#define __tsan_release(addr) ((void)0)
#endif

namespace __cxxabiv1 {
// Use an anonymous namespace to ensure that the tests and actual implementation
// have unique definitions of these symbols.
namespace {

//===----------------------------------------------------------------------===//
//                          Misc Utilities
//===----------------------------------------------------------------------===//

template <class T, T(*Init)()>
struct LazyValue {
  LazyValue() : is_init(false) {}

  T& get() {
    if (!is_init) {
      value = Init();
      is_init = true;
    }
    return value;
  }
 private:
  T value;
  bool is_init = false;
};

template <class IntType>
class AtomicInt {
public:
  using MemoryOrder = std::__libcpp_atomic_order;

  explicit AtomicInt(IntType *b) : b(b) {}
  AtomicInt(AtomicInt const&) = delete;
  AtomicInt& operator=(AtomicInt const&) = delete;

  IntType load(MemoryOrder ord) {
    return std::__libcpp_atomic_load(b, ord);
  }
  void store(IntType val, MemoryOrder ord) {
    std::__libcpp_atomic_store(b, val, ord);
  }
  IntType exchange(IntType new_val, MemoryOrder ord) {
    return std::__libcpp_atomic_exchange(b, new_val, ord);
  }
  bool compare_exchange(IntType *expected, IntType desired, MemoryOrder ord_success, MemoryOrder ord_failure) {
    return std::__libcpp_atomic_compare_exchange(b, expected, desired, ord_success, ord_failure);
  }

private:
  IntType *b;
};

//===----------------------------------------------------------------------===//
//                       PlatformGetThreadID
//===----------------------------------------------------------------------===//

#if defined(__APPLE__) && defined(_LIBCPP_HAS_THREAD_API_PTHREAD)
uint32_t PlatformThreadID() {
  static_assert(sizeof(mach_port_t) == sizeof(uint32_t), "");
  return static_cast<uint32_t>(
      pthread_mach_thread_np(std::__libcpp_thread_get_current_id()));
}
#elif defined(SYS_gettid) && defined(_LIBCPP_HAS_THREAD_API_PTHREAD)
uint32_t PlatformThreadID() {
  static_assert(sizeof(pid_t) == sizeof(uint32_t), "");
  return static_cast<uint32_t>(syscall(SYS_gettid));
}
#else
constexpr uint32_t (*PlatformThreadID)() = nullptr;
#endif


constexpr bool PlatformSupportsThreadID() {
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-pointer-compare"
#endif
  return +PlatformThreadID != nullptr;
#ifdef __clang__
#pragma clang diagnostic pop
#endif
}

//===----------------------------------------------------------------------===//
//                          GuardBase
//===----------------------------------------------------------------------===//

enum class AcquireResult {
  INIT_IS_DONE,
  INIT_IS_PENDING,
};
constexpr AcquireResult INIT_IS_DONE = AcquireResult::INIT_IS_DONE;
constexpr AcquireResult INIT_IS_PENDING = AcquireResult::INIT_IS_PENDING;

static constexpr uint8_t UNSET = 0;
static constexpr uint8_t COMPLETE_BIT = (1 << 0);
static constexpr uint8_t PENDING_BIT = (1 << 1);
static constexpr uint8_t WAITING_BIT = (1 << 2);

template <class Derived>
struct GuardObject {
  GuardObject() = delete;
  GuardObject(GuardObject const&) = delete;
  GuardObject& operator=(GuardObject const&) = delete;

  explicit GuardObject(uint32_t* g)
      : base_address(g), guard_byte_address(reinterpret_cast<uint8_t*>(g)),
        init_byte_address(reinterpret_cast<uint8_t*>(g) + 1),
        thread_id_address(nullptr) {}

  explicit GuardObject(uint64_t* g)
      : base_address(g), guard_byte_address(reinterpret_cast<uint8_t*>(g)),
        init_byte_address(reinterpret_cast<uint8_t*>(g) + 1),
        thread_id_address(reinterpret_cast<uint32_t*>(g) + 1) {}

public:
  /// Implements __cxa_guard_acquire
  AcquireResult cxa_guard_acquire() {
    AtomicInt<uint8_t> guard_byte(guard_byte_address);
    if (guard_byte.load(std::_AO_Acquire) != UNSET)
      return INIT_IS_DONE;
    return derived()->acquire_init_byte();
  }

  /// Implements __cxa_guard_release
  void cxa_guard_release() {
    AtomicInt<uint8_t> guard_byte(guard_byte_address);
    // Store complete first, so that when release wakes other folks, they see
    // it as having been completed.
    guard_byte.store(COMPLETE_BIT, std::_AO_Release);
    derived()->release_init_byte();
  }

  /// Implements __cxa_guard_abort
  void cxa_guard_abort() { derived()->abort_init_byte(); }

public:
  /// base_address - the address of the original guard object.
  void* const base_address;
  /// The address of the guard byte at offset 0.
  uint8_t* const guard_byte_address;
  /// The address of the byte used by the implementation during initialization.
  uint8_t* const init_byte_address;
  /// An optional address storing an identifier for the thread performing initialization.
  /// It's used to detect recursive initialization.
  uint32_t* const thread_id_address;

private:
  Derived* derived() { return static_cast<Derived*>(this); }
};

//===----------------------------------------------------------------------===//
//                    Single Threaded Implementation
//===----------------------------------------------------------------------===//

struct InitByteNoThreads : GuardObject<InitByteNoThreads> {
  using GuardObject::GuardObject;

  AcquireResult acquire_init_byte() {
    if (*init_byte_address == COMPLETE_BIT)
      return INIT_IS_DONE;
    if (*init_byte_address & PENDING_BIT)
      ABORT_WITH_MESSAGE("__cxa_guard_acquire detected recursive initialization");
    *init_byte_address = PENDING_BIT;
    return INIT_IS_PENDING;
  }

  void release_init_byte() { *init_byte_address = COMPLETE_BIT; }
  void abort_init_byte() { *init_byte_address = UNSET; }
};


//===----------------------------------------------------------------------===//
//                     Global Mutex Implementation
//===----------------------------------------------------------------------===//

struct LibcppMutex;
struct LibcppCondVar;

#ifndef _LIBCXXABI_HAS_NO_THREADS
struct LibcppMutex {
  LibcppMutex() = default;
  LibcppMutex(LibcppMutex const&) = delete;
  LibcppMutex& operator=(LibcppMutex const&) = delete;

  bool lock() { return std::__libcpp_mutex_lock(&mutex); }
  bool unlock() { return std::__libcpp_mutex_unlock(&mutex); }

private:
  friend struct LibcppCondVar;
  std::__libcpp_mutex_t mutex = _LIBCPP_MUTEX_INITIALIZER;
};

struct LibcppCondVar {
  LibcppCondVar() = default;
  LibcppCondVar(LibcppCondVar const&) = delete;
  LibcppCondVar& operator=(LibcppCondVar const&) = delete;

  bool wait(LibcppMutex& mut) {
    return std::__libcpp_condvar_wait(&cond, &mut.mutex);
  }
  bool broadcast() { return std::__libcpp_condvar_broadcast(&cond); }

private:
  std::__libcpp_condvar_t cond = _LIBCPP_CONDVAR_INITIALIZER;
};
#else
struct LibcppMutex {};
struct LibcppCondVar {};
#endif // !defined(_LIBCXXABI_HAS_NO_THREADS)


template <class Mutex, class CondVar, Mutex& global_mutex, CondVar& global_cond,
          uint32_t (*GetThreadID)() = PlatformThreadID>
struct InitByteGlobalMutex
    : GuardObject<InitByteGlobalMutex<Mutex, CondVar, global_mutex, global_cond,
                                    GetThreadID>> {

  using BaseT = typename InitByteGlobalMutex::GuardObject;
  using BaseT::BaseT;

  explicit InitByteGlobalMutex(uint32_t *g)
    : BaseT(g), has_thread_id_support(false) {}
  explicit InitByteGlobalMutex(uint64_t *g)
    : BaseT(g), has_thread_id_support(PlatformSupportsThreadID()) {}

public:
  AcquireResult acquire_init_byte() {
    LockGuard g("__cxa_guard_acquire");
    // Check for possible recursive initialization.
    if (has_thread_id_support && (*init_byte_address & PENDING_BIT)) {
      if (*thread_id_address == current_thread_id.get())
       ABORT_WITH_MESSAGE("__cxa_guard_acquire detected recursive initialization");
    }

    // Wait until the pending bit is not set.
    while (*init_byte_address & PENDING_BIT) {
      *init_byte_address |= WAITING_BIT;
      global_cond.wait(global_mutex);
    }

    if (*init_byte_address == COMPLETE_BIT)
      return INIT_IS_DONE;

    if (has_thread_id_support)
      *thread_id_address = current_thread_id.get();

    *init_byte_address = PENDING_BIT;
    return INIT_IS_PENDING;
  }

  void release_init_byte() {
    bool has_waiting;
    {
      LockGuard g("__cxa_guard_release");
      has_waiting = *init_byte_address & WAITING_BIT;
      *init_byte_address = COMPLETE_BIT;
    }
    if (has_waiting) {
      if (global_cond.broadcast()) {
        ABORT_WITH_MESSAGE("%s failed to broadcast", "__cxa_guard_release");
      }
    }
  }

  void abort_init_byte() {
    bool has_waiting;
    {
      LockGuard g("__cxa_guard_abort");
      if (has_thread_id_support)
        *thread_id_address = 0;
      has_waiting = *init_byte_address & WAITING_BIT;
      *init_byte_address = UNSET;
    }
    if (has_waiting) {
      if (global_cond.broadcast()) {
        ABORT_WITH_MESSAGE("%s failed to broadcast", "__cxa_guard_abort");
      }
    }
  }

private:
  using BaseT::init_byte_address;
  using BaseT::thread_id_address;
  const bool has_thread_id_support;
  LazyValue<uint32_t, GetThreadID> current_thread_id;

private:
  struct LockGuard {
    LockGuard() = delete;
    LockGuard(LockGuard const&) = delete;
    LockGuard& operator=(LockGuard const&) = delete;

    explicit LockGuard(const char* calling_func)
        : calling_func(calling_func)  {
      if (global_mutex.lock())
        ABORT_WITH_MESSAGE("%s failed to acquire mutex", calling_func);
    }

    ~LockGuard() {
      if (global_mutex.unlock())
        ABORT_WITH_MESSAGE("%s failed to release mutex", calling_func);
    }

  private:
    const char* const calling_func;
  };
};

//===----------------------------------------------------------------------===//
//                         Futex Implementation
//===----------------------------------------------------------------------===//

#if defined(SYS_futex)
void PlatformFutexWait(int* addr, int expect) {
  constexpr int WAIT = 0;
  syscall(SYS_futex, addr, WAIT, expect, 0);
  __tsan_acquire(addr);
}
void PlatformFutexWake(int* addr) {
  constexpr int WAKE = 1;
  __tsan_release(addr);
  syscall(SYS_futex, addr, WAKE, INT_MAX);
}
#else
constexpr void (*PlatformFutexWait)(int*, int) = nullptr;
constexpr void (*PlatformFutexWake)(int*) = nullptr;
#endif

constexpr bool PlatformSupportsFutex() {
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-pointer-compare"
#endif
  return +PlatformFutexWait != nullptr;
#ifdef __clang__
#pragma clang diagnostic pop
#endif
}

/// InitByteFutex - Manages initialization using atomics and the futex syscall
/// for waiting and waking.
template <void (*Wait)(int*, int) = PlatformFutexWait,
          void (*Wake)(int*) = PlatformFutexWake,
          uint32_t (*GetThreadIDArg)() = PlatformThreadID>
struct InitByteFutex : GuardObject<InitByteFutex<Wait, Wake, GetThreadIDArg>> {
  using BaseT = typename InitByteFutex::GuardObject;

  /// ARM Constructor
  explicit InitByteFutex(uint32_t *g) : BaseT(g),
    init_byte(this->init_byte_address),
    has_thread_id_support(this->thread_id_address && GetThreadIDArg),
    thread_id(this->thread_id_address) {}

  /// Itanium Constructor
  explicit InitByteFutex(uint64_t *g) : BaseT(g),
    init_byte(this->init_byte_address),
    has_thread_id_support(this->thread_id_address && GetThreadIDArg),
    thread_id(this->thread_id_address) {}

public:
  AcquireResult acquire_init_byte() {
    while (true) {
      uint8_t last_val = UNSET;
      if (init_byte.compare_exchange(&last_val, PENDING_BIT, std::_AO_Acq_Rel,
                                     std::_AO_Acquire)) {
        if (has_thread_id_support) {
          thread_id.store(current_thread_id.get(), std::_AO_Relaxed);
        }
        return INIT_IS_PENDING;
      }

      if (last_val == COMPLETE_BIT)
        return INIT_IS_DONE;

      if (last_val & PENDING_BIT) {

        // Check for recursive initialization
        if (has_thread_id_support && thread_id.load(std::_AO_Relaxed) == current_thread_id.get()) {
            ABORT_WITH_MESSAGE("__cxa_guard_acquire detected recursive initialization");
        }

        if ((last_val & WAITING_BIT) == 0) {
          // This compare exchange can fail for several reasons
          // (1) another thread finished the whole thing before we got here
          // (2) another thread set the waiting bit we were trying to thread
          // (3) another thread had an exception and failed to finish
          if (!init_byte.compare_exchange(&last_val, PENDING_BIT | WAITING_BIT,
                                          std::_AO_Acq_Rel, std::_AO_Release)) {
            // (1) success, via someone else's work!
            if (last_val == COMPLETE_BIT)
              return INIT_IS_DONE;

            // (3) someone else, bailed on doing the work, retry from the start!
            if (last_val == UNSET)
              continue;

            // (2) the waiting bit got set, so we are happy to keep waiting
          }
        }
        wait_on_initialization();
      }
    }
  }

  void release_init_byte() {
    uint8_t old = init_byte.exchange(COMPLETE_BIT, std::_AO_Acq_Rel);
    if (old & WAITING_BIT)
      wake_all();
  }

  void abort_init_byte() {
    if (has_thread_id_support)
      thread_id.store(0, std::_AO_Relaxed);

    uint8_t old = init_byte.exchange(0, std::_AO_Acq_Rel);
    if (old & WAITING_BIT)
      wake_all();
  }

private:
  /// Use the futex to wait on the current guard variable. Futex expects a
  /// 32-bit 4-byte aligned address as the first argument, so we have to use use
  /// the base address of the guard variable (not the init byte).
  void wait_on_initialization() {
    Wait(static_cast<int*>(this->base_address),
         expected_value_for_futex(PENDING_BIT | WAITING_BIT));
  }
  void wake_all() { Wake(static_cast<int*>(this->base_address)); }

private:
  AtomicInt<uint8_t> init_byte;

  const bool has_thread_id_support;
  // Unsafe to use unless has_thread_id_support
  AtomicInt<uint32_t> thread_id;
  LazyValue<uint32_t, GetThreadIDArg> current_thread_id;

  /// Create the expected integer value for futex `wait(int* addr, int expected)`.
  /// We pass the base address as the first argument, So this function creates
  /// an zero-initialized integer  with `b` copied at the correct offset.
  static int expected_value_for_futex(uint8_t b) {
    int dest_val = 0;
    std::memcpy(reinterpret_cast<char*>(&dest_val) + 1, &b, 1);
    return dest_val;
  }

  static_assert(Wait != nullptr && Wake != nullptr, "");
};

//===----------------------------------------------------------------------===//
//
//===----------------------------------------------------------------------===//

template <class T>
struct GlobalStatic {
  static T instance;
};
template <class T>
_LIBCPP_SAFE_STATIC T GlobalStatic<T>::instance = {};

enum class Implementation {
  NoThreads,
  GlobalLock,
  Futex
};

template <Implementation Impl>
struct SelectImplementation;

template <>
struct SelectImplementation<Implementation::NoThreads> {
  using type = InitByteNoThreads;
};

template <>
struct SelectImplementation<Implementation::GlobalLock> {
  using type = InitByteGlobalMutex<
      LibcppMutex, LibcppCondVar, GlobalStatic<LibcppMutex>::instance,
      GlobalStatic<LibcppCondVar>::instance, PlatformThreadID>;
};

template <>
struct SelectImplementation<Implementation::Futex> {
  using type =
      InitByteFutex<PlatformFutexWait, PlatformFutexWake, PlatformThreadID>;
};

// TODO(EricWF): We should prefer the futex implementation when available. But
// it should be done in a separate step from adding the implementation.
constexpr Implementation CurrentImplementation =
#if defined(_LIBCXXABI_HAS_NO_THREADS)
    Implementation::NoThreads;
#elif defined(_LIBCXXABI_USE_FUTEX)
    Implementation::Futex;
#else
   Implementation::GlobalLock;
#endif

static_assert(CurrentImplementation != Implementation::Futex
           || PlatformSupportsFutex(), "Futex selected but not supported");

using SelectedImplementation =
    SelectImplementation<CurrentImplementation>::type;

} // end namespace
} // end namespace __cxxabiv1

#endif // LIBCXXABI_SRC_INCLUDE_CXA_GUARD_IMPL_H
