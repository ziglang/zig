#ifndef PANIC_H
#define PANIC_H

#include <stdio.h>
#include <stdlib.h>

// panic is a macro rather than a function so the caller can derive
// that this is noreturn from the call to abort()
#define panic(reason) do { fprintf(stderr, "%s\n", reason); abort(); } while (0)

#endif /* PANIC_H */
