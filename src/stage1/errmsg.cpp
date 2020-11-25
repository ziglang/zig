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
    bool is_tty = os_stderr_tty();
    bool use_colors = color == ErrColorOn || (color == ErrColorAuto && is_tty);

    // Show the error location, if available
    if (err->path != nullptr) {
        const char *path = buf_ptr(err->path);
        Slice<const char> pathslice{path, strlen(path)};

        // Cache cwd
        static Buf *cwdbuf{nullptr};
        static Slice<const char> cwd;

        if (cwdbuf == nullptr) {
            cwdbuf = buf_alloc();
            Error err = os_get_cwd(cwdbuf);
            if (err != ErrorNone)
                zig_panic("get cwd failed");
            buf_append_char(cwdbuf, ZIG_OS_SEP_CHAR);
            cwd.ptr = buf_ptr(cwdbuf);
            cwd.len = strlen(cwd.ptr);
        }

        const size_t line = err->line_start + 1;
        const size_t col = err->column_start + 1;
        if (use_colors) os_stderr_set_color(TermColorBold);

        // Strip cwd from path
        if (memStartsWith(pathslice, cwd))
            fprintf(stderr, ".%c%s:%" ZIG_PRI_usize ":%" ZIG_PRI_usize ": ", ZIG_OS_SEP_CHAR, path+cwd.len, line, col);
        else
            fprintf(stderr, "%s:%" ZIG_PRI_usize ":%" ZIG_PRI_usize ": ", path, line, col);
    }

    // Write out the error type
    switch (err_type) {
        case ErrTypeError:
            if (use_colors) os_stderr_set_color(TermColorRed);
            fprintf(stderr, "error: ");
            break;
        case ErrTypeNote:
            if (use_colors) os_stderr_set_color(TermColorCyan);
            fprintf(stderr, "note: ");
            break;
        default:
            zig_unreachable();
    }

    // Write out the error message
    if (use_colors) os_stderr_set_color(TermColorBold);
    fputs(buf_ptr(err->msg), stderr);
    if (use_colors) os_stderr_set_color(TermColorReset);
    fputc('\n', stderr);

    if (buf_len(&err->line_buf) != 0){
        // Show the referenced line
        fprintf(stderr, "%s\n", buf_ptr(&err->line_buf));
        for (size_t i = 0; i < err->column_start; i += 1) {
            fprintf(stderr, " ");
        }
        // Draw the caret
        if (use_colors) os_stderr_set_color(TermColorGreen);
        fprintf(stderr, "^");
        if (use_colors) os_stderr_set_color(TermColorReset);
        fprintf(stderr, "\n");
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
    ErrorMsg *err_msg = heap::c_allocator.create<ErrorMsg>();
    err_msg->path = path;
    err_msg->line_start = line;
    err_msg->column_start = column;
    err_msg->msg = msg;

    if (source == nullptr) {
        // Must initialize the buffer anyway
        buf_init_from_str(&err_msg->line_buf, "");
        return err_msg;
    }

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
    ErrorMsg *err_msg = heap::c_allocator.create<ErrorMsg>();
    err_msg->path = path;
    err_msg->line_start = line;
    err_msg->column_start = column;
    err_msg->msg = msg;

    size_t line_start_offset = line_offsets->at(line);
    size_t end_line = line + 1;
    size_t line_end_offset = (end_line >= line_offsets->length) ? buf_len(source) : line_offsets->at(line + 1);
    size_t len = (line_end_offset + 1 > line_start_offset) ? (line_end_offset - line_start_offset - 1) : 0;
    if (len == SIZE_MAX) len = 0;

    buf_init_from_mem(&err_msg->line_buf, buf_ptr(source) + line_start_offset, len);

    return err_msg;
}
