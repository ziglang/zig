#include <stdint.h>

typedef struct rpy_revdb_command_s {
    int32_t cmd;      /* neg for standard commands, pos for interp-specific */
    uint32_t extra_size;
    int64_t arg1;
    int64_t arg2;
    int64_t arg3;
    /* char extra[extra_size]; */
} rpy_revdb_command_t;
