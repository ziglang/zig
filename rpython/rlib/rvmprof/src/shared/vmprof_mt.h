#pragma once
/* Support for multithreaded write() operations */

#include "vmprof.h"

#include <string.h>
#include <sys/mman.h>

/* The idea is that we have MAX_NUM_BUFFERS available, all of size
   SINGLE_BUF_SIZE.  Threads and signal handlers can ask to reserve a
   buffer, fill it, and finally "commit" it, at which point its
   content is written into the profile file.  There is no hard
   guarantee about the order in which the committed blocks are
   actually written.  We do this with two constrains:

   - write() calls should not overlap; only one thread can be
     currently calling it.

   - the code needs to be multithread-safe *and* signal-handler-safe,
     which means it must be written in a wait-free style: never have
     spin loops waiting for some lock to be released, from any of
     the functions that can be called from the signal handler!  The
     code holding the lock could be running in the same thread,
     currently interrupted by the signal handler.

   The value of MAX_NUM_BUFFERS is a trade-off between too high
   (lots of unnecessary memory, lots of checking all of them)
   and too low (risk that there is none left).
*/
#define MAX_NUM_BUFFERS  20

#ifndef MAP_ANONYMOUS
#define MAP_ANONYMOUS MAP_ANON
#endif

#define PROFBUF_UNUSED   0
#define PROFBUF_FILLING  1
#define PROFBUF_READY    2


struct profbuf_s {
    unsigned int data_size;
    unsigned int data_offset;
    char data[SINGLE_BUF_SIZE];
};

int prepare_concurrent_bufs(void);
struct profbuf_s *reserve_buffer(int fd);
void commit_buffer(int fd, struct profbuf_s *buf);
void cancel_buffer(struct profbuf_s *buf);
int shutdown_concurrent_bufs(int fd);
