/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_ERRMSG_HPP
#define ZIG_ERRMSG_HPP

#include "buffer.hpp"
#include "list.hpp"
#include "stage1.h"

struct ErrorMsg {
    size_t line_start;
    size_t column_start;
    Buf *msg;
    Buf *path;
    Buf line_buf;

    ZigList<ErrorMsg *> notes;
};

void print_err_msg(ErrorMsg *msg, ErrColor color);

void err_msg_add_note(ErrorMsg *parent, ErrorMsg *note);
ErrorMsg *err_msg_create_with_offset(Buf *path, uint32_t byte_offset, const char *source, Buf *msg);

#endif
