//===-- sanitizer_procmaps_solaris.cpp ------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Information about the process mappings (Solaris-specific parts).
//===----------------------------------------------------------------------===//

#include "sanitizer_platform.h"
#if SANITIZER_SOLARIS
#include "sanitizer_common.h"
#include "sanitizer_procmaps.h"

// Before Solaris 11.4, <procfs.h> doesn't work in a largefile environment.
#undef _FILE_OFFSET_BITS
#include <procfs.h>
#include <limits.h>

namespace __sanitizer {

void ReadProcMaps(ProcSelfMapsBuff *proc_maps) {
  if (!ReadFileToBuffer("/proc/self/xmap", &proc_maps->data,
                        &proc_maps->mmaped_size, &proc_maps->len)) {
    proc_maps->data = nullptr;
    proc_maps->mmaped_size = 0;
    proc_maps->len = 0;
  }
}

bool MemoryMappingLayout::Next(MemoryMappedSegment *segment) {
  if (Error()) return false; // simulate empty maps
  char *last = data_.proc_self_maps.data + data_.proc_self_maps.len;
  if (data_.current >= last) return false;

  prxmap_t *xmapentry = (prxmap_t*)data_.current;

  segment->start = (uptr)xmapentry->pr_vaddr;
  segment->end = (uptr)(xmapentry->pr_vaddr + xmapentry->pr_size);
  segment->offset = (uptr)xmapentry->pr_offset;

  segment->protection = 0;
  if ((xmapentry->pr_mflags & MA_READ) != 0)
    segment->protection |= kProtectionRead;
  if ((xmapentry->pr_mflags & MA_WRITE) != 0)
    segment->protection |= kProtectionWrite;
  if ((xmapentry->pr_mflags & MA_EXEC) != 0)
    segment->protection |= kProtectionExecute;

  if (segment->filename != NULL && segment->filename_size > 0) {
    char proc_path[PATH_MAX + 1];

    internal_snprintf(proc_path, sizeof(proc_path), "/proc/self/path/%s",
                      xmapentry->pr_mapname);
    internal_readlink(proc_path, segment->filename, segment->filename_size);
  }

  data_.current += sizeof(prxmap_t);

  return true;
}

}  // namespace __sanitizer

#endif  // SANITIZER_SOLARIS
