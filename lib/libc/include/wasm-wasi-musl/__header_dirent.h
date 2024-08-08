#ifndef __wasilibc___header_dirent_h
#define __wasilibc___header_dirent_h

#include <wasi/api.h>

#define DT_BLK __WASI_FILETYPE_BLOCK_DEVICE
#define DT_CHR __WASI_FILETYPE_CHARACTER_DEVICE
#define DT_DIR __WASI_FILETYPE_DIRECTORY
#define DT_FIFO __WASI_FILETYPE_SOCKET_STREAM
#define DT_LNK __WASI_FILETYPE_SYMBOLIC_LINK
#define DT_REG __WASI_FILETYPE_REGULAR_FILE
#define DT_UNKNOWN __WASI_FILETYPE_UNKNOWN

// DT_SOCK is not supported in WASI Preview 1 (but will be in Preview 2).  We
// define it regardless so that libc++'s `<filesystem>` implementation builds.
// The exact value is mostly arbitrary, but chosen so it doesn't conflict with
// any of the existing `__WASI_FILETYPE_*` flags.  We do not expect any new
// flags to be added to WASI Preview 1, so that should be sufficient.
#define DT_SOCK 20

#define IFTODT(x) (__wasilibc_iftodt(x))
#define DTTOIF(x) (__wasilibc_dttoif(x))

#include <__struct_dirent.h>
#include <__typedef_DIR.h>

#ifdef __cplusplus
extern "C" {
#endif

int __wasilibc_iftodt(int x);
int __wasilibc_dttoif(int x);

int closedir(DIR *);
DIR *opendir(const char *);
DIR *fdopendir(int);
int fdclosedir(DIR *);
struct dirent *readdir(DIR *);
void rewinddir(DIR *);
void seekdir(DIR *, long);
long telldir(DIR *);
DIR *opendirat(int, const char *);
void rewinddir(DIR *);
int scandirat(int, const char *, struct dirent ***,
              int (*)(const struct dirent *),
              int (*)(const struct dirent **, const struct dirent **));

#ifdef __cplusplus
}
#endif

#endif
