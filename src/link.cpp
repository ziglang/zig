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
    Buf out_file_o;
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
    Buf *std_dir_path = buf_create_from_str(ZIG_STD_DIR);

    ZigTarget *child_target = parent_gen->is_native_target ? nullptr : &parent_gen->zig_target;
    CodeGen *child_gen = codegen_create(std_dir_path, child_target);
    child_gen->link_libc = parent_gen->link_libc;

    codegen_set_is_release(child_gen, parent_gen->is_release_build);

    codegen_set_strip(child_gen, parent_gen->strip_debug_symbols);
    codegen_set_is_static(child_gen, parent_gen->is_static);

    codegen_set_out_type(child_gen, OutTypeObj);
    codegen_set_out_name(child_gen, buf_create_from_str(oname));

    codegen_set_verbose(child_gen, parent_gen->verbose);
    codegen_set_errmsg_color(child_gen, parent_gen->err_color);

    codegen_set_mmacosx_version_min(child_gen, parent_gen->mmacosx_version_min);
    codegen_set_mios_version_min(child_gen, parent_gen->mios_version_min);

    Buf *full_path = buf_alloc();
    os_path_join(std_dir_path, source_basename, full_path);
    Buf source_code = BUF_INIT;
    if (os_fetch_file_path(full_path, &source_code)) {
        zig_panic("unable to fetch file: %s\n", buf_ptr(full_path));
    }

    codegen_add_root_code(child_gen, std_dir_path, source_basename, &source_code);
    Buf *o_out = buf_sprintf("%s.o", oname);
    codegen_link(child_gen, buf_ptr(o_out));

    return o_out;
}

static const char *get_o_file_extension(CodeGen *g) {
    if (g->zig_target.env_type == ZigLLVM_MSVC) {
        return ".obj";
    } else {
        return ".o";
    }
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

static void construct_linker_job_linux(LinkJob *lj) {
    CodeGen *g = lj->codegen;

    if (lj->link_in_crt) {
        find_libc_lib_path(g);
    }


    lj->args.append("-m");
    lj->args.append(getLDMOption(&g->zig_target));

    bool is_lib = g->out_type == OutTypeLib;
    bool shared = !g->is_static && is_lib;
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

    for (int i = 0; i < g->lib_dirs.length; i += 1) {
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
        lj->args.append(buf_ptr(get_dynamic_linker(g->target_machine)));
    }

    if (g->out_type == OutTypeLib) {
        buf_resize(&lj->out_file, 0);
        buf_appendf(&lj->out_file, "lib%s.so.%d.%d.%d",
                buf_ptr(g->root_out_name), g->version_major, g->version_minor, g->version_patch);
        Buf *soname = buf_sprintf("lib%s.so.%d", buf_ptr(g->root_out_name), g->version_major);
        lj->args.append("-soname");
        lj->args.append(buf_ptr(soname));
    }

    // .o files
    lj->args.append((const char *)buf_ptr(&lj->out_file_o));

    if (g->is_test_build) {
        const char *test_runner_name = g->link_libc ? "test_runner_libc" : "test_runner_nolibc";
        Buf *test_runner_o_path = build_o(g, test_runner_name);
        lj->args.append(buf_ptr(test_runner_o_path));
    }

    if (!g->link_libc && (g->out_type == OutTypeExe || g->out_type == OutTypeLib)) {
        Buf *builtin_o_path = build_o(g, "builtin");
        lj->args.append(buf_ptr(builtin_o_path));

        Buf *compiler_rt_o_path = build_o(g, "compiler_rt");
        lj->args.append(buf_ptr(compiler_rt_o_path));
    }

    for (int i = 0; i < g->link_libs.length; i += 1) {
        Buf *link_lib = g->link_libs.at(i);
        Buf *arg = buf_sprintf("-l%s", buf_ptr(link_lib));
        lj->args.append(buf_ptr(arg));
    }


    // libc dep
    if (g->link_libc) {
        if (g->is_static) {
            lj->args.append("--start-group");
            lj->args.append("-lgcc");
            lj->args.append("-lgcc_eh");
            lj->args.append("-lc");
            lj->args.append("--end-group");
        } else {
            lj->args.append("-lgcc");
            lj->args.append("--as-needed");
            lj->args.append("-lgcc_s");
            lj->args.append("--no-as-needed");
            lj->args.append("-lc");
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

static void construct_linker_job_mingw(LinkJob *lj) {
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

    for (int i = 0; i < g->lib_dirs.length; i += 1) {
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

    lj->args.append((const char *)buf_ptr(&lj->out_file_o));

    if (g->is_test_build) {
        const char *test_runner_name = g->link_libc ? "test_runner_libc" : "test_runner_nolibc";
        Buf *test_runner_o_path = build_o(g, test_runner_name);
        lj->args.append(buf_ptr(test_runner_o_path));
    }

    if (!g->link_libc && (g->out_type == OutTypeExe || g->out_type == OutTypeLib)) {
        Buf *builtin_o_path = build_o(g, "builtin");
        lj->args.append(buf_ptr(builtin_o_path));

        Buf *compiler_rt_o_path = build_o(g, "compiler_rt");
        lj->args.append(buf_ptr(compiler_rt_o_path));
    }


    for (int i = 0; i < g->link_libs.length; i += 1) {
        Buf *link_lib = g->link_libs.at(i);
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
    *major = strtol(str, &end, 10);
    if (*str != '\0' && *end == '\0')
        return true;
    if (*end != '.')
        return false;

    str = end + 1;
    *minor = strtol(str, &end, 10);
    if (*str != '\0' && *end == '\0')
        return true;
    if (*end != '.')
        return false;

    str = end + 1;
    *micro = strtol(str, &end, 10);
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

static void construct_linker_job_darwin(LinkJob *lj) {
    CodeGen *g = lj->codegen;

    int ver_major;
    int ver_minor;
    int ver_micro;
    bool had_extra;

    if (!darwin_get_release_version(buf_ptr(g->darwin_linker_version), &ver_major, &ver_minor, &ver_micro,
                &had_extra) || had_extra)
    {
        zig_panic("invalid linker version number");
    }

    // Newer linkers support -demangle. Pass it if supported and not disabled by
    // the user.
    if (ver_major >= 100) {
        lj->args.append("-demangle");
    }

    if (g->linker_rdynamic && ver_major >= 137) {
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

    for (int i = 0; i < g->lib_dirs.length; i += 1) {
        const char *lib_dir = g->lib_dirs.at(i);
        lj->args.append("-L");
        lj->args.append(lib_dir);
    }

    lj->args.append((const char *)buf_ptr(&lj->out_file_o));

    for (int i = 0; i < g->link_libs.length; i += 1) {
        Buf *link_lib = g->link_libs.at(i);
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

}

static void construct_linker_job(LinkJob *lj) {
    switch (lj->codegen->zig_target.os) {
        case ZigLLVM_UnknownOS:
            zig_unreachable();
        case ZigLLVM_Linux:
            if (lj->codegen->zig_target.arch.arch == ZigLLVM_hexagon) {
                zig_panic("TODO construct hexagon_TC linker job");
            } else {
                return construct_linker_job_linux(lj);
            }
        case ZigLLVM_CloudABI:
            zig_panic("TODO construct CloudABI linker job");
        case ZigLLVM_Darwin:
        case ZigLLVM_MacOSX:
        case ZigLLVM_IOS:
            return construct_linker_job_darwin(lj);
        case ZigLLVM_DragonFly:
            zig_panic("TODO construct DragonFly linker job");
        case ZigLLVM_OpenBSD:
            zig_panic("TODO construct OpenBSD linker job");
        case ZigLLVM_Bitrig:
            zig_panic("TODO construct Bitrig linker job");
        case ZigLLVM_NetBSD:
            zig_panic("TODO construct NetBSD linker job");
        case ZigLLVM_FreeBSD:
            zig_panic("TODO construct FreeBSD linker job");
        case ZigLLVM_Minix:
            zig_panic("TODO construct Minix linker job");
        case ZigLLVM_NaCl:
            zig_panic("TODO construct NaCl_TC linker job");
        case ZigLLVM_Solaris:
            zig_panic("TODO construct Solaris linker job");
        case ZigLLVM_Win32:
            switch (lj->codegen->zig_target.env_type) {
                default:
                    if (lj->codegen->zig_target.oformat == ZigLLVM_ELF) {
                        zig_panic("TODO construct Generic_ELF linker job");
                    } else if (lj->codegen->zig_target.oformat == ZigLLVM_MachO) {
                        zig_panic("TODO construct MachO linker job");
                    } else {
                        zig_panic("TODO construct Generic_GCC linker job");
                    }
                case ZigLLVM_GNU:
                    return construct_linker_job_mingw(lj);
                case ZigLLVM_Itanium:
                    zig_panic("TODO construct CrossWindowsToolChain linker job");
                case ZigLLVM_MSVC:
                case ZigLLVM_UnknownEnvironment:
                    zig_panic("TODO construct MSVC linker job");
            }
        case ZigLLVM_CUDA:
            zig_panic("TODO construct Cuda linker job");
        default:
            // Of these targets, Hexagon is the only one that might have
            // an OS of Linux, in which case it got handled above already.
            if (lj->codegen->zig_target.arch.arch == ZigLLVM_tce) {
                zig_panic("TODO construct TCE linker job");
            } else if (lj->codegen->zig_target.arch.arch == ZigLLVM_hexagon) {
                zig_panic("TODO construct Hexagon_TC linker job");
            } else if (lj->codegen->zig_target.arch.arch == ZigLLVM_xcore) {
                zig_panic("TODO construct XCore linker job");
            } else if (lj->codegen->zig_target.arch.arch == ZigLLVM_shave) {
                zig_panic("TODO construct SHAVE linker job");
            } else if (lj->codegen->zig_target.oformat == ZigLLVM_ELF) {
                zig_panic("TODO construct Generic_ELF linker job");
            } else if (lj->codegen->zig_target.oformat == ZigLLVM_MachO) {
                zig_panic("TODO construct MachO linker job");
            } else {
                zig_panic("TODO construct Generic_GCC linker job");
            }

    }
}

static void ensure_we_have_linker_path(CodeGen *g) {
    if (!g->linker_path || buf_len(g->linker_path) == 0) {
        zig_panic("zig does not know the path to the linker");
    }
}

void codegen_link(CodeGen *g, const char *out_file) {
    LinkJob lj = {0};
    lj.codegen = g;
    if (out_file) {
        buf_init_from_str(&lj.out_file, out_file);
    } else {
        buf_resize(&lj.out_file, 0);
    }

    bool is_optimized = g->is_release_build;
    if (is_optimized) {
        if (g->verbose) {
            fprintf(stderr, "\nOptimization:\n");
            fprintf(stderr, "---------------\n");
        }

        LLVMZigOptimizeModule(g->target_machine, g->module);

        if (g->verbose) {
            LLVMDumpModule(g->module);
        }
    }
    if (g->verbose) {
        fprintf(stderr, "\nLink:\n");
        fprintf(stderr, "-------\n");
    }

    if (buf_len(&lj.out_file) == 0) {
        assert(g->root_out_name);
        buf_init_from_buf(&lj.out_file, g->root_out_name);
        buf_append_str(&lj.out_file, get_exe_file_extension(g));
    }

    buf_init_from_buf(&lj.out_file_o, &lj.out_file);

    if (g->out_type != OutTypeObj) {
        const char *o_ext = get_o_file_extension(g);
        buf_append_str(&lj.out_file_o, o_ext);
    }

    char *err_msg = nullptr;
    if (LLVMTargetMachineEmitToFile(g->target_machine, g->module, buf_ptr(&lj.out_file_o),
                LLVMObjectFile, &err_msg))
    {
        zig_panic("unable to write object file: %s", err_msg);
    }

    if (g->out_type == OutTypeObj) {
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
    ensure_we_have_linker_path(g);

    construct_linker_job(&lj);


    if (g->verbose) {
        fprintf(stderr, "%s", buf_ptr(g->linker_path));
        for (int i = 0; i < lj.args.length; i += 1) {
            fprintf(stderr, " %s", lj.args.at(i));
        }
        fprintf(stderr, "\n");
    }

    int return_code;
    Buf ld_stderr = BUF_INIT;
    Buf ld_stdout = BUF_INIT;
    int err = os_exec_process(buf_ptr(g->linker_path), lj.args, &return_code, &ld_stderr, &ld_stdout);
    if (err) {
        fprintf(stderr, "linker not found: '%s'\n", buf_ptr(g->linker_path));
        exit(1);
    }

    if (return_code != 0) {
        fprintf(stderr, "linker failed with return code %d\n", return_code);
        fprintf(stderr, "%s ", buf_ptr(g->linker_path));
        for (int i = 0; i < lj.args.length; i += 1) {
            fprintf(stderr, "%s ", lj.args.at(i));
        }
        fprintf(stderr, "\n%s\n", buf_ptr(&ld_stderr));
        exit(1);
    } else if (buf_len(&ld_stderr)) {
        fprintf(stderr, "%s\n", buf_ptr(&ld_stderr));
    }

    if (g->out_type == OutTypeLib) {
        codegen_generate_h_file(g);
    }

    if (g->verbose) {
        fprintf(stderr, "OK\n");
    }
}
