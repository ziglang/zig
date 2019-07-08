#include "cache_hash.hpp"
#include "os.hpp"

#include <stdio.h>

static Buf saved_compiler_id = BUF_INIT;
static Buf saved_app_data_dir = BUF_INIT;
static Buf saved_stage1_path = BUF_INIT;
static Buf saved_lib_dir = BUF_INIT;
static Buf saved_special_dir = BUF_INIT;
static Buf saved_std_dir = BUF_INIT;

static Buf saved_dynamic_linker_path = BUF_INIT;
static bool searched_for_dyn_linker = false;

static Buf saved_libc_path = BUF_INIT;
static bool searched_for_libc = false;

Buf *get_stage1_cache_path(void) {
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

static void detect_dynamic_linker(Buf *lib_path) {
#if defined(ZIG_OS_LINUX)
    for (size_t i = 0; possible_ld_names[i] != NULL; i += 1) {
        if (buf_ends_with_str(lib_path, possible_ld_names[i])) {
            buf_init_from_buf(&saved_dynamic_linker_path, lib_path);
            break;
        }
    }
#endif
}

const Buf *get_self_libc_path(void) {
    for (;;) {
        if (saved_libc_path.list.length != 0) {
            return &saved_libc_path;
        }
        if (searched_for_libc)
            return nullptr;
        ZigList<Buf *> lib_paths = {};
        Error err;
        if ((err = os_self_exe_shared_libs(lib_paths)))
            return nullptr;
        for (size_t i = 0; i < lib_paths.length; i += 1) {
            Buf *lib_path = lib_paths.at(i);
            if (buf_ends_with_str(lib_path, "libc.so.6")) {
                buf_init_from_buf(&saved_libc_path, lib_path);
                return &saved_libc_path;
            }
        }
        searched_for_libc = true;
    }
}

Buf *get_self_dynamic_linker_path(void) {
    for (;;) {
        if (saved_dynamic_linker_path.list.length != 0) {
            return &saved_dynamic_linker_path;
        }
        if (searched_for_dyn_linker)
            return nullptr;
        ZigList<Buf *> lib_paths = {};
        Error err;
        if ((err = os_self_exe_shared_libs(lib_paths)))
            return nullptr;
        for (size_t i = 0; i < lib_paths.length; i += 1) {
            Buf *lib_path = lib_paths.at(i);
            detect_dynamic_linker(lib_path);
        }
        searched_for_dyn_linker = true;
    }
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
    if ((err = cache_hit(ch, &saved_compiler_id))) {
        if (err != ErrorInvalidFormat)
            return err;
    }
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
        detect_dynamic_linker(lib_path);
        if ((err = cache_add_file(ch, lib_path)))
            return err;
    }
    if ((err = cache_final(ch, &saved_compiler_id)))
        return err;

    cache_release(ch);

    *result = &saved_compiler_id;
    return ErrorNone;
}

static bool test_zig_install_prefix(Buf *test_path, Buf *out_zig_lib_dir) {
    Buf lib_buf = BUF_INIT;
    buf_init_from_str(&lib_buf, "lib");

    Buf zig_buf = BUF_INIT;
    buf_init_from_str(&zig_buf, "zig");

    Buf std_buf = BUF_INIT;
    buf_init_from_str(&std_buf, "std");

    Buf std_zig_buf = BUF_INIT;
    buf_init_from_str(&std_zig_buf, "std.zig");

    Buf test_lib_dir = BUF_INIT;
    Buf test_zig_dir = BUF_INIT;
    Buf test_std_dir = BUF_INIT;
    Buf test_index_file = BUF_INIT;

    os_path_join(test_path, &lib_buf, &test_lib_dir);
    os_path_join(&test_lib_dir, &zig_buf, &test_zig_dir);
    os_path_join(&test_zig_dir, &std_buf, &test_std_dir);
    os_path_join(&test_std_dir, &std_zig_buf, &test_index_file);

    int err;
    bool exists;
    if ((err = os_file_exists(&test_index_file, &exists))) {
        exists = false;
    }
    if (exists) {
        buf_init_from_buf(out_zig_lib_dir, &test_zig_dir);
        return true;
    }
    return false;
}

static int find_zig_lib_dir(Buf *out_path) {
    int err;

    Buf self_exe_path = BUF_INIT;
    buf_resize(&self_exe_path, 0);
    if (!(err = os_self_exe_path(&self_exe_path))) {
        Buf *cur_path = &self_exe_path;

        for (;;) {
            Buf *test_dir = buf_alloc();
            os_path_dirname(cur_path, test_dir);

            if (buf_eql_buf(test_dir, cur_path)) {
                break;
            }

            if (test_zig_install_prefix(test_dir, out_path)) {
                return 0;
            }

            cur_path = test_dir;
        }
    }

    return ErrorFileNotFound;
}

Buf *get_zig_lib_dir(void) {
    if (saved_lib_dir.list.length != 0) {
        return &saved_lib_dir;
    }
    buf_resize(&saved_lib_dir, 0);

    int err;
    if ((err = find_zig_lib_dir(&saved_lib_dir))) {
        fprintf(stderr, "Unable to find zig lib directory\n");
        exit(EXIT_FAILURE);
    }
    return &saved_lib_dir;
}

Buf *get_zig_std_dir(Buf *zig_lib_dir) {
    if (saved_std_dir.list.length != 0) {
        return &saved_std_dir;
    }
    buf_resize(&saved_std_dir, 0);

    os_path_join(zig_lib_dir, buf_create_from_str("std"), &saved_std_dir);

    return &saved_std_dir;
}

Buf *get_zig_special_dir(Buf *zig_lib_dir) {
    if (saved_special_dir.list.length != 0) {
        return &saved_special_dir;
    }
    buf_resize(&saved_special_dir, 0);

    os_path_join(get_zig_std_dir(zig_lib_dir), buf_sprintf("special"), &saved_special_dir);

    return &saved_special_dir;
}
