//===-- sanitizer_win_interception.cpp --------------------    --*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Windows-specific export surface to provide interception for parts of the
// runtime that are always statically linked, both for overriding user-defined
// functions as well as registering weak functions that the ASAN runtime should
// use over defaults.
//
//===----------------------------------------------------------------------===//

#include "sanitizer_platform.h"
#if SANITIZER_WINDOWS
#  include <stddef.h>

#  include "interception/interception.h"
#  include "sanitizer_addrhashmap.h"
#  include "sanitizer_common.h"
#  include "sanitizer_internal_defs.h"
#  include "sanitizer_placement_new.h"
#  include "sanitizer_win_immortalize.h"
#  include "sanitizer_win_interception.h"

using namespace __sanitizer;

extern "C" void *__ImageBase;

namespace __sanitizer {

static uptr GetSanitizerDllExport(const char *export_name) {
  const uptr function_address =
      __interception::InternalGetProcAddress(&__ImageBase, export_name);
  if (function_address == 0) {
    Report("ERROR: Failed to find sanitizer DLL export '%s'\n", export_name);
    CHECK("Failed to find sanitizer DLL export" && 0);
  }
  return function_address;
}

struct WeakCallbackList {
  explicit constexpr WeakCallbackList(RegisterWeakFunctionCallback cb)
      : callback(cb), next(nullptr) {}

  static void *operator new(size_t size) { return InternalAlloc(size); }

  static void operator delete(void *p) { InternalFree(p); }

  RegisterWeakFunctionCallback callback;
  WeakCallbackList *next;
};
using WeakCallbackMap = AddrHashMap<WeakCallbackList *, 11>;

static WeakCallbackMap *GetWeakCallbackMap() {
  return &immortalize<WeakCallbackMap>();
}

void AddRegisterWeakFunctionCallback(uptr export_address,
                                     RegisterWeakFunctionCallback cb) {
  WeakCallbackMap::Handle h_find_or_create(GetWeakCallbackMap(), export_address,
                                           false, true);
  CHECK(h_find_or_create.exists());
  if (h_find_or_create.created()) {
    *h_find_or_create = new WeakCallbackList(cb);
  } else {
    (*h_find_or_create)->next = new WeakCallbackList(cb);
  }
}

static void RunWeakFunctionCallbacks(uptr export_address) {
  WeakCallbackMap::Handle h_find(GetWeakCallbackMap(), export_address, false,
                                 false);
  if (!h_find.exists()) {
    return;
  }

  WeakCallbackList *list = *h_find;
  do {
    list->callback();
  } while ((list = list->next));
}

}  // namespace __sanitizer

extern "C" __declspec(dllexport) bool __cdecl __sanitizer_override_function(
    const char *export_name, const uptr user_function,
    uptr *const old_user_function) {
  CHECK(export_name);
  CHECK(user_function);

  const uptr sanitizer_function = GetSanitizerDllExport(export_name);

  const bool function_overridden = __interception::OverrideFunction(
      user_function, sanitizer_function, old_user_function);
  if (!function_overridden) {
    Report(
        "ERROR: Failed to override local function at '%p' with sanitizer "
        "function '%s'\n",
        user_function, export_name);
    CHECK("Failed to replace local function with sanitizer version." && 0);
  }

  return function_overridden;
}

extern "C"
    __declspec(dllexport) bool __cdecl __sanitizer_override_function_by_addr(
        const uptr source_function, const uptr target_function,
        uptr *const old_target_function) {
  CHECK(source_function);
  CHECK(target_function);

  const bool function_overridden = __interception::OverrideFunction(
      target_function, source_function, old_target_function);
  if (!function_overridden) {
    Report(
        "ERROR: Failed to override function at '%p' with function at "
        "'%p'\n",
        target_function, source_function);
    CHECK("Failed to apply function override." && 0);
  }

  return function_overridden;
}

extern "C"
    __declspec(dllexport) bool __cdecl __sanitizer_register_weak_function(
        const char *export_name, const uptr user_function,
        uptr *const old_user_function) {
  CHECK(export_name);
  CHECK(user_function);

  const uptr sanitizer_function = GetSanitizerDllExport(export_name);

  const bool function_overridden = __interception::OverrideFunction(
      sanitizer_function, user_function, old_user_function);
  if (!function_overridden) {
    Report(
        "ERROR: Failed to register local function at '%p' to be used in "
        "place of sanitizer function '%s'\n.",
        user_function, export_name);
    CHECK("Failed to register weak function." && 0);
  }

  // Note that thread-safety of RunWeakFunctionCallbacks in InitializeFlags
  // depends on __sanitizer_register_weak_functions being called during the
  // loader lock.
  RunWeakFunctionCallbacks(sanitizer_function);

  return function_overridden;
}

#endif  // SANITIZER_WINDOWS
