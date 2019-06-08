/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "os.hpp"
#include "config.h"
#include "codegen.hpp"
#include "analyze.hpp"
#include "compiler.hpp"
#include "install_files.h"

struct LinkJob {
    CodeGen *codegen;
    ZigList<const char *> args;
    bool link_in_crt;
    HashMap<Buf *, bool, buf_hash, buf_eql_buf> rpath_table;
};

static CodeGen *create_child_codegen(CodeGen *parent_gen, Buf *root_src_path, OutType out_type,
        ZigLibCInstallation *libc)
{
    CodeGen *child_gen = codegen_create(nullptr, root_src_path, parent_gen->zig_target, out_type,
        parent_gen->build_mode, parent_gen->zig_lib_dir, parent_gen->zig_std_dir, libc, get_stage1_cache_path());
    child_gen->disable_gen_h = true;
    child_gen->want_stack_check = WantStackCheckDisabled;
    child_gen->verbose_tokenize = parent_gen->verbose_tokenize;
    child_gen->verbose_ast = parent_gen->verbose_ast;
    child_gen->verbose_link = parent_gen->verbose_link;
    child_gen->verbose_ir = parent_gen->verbose_ir;
    child_gen->verbose_llvm_ir = parent_gen->verbose_llvm_ir;
    child_gen->verbose_cimport = parent_gen->verbose_cimport;
    child_gen->verbose_cc = parent_gen->verbose_cc;
    child_gen->llvm_argv = parent_gen->llvm_argv;
    child_gen->dynamic_linker_path = parent_gen->dynamic_linker_path;

    codegen_set_strip(child_gen, parent_gen->strip_debug_symbols);
    child_gen->want_pic = parent_gen->have_pic ? WantPICEnabled : WantPICDisabled;
    child_gen->valgrind_support = ValgrindSupportDisabled;

    codegen_set_errmsg_color(child_gen, parent_gen->err_color);

    codegen_set_mmacosx_version_min(child_gen, parent_gen->mmacosx_version_min);
    codegen_set_mios_version_min(child_gen, parent_gen->mios_version_min);

    child_gen->enable_cache = true;

    return child_gen;
}

static const char *build_libc_object(CodeGen *parent_gen, const char *name, CFile *c_file) {
    CodeGen *child_gen = create_child_codegen(parent_gen, nullptr, OutTypeObj, nullptr);
    codegen_set_out_name(child_gen, buf_create_from_str(name));
    ZigList<CFile *> c_source_files = {0};
    c_source_files.append(c_file);
    child_gen->c_source_files = c_source_files;
    codegen_build_and_link(child_gen);
    return buf_ptr(&child_gen->output_file_path);
}

static const char *path_from_zig_lib(CodeGen *g, const char *dir, const char *subpath) {
    Buf *dir1 = buf_alloc();
    os_path_join(g->zig_lib_dir, buf_create_from_str(dir), dir1);
    Buf *result = buf_alloc();
    os_path_join(dir1, buf_create_from_str(subpath), result);
    return buf_ptr(result);
}

static const char *path_from_libc(CodeGen *g, const char *subpath) {
    return path_from_zig_lib(g, "libc", subpath);
}

static const char *path_from_libunwind(CodeGen *g, const char *subpath) {
    return path_from_zig_lib(g, "libunwind", subpath);
}

static const char *build_dummy_so(CodeGen *parent, const char *name, size_t major_version) {
    Buf *glibc_dummy_root_src = buf_sprintf("%s" OS_SEP "libc" OS_SEP "dummy" OS_SEP "%s.zig",
            buf_ptr(parent->zig_lib_dir), name);
    CodeGen *child_gen = create_child_codegen(parent, glibc_dummy_root_src, OutTypeLib, nullptr);
    codegen_set_out_name(child_gen, buf_create_from_str(name));
    codegen_set_lib_version(child_gen, major_version, 0, 0);
    child_gen->is_dynamic = true;
    child_gen->is_dummy_so = true;
    codegen_build_and_link(child_gen);
    return buf_ptr(&child_gen->output_file_path);
}

static const char *build_libunwind(CodeGen *parent) {
    CodeGen *child_gen = create_child_codegen(parent, nullptr, OutTypeLib, nullptr);
    codegen_set_out_name(child_gen, buf_create_from_str("unwind"));
    LinkLib *new_link_lib = codegen_add_link_lib(child_gen, buf_create_from_str("c"));
    new_link_lib->provided_explicitly = false;
    enum SrcKind {
        SrcCpp,
        SrcC,
        SrcAsm,
    };
    static const struct {
        const char *path;
        SrcKind kind;
    } unwind_src[] = {
        {"src" OS_SEP "libunwind.cpp", SrcCpp},
        {"src" OS_SEP "Unwind-EHABI.cpp", SrcCpp},
        {"src" OS_SEP "Unwind-seh.cpp", SrcCpp},

        {"src" OS_SEP "UnwindLevel1.c", SrcC},
        {"src" OS_SEP "UnwindLevel1-gcc-ext.c", SrcC},
        {"src" OS_SEP "Unwind-sjlj.c", SrcC},

        {"src" OS_SEP "UnwindRegistersRestore.S", SrcAsm},
        {"src" OS_SEP "UnwindRegistersSave.S", SrcAsm},
    };
    ZigList<CFile *> c_source_files = {0};
    for (size_t i = 0; i < array_length(unwind_src); i += 1) {
        CFile *c_file = allocate<CFile>(1);
        c_file->source_path = path_from_libunwind(parent, unwind_src[i].path);
        switch (unwind_src[i].kind) {
            case SrcC:
                c_file->args.append("-std=c99");
                break;
            case SrcCpp:
                c_file->args.append("-fno-rtti");
                c_file->args.append("-I");
                c_file->args.append(path_from_zig_lib(parent, "libcxx", "include"));
                break;
            case SrcAsm:
                break;
        }
        c_file->args.append("-I");
        c_file->args.append(path_from_libunwind(parent, "include"));
        c_file->args.append("-fPIC");
        c_file->args.append("-D_LIBUNWIND_DISABLE_VISIBILITY_ANNOTATIONS");
        c_file->args.append("-Wa,--noexecstack");
        if (parent->zig_target->is_native) {
            c_file->args.append("-D_LIBUNWIND_IS_NATIVE_ONLY");
        }
        if (parent->build_mode == BuildModeDebug) {
            c_file->args.append("-D_DEBUG");
        }
        if (parent->is_single_threaded) {
            c_file->args.append("-D_LIBUNWIND_HAS_NO_THREADS");
        }
        c_source_files.append(c_file);
    }
    child_gen->c_source_files = c_source_files;
    codegen_build_and_link(child_gen);
    return buf_ptr(&child_gen->output_file_path);
}

static void glibc_add_include_dirs_arch(CFile *c_file, ZigLLVM_ArchType arch, const char *nptl, const char *dir) {
    bool is_x86 = arch == ZigLLVM_x86 || arch == ZigLLVM_x86_64;
    bool is_aarch64 = arch == ZigLLVM_aarch64 || arch == ZigLLVM_aarch64_be;
    bool is_mips = arch == ZigLLVM_mips || arch == ZigLLVM_mipsel ||
        arch == ZigLLVM_mips64el || arch == ZigLLVM_mips64;
    bool is_arm = arch == ZigLLVM_arm || arch == ZigLLVM_armeb;
    bool is_ppc = arch == ZigLLVM_ppc || arch == ZigLLVM_ppc64 || arch == ZigLLVM_ppc64le;
    bool is_riscv = arch == ZigLLVM_riscv32 || arch == ZigLLVM_riscv64;
    bool is_sparc = arch == ZigLLVM_sparc || arch == ZigLLVM_sparcel || arch == ZigLLVM_sparcv9;
    bool is_64 = target_arch_pointer_bit_width(arch) == 64;

    if (is_x86) {
        if (arch == ZigLLVM_x86_64) {
            if (nptl != nullptr) {
                c_file->args.append("-I");
                c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "x86_64" OS_SEP "%s", dir, nptl)));
            } else {
                c_file->args.append("-I");
                c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "x86_64", dir)));
            }
        } else if (arch == ZigLLVM_x86) {
            if (nptl != nullptr) {
                c_file->args.append("-I");
                c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "i386" OS_SEP "%s", dir, nptl)));
            } else {
                c_file->args.append("-I");
                c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "i386", dir)));
            }
        }
        if (nptl != nullptr) {
            c_file->args.append("-I");
            c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "x86" OS_SEP "%s", dir, nptl)));
        } else {
            c_file->args.append("-I");
            c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "x86", dir)));
        }
    } else if (is_arm) {
        if (nptl != nullptr) {
            c_file->args.append("-I");
            c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "arm" OS_SEP "%s", dir, nptl)));
        } else {
            c_file->args.append("-I");
            c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "arm", dir)));
        }
    } else if (is_mips) {
        if (nptl != nullptr) {
            c_file->args.append("-I");
            c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "mips" OS_SEP "%s", dir, nptl)));
        } else {
            if (is_64) {
                c_file->args.append("-I");
                c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "mips" OS_SEP "mips64", dir)));
            } else {
                c_file->args.append("-I");
                c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "mips" OS_SEP "mips32", dir)));
            }
            c_file->args.append("-I");
            c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "mips", dir)));
        }
    } else if (is_sparc) {
        if (nptl != nullptr) {
            c_file->args.append("-I");
            c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "sparc" OS_SEP "%s", dir, nptl)));
        } else {
            if (is_64) {
                c_file->args.append("-I");
                c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "sparc" OS_SEP "sparc64", dir)));
            } else {
                c_file->args.append("-I");
                c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "sparc" OS_SEP "sparc32", dir)));
            }
            c_file->args.append("-I");
            c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "sparc", dir)));
        }
    } else if (is_aarch64) {
        if (nptl != nullptr) {
            c_file->args.append("-I");
            c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "aarch64" OS_SEP "%s", dir, nptl)));
        } else {
            c_file->args.append("-I");
            c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "aarch64", dir)));
        }
    } else if (is_ppc) {
        if (nptl != nullptr) {
            c_file->args.append("-I");
            c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "powerpc" OS_SEP "%s", dir, nptl)));
        } else {
            if (is_64) {
                c_file->args.append("-I");
                c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "powerpc" OS_SEP "powerpc64", dir)));
            } else {
                c_file->args.append("-I");
                c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "powerpc" OS_SEP "powerpc32", dir)));
            }
            c_file->args.append("-I");
            c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "powerpc", dir)));
        }
    } else if (is_riscv) {
        if (nptl != nullptr) {
            c_file->args.append("-I");
            c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "riscv" OS_SEP "%s", dir, nptl)));
        } else {
            c_file->args.append("-I");
            c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "riscv", dir)));
        }
    }
}

static void glibc_add_include_dirs(CodeGen *parent, CFile *c_file) {
    ZigLLVM_ArchType arch = parent->zig_target->arch;
    const char *nptl = (parent->zig_target->os == OsLinux) ? "nptl" : "htl";
    const char *glibc = path_from_libc(parent, "glibc");

    c_file->args.append("-I");
    c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "include", glibc)));

    if (parent->zig_target->os == OsLinux) {
        glibc_add_include_dirs_arch(c_file, arch, nullptr,
            path_from_libc(parent, "glibc" OS_SEP "sysdeps" OS_SEP "unix" OS_SEP "sysv" OS_SEP "linux"));
    }

    if (nptl != nullptr) {
        glibc_add_include_dirs_arch(c_file, arch, nptl, path_from_libc(parent, "glibc" OS_SEP "sysdeps"));
    }

    if (parent->zig_target->os == OsLinux) {
        c_file->args.append("-I");
        c_file->args.append(path_from_libc(parent, "glibc" OS_SEP "sysdeps" OS_SEP
                    "unix" OS_SEP "sysv" OS_SEP "linux" OS_SEP "include"));
        c_file->args.append("-I");
        c_file->args.append(path_from_libc(parent, "glibc" OS_SEP "sysdeps" OS_SEP
                    "unix" OS_SEP "sysv" OS_SEP "linux"));
    }
    if (nptl != nullptr) {
        c_file->args.append("-I");
        c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "sysdeps" OS_SEP "%s", glibc, nptl)));
    }

    c_file->args.append("-I");
    c_file->args.append(path_from_libc(parent, "glibc" OS_SEP "sysdeps" OS_SEP "pthread"));

    c_file->args.append("-I");
    c_file->args.append(path_from_libc(parent, "glibc" OS_SEP "sysdeps" OS_SEP "unix" OS_SEP "sysv"));

    glibc_add_include_dirs_arch(c_file, arch, nullptr,
            path_from_libc(parent, "glibc" OS_SEP "sysdeps" OS_SEP "unix"));

    c_file->args.append("-I");
    c_file->args.append(path_from_libc(parent, "glibc" OS_SEP "sysdeps" OS_SEP "unix"));

    glibc_add_include_dirs_arch(c_file, arch, nullptr, path_from_libc(parent, "glibc" OS_SEP "sysdeps"));

    c_file->args.append("-I");
    c_file->args.append(path_from_libc(parent, "glibc" OS_SEP "sysdeps" OS_SEP "generic"));

    c_file->args.append("-I");
    c_file->args.append(path_from_libc(parent, "glibc"));

    c_file->args.append("-I");
    c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "libc" OS_SEP "include" OS_SEP "%s-%s-%s",
                    buf_ptr(parent->zig_lib_dir), target_arch_name(parent->zig_target->arch),
                    target_os_name(parent->zig_target->os), target_abi_name(parent->zig_target->abi))));

    c_file->args.append("-I");
    c_file->args.append(path_from_libc(parent, "include" OS_SEP "generic-glibc"));

    c_file->args.append("-I");
    c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "libc" OS_SEP "include" OS_SEP "%s-linux-any",
                    buf_ptr(parent->zig_lib_dir), target_arch_name(parent->zig_target->arch))));

    c_file->args.append("-I");
    c_file->args.append(path_from_libc(parent, "include" OS_SEP "any-linux-any"));
}

static const char *glibc_start_asm_path(CodeGen *parent, const char *file) {
    ZigLLVM_ArchType arch = parent->zig_target->arch;
    bool is_aarch64 = arch == ZigLLVM_aarch64 || arch == ZigLLVM_aarch64_be;
    bool is_mips = arch == ZigLLVM_mips || arch == ZigLLVM_mipsel ||
        arch == ZigLLVM_mips64el || arch == ZigLLVM_mips64;
    bool is_arm = arch == ZigLLVM_arm || arch == ZigLLVM_armeb;
    bool is_ppc = arch == ZigLLVM_ppc || arch == ZigLLVM_ppc64 || arch == ZigLLVM_ppc64le;
    bool is_riscv = arch == ZigLLVM_riscv32 || arch == ZigLLVM_riscv64;
    bool is_sparc = arch == ZigLLVM_sparc || arch == ZigLLVM_sparcel || arch == ZigLLVM_sparcv9;
    bool is_64 = target_arch_pointer_bit_width(arch) == 64;

    Buf result = BUF_INIT;
    buf_resize(&result, 0);
    buf_append_buf(&result, parent->zig_lib_dir);
    buf_append_str(&result, OS_SEP "libc" OS_SEP "glibc" OS_SEP "sysdeps" OS_SEP);
    if (is_sparc) {
        if (is_64) {
            buf_append_str(&result, "sparc" OS_SEP "sparc64");
        } else {
            buf_append_str(&result, "sparc" OS_SEP "sparc32");
        }
    } else if (is_arm) {
        buf_append_str(&result, "arm");
    } else if (is_mips) {
        buf_append_str(&result, "mips");
    } else if (arch == ZigLLVM_x86_64) {
        buf_append_str(&result, "x86_64");
    } else if (arch == ZigLLVM_x86) {
        buf_append_str(&result, "i386");
    } else if (is_aarch64) {
        buf_append_str(&result, "aarch64");
    } else if (is_riscv) {
        buf_append_str(&result, "riscv");
    } else if (is_ppc) {
        if (is_64) {
            buf_append_str(&result, "powerpc" OS_SEP "powerpc64");
        } else {
            buf_append_str(&result, "powerpc" OS_SEP "powerpc32");
        }
    }

    buf_append_str(&result, OS_SEP);
    buf_append_str(&result, file);
    return buf_ptr(&result);
}

static const char *musl_arch_name(const ZigTarget *target) {
    switch (target->arch) {
        case ZigLLVM_aarch64:
        case ZigLLVM_aarch64_be:
            return "aarch64";
        case ZigLLVM_arm:
        case ZigLLVM_armeb:
            return "arm";
        case ZigLLVM_mips:
        case ZigLLVM_mipsel:
            return "mips";
        case ZigLLVM_mips64el:
        case ZigLLVM_mips64:
            return "mips64";
        case ZigLLVM_ppc:
            return "powerpc";
        case ZigLLVM_ppc64:
        case ZigLLVM_ppc64le:
            return "powerpc64";
        case ZigLLVM_systemz:
            return "s390x";
        case ZigLLVM_x86:
            return "i386";
        case ZigLLVM_x86_64:
            return "x86_64";
        default:
            zig_unreachable();
    }
}

static const char *musl_start_asm_path(CodeGen *parent, const char *file) {
    Buf *result = buf_sprintf("%s" OS_SEP "libc" OS_SEP "musl" OS_SEP "crt" OS_SEP "%s" OS_SEP "%s",
                   buf_ptr(parent->zig_lib_dir), musl_arch_name(parent->zig_target), file);
    return buf_ptr(result);
}

static void musl_add_cc_args(CodeGen *parent, CFile *c_file, bool want_O3) {
    c_file->args.append("-std=c99");
    c_file->args.append("-ffreestanding");
    // Musl adds these args to builds with gcc but clang does not support them. 
    //c_file->args.append("-fexcess-precision=standard");
    //c_file->args.append("-frounding-math");
    c_file->args.append("-Wa,--noexecstack");
    c_file->args.append("-D_XOPEN_SOURCE=700");

    c_file->args.append("-I");
    c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "libc" OS_SEP "musl" OS_SEP "arch" OS_SEP "%s",
            buf_ptr(parent->zig_lib_dir), musl_arch_name(parent->zig_target))));

    c_file->args.append("-I");
    c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "libc" OS_SEP "musl" OS_SEP "arch" OS_SEP "generic",
            buf_ptr(parent->zig_lib_dir))));

    c_file->args.append("-I");
    c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "libc" OS_SEP "musl" OS_SEP "src" OS_SEP "internal",
            buf_ptr(parent->zig_lib_dir))));

    c_file->args.append("-I");
    c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "libc" OS_SEP "musl" OS_SEP "src" OS_SEP "include",
            buf_ptr(parent->zig_lib_dir))));

    c_file->args.append("-I");
    c_file->args.append(buf_ptr(buf_sprintf(
            "%s" OS_SEP "libc" OS_SEP "include" OS_SEP "%s-%s-%s",
        buf_ptr(parent->zig_lib_dir),
        target_arch_name(parent->zig_target->arch),
        target_os_name(parent->zig_target->os),
        target_abi_name(parent->zig_target->abi))));

    c_file->args.append("-I");
    c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "libc" OS_SEP "include" OS_SEP "generic-musl",
            buf_ptr(parent->zig_lib_dir))));

    if (want_O3)
        c_file->args.append("-O3");
    else
        c_file->args.append("-Os");

    c_file->args.append("-fomit-frame-pointer");
    c_file->args.append("-fno-unwind-tables");
    c_file->args.append("-fno-asynchronous-unwind-tables");
    c_file->args.append("-ffunction-sections");
    c_file->args.append("-fdata-sections");
}

static const char *musl_arch_names[] = {
    "aarch64",
    "arm",
    "generic",
    "i386",
    "m68k",
    "microblaze",
    "mips",
    "mips64",
    "mipsn32",
    "or1k",
    "powerpc",
    "powerpc64",
    "s390x",
    "sh",
    "x32",
    "x86_64",
};

static bool is_musl_arch_name(const char *name) {
    for (size_t i = 0; i < array_length(musl_arch_names); i += 1) {
        if (strcmp(name, musl_arch_names[i]) == 0)
            return true;
    }
    return false;
}

static const char *build_musl(CodeGen *parent) {
    CodeGen *child_gen = create_child_codegen(parent, nullptr, OutTypeLib, nullptr);
    codegen_set_out_name(child_gen, buf_create_from_str("c"));

    // When there is a src/<arch>/foo.* then it should substitute for src/foo.*
    // Even a .s file can substitute for a .c file.

    enum MuslSrc {
        MuslSrcAsm,
        MuslSrcNormal,
        MuslSrcO3,
    };

    const char *target_musl_arch_name = musl_arch_name(parent->zig_target);

    HashMap<Buf *, MuslSrc, buf_hash, buf_eql_buf> source_table = {};
    source_table.init(1800);

    for (size_t i = 0; i < array_length(ZIG_MUSL_SRC_FILES); i += 1) {
        Buf *src_file = buf_create_from_str(ZIG_MUSL_SRC_FILES[i]);

        MuslSrc src_kind;
        if (buf_ends_with_str(src_file, ".c")) {
            assert(buf_starts_with_str(src_file, "musl/src/"));
            bool want_O3 = buf_starts_with_str(src_file, "musl/src/malloc/") ||
                buf_starts_with_str(src_file, "musl/src/string/") ||
                buf_starts_with_str(src_file, "musl/src/internal/");
            src_kind = want_O3 ? MuslSrcO3 : MuslSrcNormal;
        } else if (buf_ends_with_str(src_file, ".s") || buf_ends_with_str(src_file, ".S")) {
            src_kind = MuslSrcAsm;
        } else {
            continue;
        }
        if (ZIG_OS_SEP_CHAR != '/') {
            buf_replace(src_file, '/', ZIG_OS_SEP_CHAR);
        }
        source_table.put_unique(src_file, src_kind);
    }

    ZigList<CFile *> c_source_files = {0};

    Buf dirname = BUF_INIT;
    Buf basename = BUF_INIT;
    Buf noextbasename = BUF_INIT;
    Buf dirbasename = BUF_INIT;
    Buf before_arch_dir = BUF_INIT;

    auto source_it = source_table.entry_iterator();
    for (;;) {
        auto *entry = source_it.next();
        if (!entry) break;

        Buf *src_file = entry->key;
        MuslSrc src_kind = entry->value;

        os_path_split(src_file, &dirname, &basename);
        os_path_extname(&basename, &noextbasename, nullptr);
        os_path_split(&dirname, &before_arch_dir, &dirbasename);

        bool is_arch_specific = false;
        // Architecture-specific implementations are under a <arch>/ folder.
        if (is_musl_arch_name(buf_ptr(&dirbasename))) {
            // Not the architecture we're compiling for.
            if (strcmp(buf_ptr(&dirbasename), target_musl_arch_name) != 0)
                continue;
            is_arch_specific = true;
        }

        if (!is_arch_specific) {
            Buf override_path = BUF_INIT;

            // Look for an arch specific override.
            buf_resize(&override_path, 0);
            buf_appendf(&override_path, "%s" OS_SEP "%s" OS_SEP "%s.s",
                        buf_ptr(&dirname), target_musl_arch_name, buf_ptr(&noextbasename));
            if (source_table.maybe_get(&override_path) != nullptr)
                continue;

            buf_resize(&override_path, 0);
            buf_appendf(&override_path, "%s" OS_SEP "%s" OS_SEP "%s.S",
                        buf_ptr(&dirname), target_musl_arch_name, buf_ptr(&noextbasename));
            if (source_table.maybe_get(&override_path) != nullptr)
                continue;

            buf_resize(&override_path, 0);
            buf_appendf(&override_path, "%s" OS_SEP "%s" OS_SEP "%s.c",
                        buf_ptr(&dirname), target_musl_arch_name, buf_ptr(&noextbasename));
            if (source_table.maybe_get(&override_path) != nullptr)
                continue;
        }

        Buf *full_path = buf_sprintf("%s" OS_SEP "libc" OS_SEP "%s",
                buf_ptr(parent->zig_lib_dir), buf_ptr(src_file));

        CFile *c_file = allocate<CFile>(1);
        c_file->source_path = buf_ptr(full_path);

        musl_add_cc_args(parent, c_file, src_kind == MuslSrcO3);
        c_file->args.append("-Qunused-arguments");
        c_file->args.append("-w"); // disable all warnings

        c_source_files.append(c_file);
    }

    child_gen->c_source_files = c_source_files;
    codegen_build_and_link(child_gen);
    return buf_ptr(&child_gen->output_file_path);
}


static const char *get_libc_crt_file(CodeGen *parent, const char *file) {
    if (parent->libc == nullptr && target_is_glibc(parent->zig_target)) {
        if (strcmp(file, "crti.o") == 0) {
            CFile *c_file = allocate<CFile>(1);
            c_file->source_path = glibc_start_asm_path(parent, "crti.S");
            glibc_add_include_dirs(parent, c_file);
            c_file->args.append("-D_LIBC_REENTRANT");
            c_file->args.append("-include");
            c_file->args.append(path_from_libc(parent, "glibc" OS_SEP "include" OS_SEP "libc-modules.h"));
            c_file->args.append("-DMODULE_NAME=libc");
            c_file->args.append("-include");
            c_file->args.append(path_from_libc(parent, "glibc" OS_SEP "include" OS_SEP "libc-symbols.h"));
            c_file->args.append("-DTOP_NAMESPACE=glibc");
            c_file->args.append("-DASSEMBLER");
            c_file->args.append("-g");
            c_file->args.append("-Wa,--noexecstack");
            return build_libc_object(parent, "crti", c_file);
        } else if (strcmp(file, "crtn.o") == 0) {
            CFile *c_file = allocate<CFile>(1);
            c_file->source_path = glibc_start_asm_path(parent, "crtn.S");
            glibc_add_include_dirs(parent, c_file);
            c_file->args.append("-D_LIBC_REENTRANT");
            c_file->args.append("-DMODULE_NAME=libc");
            c_file->args.append("-DTOP_NAMESPACE=glibc");
            c_file->args.append("-DASSEMBLER");
            c_file->args.append("-g");
            c_file->args.append("-Wa,--noexecstack");
            return build_libc_object(parent, "crtn", c_file);
        } else if (strcmp(file, "start.os") == 0) {
            CFile *c_file = allocate<CFile>(1);
            c_file->source_path = glibc_start_asm_path(parent, "start.S");
            glibc_add_include_dirs(parent, c_file);
            c_file->args.append("-D_LIBC_REENTRANT");
            c_file->args.append("-include");
            c_file->args.append(path_from_libc(parent, "glibc" OS_SEP "include" OS_SEP "libc-modules.h"));
            c_file->args.append("-DMODULE_NAME=libc");
            c_file->args.append("-include");
            c_file->args.append(path_from_libc(parent, "glibc" OS_SEP "include" OS_SEP "libc-symbols.h"));
            c_file->args.append("-DPIC");
            c_file->args.append("-DSHARED");
            c_file->args.append("-DTOP_NAMESPACE=glibc");
            c_file->args.append("-DASSEMBLER");
            c_file->args.append("-g");
            c_file->args.append("-Wa,--noexecstack");
            return build_libc_object(parent, "start", c_file);
        } else if (strcmp(file, "abi-note.o") == 0) {
            CFile *c_file = allocate<CFile>(1);
            c_file->source_path = path_from_libc(parent, "glibc" OS_SEP "csu" OS_SEP "abi-note.S");
            c_file->args.append("-I");
            c_file->args.append(path_from_libc(parent, "glibc" OS_SEP "csu"));
            glibc_add_include_dirs(parent, c_file);
            c_file->args.append("-D_LIBC_REENTRANT");
            c_file->args.append("-DMODULE_NAME=libc");
            c_file->args.append("-DTOP_NAMESPACE=glibc");
            c_file->args.append("-DASSEMBLER");
            c_file->args.append("-g");
            c_file->args.append("-Wa,--noexecstack");
            return build_libc_object(parent, "abi-note", c_file);
        } else if (strcmp(file, "Scrt1.o") == 0) {
            const char *start_os = get_libc_crt_file(parent, "start.os");
            const char *abi_note_o = get_libc_crt_file(parent, "abi-note.o");
            CodeGen *child_gen = create_child_codegen(parent, nullptr, OutTypeObj, nullptr);
            codegen_set_out_name(child_gen, buf_create_from_str("Scrt1"));
            codegen_add_object(child_gen, buf_create_from_str(start_os));
            codegen_add_object(child_gen, buf_create_from_str(abi_note_o));
            codegen_build_and_link(child_gen);
            return buf_ptr(&child_gen->output_file_path);
        } else if (strcmp(file, "libc_nonshared.a") == 0) {
            CodeGen *child_gen = create_child_codegen(parent, nullptr, OutTypeLib, nullptr);
            codegen_set_out_name(child_gen, buf_create_from_str("c_nonshared"));
            {
                CFile *c_file = allocate<CFile>(1);
                c_file->source_path = path_from_libc(parent, "glibc" OS_SEP "csu" OS_SEP "elf-init.c");
                c_file->args.append("-std=gnu11");
                c_file->args.append("-fgnu89-inline");
                c_file->args.append("-g");
                c_file->args.append("-O2");
                c_file->args.append("-fmerge-all-constants");
                c_file->args.append("-fno-stack-protector");
                c_file->args.append("-fmath-errno");
                c_file->args.append("-fno-stack-protector");
                c_file->args.append("-I");
                c_file->args.append(path_from_libc(parent, "glibc" OS_SEP "csu"));
                glibc_add_include_dirs(parent, c_file);
                c_file->args.append("-DSTACK_PROTECTOR_LEVEL=0");
                c_file->args.append("-fPIC");
                c_file->args.append("-fno-stack-protector");
                c_file->args.append("-ftls-model=initial-exec");
                c_file->args.append("-D_LIBC_REENTRANT");
                c_file->args.append("-include");
                c_file->args.append(path_from_libc(parent, "glibc" OS_SEP "include" OS_SEP "libc-modules.h"));
                c_file->args.append("-DMODULE_NAME=libc");
                c_file->args.append("-include");
                c_file->args.append(path_from_libc(parent, "glibc" OS_SEP "include" OS_SEP "libc-symbols.h"));
                c_file->args.append("-DPIC");
                c_file->args.append("-DLIBC_NONSHARED=1");
                c_file->args.append("-DTOP_NAMESPACE=glibc");
                codegen_add_object(child_gen, buf_create_from_str(build_libc_object(parent, "elf-init", c_file)));
            }
            static const struct {
                const char *name;
                const char *path;
            } deps[] = {
                {"atexit", "glibc" OS_SEP "stdlib" OS_SEP "atexit.c"},
                {"at_quick_exit", "glibc" OS_SEP "stdlib" OS_SEP "at_quick_exit.c"},
                {"stat", "glibc" OS_SEP "io" OS_SEP "stat.c"},
                {"fstat", "glibc" OS_SEP "io" OS_SEP "fstat.c"},
                {"lstat", "glibc" OS_SEP "io" OS_SEP "lstat.c"},
                {"stat64", "glibc" OS_SEP "io" OS_SEP "stat64.c"},
                {"fstat64", "glibc" OS_SEP "io" OS_SEP "fstat64.c"},
                {"lstat64", "glibc" OS_SEP "io" OS_SEP "lstat64.c"},
                {"fstatat", "glibc" OS_SEP "io" OS_SEP "fstatat.c"},
                {"fstatat64", "glibc" OS_SEP "io" OS_SEP "fstatat64.c"},
                {"mknod", "glibc" OS_SEP "io" OS_SEP "mknod.c"},
                {"mknodat", "glibc" OS_SEP "io" OS_SEP "mknodat.c"},
                {"pthread_atfork", "glibc" OS_SEP "nptl" OS_SEP "pthread_atfork.c"},
                {"stack_chk_fail_local", "glibc" OS_SEP "debug" OS_SEP "stack_chk_fail_local.c"},
            };
            for (size_t i = 0; i < array_length(deps); i += 1) {
                CFile *c_file = allocate<CFile>(1);
                c_file->source_path = path_from_libc(parent, deps[i].path);
                c_file->args.append("-std=gnu11");
                c_file->args.append("-fgnu89-inline");
                c_file->args.append("-g");
                c_file->args.append("-O2");
                c_file->args.append("-fmerge-all-constants");
                c_file->args.append("-fno-stack-protector");
                c_file->args.append("-fmath-errno");
                c_file->args.append("-ftls-model=initial-exec");
                c_file->args.append("-Wno-ignored-attributes");
                glibc_add_include_dirs(parent, c_file);
                c_file->args.append("-D_LIBC_REENTRANT");
                c_file->args.append("-include");
                c_file->args.append(path_from_libc(parent, "glibc" OS_SEP "include" OS_SEP "libc-modules.h"));
                c_file->args.append("-DMODULE_NAME=libc");
                c_file->args.append("-include");
                c_file->args.append(path_from_libc(parent, "glibc" OS_SEP "include" OS_SEP "libc-symbols.h"));
                c_file->args.append("-DPIC");
                c_file->args.append("-DLIBC_NONSHARED=1");
                c_file->args.append("-DTOP_NAMESPACE=glibc");
                codegen_add_object(child_gen, buf_create_from_str(build_libc_object(parent, deps[i].name, c_file)));
            }
            codegen_build_and_link(child_gen);
            return buf_ptr(&child_gen->output_file_path);
        } else {
            zig_unreachable();
        }
    } else if (parent->libc == nullptr && target_is_musl(parent->zig_target)) {
        if (strcmp(file, "crti.o") == 0) {
            CFile *c_file = allocate<CFile>(1);
            c_file->source_path = musl_start_asm_path(parent, "crti.s");
            musl_add_cc_args(parent, c_file, false);
            c_file->args.append("-Qunused-arguments");
            return build_libc_object(parent, "crti", c_file);
        } else if (strcmp(file, "crtn.o") == 0) {
            CFile *c_file = allocate<CFile>(1);
            c_file->source_path = musl_start_asm_path(parent, "crtn.s");
            c_file->args.append("-Qunused-arguments");
            musl_add_cc_args(parent, c_file, false);
            return build_libc_object(parent, "crtn", c_file);
        } else if (strcmp(file, "crt1.o") == 0) {
            CFile *c_file = allocate<CFile>(1);
            c_file->source_path = path_from_libc(parent, "musl" OS_SEP "crt" OS_SEP "crt1.c");
            musl_add_cc_args(parent, c_file, false);
            c_file->args.append("-fno-stack-protector");
            c_file->args.append("-DCRT");
            return build_libc_object(parent, "crt1", c_file);
        } else if (strcmp(file, "Scrt1.o") == 0) {
            CFile *c_file = allocate<CFile>(1);
            c_file->source_path = path_from_libc(parent, "musl" OS_SEP "crt" OS_SEP "Scrt1.c");
            musl_add_cc_args(parent, c_file, false);
            c_file->args.append("-fPIC");
            c_file->args.append("-fno-stack-protector");
            c_file->args.append("-DCRT");
            return build_libc_object(parent, "Scrt1", c_file);
        } else {
            zig_unreachable();
        }
    } else {
        assert(parent->libc != nullptr);
        Buf *out_buf = buf_alloc();
        os_path_join(&parent->libc->crt_dir, buf_create_from_str(file), out_buf);
        return buf_ptr(out_buf);
    }
}

static Buf *build_a_raw(CodeGen *parent_gen, const char *aname, Buf *full_path, OutType child_out_type) {
    CodeGen *child_gen = create_child_codegen(parent_gen, full_path, child_out_type,
            parent_gen->libc);
    codegen_set_out_name(child_gen, buf_create_from_str(aname));

    // This is so that compiler_rt and libc.zig libraries know whether they
    // will eventually be linked with libc. They make different decisions
    // about what to export depending on whether libc is linked.
    if (parent_gen->libc_link_lib != nullptr) {
        LinkLib *new_link_lib = codegen_add_link_lib(child_gen, parent_gen->libc_link_lib->name);
        new_link_lib->provided_explicitly = parent_gen->libc_link_lib->provided_explicitly;
    }

    codegen_build_and_link(child_gen);
    return &child_gen->output_file_path;
}

static Buf *build_compiler_rt(CodeGen *parent_gen, OutType child_out_type) {
    Buf *full_path = buf_alloc();
    os_path_join(parent_gen->zig_std_special_dir, buf_create_from_str("compiler_rt.zig"), full_path);

    return build_a_raw(parent_gen, "compiler_rt", full_path, child_out_type);
}

static Buf *build_c(CodeGen *parent_gen, OutType child_out_type) {
    Buf *full_path = buf_alloc();
    os_path_join(parent_gen->zig_std_special_dir, buf_create_from_str("c.zig"), full_path);

    return build_a_raw(parent_gen, "c", full_path, child_out_type);
}

static const char *get_darwin_arch_string(const ZigTarget *t) {
    switch (t->arch) {
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
            return ZigLLVMGetArchTypeName(t->arch);
    }
}


static const char *getLDMOption(const ZigTarget *t) {
    switch (t->arch) {
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
            if (t->abi == ZigLLVM_GNUX32) {
                return "elf32_x86_64";
            }
            // Any target elf will use the freebsd osabi if suffixed with "_fbsd".
            if (t->os == OsFreeBSD) {
                return "elf_x86_64_fbsd";
            }
            return "elf_x86_64";
        case ZigLLVM_riscv32:
            return "elf32lriscv";
        case ZigLLVM_riscv64:
            return "elf64lriscv";
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

    lj->args.append("-error-limit=0");

    if (g->linker_script) {
        lj->args.append("-T");
        lj->args.append(g->linker_script);
    }

    if (g->out_type != OutTypeObj) {
        lj->args.append("--gc-sections");
    }

    lj->args.append("-m");
    lj->args.append(getLDMOption(g->zig_target));

    bool is_lib = g->out_type == OutTypeLib;
    bool is_dyn_lib = g->is_dynamic && is_lib;
    Buf *soname = nullptr;
    if (!g->have_dynamic_link) {
        if (g->zig_target->arch == ZigLLVM_arm || g->zig_target->arch == ZigLLVM_armeb ||
            g->zig_target->arch == ZigLLVM_thumb || g->zig_target->arch == ZigLLVM_thumbeb)
        {
            lj->args.append("-Bstatic");
        } else {
            lj->args.append("-static");
        }
    } else if (is_dyn_lib) {
        lj->args.append("-shared");

        assert(buf_len(&g->output_file_path) != 0);
        soname = buf_sprintf("lib%s.so.%" ZIG_PRI_usize, buf_ptr(g->root_out_name), g->version_major);
    }

    lj->args.append("-o");
    lj->args.append(buf_ptr(&g->output_file_path));

    if (lj->link_in_crt) {
        const char *crt1o;
        if (g->zig_target->os == OsNetBSD) {
            crt1o = "crt0.o";
        } else if (!g->have_dynamic_link) {
            crt1o = "crt1.o";
        } else {
            crt1o = "Scrt1.o";
        }
        lj->args.append(get_libc_crt_file(g, crt1o));
        lj->args.append(get_libc_crt_file(g, "crti.o"));
    }

    for (size_t i = 0; i < g->rpath_list.length; i += 1) {
        Buf *rpath = g->rpath_list.at(i);
        add_rpath(lj, rpath);
    }
    if (g->each_lib_rpath) {
        for (size_t i = 0; i < g->lib_dirs.length; i += 1) {
            const char *lib_dir = g->lib_dirs.at(i);
            for (size_t i = 0; i < g->link_libs_list.length; i += 1) {
                LinkLib *link_lib = g->link_libs_list.at(i);
                if (buf_eql_str(link_lib->name, "c")) {
                    continue;
                }
                bool does_exist;
                Buf *test_path = buf_sprintf("%s/lib%s.so", lib_dir, buf_ptr(link_lib->name));
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

    if (g->libc_link_lib != nullptr) {
        if (g->libc != nullptr) {
            lj->args.append("-L");
            lj->args.append(buf_ptr(&g->libc->crt_dir));
        }

        if (g->have_dynamic_link && (is_dyn_lib || g->out_type == OutTypeExe)) {
            assert(g->dynamic_linker_path != nullptr);
            lj->args.append("-dynamic-linker");
            lj->args.append(buf_ptr(g->dynamic_linker_path));
        }
    }

    if (is_dyn_lib) {
        lj->args.append("-soname");
        lj->args.append(buf_ptr(soname));
    }

    // .o files
    for (size_t i = 0; i < g->link_objects.length; i += 1) {
        lj->args.append((const char *)buf_ptr(g->link_objects.at(i)));
    }

    if (!g->is_dummy_so && (g->out_type == OutTypeExe || is_dyn_lib)) {
        if (g->libc_link_lib == nullptr) {
            Buf *libc_a_path = build_c(g, OutTypeLib);
            lj->args.append(buf_ptr(libc_a_path));
        }

        Buf *compiler_rt_o_path = build_compiler_rt(g, OutTypeLib);
        lj->args.append(buf_ptr(compiler_rt_o_path));
    }

    for (size_t i = 0; i < g->link_libs_list.length; i += 1) {
        LinkLib *link_lib = g->link_libs_list.at(i);
        if (buf_eql_str(link_lib->name, "c")) {
            // libc is linked specially
            continue;
        }
        if (g->libc == nullptr && target_is_libc_lib_name(g->zig_target, buf_ptr(link_lib->name))) {
            // these libraries are always linked below when targeting glibc
            continue;
        }
        Buf *arg;
        if (buf_starts_with_str(link_lib->name, "/") || buf_ends_with_str(link_lib->name, ".a") ||
            buf_ends_with_str(link_lib->name, ".so"))
        {
            arg = link_lib->name;
        } else {
            arg = buf_sprintf("-l%s", buf_ptr(link_lib->name));
        }
        lj->args.append(buf_ptr(arg));
    }


    // libc dep
    if (g->libc_link_lib != nullptr) {
        if (g->libc != nullptr) {
            if (!g->have_dynamic_link) {
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
        } else if (target_is_glibc(g->zig_target)) {
            lj->args.append(build_libunwind(g));
            lj->args.append(build_dummy_so(g, "c", 6));
            lj->args.append(build_dummy_so(g, "m", 6));
            lj->args.append(build_dummy_so(g, "pthread", 0));
            lj->args.append(build_dummy_so(g, "dl", 2));
            lj->args.append(build_dummy_so(g, "rt", 1));
            lj->args.append(get_libc_crt_file(g, "libc_nonshared.a"));
        } else if (target_is_musl(g->zig_target)) {
            lj->args.append(build_libunwind(g));
            lj->args.append(build_musl(g));
        } else {
            zig_unreachable();
        }
    }

    // crt end
    if (lj->link_in_crt) {
        lj->args.append(get_libc_crt_file(g, "crtn.o"));
    }

    if (!g->zig_target->is_native) {
        lj->args.append("--allow-shlib-undefined");
    }

    if (g->zig_target->os == OsZen) {
        lj->args.append("-e");
        lj->args.append("_start");

        lj->args.append("--image-base=0x10000000");
    }
}

static void construct_linker_job_wasm(LinkJob *lj) {
    CodeGen *g = lj->codegen;

    lj->args.append("-error-limit=0");

    if (g->out_type != OutTypeExe) {
	    lj->args.append("--no-entry"); // So lld doesn't look for _start.

        // If there are any C source files we cannot rely on individual exports.
        if (g->c_source_files.length != 0) {
            lj->args.append("--export-all");
        } else {
            auto export_it = g->exported_symbol_names.entry_iterator();
            decltype(g->exported_symbol_names)::Entry *curr_entry = nullptr;
            while ((curr_entry = export_it.next()) != nullptr) {
                Buf *arg = buf_sprintf("--export=%s", buf_ptr(curr_entry->key));
                lj->args.append(buf_ptr(arg));
            }
        }
    }
    lj->args.append("--allow-undefined");
    lj->args.append("-o");
    lj->args.append(buf_ptr(&g->output_file_path));

    // .o files
    for (size_t i = 0; i < g->link_objects.length; i += 1) {
        lj->args.append((const char *)buf_ptr(g->link_objects.at(i)));
    }

    if (g->out_type != OutTypeObj) {
        Buf *libc_o_path = build_c(g, OutTypeObj);
        lj->args.append(buf_ptr(libc_o_path));

        Buf *compiler_rt_o_path = build_compiler_rt(g, OutTypeObj);
        lj->args.append(buf_ptr(compiler_rt_o_path));
    }
}

static void coff_append_machine_arg(CodeGen *g, ZigList<const char *> *list) {
    if (g->zig_target->arch == ZigLLVM_x86) {
        list->append("-MACHINE:X86");
    } else if (g->zig_target->arch == ZigLLVM_x86_64) {
        list->append("-MACHINE:X64");
    } else if (g->zig_target->arch == ZigLLVM_arm) {
        list->append("-MACHINE:ARM");
    }
}

static void link_diag_callback(void *context, const char *ptr, size_t len) {
    Buf *diag = reinterpret_cast<Buf *>(context);
    buf_append_mem(diag, ptr, len);
}

static bool zig_lld_link(ZigLLVM_ObjectFormatType oformat, const char **args, size_t arg_count, Buf *diag) {
    buf_resize(diag, 0);
    return ZigLLDLink(oformat, args, arg_count, link_diag_callback, diag);
}

static void add_uefi_link_args(LinkJob *lj) {
    lj->args.append("-BASE:0");
    lj->args.append("-ENTRY:EfiMain");
    lj->args.append("-OPT:REF");
    lj->args.append("-SAFESEH:NO");
    lj->args.append("-MERGE:.rdata=.data");
    lj->args.append("-ALIGN:32");
    lj->args.append("-NODEFAULTLIB");
    lj->args.append("-SECTION:.xdata,D");
}

static void add_msvc_link_args(LinkJob *lj, bool is_library) {
    CodeGen *g = lj->codegen;

    // TODO: https://github.com/ziglang/zig/issues/2064
    bool is_dynamic = true; // g->is_dynamic;
    const char *lib_str = is_dynamic ? "" : "lib";
    const char *d_str = (g->build_mode == BuildModeDebug) ? "d" : "";

    if (!is_dynamic) {
        Buf *cmt_lib_name = buf_sprintf("libcmt%s.lib", d_str);
        lj->args.append(buf_ptr(cmt_lib_name));
    } else {
        Buf *msvcrt_lib_name = buf_sprintf("msvcrt%s.lib", d_str);
        lj->args.append(buf_ptr(msvcrt_lib_name));
    }

    Buf *vcruntime_lib_name = buf_sprintf("%svcruntime%s.lib", lib_str, d_str);
    lj->args.append(buf_ptr(vcruntime_lib_name));

    Buf *crt_lib_name = buf_sprintf("%sucrt%s.lib", lib_str, d_str);
    lj->args.append(buf_ptr(crt_lib_name));

    //Visual C++ 2015 Conformance Changes
    //https://msdn.microsoft.com/en-us/library/bb531344.aspx
    lj->args.append("legacy_stdio_definitions.lib");

    // msvcrt depends on kernel32 and ntdll
    lj->args.append("kernel32.lib");
    lj->args.append("ntdll.lib");
}

static const char *get_libc_file(ZigLibCInstallation *lib, const char *file) {
    Buf *out_buf = buf_alloc();
    os_path_join(&lib->crt_dir, buf_create_from_str(file), out_buf);
    return buf_ptr(out_buf);
}

static const char *get_libc_static_file(ZigLibCInstallation *lib, const char *file) {
    Buf *out_buf = buf_alloc();
    os_path_join(&lib->static_crt_dir, buf_create_from_str(file), out_buf);
    return buf_ptr(out_buf);
}

static void add_mingw_link_args(LinkJob *lj, bool is_library) {
    CodeGen *g = lj->codegen;

    bool is_dll = g->out_type == OutTypeLib && g->is_dynamic;

    if (g->zig_target->arch == ZigLLVM_x86) {
        lj->args.append("-ALTERNATENAME:__image_base__=___ImageBase");
    } else {
        lj->args.append("-ALTERNATENAME:__image_base__=__ImageBase");
    }

    if (is_dll) {
       lj->args.append(get_libc_file(g->libc, "dllcrt2.o"));
    } else {
       lj->args.append(get_libc_file(g->libc, "crt2.o"));
    }

    lj->args.append(get_libc_static_file(g->libc, "crtbegin.o"));

    lj->args.append(get_libc_file(g->libc, "libmingw32.a"));

    if (is_dll) {
        lj->args.append(get_libc_static_file(g->libc, "libgcc_s.a"));
        lj->args.append(get_libc_static_file(g->libc, "libgcc.a"));
    } else {
        lj->args.append(get_libc_static_file(g->libc, "libgcc.a"));
        lj->args.append(get_libc_static_file(g->libc, "libgcc_eh.a"));
    }

    lj->args.append(get_libc_static_file(g->libc, "libssp.a"));
    lj->args.append(get_libc_file(g->libc, "libmoldname.a"));
    lj->args.append(get_libc_file(g->libc, "libmingwex.a"));
    lj->args.append(get_libc_file(g->libc, "libmsvcrt.a"));

    if (detect_subsystem(g) == TargetSubsystemWindows) {
        lj->args.append(get_libc_file(g->libc, "libgdi32.a"));
        lj->args.append(get_libc_file(g->libc, "libcomdlg32.a"));
    }

    lj->args.append(get_libc_file(g->libc, "libadvapi32.a"));
    lj->args.append(get_libc_file(g->libc, "libadvapi32.a"));
    lj->args.append(get_libc_file(g->libc, "libshell32.a"));
    lj->args.append(get_libc_file(g->libc, "libuser32.a"));
    lj->args.append(get_libc_file(g->libc, "libkernel32.a"));

    lj->args.append(get_libc_static_file(g->libc, "crtend.o"));
}

static void add_win_link_args(LinkJob *lj, bool is_library) {
    if (lj->link_in_crt) {
        if (target_abi_is_gnu(lj->codegen->zig_target->abi)) {
            add_mingw_link_args(lj, is_library);
        } else {
            add_msvc_link_args(lj, is_library);
        }
    } else {
        lj->args.append("-NODEFAULTLIB");
        if (!is_library) {
            if (lj->codegen->have_winmain) {
                lj->args.append("-ENTRY:WinMain");
            } else {
                lj->args.append("-ENTRY:WinMainCRTStartup");
            }
        }
    }
}

static void construct_linker_job_coff(LinkJob *lj) {
    Error err;
    CodeGen *g = lj->codegen;

    lj->args.append("-ERRORLIMIT:0");

    lj->args.append("-NOLOGO");

    if (!g->strip_debug_symbols) {
        lj->args.append("-DEBUG");
    }

    if (g->out_type == OutTypeExe) {
        // TODO compile time stack upper bound detection
        lj->args.append("-STACK:16777216");
    }

    coff_append_machine_arg(g, &lj->args);

    bool is_library = g->out_type == OutTypeLib;
    if (is_library && g->is_dynamic) {
        lj->args.append("-DLL");
    }

    lj->args.append(buf_ptr(buf_sprintf("-OUT:%s", buf_ptr(&g->output_file_path))));

    if (g->libc_link_lib != nullptr) {
        assert(g->libc != nullptr);

        lj->args.append(buf_ptr(buf_sprintf("-LIBPATH:%s", buf_ptr(&g->libc->crt_dir))));

        if (target_abi_is_gnu(g->zig_target->abi)) {
            lj->args.append(buf_ptr(buf_sprintf("-LIBPATH:%s", buf_ptr(&g->libc->sys_include_dir))));
            lj->args.append(buf_ptr(buf_sprintf("-LIBPATH:%s", buf_ptr(&g->libc->include_dir))));
        } else {
            lj->args.append(buf_ptr(buf_sprintf("-LIBPATH:%s", buf_ptr(&g->libc->msvc_lib_dir))));
            lj->args.append(buf_ptr(buf_sprintf("-LIBPATH:%s", buf_ptr(&g->libc->kernel32_lib_dir))));
        }
    }

    for (size_t i = 0; i < g->lib_dirs.length; i += 1) {
        const char *lib_dir = g->lib_dirs.at(i);
        lj->args.append(buf_ptr(buf_sprintf("-LIBPATH:%s", lib_dir)));
    }

    for (size_t i = 0; i < g->link_objects.length; i += 1) {
        lj->args.append((const char *)buf_ptr(g->link_objects.at(i)));
    }

    switch (detect_subsystem(g)) {
        case TargetSubsystemAuto:
            if (g->zig_target->os == OsUefi) {
                add_uefi_link_args(lj);
            } else {
                add_win_link_args(lj, is_library);
            }
            break;
        case TargetSubsystemConsole:
            lj->args.append("-SUBSYSTEM:console");
            add_win_link_args(lj, is_library);
            break;
        case TargetSubsystemEfiApplication:
            lj->args.append("-SUBSYSTEM:efi_application");
            add_uefi_link_args(lj);
            break;
        case TargetSubsystemEfiBootServiceDriver:
            lj->args.append("-SUBSYSTEM:efi_boot_service_driver");
            add_uefi_link_args(lj);
            break;
        case TargetSubsystemEfiRom:
            lj->args.append("-SUBSYSTEM:efi_rom");
            add_uefi_link_args(lj);
            break;
        case TargetSubsystemEfiRuntimeDriver:
            lj->args.append("-SUBSYSTEM:efi_runtime_driver");
            add_uefi_link_args(lj);
            break;
        case TargetSubsystemNative:
            lj->args.append("-SUBSYSTEM:native");
            add_win_link_args(lj, is_library);
            break;
        case TargetSubsystemPosix:
            lj->args.append("-SUBSYSTEM:posix");
            add_win_link_args(lj, is_library);
            break;
        case TargetSubsystemWindows:
            lj->args.append("-SUBSYSTEM:windows");
            add_win_link_args(lj, is_library);
            break;
    }

    if (g->out_type == OutTypeExe || (g->out_type == OutTypeLib && g->is_dynamic)) {
        if (g->libc_link_lib == nullptr && !g->is_dummy_so) {
            Buf *libc_a_path = build_c(g, OutTypeLib);
            lj->args.append(buf_ptr(libc_a_path));
        }

        // msvc compiler_rt is missing some stuff, so we still build it and rely on weak linkage
        Buf *compiler_rt_o_path = build_compiler_rt(g, OutTypeLib);
        lj->args.append(buf_ptr(compiler_rt_o_path));
    }

    Buf *def_contents = buf_alloc();
    ZigList<const char *> gen_lib_args = {0};
    for (size_t lib_i = 0; lib_i < g->link_libs_list.length; lib_i += 1) {
        LinkLib *link_lib = g->link_libs_list.at(lib_i);
        if (buf_eql_str(link_lib->name, "c")) {
            continue;
        }
        if (link_lib->provided_explicitly) {
            if (target_abi_is_gnu(lj->codegen->zig_target->abi)) {
                Buf *lib_name = buf_sprintf("lib%s.a", buf_ptr(link_lib->name));
                lj->args.append(buf_ptr(lib_name));
            } else {
                lj->args.append(buf_ptr(link_lib->name));
            }
        } else {
            buf_resize(def_contents, 0);
            buf_appendf(def_contents, "LIBRARY %s\nEXPORTS\n", buf_ptr(link_lib->name));
            for (size_t exp_i = 0; exp_i < link_lib->symbols.length; exp_i += 1) {
                Buf *symbol_name = link_lib->symbols.at(exp_i);
                buf_appendf(def_contents, "%s\n", buf_ptr(symbol_name));
            }
            buf_appendf(def_contents, "\n");

            Buf *def_path = buf_alloc();
            os_path_join(g->output_dir, buf_sprintf("%s.def", buf_ptr(link_lib->name)), def_path);
            if ((err = os_write_file(def_path, def_contents))) {
                zig_panic("error writing def file: %s", err_str(err));
            }

            Buf *generated_lib_path = buf_alloc();
            os_path_join(g->output_dir, buf_sprintf("%s.lib", buf_ptr(link_lib->name)), generated_lib_path);

            gen_lib_args.resize(0);
            gen_lib_args.append("link");

            coff_append_machine_arg(g, &gen_lib_args);
            gen_lib_args.append(buf_ptr(buf_sprintf("-DEF:%s", buf_ptr(def_path))));
            gen_lib_args.append(buf_ptr(buf_sprintf("-OUT:%s", buf_ptr(generated_lib_path))));
            Buf diag = BUF_INIT;
            ZigLLVM_ObjectFormatType target_ofmt = target_object_format(g->zig_target);
            if (!zig_lld_link(target_ofmt, gen_lib_args.items, gen_lib_args.length, &diag)) {
                fprintf(stderr, "%s\n", buf_ptr(&diag));
                exit(1);
            }
            lj->args.append(buf_ptr(generated_lib_path));
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
    } else if (g->zig_target->os == OsMacOSX) {
        platform->kind = MacOS;
        g->mmacosx_version_min = buf_create_from_str("10.14");
    } else {
        zig_panic("unable to infer -mmacosx-version-min or -mios-version-min");
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
        (g->zig_target->arch == ZigLLVM_x86 ||
         g->zig_target->arch == ZigLLVM_x86_64))
    {
        platform->kind = IPhoneOSSimulator;
    }
}

static void construct_linker_job_macho(LinkJob *lj) {
    CodeGen *g = lj->codegen;

    // LLD MACH-O has no error limit option.
    //lj->args.append("-error-limit=0");
    lj->args.append("-demangle");

    if (g->linker_rdynamic) {
        lj->args.append("-export_dynamic");
    }

    bool is_lib = g->out_type == OutTypeLib;
    bool is_dyn_lib = g->is_dynamic && is_lib;
    if (is_lib && !g->is_dynamic) {
        lj->args.append("-static");
    } else {
        lj->args.append("-dynamic");
    }

    if (is_dyn_lib) {
        lj->args.append("-dylib");

        Buf *compat_vers = buf_sprintf("%" ZIG_PRI_usize ".0.0", g->version_major);
        lj->args.append("-compatibility_version");
        lj->args.append(buf_ptr(compat_vers));

        Buf *cur_vers = buf_sprintf("%" ZIG_PRI_usize ".%" ZIG_PRI_usize ".%" ZIG_PRI_usize,
            g->version_major, g->version_minor, g->version_patch);
        lj->args.append("-current_version");
        lj->args.append(buf_ptr(cur_vers));

        // TODO getting an error when running an executable when doing this rpath thing
        //Buf *dylib_install_name = buf_sprintf("@rpath/lib%s.%" ZIG_PRI_usize ".dylib",
        //    buf_ptr(g->root_out_name), g->version_major);
        //lj->args.append("-install_name");
        //lj->args.append(buf_ptr(dylib_install_name));

        assert(buf_len(&g->output_file_path) != 0);
    }

    lj->args.append("-arch");
    lj->args.append(get_darwin_arch_string(g->zig_target));

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
    Buf *version_string = buf_sprintf("%d.%d.%d", platform.major, platform.minor, platform.micro);
    lj->args.append(buf_ptr(version_string));

    lj->args.append("-sdk_version");
    lj->args.append(buf_ptr(version_string));


    if (g->out_type == OutTypeExe) {
        lj->args.append("-pie");
    }

    lj->args.append("-o");
    lj->args.append(buf_ptr(&g->output_file_path));

    for (size_t i = 0; i < g->rpath_list.length; i += 1) {
        Buf *rpath = g->rpath_list.at(i);
        add_rpath(lj, rpath);
    }
    if (is_dyn_lib) {
        add_rpath(lj, &g->output_file_path);
    }

    if (is_dyn_lib) {
        if (g->system_linker_hack) {
            lj->args.append("-headerpad_max_install_names");
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

    // compiler_rt on darwin is missing some stuff, so we still build it and rely on LinkOnce
    if (g->out_type == OutTypeExe || is_dyn_lib) {
        Buf *compiler_rt_o_path = build_compiler_rt(g, OutTypeLib);
        lj->args.append(buf_ptr(compiler_rt_o_path));
    }

    if (g->zig_target->is_native) {
        for (size_t lib_i = 0; lib_i < g->link_libs_list.length; lib_i += 1) {
            LinkLib *link_lib = g->link_libs_list.at(lib_i);
            if (target_is_libc_lib_name(g->zig_target, buf_ptr(link_lib->name))) {
                // handled by libSystem
                continue;
            }
            if (strchr(buf_ptr(link_lib->name), '/') == nullptr) {
                Buf *arg = buf_sprintf("-l%s", buf_ptr(link_lib->name));
                lj->args.append(buf_ptr(arg));
            } else {
                lj->args.append(buf_ptr(link_lib->name));
            }
        }
        // on Darwin, libSystem has libc in it, but also you have to use it
        // to make syscalls because the syscall numbers are not documented
        // and change between versions.
        // so we always link against libSystem
        lj->args.append("-lSystem");
    } else {
        lj->args.append("-undefined");
        lj->args.append("dynamic_lookup");
    }

    for (size_t i = 0; i < g->darwin_frameworks.length; i += 1) {
        lj->args.append("-framework");
        lj->args.append(buf_ptr(g->darwin_frameworks.at(i)));
    }

}

static void construct_linker_job(LinkJob *lj) {
    switch (target_object_format(lj->codegen->zig_target)) {
        case ZigLLVM_UnknownObjectFormat:
            zig_unreachable();

        case ZigLLVM_COFF:
            return construct_linker_job_coff(lj);
        case ZigLLVM_ELF:
            return construct_linker_job_elf(lj);
        case ZigLLVM_MachO:
            return construct_linker_job_macho(lj);
        case ZigLLVM_Wasm:
            return construct_linker_job_wasm(lj);
    }
}

void zig_link_add_compiler_rt(CodeGen *g) {
    Buf *compiler_rt_o_path = build_compiler_rt(g, OutTypeObj);
    g->link_objects.append(compiler_rt_o_path);
}

void codegen_link(CodeGen *g) {
    codegen_add_time_event(g, "Build Dependencies");

    LinkJob lj = {0};

    // even though we're calling LLD as a library it thinks the first
    // argument is its own exe name
    lj.args.append("lld");

    lj.rpath_table.init(4);
    lj.codegen = g;

    if (g->verbose_llvm_ir) {
        fprintf(stderr, "\nOptimization:\n");
        fprintf(stderr, "---------------\n");
        fflush(stderr);
        LLVMDumpModule(g->module);
    }

    if (g->out_type == OutTypeObj) {
        lj.args.append("-r");
    }

    if (g->out_type == OutTypeLib && !g->is_dynamic && !target_is_wasm(g->zig_target)) {
        ZigList<const char *> file_names = {};
        for (size_t i = 0; i < g->link_objects.length; i += 1) {
            file_names.append(buf_ptr(g->link_objects.at(i)));
        }
        ZigLLVM_OSType os_type = get_llvm_os_type(g->zig_target->os);
        codegen_add_time_event(g, "LLVM Link");
        if (g->verbose_link) {
            fprintf(stderr, "ar rcs %s", buf_ptr(&g->output_file_path));
            for (size_t i = 0; i < file_names.length; i += 1) {
                fprintf(stderr, " %s", file_names.at(i));
            }
            fprintf(stderr, "\n");
        }
        if (ZigLLVMWriteArchive(buf_ptr(&g->output_file_path), file_names.items, file_names.length, os_type)) {
            fprintf(stderr, "Unable to write archive '%s'\n", buf_ptr(&g->output_file_path));
            exit(1);
        }
        return;
    }

    lj.link_in_crt = (g->libc_link_lib != nullptr && g->out_type == OutTypeExe);

    construct_linker_job(&lj);


    if (g->verbose_link) {
        for (size_t i = 0; i < lj.args.length; i += 1) {
            const char *space = (i != 0) ? " " : "";
            fprintf(stderr, "%s%s", space, lj.args.at(i));
        }
        fprintf(stderr, "\n");
    }

    Buf diag = BUF_INIT;

    codegen_add_time_event(g, "LLVM Link");
    if (g->system_linker_hack && g->zig_target->os == OsMacOSX) {
        Termination term;
        ZigList<const char *> args = {};
        for (size_t i = 1; i < lj.args.length; i += 1) {
            args.append(lj.args.at(i));
        }
        os_spawn_process("ld", args, &term);
        if (term.how != TerminationIdClean || term.code != 0) {
            exit(1);
        }
    } else if (!zig_lld_link(target_object_format(g->zig_target), lj.args.items, lj.args.length, &diag)) {
        fprintf(stderr, "%s\n", buf_ptr(&diag));
        exit(1);
    }
}
