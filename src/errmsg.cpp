/*
 * Copyright (c) 2016 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "errmsg.hpp"
#include "os.hpp"

#include <stdio.h>

enum ErrType {
    ErrTypeError,
    ErrTypeNote,
};

static void print_err_msg_type(ErrorMsg *err, ErrColor color, ErrType err_type) {
    const char *path = buf_ptr(err->path);
    size_t line = err->line_start + 1;
    size_t col = err->column_start + 1;
    const char *text = buf_ptr(err->msg);

    bool is_tty = os_stderr_tty();
    if (color == ErrColorOn || (color == ErrColorAuto && is_tty)) {
        if (err_type == ErrTypeError) {
            os_stderr_set_color(TermColorWhite);
            fprintf(stderr, "%s:%" ZIG_PRI_usize ":%" ZIG_PRI_usize ": ", path, line, col);
            os_stderr_set_color(TermColorRed);
            fprintf(stderr, "error:");
            os_stderr_set_color(TermColorWhite);
            fprintf(stderr, " %s", text);
            os_stderr_set_color(TermColorReset);
            fprintf(stderr, "\n");
        } else if (err_type == ErrTypeNote) {
            os_stderr_set_color(TermColorWhite);
            fprintf(stderr, "%s:%" ZIG_PRI_usize ":%" ZIG_PRI_usize ": ", path, line, col);
            os_stderr_set_color(TermColorCyan);
            fprintf(stderr, "note:");
            os_stderr_set_color(TermColorWhite);
            fprintf(stderr, " %s", text);
            os_stderr_set_color(TermColorReset);
            fprintf(stderr, "\n");
        } else {
            zig_unreachable();
        }

        fprintf(stderr, "%s\n", buf_ptr(&err->line_buf));
        for (size_t i = 0; i < err->column_start; i += 1) {
            fprintf(stderr, " ");
        }
        os_stderr_set_color(TermColorGreen);
        fprintf(stderr, "^");
        os_stderr_set_color(TermColorReset);
        fprintf(stderr, "\n");
    } else {
        if (err_type == ErrTypeError) {
            fprintf(stderr, "%s:%" ZIG_PRI_usize ":%" ZIG_PRI_usize ": error: %s\n", path, line, col, text);
        } else if (err_type == ErrTypeNote) {
            fprintf(stderr, " %s:%" ZIG_PRI_usize ":%" ZIG_PRI_usize ": note: %s\n", path, line, col, text);
        } else {
            zig_unreachable();
        }
    }

    for (size_t i = 0; i < err->notes.length; i += 1) {
        ErrorMsg *note = err->notes.at(i);
        print_err_msg_type(note, color, ErrTypeNote);
    }
}

void print_err_msg(ErrorMsg *err, ErrColor color) {
    print_err_msg_type(err, color, ErrTypeError);
}

void err_msg_add_note(ErrorMsg *parent, ErrorMsg *note) {
    parent->notes.append(note);
}

ErrorMsg *err_msg_create_with_offset(Buf *path, size_t line, size_t column, size_t offset,
        const char *source, Buf *msg)
{
    ErrorMsg *err_msg = allocate<ErrorMsg>(1);
    err_msg->path = path;
    err_msg->line_start = line;
    err_msg->column_start = column;
    err_msg->msg = msg;

    size_t line_start_offset = offset;
    for (;;) {
        if (line_start_offset == 0) {
            break;
        }

        line_start_offset -= 1;

        if (source[line_start_offset] == '\n') {
            line_start_offset += 1;
            break;
        }
    }

    size_t line_end_offset = offset;
    while (source[line_end_offset] && source[line_end_offset] != '\n') {
        line_end_offset += 1;
    }

    buf_init_from_mem(&err_msg->line_buf, source + line_start_offset, line_end_offset - line_start_offset);

    return err_msg;
}

ErrorMsg *err_msg_create_with_line(Buf *path, size_t line, size_t column,
        Buf *source, ZigList<size_t> *line_offsets, Buf *msg)
{
    ErrorMsg *err_msg = allocate<ErrorMsg>(1);
    err_msg->path = path;
    err_msg->line_start = line;
    err_msg->column_start = column;
    err_msg->msg = msg;

    size_t line_start_offset = line_offsets->at(line);
    size_t end_line = line + 1;
    size_t line_end_offset = (end_line >= line_offsets->length) ? buf_len(source) : line_offsets->at(line + 1);
    size_t len = (line_end_offset + 1 > line_start_offset) ? (line_end_offset - line_start_offset - 1) : 0;

    buf_init_from_mem(&err_msg->line_buf, buf_ptr(source) + line_start_offset, len);

    return err_msg;
}
