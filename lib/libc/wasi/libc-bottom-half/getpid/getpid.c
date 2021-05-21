#include <unistd.h>

pid_t getpid(void) {
    // Return an arbitrary value, greater than 1 which is special.
    return 42;
}
