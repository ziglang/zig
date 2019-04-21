#ifndef __wasm_basics___struct_stat_h
#define __wasm_basics___struct_stat_h

#include <__typedef_dev_t.h>
#include <__typedef_ino_t.h>
#include <__typedef_nlink_t.h>
#include <__typedef_mode_t.h>
#include <__typedef_uid_t.h>
#include <__typedef_gid_t.h>
#include <__typedef_off_t.h>
#include <__typedef_blksize_t.h>
#include <__typedef_blkcnt_t.h>
#include <__struct_timespec.h>

struct stat {
    dev_t st_dev;
    ino_t st_ino;
    nlink_t st_nlink;

    mode_t st_mode;
    uid_t st_uid;
    gid_t st_gid;
    unsigned int __pad0;
    dev_t st_rdev;
    off_t st_size;
    blksize_t st_blksize;
    blkcnt_t st_blocks;

    struct timespec st_atim;
    struct timespec st_mtim;
    struct timespec st_ctim;
    long long __reserved[3];
};

#endif
