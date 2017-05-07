/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "link.hpp"
#include "os.hpp"
#include "config.h"
#include "codegen.hpp"
#include "analyze.hpp"

struct LinkJob {
    CodeGen *codegen;
    Buf out_file;
    ZigList<const char *> args;
    bool link_in_crt;
    HashMap<Buf *, bool, buf_hash, buf_eql_buf> rpath_table;
};

static const char *get_libc_file(CodeGen *g, const char *file) {
    Buf *out_buf = buf_alloc();
    os_path_join(g->libc_lib_dir, buf_create_from_str(file), out_buf);
    return buf_ptr(out_buf);
}

static const char *get_libc_static_file(CodeGen *g, const char *file) {
    Buf *out_buf = buf_alloc();
    os_path_join(g->libc_static_lib_dir, buf_create_from_str(file), out_buf);
    return buf_ptr(out_buf);
}

static Buf *build_o(CodeGen *parent_gen, const char *oname) {
    Buf *source_basename = buf_sprintf("%s.zig", oname);
    Buf *full_path = buf_alloc();
    os_path_join(parent_gen->zig_std_special_dir, source_basename, full_path);

    ZigTarget *child_target = parent_gen->is_native_target ? nullptr : &parent_gen->zig_target;
    CodeGen *child_gen = codegen_create(full_path, child_target, OutTypeObj, parent_gen->build_mode);
    child_gen->link_libc = parent_gen->link_libc;

    child_gen->link_libs.resize(parent_gen->link_libs.length);
    for (size_t i = 0; i < parent_gen->link_libs.length; i += 1) {
        child_gen->link_libs.items[i] = parent_gen->link_libs.items[i];
    }

    codegen_set_omit_zigrt(child_gen, true);
    child_gen->want_h_file = false;

    codegen_set_cache_dir(child_gen, parent_gen->cache_dir);

    codegen_set_strip(child_gen, parent_gen->strip_debug_symbols);
    codegen_set_is_static(child_gen, parent_gen->is_static);

    codegen_set_out_name(child_gen, buf_create_from_str(oname));

    codegen_set_verbose(child_gen, parent_gen->verbose);
    codegen_set_errmsg_color(child_gen, parent_gen->err_color);

    codegen_set_mmacosx_version_min(child_gen, parent_gen->mmacosx_version_min);
    codegen_set_mios_version_min(child_gen, parent_gen->mios_version_min);

    codegen_build(child_gen);
    const char *o_ext = target_o_file_ext(&child_gen->zig_target);
    Buf *o_out_name = buf_sprintf("%s%s", oname, o_ext);
    Buf *output_path = buf_alloc();
    os_path_join(parent_gen->cache_dir, o_out_name, output_path);
    codegen_link(child_gen, buf_ptr(output_path));

    return output_path;
}

static const char *get_exe_file_extension(CodeGen *g) {
    if (g->zig_target.os == ZigLLVM_Win32) {
        return ".exe";
    } else {
        return "";
    }
}

static const char *get_darwin_arch_string(const ZigTarget *t) {
    switch (t->arch.arch) {
        case ZigLLVM_aarch64:
            return "arm64";
        case ZigLLVM_thumb:
        case ZigLLVM_arm:
            return "arm";
        case ZigLLVM_ppc:
            return "ppc";
        case ZigLLVM_ppc64:
            return "ppc64";
        case ZigLLVM_ppc64le:
            return "ppc64le";
        default:
            return ZigLLVMGetArchTypeName(t->arch.arch);
    }
}


static const char *getLDMOption(const ZigTarget *t) {
    switch (t->arch.arch) {
        case ZigLLVM_x86:
            return "elf_i386";
        case ZigLLVM_aarch64:
            return "aarch64linux";
        case ZigLLVM_aarch64_be:
            return "aarch64_be_linux";
        case ZigLLVM_arm:
        case ZigLLVM_thumb:
            return "armelf_linux_eabi";
        case ZigLLVM_armeb:
        case ZigLLVM_thumbeb:
            return "armebelf_linux_eabi";
        case ZigLLVM_ppc:
            return "elf32ppclinux";
        case ZigLLVM_ppc64:
            return "elf64ppc";
        case ZigLLVM_ppc64le:
            return "elf64lppc";
        case ZigLLVM_sparc:
        case ZigLLVM_sparcel:
            return "elf32_sparc";
        case ZigLLVM_sparcv9:
            return "elf64_sparc";
        case ZigLLVM_mips:
            return "elf32btsmip";
        case ZigLLVM_mipsel:
            return "elf32ltsmip";
            return "elf64btsmip";
        case ZigLLVM_mips64el:
            return "elf64ltsmip";
        case ZigLLVM_systemz:
            return "elf64_s390";
        case ZigLLVM_x86_64:
            if (t->env_type == ZigLLVM_GNUX32) {
                return "elf32_x86_64";
            }
            return "elf_x86_64";
        default:
            zig_unreachable();
    }
}

static void add_rpath(LinkJob *lj, Buf *rpath) {
    if (lj->rpath_table.maybe_get(rpath) != nullptr)
        return;

    lj->args.append("-rpath");
    lj->args.append(buf_ptr(rpath));

    lj->rpath_table.put(rpath, true);
}

static void construct_linker_job_elf(LinkJob *lj) {
    CodeGen *g = lj->codegen;

    if (lj->link_in_crt) {
        find_libc_lib_path(g);
    }

    if (g->linker_script) {
        lj->args.append("-T");
        lj->args.append(g->linker_script);
    }

    lj->args.append("--gc-sections");

    lj->args.append("-m");
    lj->args.append(getLDMOption(&g->zig_target));

    bool is_lib = g->out_type == OutTypeLib;
    bool shared = !g->is_static && is_lib;
    Buf *soname = nullptr;
    if (g->is_static) {
        if (g->zig_target.arch.arch == ZigLLVM_arm || g->zig_target.arch.arch == ZigLLVM_armeb ||
            g->zig_target.arch.arch == ZigLLVM_thumb || g->zig_target.arch.arch == ZigLLVM_thumbeb)
        {
            lj->args.append("-Bstatic");
        } else {
            lj->args.append("-static");
        }
    } else if (shared) {
        lj->args.append("-shared");

        if (buf_len(&lj->out_file) == 0) {
            buf_appendf(&lj->out_file, "lib%s.so.%zu.%zu.%zu",
                    buf_ptr(g->root_out_name), g->version_major, g->version_minor, g->version_patch);
        }
        soname = buf_sprintf("lib%s.so.%zu", buf_ptr(g->root_out_name), g->version_major);
    }

    lj->args.append("-o");
    lj->args.append(buf_ptr(&lj->out_file));

    if (lj->link_in_crt) {
        const char *crt1o;
        const char *crtbegino;
        if (g->is_static) {
            crt1o = "crt1.o";
            crtbegino = "crtbeginT.o";
        } else {
            crt1o = "Scrt1.o";
            crtbegino = "crtbegin.o";
        }
        lj->args.append(get_libc_file(g, crt1o));
        lj->args.append(get_libc_file(g, "crti.o"));
        lj->args.append(get_libc_static_file(g, crtbegino));
    }

    for (size_t i = 0; i < g->rpath_list.length; i += 1) {
        Buf *rpath = g->rpath_list.at(i);
        add_rpath(lj, rpath);
    }
    if (g->each_lib_rpath) {
        for (size_t i = 0; i < g->lib_dirs.length; i += 1) {
            const char *lib_dir = g->lib_dirs.at(i);
            for (size_t i = 0; i < g->link_libs.length; i += 1) {
                Buf *link_lib = g->link_libs.at(i);
                if (buf_eql_str(link_lib, "c")) {
                    continue;
                }
                bool does_exist;
                Buf *test_path = buf_sprintf("%s/lib%s.so", lib_dir, buf_ptr(link_lib));
                if (os_file_exists(test_path, &does_exist) != ErrorNone) {
                    zig_panic("link: unable to check if file exists: %s", buf_ptr(test_path));
                }
                if (does_exist) {
                    add_rpath(lj, buf_create_from_str(lib_dir));
                    break;
                }
            }
        }
    }

    for (size_t i = 0; i < g->lib_dirs.length; i += 1) {
        const char *lib_dir = g->lib_dirs.at(i);
        lj->args.append("-L");
        lj->args.append(lib_dir);
    }

    if (g->link_libc) {
        lj->args.append("-L");
        lj->args.append(buf_ptr(g->libc_lib_dir));

        lj->args.append("-L");
        lj->args.append(buf_ptr(g->libc_static_lib_dir));
    }

    if (g->dynamic_linker && buf_len(g->dynamic_linker) > 0) {
        lj->args.append("-dynamic-linker");
        lj->args.append(buf_ptr(g->dynamic_linker));
    } else {
        lj->args.append("-dynamic-linker");
        lj->args.append(buf_ptr(target_dynamic_linker(&g->zig_target)));
    }

    if (shared) {
        lj->args.append("-soname");
        lj->args.append(buf_ptr(soname));
    }

    // .o files
    for (size_t i = 0; i < g->link_objects.length; i += 1) {
        lj->args.append((const char *)buf_ptr(g->link_objects.at(i)));
    }

    if (!g->link_libc && (g->out_type == OutTypeExe || g->out_type == OutTypeLib)) {
        Buf *builtin_o_path = build_o(g, "builtin");
        lj->args.append(buf_ptr(builtin_o_path));

        Buf *compiler_rt_o_path = build_o(g, "compiler_rt");
        lj->args.append(buf_ptr(compiler_rt_o_path));
    }

    for (size_t i = 0; i < g->link_libs.length; i += 1) {
        Buf *link_lib = g->link_libs.at(i);
        if (buf_eql_str(link_lib, "c")) {
            continue;
        }
        Buf *arg;
        if (buf_starts_with_str(link_lib, "/") || buf_ends_with_str(link_lib, ".a") ||
            buf_ends_with_str(link_lib, ".so"))
        {
            arg = link_lib;
        } else {
            arg = buf_sprintf("-l%s", buf_ptr(link_lib));
        }
        lj->args.append(buf_ptr(arg));
    }


    // libc dep
    if (g->link_libc) {
        if (g->is_static) {
            lj->args.append("--start-group");
            lj->args.append("-lgcc");
            lj->args.append("-lgcc_eh");
            lj->args.append("-lc");
            lj->args.append("-lm");
            lj->args.append("--end-group");
        } else {
            lj->args.append("-lgcc");
            lj->args.append("--as-needed");
            lj->args.append("-lgcc_s");
            lj->args.append("--no-as-needed");
            lj->args.append("-lc");
            lj->args.append("-lm");
            lj->args.append("-lgcc");
            lj->args.append("--as-needed");
            lj->args.append("-lgcc_s");
            lj->args.append("--no-as-needed");
        }
    }

    // crt end
    if (lj->link_in_crt) {
        lj->args.append(get_libc_static_file(g, "crtend.o"));
        lj->args.append(get_libc_file(g, "crtn.o"));
    }
}

static bool is_target_cyg_mingw(const ZigTarget *target) {
    return (target->os == ZigLLVM_Win32 && target->env_type == ZigLLVM_Cygnus) ||
        (target->os == ZigLLVM_Win32 && target->env_type == ZigLLVM_GNU);
}

static void construct_linker_job_coff(LinkJob *lj) {
    CodeGen *g = lj->codegen;

    if (lj->link_in_crt) {
        find_libc_lib_path(g);
    }

    if (g->zig_target.arch.arch == ZigLLVM_x86) {
        lj->args.append("-m");
        lj->args.append("i386pe");
    } else if (g->zig_target.arch.arch == ZigLLVM_x86_64) {
        lj->args.append("-m");
        lj->args.append("i386pep");
    } else if (g->zig_target.arch.arch == ZigLLVM_arm) {
        lj->args.append("-m");
        lj->args.append("thumb2pe");
    }

    if (g->windows_subsystem_windows) {
        lj->args.append("--subsystem");
        lj->args.append("windows");
    } else if (g->windows_subsystem_console) {
        lj->args.append("--subsystem");
        lj->args.append("console");
    }

    bool dll = g->out_type == OutTypeLib;
    bool shared = !g->is_static && dll;
    if (g->is_static) {
        lj->args.append("-Bstatic");
    } else {
        if (dll) {
            lj->args.append("--dll");
        } else if (shared) {
            lj->args.append("--shared");
        }
        lj->args.append("-Bdynamic");
        if (dll || shared) {
            lj->args.append("-e");
            if (g->zig_target.arch.arch == ZigLLVM_x86) {
                lj->args.append("_DllMainCRTStartup@12");
            } else {
                lj->args.append("DllMainCRTStartup");
            }
            lj->args.append("--enable-auto-image-base");
        }
    }

    lj->args.append("-o");
    lj->args.append(buf_ptr(&lj->out_file));

    if (lj->link_in_crt) {
        if (shared || dll) {
            lj->args.append(get_libc_file(g, "dllcrt2.o"));
        } else {
            if (g->windows_linker_unicode) {
                lj->args.append(get_libc_file(g, "crt2u.o"));
            } else {
                lj->args.append(get_libc_file(g, "crt2.o"));
            }
        }
        lj->args.append(get_libc_static_file(g, "crtbegin.o"));
    }

    for (size_t i = 0; i < g->lib_dirs.length; i += 1) {
        const char *lib_dir = g->lib_dirs.at(i);
        lj->args.append("-L");
        lj->args.append(lib_dir);
    }

    if (g->link_libc) {
        lj->args.append("-L");
        lj->args.append(buf_ptr(g->libc_lib_dir));

        lj->args.append("-L");
        lj->args.append(buf_ptr(g->libc_static_lib_dir));
    }

    for (size_t i = 0; i < g->link_objects.length; i += 1) {
        lj->args.append((const char *)buf_ptr(g->link_objects.at(i)));
    }

    if (!g->link_libc && (g->out_type == OutTypeExe || g->out_type == OutTypeLib)) {
        Buf *builtin_o_path = build_o(g, "builtin");
        lj->args.append(buf_ptr(builtin_o_path));

        Buf *compiler_rt_o_path = build_o(g, "compiler_rt");
        lj->args.append(buf_ptr(compiler_rt_o_path));
    }


    for (size_t i = 0; i < g->link_libs.length; i += 1) {
        Buf *link_lib = g->link_libs.at(i);
        if (buf_eql_str(link_lib, "c")) {
            continue;
        }
        Buf *arg = buf_sprintf("-l%s", buf_ptr(link_lib));
        lj->args.append(buf_ptr(arg));
    }

    if (g->link_libc) {
        if (g->is_static) {
            lj->args.append("--start-group");
        }

        lj->args.append("-lmingw32");

        lj->args.append("-lgcc");
        bool is_android = (g->zig_target.env_type == ZigLLVM_Android);
        bool is_cyg_ming = is_target_cyg_mingw(&g->zig_target);
        if (!g->is_static && !is_android) {
            if (!is_cyg_ming) {
                lj->args.append("--as-needed");
            }
            //lj->args.append("-lgcc_s");
            if (!is_cyg_ming) {
                lj->args.append("--no-as-needed");
            }
        }
        if (g->is_static && !is_android) {
            //lj->args.append("-lgcc_eh");
        }
        if (is_android && !g->is_static) {
            lj->args.append("-ldl");
        }

        lj->args.append("-lmoldname");
        lj->args.append("-lmingwex");
        lj->args.append("-lmsvcrt");


        if (g->windows_subsystem_windows) {
            lj->args.append("-lgdi32");
            lj->args.append("-lcomdlg32");
        }
        lj->args.append("-ladvapi32");
        lj->args.append("-lshell32");
        lj->args.append("-luser32");
        lj->args.append("-lkernel32");

        if (g->is_static) {
            lj->args.append("--end-group");
        }

        if (lj->link_in_crt) {
            lj->args.append(get_libc_static_file(g, "crtend.o"));
        }
    }
}


// Parse (([0-9]+)(.([0-9]+)(.([0-9]+)?))?)? and return the
// grouped values as integers. Numbers which are not provided are set to 0.
// return true if the entire string was parsed (9.2), or all groups were
// parsed (10.3.5extrastuff).
static bool darwin_get_release_version(const char *str, int *major, int *minor, int *micro, bool *had_extra) {
    *had_extra = false;

    *major = 0;
    *minor = 0;
    *micro = 0;

    if (*str == '\0')
        return false;

    char *end;
    *major = (int)strtol(str, &end, 10);
    if (*str != '\0' && *end == '\0')
        return true;
    if (*end != '.')
        return false;

    str = end + 1;
    *minor = (int)strtol(str, &end, 10);
    if (*str != '\0' && *end == '\0')
        return true;
    if (*end != '.')
        return false;

    str = end + 1;
    *micro = (int)strtol(str, &end, 10);
    if (*str != '\0' && *end == '\0')
        return true;
    if (str == end)
        return false;
    *had_extra = true;
    return true;
}

enum DarwinPlatformKind {
    MacOS,
    IPhoneOS,
    IPhoneOSSimulator,
};

struct DarwinPlatform {
    DarwinPlatformKind kind;
    int major;
    int minor;
    int micro;
};

static void get_darwin_platform(LinkJob *lj, DarwinPlatform *platform) {
    CodeGen *g = lj->codegen;

    if (g->mmacosx_version_min) {
        platform->kind = MacOS;
    } else if (g->mios_version_min) {
        platform->kind = IPhoneOS;
    } else {
        zig_panic("unable to infer -macosx-version-min or -mios-version-min");
    }

    bool had_extra;
    if (platform->kind == MacOS) {
        if (!darwin_get_release_version(buf_ptr(g->mmacosx_version_min),
                    &platform->major, &platform->minor, &platform->micro, &had_extra) ||
                had_extra || platform->major != 10 || platform->minor >= 100 || platform->micro >= 100)
        {
            zig_panic("invalid -mmacosx-version-min");
        }
    } else if (platform->kind == IPhoneOS) {
        if (!darwin_get_release_version(buf_ptr(g->mios_version_min),
                    &platform->major, &platform->minor, &platform->micro, &had_extra) ||
                had_extra || platform->major >= 10 || platform->minor >= 100 || platform->micro >= 100)
        {
            zig_panic("invalid -mios-version-min");
        }
    } else {
        zig_unreachable();
    }

    if (platform->kind == IPhoneOS &&
        (g->zig_target.arch.arch == ZigLLVM_x86 ||
         g->zig_target.arch.arch == ZigLLVM_x86_64))
    {
        platform->kind = IPhoneOSSimulator;
    }
}

static bool darwin_version_lt(DarwinPlatform *platform, int major, int minor) {
    if (platform->major < major) {
        return true;
    } else if (platform->major > major) {
        return false;
    }
    if (platform->minor < minor) {
        return true;
    }
    return false;
}

static void construct_linker_job_macho(LinkJob *lj) {
    CodeGen *g = lj->codegen;

    lj->args.append("-demangle");

    if (g->linker_rdynamic) {
        lj->args.append("-export_dynamic");
    }

    bool is_lib = g->out_type == OutTypeLib;
    bool shared = !g->is_static && is_lib;
    if (g->is_static) {
        lj->args.append("-static");
    } else {
        lj->args.append("-dynamic");
    }

    if (is_lib) {
        zig_panic("TODO linker args on darwin for making a library");
    }

    lj->args.append("-arch");
    lj->args.append(get_darwin_arch_string(&g->zig_target));

    DarwinPlatform platform;
    get_darwin_platform(lj, &platform);
    switch (platform.kind) {
        case MacOS:
            lj->args.append("-macosx_version_min");
            break;
        case IPhoneOS:
            lj->args.append("-iphoneos_version_min");
            break;
        case IPhoneOSSimulator:
            lj->args.append("-ios_simulator_version_min");
            break;
    }
    lj->args.append(buf_ptr(buf_sprintf("%d.%d.%d", platform.major, platform.minor, platform.micro)));


    if (g->out_type == OutTypeExe) {
        if (g->is_static) {
            lj->args.append("-no_pie");
        } else {
            lj->args.append("-pie");
        }
    }

    lj->args.append("-o");
    lj->args.append(buf_ptr(&lj->out_file));

    if (shared) {
        zig_panic("TODO");
    } else if (g->is_static) {
        lj->args.append("-lcrt0.o");
    } else {
        switch (platform.kind) {
            case MacOS:
                if (darwin_version_lt(&platform, 10, 5)) {
                    lj->args.append("-lcrt1.o");
                } else if (darwin_version_lt(&platform, 10, 6)) {
                    lj->args.append("-lcrt1.10.5.o");
                } else if (darwin_version_lt(&platform, 10, 8)) {
                    lj->args.append("-lcrt1.10.6.o");
                }
                break;
            case IPhoneOS:
                if (g->zig_target.arch.arch == ZigLLVM_aarch64) {
                    // iOS does not need any crt1 files for arm64
                } else if (darwin_version_lt(&platform, 3, 1)) {
                    lj->args.append("-lcrt1.o");
                } else if (darwin_version_lt(&platform, 6, 0)) {
                    lj->args.append("-lcrt1.3.1.o");
                }
                break;
            case IPhoneOSSimulator:
                // no crt1.o needed
                break;
        }
    }

    for (size_t i = 0; i < g->lib_dirs.length; i += 1) {
        const char *lib_dir = g->lib_dirs.at(i);
        lj->args.append("-L");
        lj->args.append(lib_dir);
    }

    for (size_t i = 0; i < g->link_objects.length; i += 1) {
        lj->args.append((const char *)buf_ptr(g->link_objects.at(i)));
    }

    for (size_t i = 0; i < g->link_libs.length; i += 1) {
        Buf *link_lib = g->link_libs.at(i);
        if (buf_eql_str(link_lib, "c")) {
            continue;
        }
        Buf *arg = buf_sprintf("-l%s", buf_ptr(link_lib));
        lj->args.append(buf_ptr(arg));
    }

    // on Darwin, libSystem has libc in it, but also you have to use it
    // to make syscalls because the syscall numbers are not documented
    // and change between versions.
    // so we always link against libSystem
    lj->args.append("-lSystem");

    if (platform.kind == MacOS) {
        if (darwin_version_lt(&platform, 10, 5)) {
            lj->args.append("-lgcc_s.10.4");
        } else if (darwin_version_lt(&platform, 10, 6)) {
            lj->args.append("-lgcc_s.10.5");
        }
    } else {
        zig_panic("TODO");
    }

    for (size_t i = 0; i < g->darwin_frameworks.length; i += 1) {
        lj->args.append("-framework");
        lj->args.append(buf_ptr(g->darwin_frameworks.at(i)));
    }

}

static void construct_linker_job(LinkJob *lj) {
    switch (lj->codegen->zig_target.oformat) {
        case ZigLLVM_UnknownObjectFormat:
            zig_unreachable();

        case ZigLLVM_COFF:
            return construct_linker_job_coff(lj);
        case ZigLLVM_ELF:
            return construct_linker_job_elf(lj);
        case ZigLLVM_MachO:
            return construct_linker_job_macho(lj);
    }
}

void codegen_link(CodeGen *g, const char *out_file) {
    codegen_add_time_event(g, "Build Dependencies");

    LinkJob lj = {0};

    // even though we're calling LLD as a library it thinks the first
    // argument is its own exe name
    lj.args.append("lld");

    lj.rpath_table.init(4);
    lj.codegen = g;
    if (out_file) {
        buf_init_from_str(&lj.out_file, out_file);
    } else {
        buf_resize(&lj.out_file, 0);
    }

    if (g->verbose) {
        fprintf(stderr, "\nOptimization:\n");
        fprintf(stderr, "---------------\n");
        LLVMDumpModule(g->module);
    }
    if (g->verbose) {
        fprintf(stderr, "\nLink:\n");
        fprintf(stderr, "-------\n");
    }

    bool override_out_file = (buf_len(&lj.out_file) != 0);
    if (!override_out_file) {
        assert(g->root_out_name);

        buf_init_from_buf(&lj.out_file, g->root_out_name);
        if (g->out_type == OutTypeExe) {
            buf_append_str(&lj.out_file, get_exe_file_extension(g));
        }
    }

    if (g->out_type == OutTypeObj) {
        if (override_out_file) {
            assert(g->link_objects.length == 1);
            Buf *o_file_path = g->link_objects.at(0);
            int err;
            if ((err = os_rename(o_file_path, &lj.out_file))) {
                zig_panic("unable to rename object file into final output: %s", err_str(err));
            }
        }
        if (g->verbose) {
            fprintf(stderr, "OK\n");
        }
        return;
    }

    if (g->out_type == OutTypeLib && g->is_static) {
        // invoke `ar`
        // example:
        // # static link into libfoo.a
        // ar rcs libfoo.a foo1.o foo2.o
        zig_panic("TODO invoke ar");
        return;
    }

    lj.link_in_crt = (g->link_libc && g->out_type == OutTypeExe);

    construct_linker_job(&lj);


    if (g->verbose) {
        for (size_t i = 0; i < lj.args.length; i += 1) {
            const char *space = (i != 0) ? " " : "";
            fprintf(stderr, "%s%s", space, lj.args.at(i));
        }
        fprintf(stderr, "\n");
    }

    Buf diag = BUF_INIT;

    codegen_add_time_event(g, "LLVM Link");
    if (!ZigLLDLink(g->zig_target.oformat, lj.args.items, lj.args.length, &diag)) {
        fprintf(stderr, "%s\n", buf_ptr(&diag));
        exit(1);
    }

    codegen_add_time_event(g, "Done");

    if (g->verbose) {
        fprintf(stderr, "OK\n");
    }
}
