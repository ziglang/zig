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

enum ErrColor {
    ErrColorAuto,
    ErrColorOff,
    ErrColorOn,
};

struct ErrorMsg {
    int line_start;
    int column_start;
    Buf *msg;
    Buf *path;
    Buf line_buf;

    ZigList<ErrorMsg *> notes;
};

void print_err_msg(ErrorMsg *msg, ErrColor color);

void err_msg_add_note(ErrorMsg *parent, ErrorMsg *note);
ErrorMsg *err_msg_create_with_offset(Buf *path, int line, int column, int offset,
        const char *source, Buf *msg);

ErrorMsg *err_msg_create_with_line(Buf *path, int line, int column,
        Buf *source, ZigList<int> *line_offsets, Buf *msg);

#endif
