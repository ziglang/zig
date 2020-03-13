/*
 * Copyright (c) 2018 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_CACHE_HASH_HPP
#define ZIG_CACHE_HASH_HPP

#include "blake2.h"
#include "os.hpp"

struct LinkLib;

struct CacheHashFile {
    Buf *path;
    OsFileAttr attr;
    uint8_t bin_digest[48];
    Buf *contents;
};

struct CacheHash {
    blake2b_state blake;
    ZigList<CacheHashFile> files;
    Buf *manifest_dir;
    Buf *manifest_file_path;
    Buf b64_digest;
    OsFile manifest_file;
    bool manifest_dirty;
    bool force_check_manifest;
};

// Always call this first to set up.
void cache_init(CacheHash *ch, Buf *manifest_dir);

// Next, use the hash population functions to add the initial parameters.
void cache_mem(CacheHash *ch, const char *ptr, size_t len);
void cache_str(CacheHash *ch, const char *ptr);
void cache_int(CacheHash *ch, int x);
void cache_bool(CacheHash *ch, bool x);
void cache_usize(CacheHash *ch, size_t x);
void cache_buf(CacheHash *ch, Buf *buf);
void cache_buf_opt(CacheHash *ch, Buf *buf);
void cache_list_of_link_lib(CacheHash *ch, LinkLib **ptr, size_t len);
void cache_list_of_buf(CacheHash *ch, Buf **ptr, size_t len);
void cache_list_of_file(CacheHash *ch, Buf **ptr, size_t len);
void cache_list_of_str(CacheHash *ch, const char **ptr, size_t len);
void cache_file(CacheHash *ch, Buf *path);
void cache_file_opt(CacheHash *ch, Buf *path);

// Then call cache_hit when you're ready to see if you can skip the next step.
// out_b64_digest will be left unchanged if it was a cache miss.
// If you got a cache hit, the next step is cache_release.
// From this point on, there is a lock on the input params. Release
// the lock with cache_release.
// Set force_check_manifest if you plan to add files later, but have not
// added any files before calling cache_hit. CacheHash::b64_digest becomes
// available for use after this call, even in the case of a miss, and it
// is a hash of the input parameters only.
// If this function returns ErrorInvalidFormat, that error may be treated
// as a cache miss.
Error ATTRIBUTE_MUST_USE cache_hit(CacheHash *ch, Buf *out_b64_digest);

// If you did not get a cache hit, call this function for every file
// that is depended on, and then finish with cache_final.
Error ATTRIBUTE_MUST_USE cache_add_file(CacheHash *ch, Buf *path);
// This opens a file created by -MD -MF args to Clang
Error ATTRIBUTE_MUST_USE cache_add_dep_file(CacheHash *ch, Buf *path, bool verbose);

// This variant of cache_add_file returns the file contents.
// Also the file path argument must be already resolved.
Error ATTRIBUTE_MUST_USE cache_add_file_fetch(CacheHash *ch, Buf *resolved_path, Buf *contents);

// out_b64_digest will be the same thing that cache_hit returns if you got a cache hit
Error ATTRIBUTE_MUST_USE cache_final(CacheHash *ch, Buf *out_b64_digest);

// Until this function is called, no one will be able to get a lock on your input params.
void cache_release(CacheHash *ch);


#endif
