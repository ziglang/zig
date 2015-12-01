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
    int line_end;
    int column_end;
    Buf *msg;
    Buf *path;
    Buf *source;
    ZigList<int> *line_offsets;
};

void print_err_msg(ErrorMsg *msg, ErrColor color);

#endif
