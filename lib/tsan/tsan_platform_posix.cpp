//===-- tsan_platform_posix.cpp -------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file is a part of ThreadSanitizer (TSan), a race detector.
//
// POSIX-specific code.
//===----------------------------------------------------------------------===//

#include "sanitizer_common/sanitizer_platform.h"
#if SANITIZER_POSIX

#  include <dlfcn.h>

#  include "sanitizer_common/sanitizer_common.h"
#  include "sanitizer_common/sanitizer_errno.h"
#  include "sanitizer_common/sanitizer_libc.h"
#  include "sanitizer_common/sanitizer_procmaps.h"
#  include "tsan_platform.h"
#  include "tsan_rtl.h"

namespace __tsan {

static const char kShadowMemoryMappingWarning[] =
    "FATAL: %s can not madvise shadow region [%zx, %zx] with %s (errno: %d)\n";
static const char kShadowMemoryMappingHint[] =
    "HINT: if %s is not supported in your environment, you may set "
    "TSAN_OPTIONS=%s=0\n";

#  if !SANITIZER_GO
void DontDumpShadow(uptr addr, uptr size) {
  if (common_flags()->use_madv_dontdump)
    if (!DontDumpShadowMemory(addr, size)) {
      Printf(kShadowMemoryMappingWarning, SanitizerToolName, addr, addr + size,
             "MADV_DONTDUMP", errno);
      Printf(kShadowMemoryMappingHint, "MADV_DONTDUMP", "use_madv_dontdump");
      Die();
    }
}

void InitializeShadowMemory() {
  // Map memory shadow.
  if (!MmapFixedSuperNoReserve(ShadowBeg(), ShadowEnd() - ShadowBeg(),
                               "shadow")) {
    Printf("FATAL: ThreadSanitizer can not mmap the shadow memory\n");
    Printf("FATAL: Make sure to compile with -fPIE and to link with -pie.\n");
    Die();
  }
  // This memory range is used for thread stacks and large user mmaps.
  // Frequently a thread uses only a small part of stack and similarly
  // a program uses a small part of large mmap. On some programs
  // we see 20% memory usage reduction without huge pages for this range.
  DontDumpShadow(ShadowBeg(), ShadowEnd() - ShadowBeg());
  DPrintf("memory shadow: %zx-%zx (%zuGB)\n",
      ShadowBeg(), ShadowEnd(),
      (ShadowEnd() - ShadowBeg()) >> 30);

  // Map meta shadow.
  const uptr meta = MetaShadowBeg();
  const uptr meta_size = MetaShadowEnd() - meta;
  if (!MmapFixedSuperNoReserve(meta, meta_size, "meta shadow")) {
    Printf("FATAL: ThreadSanitizer can not mmap the shadow memory\n");
    Printf("FATAL: Make sure to compile with -fPIE and to link with -pie.\n");
    Die();
  }
  DontDumpShadow(meta, meta_size);
  DPrintf("meta shadow: %zx-%zx (%zuGB)\n",
      meta, meta + meta_size, meta_size >> 30);

  InitializeShadowMemoryPlatform();

  on_initialize = reinterpret_cast<void (*)(void)>(
      dlsym(RTLD_DEFAULT, "__tsan_on_initialize"));
  on_finalize =
      reinterpret_cast<int (*)(int)>(dlsym(RTLD_DEFAULT, "__tsan_on_finalize"));
}

static bool TryProtectRange(uptr beg, uptr end) {
  CHECK_LE(beg, end);
  if (beg == end)
    return true;
  return beg == (uptr)MmapFixedNoAccess(beg, end - beg);
}

static void ProtectRange(uptr beg, uptr end) {
  if (!TryProtectRange(beg, end)) {
    Printf("FATAL: ThreadSanitizer can not protect [%zx,%zx]\n", beg, end);
    Printf("FATAL: Make sure you are not using unlimited stack\n");
    Die();
  }
}

void CheckAndProtect() {
  // Ensure that the binary is indeed compiled with -pie.
  MemoryMappingLayout proc_maps(true);
  MemoryMappedSegment segment;
  while (proc_maps.Next(&segment)) {
    if (IsAppMem(segment.start)) continue;
    if (segment.start >= HeapMemEnd() && segment.start < HeapEnd()) continue;
    if (segment.protection == 0)  // Zero page or mprotected.
      continue;
    if (segment.start >= VdsoBeg())  // vdso
      break;
    Printf("FATAL: ThreadSanitizer: unexpected memory mapping 0x%zx-0x%zx\n",
           segment.start, segment.end);
    Die();
  }

#    if SANITIZER_IOS && !SANITIZER_IOSSIM
  ProtectRange(HeapMemEnd(), ShadowBeg());
  ProtectRange(ShadowEnd(), MetaShadowBeg());
  ProtectRange(MetaShadowEnd(), HiAppMemBeg());
#    else
  ProtectRange(LoAppMemEnd(), ShadowBeg());
  ProtectRange(ShadowEnd(), MetaShadowBeg());
  if (MidAppMemBeg()) {
    ProtectRange(MetaShadowEnd(), MidAppMemBeg());
    ProtectRange(MidAppMemEnd(), HeapMemBeg());
  } else {
    ProtectRange(MetaShadowEnd(), HeapMemBeg());
  }
  ProtectRange(HeapEnd(), HiAppMemBeg());
#    endif

#    if defined(__s390x__)
  // Protect the rest of the address space.
  const uptr user_addr_max_l4 = 0x0020000000000000ull;
  const uptr user_addr_max_l5 = 0xfffffffffffff000ull;
  // All the maintained s390x kernels support at least 4-level page tables.
  ProtectRange(HiAppMemEnd(), user_addr_max_l4);
  // Older s390x kernels may not support 5-level page tables.
  TryProtectRange(user_addr_max_l4, user_addr_max_l5);
#endif
}
#endif

}  // namespace __tsan

#endif  // SANITIZER_POSIX
