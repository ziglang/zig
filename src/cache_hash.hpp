/*
 * Copyright (c) 2018 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_CACHE_HASH_HPP
#define ZIG_CACHE_HASH_HPP

#include "all_types.hpp"
#include "blake2.h"
#include "os.hpp"

struct CacheHashFile {
    Buf *path;
    OsTimeStamp mtime;
    uint8_t bin_digest[48];
};

struct CacheHash {
    blake2b_state blake;
    ZigList<CacheHashFile> files;
    Buf *manifest_dir;
    Buf *manifest_file_path;
    OsFile manifest_file;
    bool manifest_dirty;
};

// Always call this first to set up.
void cache_init(CacheHash *ch, Buf *manifest_dir);

// Next, use the hash population functions to add the initial parameters.
void cache_str(CacheHash *ch, const char *ptr);
void cache_int(CacheHash *ch, int x);
void cache_buf(CacheHash *ch, Buf *buf);
void cache_buf_opt(CacheHash *ch, Buf *buf);
void cache_list_of_link_lib(CacheHash *ch, LinkLib **ptr, size_t len);
void cache_list_of_buf(CacheHash *ch, Buf **ptr, size_t len);
void cache_file(CacheHash *ch, Buf *path);
void cache_file_opt(CacheHash *ch, Buf *path);

// Then call cache_hit when you're ready to see if you can skip the next step.
// out_b64_digest will be left unchanged if it was a cache miss
Error ATTRIBUTE_MUST_USE cache_hit(CacheHash *ch, Buf *out_b64_digest);

// If you got a cache hit, the flow is done. No more functions to call.
// Next call this function for every file that is depended on.
Error ATTRIBUTE_MUST_USE cache_add_file(CacheHash *ch, Buf *path);

// If you did not get a cache hit, use the hash population functions again
// and do all the actual work. When done use cache_final to save the cache
// for next time.
Error ATTRIBUTE_MUST_USE cache_final(CacheHash *ch, Buf *out_digest);

#endif
