#include "cache_hash.hpp"

#include <stdio.h>

static Buf saved_compiler_id = BUF_INIT;
static Buf saved_app_data_dir = BUF_INIT;
static Buf saved_stage1_path = BUF_INIT;

Buf *get_stage1_cache_path() {
    if (saved_stage1_path.list.length != 0) {
        return &saved_stage1_path;
    }
    Error err;
    if ((err = os_get_app_data_dir(&saved_app_data_dir, "zig"))) {
        fprintf(stderr, "Unable to get app data dir: %s\n", err_str(err));
        exit(1);
    }
    os_path_join(&saved_app_data_dir, buf_create_from_str("stage1"), &saved_stage1_path);
    return &saved_stage1_path;
}

Error get_compiler_id(Buf **result) {
    if (saved_compiler_id.list.length != 0) {
        *result = &saved_compiler_id;
        return ErrorNone;
    }

    Error err;
    Buf *stage1_dir = get_stage1_cache_path();
    Buf *manifest_dir = buf_alloc();
    os_path_join(stage1_dir, buf_create_from_str("exe"), manifest_dir);

    CacheHash cache_hash;
    CacheHash *ch = &cache_hash;
    cache_init(ch, manifest_dir);
    Buf self_exe_path = BUF_INIT;
    if ((err = os_self_exe_path(&self_exe_path)))
        return err;

    cache_file(ch, &self_exe_path);

    buf_resize(&saved_compiler_id, 0);
    if ((err = cache_hit(ch, &saved_compiler_id)))
        return err;
    if (buf_len(&saved_compiler_id) != 0) {
        cache_release(ch);
        *result = &saved_compiler_id;
        return ErrorNone;
    }
    ZigList<Buf *> lib_paths = {};
    if ((err = os_self_exe_shared_libs(lib_paths)))
        return err;
    for (size_t i = 0; i < lib_paths.length; i += 1) {
        Buf *lib_path = lib_paths.at(i);
        if ((err = cache_add_file(ch, lib_path)))
            return err;
    }
    if ((err = cache_final(ch, &saved_compiler_id)))
        return err;

    cache_release(ch);

    *result = &saved_compiler_id;
    return ErrorNone;
}

