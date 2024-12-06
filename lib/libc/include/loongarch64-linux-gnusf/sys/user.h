/* struct user_regs_struct definition for LoongArch.
   Copyright (C) 2022-2024 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

#ifndef _SYS_USER_H
#define _SYS_USER_H 1

#include <stdint.h>

struct user_regs_struct
{
  /* Saved main processor registers. */
  uint64_t regs[32];

  /* Saved special registers. */
  uint64_t orig_a0;
  uint64_t csr_era;
  uint64_t csr_badv;
  uint64_t reserved[10];
};

struct user_fp_struct {
  uint64_t    fpr[32];
  uint64_t    fcc;
  uint32_t    fcsr;
};

#endif /* _SYS_USER_H */