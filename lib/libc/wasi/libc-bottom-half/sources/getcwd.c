#include <unistd.h>
#include <errno.h>
#include <string.h>

// For threads this needs to synchronize with chdir
#ifdef _REENTRANT
#error "getcwd doesn't yet support multiple threads"
#endif

char *__wasilibc_cwd = "/";

char *getcwd(char *buf, size_t size)
{
    if (!buf) {
        buf = strdup(__wasilibc_cwd);
        if (!buf) {
            errno = ENOMEM;
            return NULL;
        }
    } else {
        size_t len = strlen(__wasilibc_cwd);
        if (size < len + 1) {
            errno = ERANGE;
            return NULL;
        }
        strcpy(buf, __wasilibc_cwd);
    }
    return buf;
}

