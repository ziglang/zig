#include "common_header.h"
#include <src/instrument.h>

#ifdef  PYPY_INSTRUMENT

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdlib.h>
#include <stdio.h>
#ifndef _WIN32
#include <sys/mman.h>
#include <unistd.h>
#else
#include <windows.h>
#endif

typedef Unsigned instrument_count_t;

instrument_count_t *_instrument_counters = NULL;

void instrument_setup() {
    char *fname = getenv("PYPY_INSTRUMENT_COUNTERS");
    if (fname) {
        int fd;
#ifdef _WIN32
        HANDLE map_handle;
        HANDLE file_handle;
#endif
        void *buf;
        size_t sz = sizeof(instrument_count_t)*PYPY_INSTRUMENT_NCOUNTER;
        fd = open(fname, O_CREAT|O_TRUNC|O_RDWR, 0744);
        if (sz > 0) {
            lseek(fd, sz-1, SEEK_SET);
            (void)write(fd, "", 1);
#ifndef _WIN32
            buf = mmap(NULL, sz, PROT_WRITE|PROT_READ, MAP_SHARED,
                       fd, 0);
            if (buf == MAP_FAILED) {
                fprintf(stderr, "mapping instrument counters file failed\n");
                abort();
            }
#else
            file_handle = (HANDLE)_get_osfhandle(fd);
            map_handle = CreateFileMapping(file_handle, NULL, PAGE_READWRITE,
                                           0, sz, "");
            buf = MapViewOfFile(map_handle, FILE_MAP_WRITE, 0, 0, 0);
            if (buf == 0) {
                fprintf(stderr, "mapping instrument counters file failed\n");
                abort();
            }
#endif
            _instrument_counters = (instrument_count_t *)buf;
        }
    }
}

void instrument_count(Signed label) {
    if(_instrument_counters) {
        _instrument_counters[label]++;
    }
}

#else

void instrument_setup() {
}

#endif
