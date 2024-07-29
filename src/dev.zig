pub const Env = enum {
    /// zig1 features
    bootstrap,

    /// zig2 features
    core,

    /// stage3 features
    full,

    /// - `zig cc`
    /// - `zig c++`
    /// - `zig translate-c`
    c_source,

    /// - `zig ast-check`
    /// - `zig changelist`
    /// - `zig dump-zir`
    ast_gen,

    /// - ast_gen
    /// - `zig build-* -fno-emit-bin`
    sema,

    /// - sema
    /// - `zig build-* -fno-llvm -fno-lld -target x86_64-linux`
    @"x86_64-linux",

    /// - sema
    /// - `zig build-* -fno-llvm -fno-lld -target riscv64-linux`
    @"riscv64-linux",

    pub inline fn supports(comptime dev_env: Env, comptime feature: Feature) bool {
        return switch (dev_env) {
            .full => true,
            .bootstrap => switch (feature) {
                .build_exe_command,
                .build_obj_command,
                .ast_gen,
                .sema,
                .c_backend,
                .c_linker,
                => true,
                else => false,
            },
            .core => switch (feature) {
                .build_exe_command,
                .build_lib_command,
                .build_obj_command,
                .test_command,
                .run_command,
                .ar_command,
                .build_command,
                .clang_command,
                .stdio_listen,
                .build_import_lib,
                .make_executable,
                .make_writable,
                .incremental,
                .ast_gen,
                .sema,
                .llvm_backend,
                .c_backend,
                .wasm_backend,
                .arm_backend,
                .x86_64_backend,
                .aarch64_backend,
                .x86_backend,
                .riscv64_backend,
                .sparc64_backend,
                .spirv64_backend,
                .lld_linker,
                .coff_linker,
                .elf_linker,
                .macho_linker,
                .c_linker,
                .wasm_linker,
                .spirv_linker,
                .plan9_linker,
                .nvptx_linker,
                => true,
                .cc_command,
                .translate_c_command,
                .jit_command,
                .fetch_command,
                .init_command,
                .targets_command,
                .version_command,
                .env_command,
                .zen_command,
                .help_command,
                .ast_check_command,
                .detect_cpu_command,
                .changelist_command,
                .dump_zir_command,
                .llvm_ints_command,
                .docs_emit,
                // Avoid dragging networking into zig2.c because it adds dependencies on some
                // linker symbols that are annoying to satisfy while bootstrapping.
                .network_listen,
                .win32_resource,
                => false,
            },
            .c_source => switch (feature) {
                .clang_command,
                .cc_command,
                .translate_c_command,
                => true,
                else => false,
            },
            .ast_gen => switch (feature) {
                .ast_check_command,
                .changelist_command,
                .dump_zir_command,
                .make_executable,
                .make_writable,
                .incremental,
                .ast_gen,
                => true,
                else => false,
            },
            .sema => switch (feature) {
                .build_exe_command,
                .build_lib_command,
                .build_obj_command,
                .test_command,
                .run_command,
                .sema,
                => true,
                else => Env.ast_gen.supports(feature),
            },
            .@"x86_64-linux" => switch (feature) {
                .x86_64_backend,
                .elf_linker,
                => true,
                else => Env.sema.supports(feature),
            },
            .@"riscv64-linux" => switch (feature) {
                .riscv64_backend,
                .elf_linker,
                => true,
                else => Env.sema.supports(feature),
            },
        };
    }

    pub inline fn supportsAny(comptime dev_env: Env, comptime features: []const Feature) bool {
        inline for (features) |feature| if (dev_env.supports(feature)) return true;
        return false;
    }

    pub inline fn supportsAll(comptime dev_env: Env, comptime features: []const Feature) bool {
        inline for (features) |feature| if (!dev_env.supports(feature)) return false;
        return true;
    }
};

pub const Feature = enum {
    build_exe_command,
    build_lib_command,
    build_obj_command,
    test_command,
    run_command,
    ar_command,
    build_command,
    clang_command,
    cc_command,
    translate_c_command,
    jit_command,
    fetch_command,
    init_command,
    targets_command,
    version_command,
    env_command,
    zen_command,
    help_command,
    ast_check_command,
    detect_cpu_command,
    changelist_command,
    dump_zir_command,
    llvm_ints_command,

    docs_emit,
    stdio_listen,
    network_listen,
    build_import_lib,
    win32_resource,
    make_executable,
    make_writable,
    incremental,
    ast_gen,
    sema,

    llvm_backend,
    c_backend,
    wasm_backend,
    arm_backend,
    x86_64_backend,
    aarch64_backend,
    x86_backend,
    riscv64_backend,
    sparc64_backend,
    spirv64_backend,

    lld_linker,
    coff_linker,
    elf_linker,
    macho_linker,
    c_linker,
    wasm_linker,
    spirv_linker,
    plan9_linker,
    nvptx_linker,
};

/// Makes the code following the call to this function unreachable if `feature` is disabled.
pub fn check(comptime feature: Feature) if (env.supports(feature)) void else noreturn {
    if (env.supports(feature)) return;
    @panic("development environment " ++ @tagName(env) ++ " does not support feature " ++ @tagName(feature));
}

/// Makes the code following the call to this function unreachable if all of `features` are disabled.
pub fn checkAny(comptime features: []const Feature) if (env.supportsAny(features)) void else noreturn {
    if (env.supportsAny(features)) return;
    comptime var feature_tags: []const u8 = "";
    inline for (features[0 .. features.len - 1]) |feature| feature_tags = feature_tags ++ @tagName(feature) ++ ", ";
    feature_tags = feature_tags ++ "or " ++ @tagName(features[features.len - 1]);
    @panic("development environment " ++ @tagName(env) ++ " does not support feature " ++ feature_tags);
}

/// Makes the code following the call to this function unreachable if any of `features` are disabled.
pub fn checkAll(comptime features: []const Feature) if (env.supportsAll(features)) void else noreturn {
    if (env.supportsAll(features)) return;
    inline for (features) |feature| if (!env.supports(feature))
        @panic("development environment " ++ @tagName(env) ++ " does not support feature " ++ @tagName(feature));
}

const build_options = @import("build_options");

pub const env: Env = if (@hasDecl(build_options, "dev"))
    @field(Env, @tagName(build_options.dev))
else if (@hasDecl(build_options, "only_c") and build_options.only_c)
    .bootstrap
else if (@hasDecl(build_options, "only_core_functionality") and build_options.only_core_functionality)
    .core
else
    .full;
