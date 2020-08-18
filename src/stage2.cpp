// This file is a shim for zig1. The real implementations of these are in
// src-self-hosted/stage1.zig

#include "stage2.h"
#include "util.hpp"
#include "zig_llvm.h"
#include "target.hpp"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

Error stage2_translate_c(struct Stage2Ast **out_ast,
        struct Stage2ErrorMsg **out_errors_ptr, size_t *out_errors_len,
        const char **args_begin, const char **args_end, const char *resources_path)
{
    const char *msg = "stage0 called stage2_translate_c";
    stage2_panic(msg, strlen(msg));
}

void stage2_free_clang_errors(struct Stage2ErrorMsg *ptr, size_t len) {
    const char *msg = "stage0 called stage2_free_clang_errors";
    stage2_panic(msg, strlen(msg));
}

void stage2_zen(const char **ptr, size_t *len) {
    const char *msg = "stage0 called stage2_zen";
    stage2_panic(msg, strlen(msg));
}

int stage2_env(int argc, char** argv) {
    const char *msg = "stage0 called stage2_env";
    stage2_panic(msg, strlen(msg));
}

void stage2_attach_segfault_handler(void) { }

void stage2_panic(const char *ptr, size_t len) {
    fwrite(ptr, 1, len, stderr);
    fprintf(stderr, "\n");
    fflush(stderr);
    abort();
}

void stage2_render_ast(struct Stage2Ast *ast, FILE *output_file) {
    const char *msg = "stage0 called stage2_render_ast";
    stage2_panic(msg, strlen(msg));
}

int stage2_fmt(int argc, char **argv) {
    const char *msg = "stage0 called stage2_fmt";
    stage2_panic(msg, strlen(msg));
}

stage2_DepTokenizer stage2_DepTokenizer_init(const char *input, size_t len) {
    const char *msg = "stage0 called stage2_DepTokenizer_init";
    stage2_panic(msg, strlen(msg));
}

void stage2_DepTokenizer_deinit(stage2_DepTokenizer *self) {
    const char *msg = "stage0 called stage2_DepTokenizer_deinit";
    stage2_panic(msg, strlen(msg));
}

stage2_DepNextResult stage2_DepTokenizer_next(stage2_DepTokenizer *self) {
    const char *msg = "stage0 called stage2_DepTokenizer_next";
    stage2_panic(msg, strlen(msg));
}


struct Stage2Progress {
    int trash;
};

struct Stage2ProgressNode {
    int trash;
};

Stage2Progress *stage2_progress_create(void) {
    return nullptr;
}

void stage2_progress_destroy(Stage2Progress *progress) {}

Stage2ProgressNode *stage2_progress_start_root(Stage2Progress *progress,
        const char *name_ptr, size_t name_len, size_t estimated_total_items)
{
    return nullptr;
}
Stage2ProgressNode *stage2_progress_start(Stage2ProgressNode *node,
        const char *name_ptr, size_t name_len, size_t estimated_total_items)
{
    return nullptr;
}
void stage2_progress_end(Stage2ProgressNode *node) {}
void stage2_progress_complete_one(Stage2ProgressNode *node) {}
void stage2_progress_disable_tty(Stage2Progress *progress) {}
void stage2_progress_update_node(Stage2ProgressNode *node, size_t completed_count, size_t estimated_total_items){}

static Os get_zig_os_type(ZigLLVM_OSType os_type) {
    switch (os_type) {
        case ZigLLVM_UnknownOS:
            return OsFreestanding;
        case ZigLLVM_Ananas:
            return OsAnanas;
        case ZigLLVM_CloudABI:
            return OsCloudABI;
        case ZigLLVM_DragonFly:
            return OsDragonFly;
        case ZigLLVM_FreeBSD:
            return OsFreeBSD;
        case ZigLLVM_Fuchsia:
            return OsFuchsia;
        case ZigLLVM_IOS:
            return OsIOS;
        case ZigLLVM_KFreeBSD:
            return OsKFreeBSD;
        case ZigLLVM_Linux:
            return OsLinux;
        case ZigLLVM_Lv2:
            return OsLv2;
        case ZigLLVM_Darwin:
        case ZigLLVM_MacOSX:
            return OsMacOSX;
        case ZigLLVM_NetBSD:
            return OsNetBSD;
        case ZigLLVM_OpenBSD:
            return OsOpenBSD;
        case ZigLLVM_Solaris:
            return OsSolaris;
        case ZigLLVM_Win32:
            return OsWindows;
        case ZigLLVM_Haiku:
            return OsHaiku;
        case ZigLLVM_Minix:
            return OsMinix;
        case ZigLLVM_RTEMS:
            return OsRTEMS;
        case ZigLLVM_NaCl:
            return OsNaCl;
        case ZigLLVM_CNK:
            return OsCNK;
        case ZigLLVM_AIX:
            return OsAIX;
        case ZigLLVM_CUDA:
            return OsCUDA;
        case ZigLLVM_NVCL:
            return OsNVCL;
        case ZigLLVM_AMDHSA:
            return OsAMDHSA;
        case ZigLLVM_PS4:
            return OsPS4;
        case ZigLLVM_ELFIAMCU:
            return OsELFIAMCU;
        case ZigLLVM_TvOS:
            return OsTvOS;
        case ZigLLVM_WatchOS:
            return OsWatchOS;
        case ZigLLVM_Mesa3D:
            return OsMesa3D;
        case ZigLLVM_Contiki:
            return OsContiki;
        case ZigLLVM_AMDPAL:
            return OsAMDPAL;
        case ZigLLVM_HermitCore:
            return OsHermitCore;
        case ZigLLVM_Hurd:
            return OsHurd;
        case ZigLLVM_WASI:
            return OsWASI;
        case ZigLLVM_Emscripten:
            return OsEmscripten;
    }
    zig_unreachable();
}

static void get_native_target(ZigTarget *target) {
    // first zero initialize
    *target = {};

    ZigLLVM_OSType os_type;
    ZigLLVM_ObjectFormatType oformat; // ignored; based on arch/os
    ZigLLVMGetNativeTarget(
            &target->arch,
            &target->vendor,
            &os_type,
            &target->abi,
            &oformat);
    target->os = get_zig_os_type(os_type);
    target->is_native_os = true;
    target->is_native_cpu = true;
    if (target->abi == ZigLLVM_UnknownEnvironment) {
        target->abi = target_default_abi(target->arch, target->os);
    }
    if (target_is_glibc(target)) {
        target->glibc_or_darwin_version = heap::c_allocator.create<Stage2SemVer>();
        target_init_default_glibc_version(target);
    }
}

Error stage2_target_parse(struct ZigTarget *target, const char *zig_triple, const char *mcpu,
        const char *dynamic_linker)
{
    Error err;

    if (zig_triple != nullptr && strcmp(zig_triple, "native") == 0) {
        zig_triple = nullptr;
    }

    if (zig_triple == nullptr) {
        get_native_target(target);

        if (mcpu == nullptr) {
            target->llvm_cpu_name = ZigLLVMGetHostCPUName();
            target->llvm_cpu_features = ZigLLVMGetNativeFeatures();
            target->cache_hash = "native\n\n";
        } else if (strcmp(mcpu, "baseline") == 0) {
            target->is_native_os = false;
            target->is_native_cpu = false;
            target->llvm_cpu_name = "";
            target->llvm_cpu_features = "";
            target->cache_hash = "baseline\n\n";
        } else {
            const char *msg = "stage0 can't handle CPU/features in the target";
            stage2_panic(msg, strlen(msg));
        }
    } else {
        // first initialize all to zero
        *target = {};

        SplitIterator it = memSplit(str(zig_triple), str("-"));

        Optional<Slice<uint8_t>> opt_archsub = SplitIterator_next(&it);
        Optional<Slice<uint8_t>> opt_os = SplitIterator_next(&it);
        Optional<Slice<uint8_t>> opt_abi = SplitIterator_next(&it);

        if (!opt_archsub.is_some)
            return ErrorMissingArchitecture;

        if ((err = target_parse_arch(&target->arch, (char*)opt_archsub.value.ptr, opt_archsub.value.len))) {
            return err;
        }

        if (!opt_os.is_some)
            return ErrorMissingOperatingSystem;

        if ((err = target_parse_os(&target->os, (char*)opt_os.value.ptr, opt_os.value.len))) {
            return err;
        }

        if (opt_abi.is_some) {
            if ((err = target_parse_abi(&target->abi, (char*)opt_abi.value.ptr, opt_abi.value.len))) {
                return err;
            }
        } else {
            target->abi = target_default_abi(target->arch, target->os);
        }

        if (mcpu != nullptr && strcmp(mcpu, "baseline") != 0) {
            const char *msg = "stage0 can't handle CPU/features in the target";
            stage2_panic(msg, strlen(msg));
        }
        target->cache_hash = "\n\n";
    }

    target->cache_hash_len = strlen(target->cache_hash);

    if (dynamic_linker != nullptr) {
        target->dynamic_linker = dynamic_linker;
    }

    return ErrorNone;
}

int stage2_cmd_targets(const char *zig_triple, const char *mcpu, const char *dynamic_linker) {
    const char *msg = "stage0 called stage2_cmd_targets";
    stage2_panic(msg, strlen(msg));
}

enum Error stage2_libc_parse(struct Stage2LibCInstallation *libc, const char *libc_file) {
    libc->include_dir = "/dummy/include";
    libc->include_dir_len = strlen(libc->include_dir);
    libc->sys_include_dir = "/dummy/sys/include";
    libc->sys_include_dir_len = strlen(libc->sys_include_dir);
    libc->crt_dir = "";
    libc->crt_dir_len = strlen(libc->crt_dir);
    libc->msvc_lib_dir = "";
    libc->msvc_lib_dir_len = strlen(libc->msvc_lib_dir);
    libc->kernel32_lib_dir = "";
    libc->kernel32_lib_dir_len = strlen(libc->kernel32_lib_dir);
    return ErrorNone;
}

enum Error stage2_libc_render(struct Stage2LibCInstallation *self, FILE *file) {
    const char *msg = "stage0 called stage2_libc_render";
    stage2_panic(msg, strlen(msg));
}

enum Error stage2_libc_find_native(struct Stage2LibCInstallation *libc) {
    const char *msg = "stage0 called stage2_libc_find_native";
    stage2_panic(msg, strlen(msg));
}

enum Error stage2_detect_native_paths(struct Stage2NativePaths *native_paths) {
    native_paths->include_dirs_ptr = nullptr;
    native_paths->include_dirs_len = 0;

    native_paths->lib_dirs_ptr = nullptr;
    native_paths->lib_dirs_len = 0;

    native_paths->rpaths_ptr = nullptr;
    native_paths->rpaths_len = 0;

    native_paths->warnings_ptr = nullptr;
    native_paths->warnings_len = 0;

    return ErrorNone;
}

void stage2_clang_arg_iterator(struct Stage2ClangArgIterator *it,
        size_t argc, char **argv)
{
    const char *msg = "stage0 called stage2_clang_arg_iterator";
    stage2_panic(msg, strlen(msg));
}

enum Error stage2_clang_arg_next(struct Stage2ClangArgIterator *it) {
    const char *msg = "stage0 called stage2_clang_arg_next";
    stage2_panic(msg, strlen(msg));
}

const bool stage2_is_zig0 = true;
