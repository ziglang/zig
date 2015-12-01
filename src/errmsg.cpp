#include "errmsg.hpp"
#include "os.hpp"

#include <stdio.h>

#define RED "\x1b[31;1m"
#define WHITE "\x1b[37;1m"
#define GREEN "\x1b[32;1m"
#define RESET "\x1b[0m"

void print_err_msg(ErrorMsg *err) {
    if (os_stderr_tty()) {
        fprintf(stderr, WHITE "%s:%d:%d: " RED "error:" WHITE " %s" RESET "\n",
                buf_ptr(err->path),
                err->line_start + 1, err->column_start + 1,
                buf_ptr(err->msg));

        assert(err->source);
        assert(err->line_offsets);

        int line_start_offset = err->line_offsets->at(err->line_start);
        int line_end_offset = err->line_offsets->at(err->line_start + 1);

        fwrite(buf_ptr(err->source) + line_start_offset, 1, line_end_offset - line_start_offset - 1, stderr);
        fprintf(stderr, "\n");
        for (int i = 0; i < err->column_start; i += 1) {
            fprintf(stderr, " ");
        }
        fprintf(stderr, GREEN "^" RESET "\n");

    } else {
        fprintf(stderr, "%s:%d:%d: error: %s\n",
                buf_ptr(err->path),
                err->line_start + 1, err->column_start + 1,
                buf_ptr(err->msg));
    }
}

