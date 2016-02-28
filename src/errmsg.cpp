#include "errmsg.hpp"
#include "os.hpp"

#include <stdio.h>

#define RED "\x1b[31;1m"
#define GREEN "\x1b[32;1m"
#define CYAN "\x1b[36;1m"
#define WHITE "\x1b[37;1m"
#define RESET "\x1b[0m"

enum ErrType {
    ErrTypeError,
    ErrTypeNote,
};

static void print_err_msg_type(ErrorMsg *err, ErrColor color, ErrType err_type) {
    const char *path = buf_ptr(err->path);
    int line = err->line_start + 1;
    int col = err->column_start + 1;
    const char *text = buf_ptr(err->msg);


    if (color == ErrColorOn || (color == ErrColorAuto && os_stderr_tty())) {
        if (err_type == ErrTypeError) {
            fprintf(stderr, WHITE "%s:%d:%d: " RED "error:" WHITE " %s" RESET "\n", path, line, col, text);
        } else if (err_type == ErrTypeNote) {
            fprintf(stderr, WHITE "%s:%d:%d: " CYAN "note:" WHITE " %s" RESET "\n", path, line, col, text);
        } else {
            zig_unreachable();
        }

        fprintf(stderr, "%s\n", buf_ptr(&err->line_buf));
        for (int i = 0; i < err->column_start; i += 1) {
            fprintf(stderr, " ");
        }
        fprintf(stderr, GREEN "^" RESET "\n");
    } else {
        if (err_type == ErrTypeError) {
            fprintf(stderr, "%s:%d:%d: error: %s\n", path, line, col, text);
        } else if (err_type == ErrTypeNote) {
            fprintf(stderr, " %s:%d:%d: note: %s\n", path, line, col, text);
        } else {
            zig_unreachable();
        }
    }

    for (int i = 0; i < err->notes.length; i += 1) {
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

ErrorMsg *err_msg_create_with_offset(Buf *path, int line, int column, int offset,
        const char *source, Buf *msg)
{
    ErrorMsg *err_msg = allocate<ErrorMsg>(1);
    err_msg->path = path;
    err_msg->line_start = line;
    err_msg->column_start = column;
    err_msg->msg = msg;

    int line_start_offset = offset;
    for (;;) {
        if (line_start_offset == 0) {
            break;
        } else if (source[line_start_offset] == '\n') {
            line_start_offset += 1;
            break;
        }
        line_start_offset -= 1;
    }

    int line_end_offset = offset;
    while (source[line_end_offset] && source[line_end_offset] != '\n') {
        line_end_offset += 1;
    }

    buf_init_from_mem(&err_msg->line_buf, source + line_start_offset, line_end_offset - line_start_offset);

    return err_msg;
}

ErrorMsg *err_msg_create_with_line(Buf *path, int line, int column,
        Buf *source, ZigList<int> *line_offsets, Buf *msg)
{
    ErrorMsg *err_msg = allocate<ErrorMsg>(1);
    err_msg->path = path;
    err_msg->line_start = line;
    err_msg->column_start = column;
    err_msg->msg = msg;

    int line_start_offset = line_offsets->at(line);
    int end_line = line + 1;
    int line_end_offset = (end_line >= line_offsets->length) ? buf_len(source) : line_offsets->at(line + 1);
    int len = line_end_offset - line_start_offset - 1;
    if (len < 0) {
        len = 0;
    }

    buf_init_from_mem(&err_msg->line_buf, buf_ptr(source) + line_start_offset, len);

    return err_msg;
}
