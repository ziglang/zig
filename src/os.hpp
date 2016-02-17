/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_OS_HPP
#define ZIG_OS_HPP

#include "list.hpp"
#include "buffer.hpp"

#include <stdio.h>

void os_init(void);
void os_spawn_process(const char *exe, ZigList<const char *> &args, int *return_code);
int os_exec_process(const char *exe, ZigList<const char *> &args,
        int *return_code, Buf *out_stderr, Buf *out_stdout);

void os_path_split(Buf *full_path, Buf *out_dirname, Buf *out_basename);
void os_path_join(Buf *dirname, Buf *basename, Buf *out_full_path);
int os_path_real(Buf *rel_path, Buf *out_abs_path);

void os_write_file(Buf *full_path, Buf *contents);


int os_fetch_file(FILE *file, Buf *out_contents);
int os_fetch_file_path(Buf *full_path, Buf *out_contents);

int os_get_cwd(Buf *out_cwd);

bool os_stderr_tty(void);

int os_buf_to_tmp_file(Buf *contents, Buf *suffix, Buf *out_tmp_path);
int os_delete_file(Buf *path);

#endif
