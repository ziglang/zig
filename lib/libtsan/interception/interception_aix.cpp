//===-- interception_aix.cpp ------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file is a part of AddressSanitizer, an address sanity checker.
//
// AIX-specific interception methods.
//===----------------------------------------------------------------------===//

#include "interception.h"
#include "sanitizer_common/sanitizer_common.h"

#if SANITIZER_AIX

#  include <dlfcn.h>  // for dlsym()

namespace __interception {

static void *GetFuncAddr(const char *name, uptr wrapper_addr) {
  // AIX dlsym can only defect the functions that are exported, so
  // on AIX, we can not intercept some basic functions like memcpy.
  // FIXME: if we are going to ship dynamic asan library, we may need to search
  // all the loaded modules with RTLD_DEFAULT if RTLD_NEXT failed.
  void *addr = dlsym(RTLD_NEXT, name);

  // In case `name' is not loaded, dlsym ends up finding the actual wrapper.
  // We don't want to intercept the wrapper and have it point to itself.
  if ((uptr)addr == wrapper_addr)
    addr = nullptr;
  return addr;
}

bool InterceptFunction(const char *name, uptr *ptr_to_real, uptr func,
                       uptr wrapper) {
  void *addr = GetFuncAddr(name, wrapper);
  *ptr_to_real = (uptr)addr;
  return addr && (func == wrapper);
}

}  // namespace __interception
#endif  // SANITIZER_AIX
