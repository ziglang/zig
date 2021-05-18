// Copyright (c) 2015 Nuxi, https://nuxi.nl/
//
// SPDX-License-Identifier: BSD-2-Clause

#include <dirent.h>
#include <unistd.h>

int closedir(DIR *dirp) {
  return close(fdclosedir(dirp));
}
