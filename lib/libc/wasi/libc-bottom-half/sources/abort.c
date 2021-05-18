#include <stdlib.h>

void abort(void) {
    // wasm doesn't support signals, so just trap to halt the program.
    __builtin_trap();
}
