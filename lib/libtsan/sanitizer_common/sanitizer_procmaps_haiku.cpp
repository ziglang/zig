//===-- sanitizer_procmaps_haiku.cpp --------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Information about the process mappings
// (Haiku-specific parts).
//===----------------------------------------------------------------------===//

#include "sanitizer_platform.h"
#if SANITIZER_HAIKU
#  include "sanitizer_common.h"
#  include "sanitizer_procmaps.h"

#  include <kernel/OS.h>

namespace __sanitizer {

void MemoryMappedSegment::AddAddressRanges(LoadedModule *module) {
  // data_ should be unused on this platform
  CHECK(!data_);
  module->addAddressRange(start, end, IsExecutable(), IsWritable());
}

MemoryMappingLayout::MemoryMappingLayout(bool) { Reset(); }

void MemoryMappingLayout::Reset() { data_.cookie = 0; }

MemoryMappingLayout::~MemoryMappingLayout() {}

// static
void MemoryMappingLayout::CacheMemoryMappings() {}

bool MemoryMappingLayout::Next(MemoryMappedSegment *segment) {
  area_info info;
  if (get_next_area_info(B_CURRENT_TEAM, &data_.cookie, &info) != B_OK)
    return false;

  segment->start = (uptr)info.address;
  segment->end = (uptr)info.address + info.size;
  segment->offset = 0;
  segment->protection = 0;
  if (info.protection & B_READ_AREA)
    segment->protection |= kProtectionRead;
  if (info.protection & B_WRITE_AREA)
    segment->protection |= kProtectionWrite;
  if (info.protection & B_EXECUTE_AREA)
    segment->protection |= kProtectionExecute;
  if (segment->filename) {
    uptr len = Min((uptr)B_OS_NAME_LENGTH, segment->filename_size - 1);
    internal_strncpy(segment->filename, info.name, len);
    segment->filename[len] = 0;
  }
  return true;
}

bool MemoryMappingLayout::Error() const { return false; }

void MemoryMappingLayout::DumpListOfModules(
    InternalMmapVectorNoCtor<LoadedModule> *modules) {
  Reset();
  InternalMmapVector<char> module_name(kMaxPathLength);
  MemoryMappedSegment segment(module_name.data(), module_name.size());
  for (uptr i = 0; Next(&segment); i++) {
    const char *cur_name = segment.filename;
    if (cur_name[0] == '\0')
      continue;
    // Don't subtract 'cur_beg' from the first entry:
    // * If a binary is compiled w/o -pie, then the first entry in
    //   process maps is likely the binary itself (all dynamic libs
    //   are mapped higher in address space). For such a binary,
    //   instruction offset in binary coincides with the actual
    //   instruction address in virtual memory (as code section
    //   is mapped to a fixed memory range).
    // * If a binary is compiled with -pie, all the modules are
    //   mapped high at address space (in particular, higher than
    //   shadow memory of the tool), so the module can't be the
    //   first entry.
    uptr base_address = (i ? segment.start : 0) - segment.offset;
    LoadedModule cur_module;
    cur_module.set(cur_name, base_address);
    segment.AddAddressRanges(&cur_module);
    modules->push_back(cur_module);
  }
}

void GetMemoryProfile(fill_profile_f cb, uptr *stats) {}

}  // namespace __sanitizer

#endif
