/*
 * Copyright (c) 2018 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "cache_hash.hpp"
#include "all_types.hpp"
#include "buffer.hpp"
#include "os.hpp"

#include <stdio.h>

void cache_init(CacheHash *ch, Buf *manifest_dir) {
    int rc = blake2b_init(&ch->blake, 48);
    assert(rc == 0);
    ch->files = {};
    ch->manifest_dir = manifest_dir;
    ch->manifest_file_path = nullptr;
    ch->manifest_dirty = false;
}

void cache_str(CacheHash *ch, const char *ptr) {
    assert(ch->manifest_file_path == nullptr);
    assert(ptr != nullptr);
    // + 1 to include the null byte
    blake2b_update(&ch->blake, ptr, strlen(ptr) + 1);
}

void cache_int(CacheHash *ch, int x) {
    assert(ch->manifest_file_path == nullptr);
    // + 1 to include the null byte
    uint8_t buf[sizeof(int) + 1];
    memcpy(buf, &x, sizeof(int));
    buf[sizeof(int)] = 0;
    blake2b_update(&ch->blake, buf, sizeof(int) + 1);
}

void cache_usize(CacheHash *ch, size_t x) {
    assert(ch->manifest_file_path == nullptr);
    // + 1 to include the null byte
    uint8_t buf[sizeof(size_t) + 1];
    memcpy(buf, &x, sizeof(size_t));
    buf[sizeof(size_t)] = 0;
    blake2b_update(&ch->blake, buf, sizeof(size_t) + 1);
}

void cache_bool(CacheHash *ch, bool x) {
    assert(ch->manifest_file_path == nullptr);
    blake2b_update(&ch->blake, &x, 1);
}

void cache_buf(CacheHash *ch, Buf *buf) {
    assert(ch->manifest_file_path == nullptr);
    assert(buf != nullptr);
    // + 1 to include the null byte
    blake2b_update(&ch->blake, buf_ptr(buf), buf_len(buf) + 1);
}

void cache_buf_opt(CacheHash *ch, Buf *buf) {
    assert(ch->manifest_file_path == nullptr);
    if (buf == nullptr) {
        cache_str(ch, "");
        cache_str(ch, "");
    } else {
        cache_buf(ch, buf);
    }
}

void cache_list_of_link_lib(CacheHash *ch, LinkLib **ptr, size_t len) {
    assert(ch->manifest_file_path == nullptr);
    for (size_t i = 0; i < len; i += 1) {
        LinkLib *lib = ptr[i];
        if (lib->provided_explicitly) {
            cache_buf(ch, lib->name);
        }
    }
    cache_str(ch, "");
}

void cache_list_of_buf(CacheHash *ch, Buf **ptr, size_t len) {
    assert(ch->manifest_file_path == nullptr);
    for (size_t i = 0; i < len; i += 1) {
        Buf *buf = ptr[i];
        cache_buf(ch, buf);
    }
    cache_str(ch, "");
}

void cache_list_of_file(CacheHash *ch, Buf **ptr, size_t len) {
    assert(ch->manifest_file_path == nullptr);

    for (size_t i = 0; i < len; i += 1) {
        Buf *buf = ptr[i];
        cache_file(ch, buf);
    }
    cache_str(ch, "");
}

void cache_list_of_str(CacheHash *ch, const char **ptr, size_t len) {
    assert(ch->manifest_file_path == nullptr);

    for (size_t i = 0; i < len; i += 1) {
        const char *s = ptr[i];
        cache_str(ch, s);
    }
    cache_str(ch, "");
}

void cache_file(CacheHash *ch, Buf *file_path) {
    assert(ch->manifest_file_path == nullptr);
    assert(file_path != nullptr);
    Buf *resolved_path = buf_alloc();
    *resolved_path = os_path_resolve(&file_path, 1);
    CacheHashFile *chf = ch->files.add_one();
    chf->path = resolved_path;
    cache_buf(ch, resolved_path);
}

void cache_file_opt(CacheHash *ch, Buf *file_path) {
    assert(ch->manifest_file_path == nullptr);
    if (file_path == nullptr) {
        cache_str(ch, "");
        cache_str(ch, "");
    } else {
        cache_file(ch, file_path);
    }
}

// Ported from std/base64.zig
static uint8_t base64_fs_alphabet[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
static void base64_encode(Slice<uint8_t> dest, Slice<uint8_t> source) {
    size_t dest_len = ((source.len + 2) / 3) * 4;
    assert(dest.len == dest_len);

    size_t i = 0;
    size_t out_index = 0;
    for (; i + 2 < source.len; i += 3) {
        dest.ptr[out_index] = base64_fs_alphabet[(source.ptr[i] >> 2) & 0x3f];
        out_index += 1;

        dest.ptr[out_index] = base64_fs_alphabet[((source.ptr[i] & 0x3) << 4) | ((source.ptr[i + 1] & 0xf0) >> 4)];
        out_index += 1;

        dest.ptr[out_index] = base64_fs_alphabet[((source.ptr[i + 1] & 0xf) << 2) | ((source.ptr[i + 2] & 0xc0) >> 6)];
        out_index += 1;

        dest.ptr[out_index] = base64_fs_alphabet[source.ptr[i + 2] & 0x3f];
        out_index += 1;
    }

    // Assert that we never need pad characters.
    assert(i == source.len);
}

// Ported from std/base64.zig
static Error base64_decode(Slice<uint8_t> dest, Slice<uint8_t> source) {
    assert(source.len % 4 == 0);
    assert(dest.len == (source.len / 4) * 3);

    // In Zig this is comptime computed. In C++ it's not worth it to do that.
    uint8_t char_to_index[256];
    bool char_in_alphabet[256] = {0};
    for (size_t i = 0; i < 64; i += 1) {
        uint8_t c = base64_fs_alphabet[i];
        assert(!char_in_alphabet[c]);
        char_in_alphabet[c] = true;
        char_to_index[c] = i;
    }

    size_t src_cursor = 0;
    size_t dest_cursor = 0;

    for (;src_cursor < source.len; src_cursor += 4) {
        if (!char_in_alphabet[source.ptr[src_cursor + 0]]) return ErrorInvalidFormat;
        if (!char_in_alphabet[source.ptr[src_cursor + 1]]) return ErrorInvalidFormat;
        if (!char_in_alphabet[source.ptr[src_cursor + 2]]) return ErrorInvalidFormat;
        if (!char_in_alphabet[source.ptr[src_cursor + 3]]) return ErrorInvalidFormat;
        dest.ptr[dest_cursor + 0] = (char_to_index[source.ptr[src_cursor + 0]] << 2) | (char_to_index[source.ptr[src_cursor + 1]] >> 4);
        dest.ptr[dest_cursor + 1] = (char_to_index[source.ptr[src_cursor + 1]] << 4) | (char_to_index[source.ptr[src_cursor + 2]] >> 2);
        dest.ptr[dest_cursor + 2] = (char_to_index[source.ptr[src_cursor + 2]] << 6) | (char_to_index[source.ptr[src_cursor + 3]]);
        dest_cursor += 3;
    }

    assert(src_cursor == source.len);
    assert(dest_cursor == dest.len);
    return ErrorNone;
}

static Error hash_file(uint8_t *digest, OsFile handle, Buf *contents) {
    Error err;

    if (contents) {
        buf_resize(contents, 0);
    }

    blake2b_state blake;
    int rc = blake2b_init(&blake, 48);
    assert(rc == 0);

    for (;;) {
        uint8_t buf[4096];
        size_t amt = 4096;
        if ((err = os_file_read(handle, buf, &amt)))
            return err;
        if (amt == 0) {
            rc = blake2b_final(&blake, digest, 48);
            assert(rc == 0);
            return ErrorNone;
        }
        blake2b_update(&blake, buf, amt);
        if (contents) {
            buf_append_mem(contents, (char*)buf, amt);
        }
    }
}

static Error populate_file_hash(CacheHash *ch, CacheHashFile *chf, Buf *contents) {
    Error err;

    assert(chf->path != nullptr);

    OsFile this_file;
    if ((err = os_file_open_r(chf->path, &this_file)))
        return err;

    if ((err = os_file_mtime(this_file, &chf->mtime))) {
        os_file_close(this_file);
        return err;
    }

    if ((err = hash_file(chf->bin_digest, this_file, contents))) {
        os_file_close(this_file);
        return err;
    }
    os_file_close(this_file);

    blake2b_update(&ch->blake, chf->bin_digest, 48);

    return ErrorNone;
}

Error cache_hit(CacheHash *ch, Buf *out_digest) {
    Error err;

    uint8_t bin_digest[48];
    int rc = blake2b_final(&ch->blake, bin_digest, 48);
    assert(rc == 0);

    Buf b64_digest = BUF_INIT;
    buf_resize(&b64_digest, 64);
    base64_encode(buf_to_slice(&b64_digest), {bin_digest, 48});

    rc = blake2b_init(&ch->blake, 48);
    assert(rc == 0);
    blake2b_update(&ch->blake, bin_digest, 48);

    ch->manifest_file_path = buf_alloc();
    os_path_join(ch->manifest_dir, &b64_digest, ch->manifest_file_path);

    buf_append_str(ch->manifest_file_path, ".txt");

    if ((err = os_make_path(ch->manifest_dir)))
        return err;

    if ((err = os_file_open_lock_rw(ch->manifest_file_path, &ch->manifest_file)))
        return err;

    Buf line_buf = BUF_INIT;
    buf_resize(&line_buf, 512);
    if ((err = os_file_read_all(ch->manifest_file, &line_buf))) {
        os_file_close(ch->manifest_file);
        return err;
    }

    size_t input_file_count = ch->files.length;
    bool any_file_changed = false;
    size_t file_i = 0;
    SplitIterator line_it = memSplit(buf_to_slice(&line_buf), str("\n"));
    for (;; file_i += 1) {
        Optional<Slice<uint8_t>> opt_line = SplitIterator_next(&line_it);
        if (!opt_line.is_some)
            break;

        CacheHashFile *chf;
        if (file_i < input_file_count) {
            chf = &ch->files.at(file_i);
        } else if (any_file_changed) {
            // cache miss.
            // keep the the manifest file open with the rw lock
            // reset the hash
            rc = blake2b_init(&ch->blake, 48);
            assert(rc == 0);
            blake2b_update(&ch->blake, bin_digest, 48);
            ch->files.resize(input_file_count);
            // bring the hash up to the input file hashes
            for (file_i = 0; file_i < input_file_count; file_i += 1) {
                blake2b_update(&ch->blake, ch->files.at(file_i).bin_digest, 48);
            }
            // caller can notice that out_digest is unmodified.
            return ErrorNone;
        } else {
            chf = ch->files.add_one();
            chf->path = nullptr;
        }

        SplitIterator it = memSplit(opt_line.value, str(" "));

        Optional<Slice<uint8_t>> opt_mtime_sec = SplitIterator_next(&it);
        if (!opt_mtime_sec.is_some) {
            os_file_close(ch->manifest_file);
            return ErrorInvalidFormat;
        }
        chf->mtime.sec = strtoull((const char *)opt_mtime_sec.value.ptr, nullptr, 10);

        Optional<Slice<uint8_t>> opt_mtime_nsec = SplitIterator_next(&it);
        if (!opt_mtime_nsec.is_some) {
            os_file_close(ch->manifest_file);
            return ErrorInvalidFormat;
        }
        chf->mtime.nsec = strtoull((const char *)opt_mtime_nsec.value.ptr, nullptr, 10);

        Optional<Slice<uint8_t>> opt_digest = SplitIterator_next(&it);
        if (!opt_digest.is_some) {
            os_file_close(ch->manifest_file);
            return ErrorInvalidFormat;
        }
        if ((err = base64_decode({chf->bin_digest, 48}, opt_digest.value))) {
            os_file_close(ch->manifest_file);
            return ErrorInvalidFormat;
        }

        Optional<Slice<uint8_t>> opt_file_path = SplitIterator_next(&it);
        if (!opt_file_path.is_some) {
            os_file_close(ch->manifest_file);
            return ErrorInvalidFormat;
        }
        Buf *this_path = buf_create_from_slice(opt_file_path.value);
        if (chf->path != nullptr && !buf_eql_buf(this_path, chf->path)) {
            os_file_close(ch->manifest_file);
            return ErrorInvalidFormat;
        }
        chf->path = this_path;

        // if the mtime matches we can trust the digest
        OsFile this_file;
        if ((err = os_file_open_r(chf->path, &this_file))) {
            os_file_close(ch->manifest_file);
            return err;
        }
        OsTimeStamp actual_mtime;
        if ((err = os_file_mtime(this_file, &actual_mtime))) {
            os_file_close(this_file);
            os_file_close(ch->manifest_file);
            return err;
        }
        if (chf->mtime.sec == actual_mtime.sec && chf->mtime.nsec == actual_mtime.nsec) {
            os_file_close(this_file);
        } else {
            // we have to recompute the digest.
            // later we'll rewrite the manifest with the new mtime/digest values
            ch->manifest_dirty = true;
            chf->mtime = actual_mtime;

            uint8_t actual_digest[48];
            if ((err = hash_file(actual_digest, this_file, nullptr))) {
                os_file_close(this_file);
                os_file_close(ch->manifest_file);
                return err;
            }
            os_file_close(this_file);
            if (memcmp(chf->bin_digest, actual_digest, 48) != 0) {
                memcpy(chf->bin_digest, actual_digest, 48);
                // keep going until we have the input file digests
                any_file_changed = true;
            }
        }
        if (!any_file_changed) {
            blake2b_update(&ch->blake, chf->bin_digest, 48);
        }
    }
    if (file_i < input_file_count) {
        // manifest file is empty or missing entries, so this is a cache miss
        ch->manifest_dirty = true;
        for (; file_i < input_file_count; file_i += 1) {
            CacheHashFile *chf = &ch->files.at(file_i);
            if ((err = populate_file_hash(ch, chf, nullptr))) {
                os_file_close(ch->manifest_file);
                return err;
            }
        }
        return ErrorNone;
    }
    // Cache Hit
    return cache_final(ch, out_digest);
}

Error cache_add_file_fetch(CacheHash *ch, Buf *resolved_path, Buf *contents) {
    Error err;

    assert(ch->manifest_file_path != nullptr);
    CacheHashFile *chf = ch->files.add_one();
    chf->path = resolved_path;
    if ((err = populate_file_hash(ch, chf, contents))) {
        os_file_close(ch->manifest_file);
        return err;
    }

    return ErrorNone;
}

Error cache_add_file(CacheHash *ch, Buf *path) {
    Buf *resolved_path = buf_alloc();
    *resolved_path = os_path_resolve(&path, 1);
    return cache_add_file_fetch(ch, resolved_path, nullptr);
}

static Error write_manifest_file(CacheHash *ch) {
    Error err;
    Buf contents = BUF_INIT;
    buf_resize(&contents, 0);
    uint8_t encoded_digest[65];
    encoded_digest[64] = 0;
    for (size_t i = 0; i < ch->files.length; i += 1) {
        CacheHashFile *chf = &ch->files.at(i);
        base64_encode({encoded_digest, 64}, {chf->bin_digest, 48});
        buf_appendf(&contents, "%" ZIG_PRI_u64 " %" ZIG_PRI_u64 " %s %s\n",
            chf->mtime.sec, chf->mtime.nsec, encoded_digest, buf_ptr(chf->path));
    }
    if ((err = os_file_overwrite(ch->manifest_file, &contents)))
        return err;

    return ErrorNone;
}

Error cache_final(CacheHash *ch, Buf *out_digest) {
    Error err;

    assert(ch->manifest_file_path != nullptr);

    if (ch->manifest_dirty) {
        if ((err = write_manifest_file(ch))) {
            fprintf(stderr, "Warning: Unable to write cache file '%s': %s\n",
                    buf_ptr(ch->manifest_file_path), err_str(err));
        }
    }
    // We don't close the manifest file yet, because we want to
    // keep it locked until the API user is done using it.

    uint8_t bin_digest[48];
    int rc = blake2b_final(&ch->blake, bin_digest, 48);
    assert(rc == 0);
    buf_resize(out_digest, 64);
    base64_encode(buf_to_slice(out_digest), {bin_digest, 48});

    return ErrorNone;
}

void cache_release(CacheHash *ch) {
    os_file_close(ch->manifest_file);
}
