/*===---- riscv_ntlh.h - RISC-V NTLH intrinsics ----------------------------===
 *
 * Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
 * See https://llvm.org/LICENSE.txt for license information.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 *
 *===-----------------------------------------------------------------------===
 */

#ifndef __RISCV_NTLH_H
#define __RISCV_NTLH_H

#ifndef __riscv_zihintntl
#error "NTLH intrinsics require the NTLH extension."
#endif

enum {
  __RISCV_NTLH_INNERMOST_PRIVATE = 2,
  __RISCV_NTLH_ALL_PRIVATE,
  __RISCV_NTLH_INNERMOST_SHARED,
  __RISCV_NTLH_ALL
};

#define __riscv_ntl_load(PTR, DOMAIN) __builtin_riscv_ntl_load((PTR), (DOMAIN))
#define __riscv_ntl_store(PTR, VAL, DOMAIN)                                    \
  __builtin_riscv_ntl_store((PTR), (VAL), (DOMAIN))

#endif