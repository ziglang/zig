// library header:
extern unsigned tstlib_len(const char* msg);

// library implementation:
#ifdef TSTLIB_IMPLEMENTATION

#include <string.h>

unsigned tstlib_len(const char* msg)
{
    return strlen(msg);
}

#endif
