// Copyright (c) 2015-2016 Nuxi, https://nuxi.nl/
//
// SPDX-License-Identifier: BSD-2-Clause

#ifdef __wasilibc_use_wasip2
#include <wasi/wasip2.h>
#else
#include <wasi/api.h>
#endif
#include <_/cdefs.h>
#include <stdnoreturn.h>
#include <unistd.h>

noreturn void _Exit(int status) {
#ifdef __wasilibc_use_wasip2
  exit_result_void_void_t exit_status = { .is_err = status != 0 };
  exit_exit(&exit_status);
#else
  __wasi_proc_exit(status);
#endif
}

__strong_reference(_Exit, _exit);
