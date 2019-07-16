#include "mathtest.h"
#include <assert.h>

int main(int argc, char **argv) {
    assert(add(42, 1337) == 1379);
    return 0;
}
