#define _GNU_SOURCE 1

#ifdef RPYTHON_LL2CTYPES
/* only for testing: ll2ctypes sets RPY_EXTERN from the command-line */
#ifndef RPY_EXTERN
#define RPY_EXTERN RPY_EXPORTED
#endif
#ifdef _WIN32
#define RPY_EXPORTED __declspec(dllexport)
#else
#define RPY_EXPORTED  extern __attribute__((visibility("default")))
#endif
#else
#include "common_header.h"
#include "structdef.h"
#include "src/threadlocal.h"
#include "rjitlog.h"
#endif

#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#ifndef _WIN32
#include <unistd.h>
#endif
#include <errno.h>

#ifdef RPY_TRANSLATE    /* compiling with rpython/bin/rpython or translate.py */
#  define JITLOG  "JITLOG"
#else
#  define JITLOG  "JITLOG_FORTESTS"
#endif

static int jitlog_fd = -1;
static int jitlog_ready = 0;

RPY_EXTERN
int jitlog_enabled()
{
    return jitlog_ready;
}

RPY_EXTERN
void jitlog_try_init_using_env(void) {
    char * filename;
    if (jitlog_ready) { return; }

    /* untranslated this is set to JITLOG_FORTESTS via a #define */
    filename = getenv(JITLOG);

    if (filename && filename[0]) {
        // mode is 644
#ifdef _WIN32
        int mode = _S_IWRITE | _S_IREAD;
#else        
        mode_t mode = 0644;
#endif
        jitlog_fd = open(filename, O_WRONLY | O_CREAT | O_TRUNC, mode);
        if (jitlog_fd == -1) {
            fprintf(stderr, "could not open '%s': ", filename);
            perror(NULL);
            exit(-1);
        }
    } else {
        jitlog_ready = 0;
        return;
    }
#ifndef _WIN32
    unsetenv(JITLOG);
#else
    putenv(JITLOG "=");
#endif
    jitlog_ready = 1;
}

RPY_EXTERN
char *jitlog_init(int fd)
{
    jitlog_fd = fd;
    jitlog_ready = 1;
    return NULL;
}

RPY_EXTERN
void jitlog_teardown()
{
    jitlog_ready = 0;
    if (jitlog_fd == -1) {
        return;
    }
    // close the jitlog file descriptor
    close(jitlog_fd);
    jitlog_fd = -1;
}

RPY_EXTERN
void jitlog_write_marked(char * text, int length)
{
    if (!jitlog_ready) { return; }

    write(jitlog_fd, text, length);
}
