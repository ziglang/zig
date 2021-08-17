//===-- sanitizer_tls_get_addr.h --------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Handle the __tls_get_addr call.
//
// All this magic is specific to glibc and is required to workaround
// the lack of interface that would tell us about the Dynamic TLS (DTLS).
// https://sourceware.org/bugzilla/show_bug.cgi?id=16291
//
// The matters get worse because the glibc implementation changed between
// 2.18 and 2.19:
// https://groups.google.com/forum/#!topic/address-sanitizer/BfwYD8HMxTM
//
// Before 2.19, every DTLS chunk is allocated with __libc_memalign,
// which we intercept and thus know where is the DTLS.
// Since 2.19, DTLS chunks are allocated with __signal_safe_memalign,
// which is an internal function that wraps a mmap call, neither of which
// we can intercept. Luckily, __signal_safe_memalign has a simple parseable
// header which we can use.
//
//===----------------------------------------------------------------------===//

#ifndef SANITIZER_TLS_GET_ADDR_H
#define SANITIZER_TLS_GET_ADDR_H

#include "sanitizer_atomic.h"
#include "sanitizer_common.h"

namespace __sanitizer {

struct DTLS {
  // Array of DTLS chunks for the current Thread.
  // If beg == 0, the chunk is unused.
  struct DTV {
    uptr beg, size;
  };
  struct DTVBlock {
    atomic_uintptr_t next;
    DTV dtvs[(4096UL - sizeof(next)) / sizeof(DTLS::DTV)];
  };

  static_assert(sizeof(DTVBlock) <= 4096UL, "Unexpected block size");

  atomic_uintptr_t dtv_block;

  // Auxiliary fields, don't access them outside sanitizer_tls_get_addr.cpp
  uptr last_memalign_size;
  uptr last_memalign_ptr;
};

template <typename Fn>
void ForEachDVT(DTLS *dtls, const Fn &fn) {
  DTLS::DTVBlock *block =
      (DTLS::DTVBlock *)atomic_load(&dtls->dtv_block, memory_order_acquire);
  while (block) {
    int id = 0;
    for (auto &d : block->dtvs) fn(d, id++);
    block = (DTLS::DTVBlock *)atomic_load(&block->next, memory_order_acquire);
  }
}

// Returns pointer and size of a linker-allocated TLS block.
// Each block is returned exactly once.
DTLS::DTV *DTLS_on_tls_get_addr(void *arg, void *res, uptr static_tls_begin,
                                uptr static_tls_end);
void DTLS_on_libc_memalign(void *ptr, uptr size);
DTLS *DTLS_Get();
void DTLS_Destroy();  // Make sure to call this before the thread is destroyed.
// Returns true if DTLS of suspended thread is in destruction process.
bool DTLSInDestruction(DTLS *dtls);

}  // namespace __sanitizer

#endif  // SANITIZER_TLS_GET_ADDR_H
