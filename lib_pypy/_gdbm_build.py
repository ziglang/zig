import cffi, os, sys

ffi = cffi.FFI()
ffi.cdef('''
#define GDBM_READER ...
#define GDBM_WRITER ...
#define GDBM_WRCREAT ...
#define GDBM_NEWDB ...
#define GDBM_FAST ...
#define GDBM_SYNC ...
#define GDBM_NOLOCK ...
#define GDBM_REPLACE ...
#define GDBM_ITEM_NOT_FOUND ...

typedef struct gdbm_file_info *GDBM_FILE;

GDBM_FILE gdbm_open(const char *, int, int, int, void (*)(const char *));

typedef struct {
    char *dptr;
    int   dsize;
} datum;

datum gdbm_fetch(GDBM_FILE, datum);
datum pygdbm_fetch(void*, char*, int);
int gdbm_delete(GDBM_FILE, datum);
int gdbm_store(GDBM_FILE, datum, datum, int);
int gdbm_exists(GDBM_FILE, datum);
int pygdbm_exists(GDBM_FILE, char*, int);
void pygdbm_close(GDBM_FILE);

int gdbm_reorganize(GDBM_FILE);

datum gdbm_firstkey(GDBM_FILE);
datum gdbm_nextkey(GDBM_FILE, datum);
void gdbm_sync(GDBM_FILE);

const char* gdbm_strerror(int);
extern int gdbm_errno;

/* Needed to release returned values */
void free(void*);
''')


kwds = {}
if sys.platform.startswith('freebsd'):
    _localbase = os.environ.get('LOCALBASE', '/usr/local')
    kwds['include_dirs'] = [os.path.join(_localbase, 'include')]
    kwds['library_dirs'] = [os.path.join(_localbase, 'lib')]

ffi.set_source("_gdbm_cffi", '''
#include <stdlib.h>
#include "gdbm.h"

static datum pygdbm_fetch(GDBM_FILE gdbm_file, char *dptr, int dsize) {
    datum key = {dptr, dsize};
    return gdbm_fetch(gdbm_file, key);
}

static int pygdbm_exists(GDBM_FILE gdbm_file, char *dptr, int dsize) {
    datum key = {dptr, dsize};
    return gdbm_exists(gdbm_file, key);
}

static void pygdbm_close(GDBM_FILE gdbm_file) {
    /*
     * In verison 17, void gdbm_close() became int gdbm_close()
     * Work around that by wrapping the function
     */
    gdbm_close(gdbm_file);
}
''', libraries=['gdbm'], **kwds)


if __name__ == '__main__':
    ffi.compile()
