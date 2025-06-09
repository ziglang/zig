#ifndef PANIC_H
#define PANIC_H

#include <stdio.h>
#include <stdlib.h>

#define panic(REASON) do { \
    fprintf(stderr, "%s:%d: %s\n", __func__, __LINE__, REASON); \
    abort(); \
} while (0)

#endif /* PANIC_H */
