//===-- sanitizer_fuchsia.h ------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===---------------------------------------------------------------------===//
//
// Fuchsia-specific sanitizer support.
//
//===---------------------------------------------------------------------===//
#ifndef SANITIZER_FUCHSIA_H
#define SANITIZER_FUCHSIA_H

#include "sanitizer_platform.h"
#if SANITIZER_FUCHSIA

#include "sanitizer_common.h"

#include <zircon/sanitizer.h>
#include <zircon/syscalls/object.h>

namespace __sanitizer {

extern uptr MainThreadStackBase, MainThreadStackSize;
extern sanitizer_shadow_bounds_t ShadowBounds;

struct MemoryMappingLayoutData {
  InternalMmapVector<zx_info_maps_t> data;
  size_t current;  // Current index into the vector.
};

void InitShadowBounds();

// Individual sanitizers can define this to explicitly run something at the end
// of `__sanitizer_startup_hook`. This can be useful if a sanitizer needs to do
// extra work after the common startup hook code is called and before module
// ctors are invoked. For example, hwasan can explicitly call its initializing
// function here so it can be set up before libc extensions are initialized.
void EarlySanitizerInit();

}  // namespace __sanitizer

#endif  // SANITIZER_FUCHSIA
#endif  // SANITIZER_FUCHSIA_H
