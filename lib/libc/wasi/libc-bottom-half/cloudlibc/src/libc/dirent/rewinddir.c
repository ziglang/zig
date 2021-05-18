// Copyright (c) 2015-2016 Nuxi, https://nuxi.nl/
//
// SPDX-License-Identifier: BSD-2-Clause

#include <wasi/api.h>
#include <dirent.h>

#include "dirent_impl.h"

void rewinddir(DIR *dirp) {
  // Update cookie.
  dirp->cookie = __WASI_DIRCOOKIE_START;
  // Mark entire buffer as processed to force a read of new data.
  dirp->buffer_used = dirp->buffer_processed = dirp->buffer_size;
}
