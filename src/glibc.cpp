/*
 * Copyright (c) 2019 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "glibc.hpp"
#include "compiler.hpp"
#include "cache_hash.hpp"
#include "codegen.hpp"

static const ZigGLibCLib glibc_libs[] = {
    {"c", 6},
    {"m", 6},
    {"pthread", 0},
    {"dl", 2},
    {"rt", 1},
};

Error glibc_load_metadata(ZigGLibCAbi **out_result, Buf *zig_lib_dir, bool verbose) {
    Error err;

    ZigGLibCAbi *glibc_abi = heap::c_allocator.create<ZigGLibCAbi>();
    glibc_abi->vers_txt_path = buf_sprintf("%s" OS_SEP "libc" OS_SEP "glibc" OS_SEP "vers.txt", buf_ptr(zig_lib_dir));
    glibc_abi->fns_txt_path = buf_sprintf("%s" OS_SEP "libc" OS_SEP "glibc" OS_SEP "fns.txt", buf_ptr(zig_lib_dir));
    glibc_abi->abi_txt_path = buf_sprintf("%s" OS_SEP "libc" OS_SEP "glibc" OS_SEP "abi.txt", buf_ptr(zig_lib_dir));
    glibc_abi->version_table.init(16);

    Buf *vers_txt_contents = buf_alloc();
    if ((err = os_fetch_file_path(glibc_abi->vers_txt_path, vers_txt_contents))) {
        if (verbose) {
            fprintf(stderr, "Unable to read %s: %s\n", buf_ptr(glibc_abi->vers_txt_path), err_str(err));
        }
        return err;
    }
    Buf *fns_txt_contents = buf_alloc();
    if ((err = os_fetch_file_path(glibc_abi->fns_txt_path, fns_txt_contents))) {
        if (verbose) {
            fprintf(stderr, "Unable to read %s: %s\n", buf_ptr(glibc_abi->fns_txt_path), err_str(err));
        }
        return err;
    }
    Buf *abi_txt_contents = buf_alloc();
    if ((err = os_fetch_file_path(glibc_abi->abi_txt_path, abi_txt_contents))) {
        if (verbose) {
            fprintf(stderr, "Unable to read %s: %s\n", buf_ptr(glibc_abi->abi_txt_path), err_str(err));
        }
        return err;
    }

    {
        SplitIterator it = memSplit(buf_to_slice(vers_txt_contents), str("\r\n"));
        for (;;) {
            Optional<Slice<uint8_t>> opt_component = SplitIterator_next(&it);
            if (!opt_component.is_some) break;
            Buf *ver_buf = buf_create_from_slice(opt_component.value);
            Stage2SemVer *this_ver = glibc_abi->all_versions.add_one();
            if ((err = target_parse_glibc_version(this_ver, buf_ptr(ver_buf)))) {
                if (verbose) {
                    fprintf(stderr, "Unable to parse glibc version '%s': %s\n", buf_ptr(ver_buf), err_str(err));
                }
                return err;
            }
        }
    }
    {
        SplitIterator it = memSplit(buf_to_slice(fns_txt_contents), str("\r\n"));
        for (;;) {
            Optional<Slice<uint8_t>> opt_component = SplitIterator_next(&it);
            if (!opt_component.is_some) break;
            SplitIterator line_it = memSplit(opt_component.value, str(" "));
            Optional<Slice<uint8_t>> opt_fn_name = SplitIterator_next(&line_it);
            if (!opt_fn_name.is_some) {
                if (verbose) {
                    fprintf(stderr, "%s: Expected function name\n", buf_ptr(glibc_abi->fns_txt_path));
                }
                return ErrorInvalidFormat;
            }
            Optional<Slice<uint8_t>> opt_lib_name = SplitIterator_next(&line_it);
            if (!opt_lib_name.is_some) {
                if (verbose) {
                    fprintf(stderr, "%s: Expected lib name\n", buf_ptr(glibc_abi->fns_txt_path));
                }
                return ErrorInvalidFormat;
            }

            Buf *this_fn_name = buf_create_from_slice(opt_fn_name.value);
            Buf *this_lib_name = buf_create_from_slice(opt_lib_name.value);
            glibc_abi->all_functions.append({ this_fn_name, glibc_lib_find(buf_ptr(this_lib_name)) });
        }
    }
    {
        SplitIterator it = memSplit(buf_to_slice(abi_txt_contents), str("\r\n"));
        ZigGLibCVerList *ver_list_base = nullptr;
        int line_num = 0;
        for (;;) {
            if (ver_list_base == nullptr) {
                line_num += 1;
                Optional<Slice<uint8_t>> opt_line = SplitIterator_next_separate(&it);
                if (!opt_line.is_some) break;

                ver_list_base = heap::c_allocator.allocate<ZigGLibCVerList>(glibc_abi->all_functions.length);
                SplitIterator line_it = memSplit(opt_line.value, str(" "));
                for (;;) {
                    ZigTarget *target = heap::c_allocator.create<ZigTarget>();
                    Optional<Slice<uint8_t>> opt_target = SplitIterator_next(&line_it);
                    if (!opt_target.is_some) break;

                    SplitIterator component_it = memSplit(opt_target.value, str("-"));
                    Optional<Slice<uint8_t>> opt_arch = SplitIterator_next(&component_it);
                    assert(opt_arch.is_some);
                    Optional<Slice<uint8_t>> opt_os = SplitIterator_next(&component_it);
                    assert(opt_os.is_some); // it's always "linux" so we ignore it
                    Optional<Slice<uint8_t>> opt_abi = SplitIterator_next(&component_it);
                    assert(opt_abi.is_some);


                    err = target_parse_arch(&target->arch, (char*)opt_arch.value.ptr, opt_arch.value.len);
                    assert(err == ErrorNone);

                    target->os = OsLinux;

                    err = target_parse_abi(&target->abi, (char*)opt_abi.value.ptr, opt_abi.value.len);
                    if (err != ErrorNone) {
                        fprintf(stderr, "Error parsing %s:%d: %s\n", buf_ptr(glibc_abi->abi_txt_path),
                                line_num, err_str(err));
                        fprintf(stderr, "arch: '%.*s', os: '%.*s', abi: '%.*s'\n",
                                (int)opt_arch.value.len, (const char*)opt_arch.value.ptr,
                                (int)opt_os.value.len, (const char*)opt_os.value.ptr,
                                (int)opt_abi.value.len, (const char*)opt_abi.value.ptr);
                        fprintf(stderr, "parsed from target: '%.*s'\n",
                                (int)opt_target.value.len, (const char*)opt_target.value.ptr);
                        fprintf(stderr, "parsed from line:\n%.*s\n", (int)opt_line.value.len, opt_line.value.ptr);
                        fprintf(stderr, "Zig installation appears to be corrupted.\n");
                        exit(1);
                    }

                    glibc_abi->version_table.put(target, ver_list_base);
                }
                continue;
            }
            for (size_t fn_i = 0; fn_i < glibc_abi->all_functions.length; fn_i += 1) {
                ZigGLibCVerList *ver_list = &ver_list_base[fn_i];
                line_num += 1;
                Optional<Slice<uint8_t>> opt_line = SplitIterator_next_separate(&it);
                assert(opt_line.is_some);

                SplitIterator line_it = memSplit(opt_line.value, str(" "));
                for (;;) {
                    Optional<Slice<uint8_t>> opt_ver = SplitIterator_next(&line_it);
                    if (!opt_ver.is_some) break;
                    assert(ver_list->len < 8); // increase the array len in the type

                    unsigned long ver_index = strtoul(buf_ptr(buf_create_from_slice(opt_ver.value)), nullptr, 10);
                    assert(ver_index < 255); // use a bigger integer in the type
                    ver_list->versions[ver_list->len] = ver_index;
                    ver_list->len += 1;
                }
            }
            ver_list_base = nullptr;
        }
    }

    *out_result = glibc_abi;
    return ErrorNone;
}

Error glibc_build_dummies_and_maps(CodeGen *g, const ZigGLibCAbi *glibc_abi, const ZigTarget *target,
        Buf **out_dir, bool verbose, Stage2ProgressNode *progress_node)
{
    Error err;

    Buf *cache_dir = get_global_cache_dir();
    CacheHash *cache_hash = heap::c_allocator.create<CacheHash>();
    Buf *manifest_dir = buf_sprintf("%s" OS_SEP CACHE_HASH_SUBDIR, buf_ptr(cache_dir));
    cache_init(cache_hash, manifest_dir);

    Buf *compiler_id;
    if ((err = get_compiler_id(&compiler_id))) {
        if (verbose) {
            fprintf(stderr, "unable to get compiler id: %s\n", err_str(err));
        }
        return err;
    }
    cache_buf(cache_hash, compiler_id);
    cache_int(cache_hash, target->arch);
    cache_int(cache_hash, target->abi);
    cache_int(cache_hash, target->glibc_or_darwin_version->major);
    cache_int(cache_hash, target->glibc_or_darwin_version->minor);
    cache_int(cache_hash, target->glibc_or_darwin_version->patch);

    Buf digest = BUF_INIT;
    buf_resize(&digest, 0);
    if ((err = cache_hit(cache_hash, &digest))) {
        // Treat an invalid format error as a cache miss.
        if (err != ErrorInvalidFormat)
            return err;
    }
    // We should always get a cache hit because there are no
    // files in the input hash.
    assert(buf_len(&digest) != 0);

    Buf *dummy_dir = buf_alloc();
    os_path_join(manifest_dir, &digest, dummy_dir);

    if ((err = os_make_path(dummy_dir)))
        return err;

    Buf *test_if_exists_path = buf_alloc();
    os_path_join(dummy_dir, buf_create_from_str("ok"), test_if_exists_path);

    bool hit;
    if ((err = os_file_exists(test_if_exists_path, &hit)))
        return err;

    if (hit) {
        *out_dir = dummy_dir;
        return ErrorNone;
    }


    ZigGLibCVerList *ver_list_base = glibc_abi->version_table.get(target);

    uint8_t target_ver_index = 0;
    for (;target_ver_index < glibc_abi->all_versions.length; target_ver_index += 1) {
        const Stage2SemVer *this_ver = &glibc_abi->all_versions.at(target_ver_index);
        if (this_ver->major == target->glibc_or_darwin_version->major &&
            this_ver->minor == target->glibc_or_darwin_version->minor &&
            this_ver->patch == target->glibc_or_darwin_version->patch)
        {
            break;
        }
    }
    if (target_ver_index == glibc_abi->all_versions.length) {
        if (verbose) {
            fprintf(stderr, "Unrecognized glibc version: %d.%d.%d\n",
                   target->glibc_or_darwin_version->major,
                   target->glibc_or_darwin_version->minor,
                   target->glibc_or_darwin_version->patch);
        }
        return ErrorUnknownABI;
    }

    Buf *map_file_path = buf_sprintf("%s" OS_SEP "all.map", buf_ptr(dummy_dir));
    Buf *map_contents = buf_alloc();

    for (uint8_t ver_i = 0; ver_i < glibc_abi->all_versions.length; ver_i += 1) {
        const Stage2SemVer *ver = &glibc_abi->all_versions.at(ver_i);
        if (ver->patch == 0) {
            buf_appendf(map_contents, "GLIBC_%d.%d { };\n", ver->major, ver->minor);
        } else {
            buf_appendf(map_contents, "GLIBC_%d.%d.%d { };\n", ver->major, ver->minor, ver->patch);
        }
    }

    if ((err = os_write_file(map_file_path, map_contents))) {
        if (verbose) {
            fprintf(stderr, "unable to write %s: %s", buf_ptr(map_file_path), err_str(err));
        }
        return err;
    }


    for (size_t lib_i = 0; lib_i < array_length(glibc_libs); lib_i += 1) {
        const ZigGLibCLib *lib = &glibc_libs[lib_i];
        Buf *zig_file_path = buf_sprintf("%s" OS_SEP "%s.zig", buf_ptr(dummy_dir), lib->name);
        Buf *zig_body = buf_alloc();
        Buf *zig_footer = buf_alloc();

        buf_appendf(zig_body, "comptime {\n");
        buf_appendf(zig_body, "    asm (\n");

        for (size_t fn_i = 0; fn_i < glibc_abi->all_functions.length; fn_i += 1) {
            const ZigGLibCFn *libc_fn = &glibc_abi->all_functions.at(fn_i);
            if (libc_fn->lib != lib) continue;
            ZigGLibCVerList *ver_list = &ver_list_base[fn_i];
            // Pick the default symbol version:
            // - If there are no versions, don't emit it
            // - Take the greatest one <= than the target one
            // - If none of them is <= than the
            //   specified one don't pick any default version
            if (ver_list->len == 0) continue;
            uint8_t chosen_def_ver_index = 255;
            for (uint8_t ver_i = 0; ver_i < ver_list->len; ver_i += 1) {
                uint8_t ver_index = ver_list->versions[ver_i];
                if ((chosen_def_ver_index == 255 || ver_index > chosen_def_ver_index) &&
                    target_ver_index >= ver_index)
                {
                    chosen_def_ver_index = ver_index;
                }
            }
            for (uint8_t ver_i = 0; ver_i < ver_list->len; ver_i += 1) {
                uint8_t ver_index = ver_list->versions[ver_i];

                Buf *stub_name;
                const Stage2SemVer *ver = &glibc_abi->all_versions.at(ver_index);
                const char *sym_name = buf_ptr(libc_fn->name);
                if (ver->patch == 0) {
                    stub_name = buf_sprintf("%s_%d_%d", sym_name, ver->major, ver->minor);
                } else {
                    stub_name = buf_sprintf("%s_%d_%d_%d", sym_name, ver->major, ver->minor, ver->patch);
                }

                buf_appendf(zig_footer, "export fn %s() void {}\n", buf_ptr(stub_name));

                // Default symbol version definition vs normal symbol version definition
                const char *at_sign_str = (chosen_def_ver_index != 255 &&
                        ver_index == chosen_def_ver_index) ? "@@" : "@";
                if (ver->patch == 0) {
                    buf_appendf(zig_body, "        \\\\ .symver %s, %s%sGLIBC_%d.%d\n",
                            buf_ptr(stub_name), sym_name, at_sign_str, ver->major, ver->minor);
                } else {
                    buf_appendf(zig_body, "        \\\\ .symver %s, %s%sGLIBC_%d.%d.%d\n",
                            buf_ptr(stub_name), sym_name, at_sign_str, ver->major, ver->minor, ver->patch);
                }
                // Hide the stub to keep the symbol table clean
                buf_appendf(zig_body, "        \\\\ .hidden %s\n", buf_ptr(stub_name));
            }
        }

        buf_appendf(zig_body, "    );\n");
        buf_appendf(zig_body, "}\n");
        buf_append_buf(zig_body, zig_footer);

        if ((err = os_write_file(zig_file_path, zig_body))) {
            if (verbose) {
                fprintf(stderr, "unable to write %s: %s", buf_ptr(zig_file_path), err_str(err));
            }
            return err;
        }

        CodeGen *child_gen = create_child_codegen(g, zig_file_path, OutTypeLib, nullptr, lib->name, progress_node);
        codegen_set_lib_version(child_gen, lib->sover, 0, 0);
        child_gen->is_dynamic = true;
        child_gen->is_dummy_so = true;
        child_gen->version_script_path = map_file_path;
        child_gen->enable_cache = false;
        child_gen->output_dir = dummy_dir;
        codegen_build_and_link(child_gen);
    }

    if ((err = os_write_file(test_if_exists_path, buf_alloc()))) {
        if (verbose) {
            fprintf(stderr, "unable to write %s: %s", buf_ptr(test_if_exists_path), err_str(err));
        }
        return err;
    }
    *out_dir = dummy_dir;
    return ErrorNone;
}

uint32_t hash_glibc_target(const ZigTarget *x) {
    return x->arch * 3250106448 +
        x->os * 542534372 +
        x->abi * 59162639;
}

bool eql_glibc_target(const ZigTarget *a, const ZigTarget *b) {
    return a->arch == b->arch &&
        a->os == b->os &&
        a->abi == b->abi;
}

size_t glibc_lib_count(void) {
    return array_length(glibc_libs);
}

const ZigGLibCLib *glibc_lib_enum(size_t index) {
    assert(index < array_length(glibc_libs));
    return &glibc_libs[index];
}

const ZigGLibCLib *glibc_lib_find(const char *name) {
    for (size_t i = 0; i < array_length(glibc_libs); i += 1) {
        if (strcmp(glibc_libs[i].name, name) == 0) {
            return &glibc_libs[i];
        }
    }
    return nullptr;
}
