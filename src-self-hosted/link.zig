const std = @import("std");
const mem = std.mem;
const c = @import("c.zig");
const builtin = @import("builtin");
const ObjectFormat = builtin.ObjectFormat;
const Compilation = @import("compilation.zig").Compilation;
const Target = @import("target.zig").Target;
const LibCInstallation = @import("libc_installation.zig").LibCInstallation;
const assert = std.debug.assert;

const Context = struct.{
    comp: *Compilation,
    arena: std.heap.ArenaAllocator,
    args: std.ArrayList([*]const u8),
    link_in_crt: bool,

    link_err: error.{OutOfMemory}!void,
    link_msg: std.Buffer,

    libc: *LibCInstallation,
    out_file_path: std.Buffer,
};

pub async fn link(comp: *Compilation) !void {
    var ctx = Context.{
        .comp = comp,
        .arena = std.heap.ArenaAllocator.init(comp.gpa()),
        .args = undefined,
        .link_in_crt = comp.haveLibC() and comp.kind == Compilation.Kind.Exe,
        .link_err = {},
        .link_msg = undefined,
        .libc = undefined,
        .out_file_path = undefined,
    };
    defer ctx.arena.deinit();
    ctx.args = std.ArrayList([*]const u8).init(&ctx.arena.allocator);
    ctx.link_msg = std.Buffer.initNull(&ctx.arena.allocator);

    if (comp.link_out_file) |out_file| {
        ctx.out_file_path = try std.Buffer.init(&ctx.arena.allocator, out_file);
    } else {
        ctx.out_file_path = try std.Buffer.init(&ctx.arena.allocator, comp.name.toSliceConst());
        switch (comp.kind) {
            Compilation.Kind.Exe => {
                try ctx.out_file_path.append(comp.target.exeFileExt());
            },
            Compilation.Kind.Lib => {
                try ctx.out_file_path.append(comp.target.libFileExt(comp.is_static));
            },
            Compilation.Kind.Obj => {
                try ctx.out_file_path.append(comp.target.objFileExt());
            },
        }
    }

    // even though we're calling LLD as a library it thinks the first
    // argument is its own exe name
    try ctx.args.append(c"lld");

    if (comp.haveLibC()) {
        ctx.libc = ctx.comp.override_libc orelse blk: {
            switch (comp.target) {
                Target.Native => {
                    break :blk (await (async comp.zig_compiler.getNativeLibC() catch unreachable)) catch return error.LibCRequiredButNotProvidedOrFound;
                },
                else => return error.LibCRequiredButNotProvidedOrFound,
            }
        };
    }

    try constructLinkerArgs(&ctx);

    if (comp.verbose_link) {
        for (ctx.args.toSliceConst()) |arg, i| {
            const space = if (i == 0) "" else " ";
            std.debug.warn("{}{s}", space, arg);
        }
        std.debug.warn("\n");
    }

    const extern_ofmt = toExternObjectFormatType(comp.target.getObjectFormat());
    const args_slice = ctx.args.toSlice();

    {
        // LLD is not thread-safe, so we grab a global lock.
        const held = await (async comp.zig_compiler.lld_lock.acquire() catch unreachable);
        defer held.release();

        // Not evented I/O. LLD does its own multithreading internally.
        if (!ZigLLDLink(extern_ofmt, args_slice.ptr, args_slice.len, linkDiagCallback, @ptrCast(*c_void, &ctx))) {
            if (!ctx.link_msg.isNull()) {
                // TODO capture these messages and pass them through the system, reporting them through the
                // event system instead of printing them directly here.
                // perhaps try to parse and understand them.
                std.debug.warn("{}\n", ctx.link_msg.toSliceConst());
            }
            return error.LinkFailed;
        }
    }
}

extern fn ZigLLDLink(
    oformat: c.ZigLLVM_ObjectFormatType,
    args: [*]const [*]const u8,
    arg_count: usize,
    append_diagnostic: extern fn (*c_void, [*]const u8, usize) void,
    context: *c_void,
) bool;

extern fn linkDiagCallback(context: *c_void, ptr: [*]const u8, len: usize) void {
    const ctx = @ptrCast(*Context, @alignCast(@alignOf(Context), context));
    ctx.link_err = linkDiagCallbackErrorable(ctx, ptr[0..len]);
}

fn linkDiagCallbackErrorable(ctx: *Context, msg: []const u8) !void {
    if (ctx.link_msg.isNull()) {
        try ctx.link_msg.resize(0);
    }
    try ctx.link_msg.append(msg);
}

fn toExternObjectFormatType(ofmt: ObjectFormat) c.ZigLLVM_ObjectFormatType {
    return switch (ofmt) {
        ObjectFormat.unknown => c.ZigLLVM_UnknownObjectFormat,
        ObjectFormat.coff => c.ZigLLVM_COFF,
        ObjectFormat.elf => c.ZigLLVM_ELF,
        ObjectFormat.macho => c.ZigLLVM_MachO,
        ObjectFormat.wasm => c.ZigLLVM_Wasm,
    };
}

fn constructLinkerArgs(ctx: *Context) !void {
    switch (ctx.comp.target.getObjectFormat()) {
        ObjectFormat.unknown => unreachable,
        ObjectFormat.coff => return constructLinkerArgsCoff(ctx),
        ObjectFormat.elf => return constructLinkerArgsElf(ctx),
        ObjectFormat.macho => return constructLinkerArgsMachO(ctx),
        ObjectFormat.wasm => return constructLinkerArgsWasm(ctx),
    }
}

fn constructLinkerArgsElf(ctx: *Context) !void {
    // TODO commented out code in this function
    //if (g->linker_script) {
    //    lj->args.append("-T");
    //    lj->args.append(g->linker_script);
    //}

    //if (g->no_rosegment_workaround) {
    //    lj->args.append("--no-rosegment");
    //}
    try ctx.args.append(c"--gc-sections");

    //lj->args.append("-m");
    //lj->args.append(getLDMOption(&g->zig_target));

    //bool is_lib = g->out_type == OutTypeLib;
    //bool shared = !g->is_static && is_lib;
    //Buf *soname = nullptr;
    if (ctx.comp.is_static) {
        if (ctx.comp.target.isArmOrThumb()) {
            try ctx.args.append(c"-Bstatic");
        } else {
            try ctx.args.append(c"-static");
        }
    }
    //} else if (shared) {
    //    lj->args.append("-shared");

    //    if (buf_len(&lj->out_file) == 0) {
    //        buf_appendf(&lj->out_file, "lib%s.so.%" ZIG_PRI_usize ".%" ZIG_PRI_usize ".%" ZIG_PRI_usize "",
    //                buf_ptr(g->root_out_name), g->version_major, g->version_minor, g->version_patch);
    //    }
    //    soname = buf_sprintf("lib%s.so.%" ZIG_PRI_usize "", buf_ptr(g->root_out_name), g->version_major);
    //}

    try ctx.args.append(c"-o");
    try ctx.args.append(ctx.out_file_path.ptr());

    if (ctx.link_in_crt) {
        const crt1o = if (ctx.comp.is_static) "crt1.o" else "Scrt1.o";
        const crtbegino = if (ctx.comp.is_static) "crtbeginT.o" else "crtbegin.o";
        try addPathJoin(ctx, ctx.libc.lib_dir.?, crt1o);
        try addPathJoin(ctx, ctx.libc.lib_dir.?, "crti.o");
        try addPathJoin(ctx, ctx.libc.static_lib_dir.?, crtbegino);
    }

    //for (size_t i = 0; i < g->rpath_list.length; i += 1) {
    //    Buf *rpath = g->rpath_list.at(i);
    //    add_rpath(lj, rpath);
    //}
    //if (g->each_lib_rpath) {
    //    for (size_t i = 0; i < g->lib_dirs.length; i += 1) {
    //        const char *lib_dir = g->lib_dirs.at(i);
    //        for (size_t i = 0; i < g->link_libs_list.length; i += 1) {
    //            LinkLib *link_lib = g->link_libs_list.at(i);
    //            if (buf_eql_str(link_lib->name, "c")) {
    //                continue;
    //            }
    //            bool does_exist;
    //            Buf *test_path = buf_sprintf("%s/lib%s.so", lib_dir, buf_ptr(link_lib->name));
    //            if (os_file_exists(test_path, &does_exist) != ErrorNone) {
    //                zig_panic("link: unable to check if file exists: %s", buf_ptr(test_path));
    //            }
    //            if (does_exist) {
    //                add_rpath(lj, buf_create_from_str(lib_dir));
    //                break;
    //            }
    //        }
    //    }
    //}

    //for (size_t i = 0; i < g->lib_dirs.length; i += 1) {
    //    const char *lib_dir = g->lib_dirs.at(i);
    //    lj->args.append("-L");
    //    lj->args.append(lib_dir);
    //}

    if (ctx.comp.haveLibC()) {
        try ctx.args.append(c"-L");
        try ctx.args.append((try std.cstr.addNullByte(&ctx.arena.allocator, ctx.libc.lib_dir.?)).ptr);

        try ctx.args.append(c"-L");
        try ctx.args.append((try std.cstr.addNullByte(&ctx.arena.allocator, ctx.libc.static_lib_dir.?)).ptr);

        if (!ctx.comp.is_static) {
            const dl = blk: {
                if (ctx.libc.dynamic_linker_path) |dl| break :blk dl;
                if (ctx.comp.target.getDynamicLinkerPath()) |dl| break :blk dl;
                return error.LibCMissingDynamicLinker;
            };
            try ctx.args.append(c"-dynamic-linker");
            try ctx.args.append((try std.cstr.addNullByte(&ctx.arena.allocator, dl)).ptr);
        }
    }

    //if (shared) {
    //    lj->args.append("-soname");
    //    lj->args.append(buf_ptr(soname));
    //}

    // .o files
    for (ctx.comp.link_objects) |link_object| {
        const link_obj_with_null = try std.cstr.addNullByte(&ctx.arena.allocator, link_object);
        try ctx.args.append(link_obj_with_null.ptr);
    }
    try addFnObjects(ctx);

    //if (g->out_type == OutTypeExe || g->out_type == OutTypeLib) {
    //    if (g->libc_link_lib == nullptr) {
    //        Buf *builtin_o_path = build_o(g, "builtin");
    //        lj->args.append(buf_ptr(builtin_o_path));
    //    }

    //    // sometimes libgcc is missing stuff, so we still build compiler_rt and rely on weak linkage
    //    Buf *compiler_rt_o_path = build_compiler_rt(g);
    //    lj->args.append(buf_ptr(compiler_rt_o_path));
    //}

    //for (size_t i = 0; i < g->link_libs_list.length; i += 1) {
    //    LinkLib *link_lib = g->link_libs_list.at(i);
    //    if (buf_eql_str(link_lib->name, "c")) {
    //        continue;
    //    }
    //    Buf *arg;
    //    if (buf_starts_with_str(link_lib->name, "/") || buf_ends_with_str(link_lib->name, ".a") ||
    //        buf_ends_with_str(link_lib->name, ".so"))
    //    {
    //        arg = link_lib->name;
    //    } else {
    //        arg = buf_sprintf("-l%s", buf_ptr(link_lib->name));
    //    }
    //    lj->args.append(buf_ptr(arg));
    //}

    // libc dep
    if (ctx.comp.haveLibC()) {
        if (ctx.comp.is_static) {
            try ctx.args.append(c"--start-group");
            try ctx.args.append(c"-lgcc");
            try ctx.args.append(c"-lgcc_eh");
            try ctx.args.append(c"-lc");
            try ctx.args.append(c"-lm");
            try ctx.args.append(c"--end-group");
        } else {
            try ctx.args.append(c"-lgcc");
            try ctx.args.append(c"--as-needed");
            try ctx.args.append(c"-lgcc_s");
            try ctx.args.append(c"--no-as-needed");
            try ctx.args.append(c"-lc");
            try ctx.args.append(c"-lm");
            try ctx.args.append(c"-lgcc");
            try ctx.args.append(c"--as-needed");
            try ctx.args.append(c"-lgcc_s");
            try ctx.args.append(c"--no-as-needed");
        }
    }

    // crt end
    if (ctx.link_in_crt) {
        try addPathJoin(ctx, ctx.libc.static_lib_dir.?, "crtend.o");
        try addPathJoin(ctx, ctx.libc.lib_dir.?, "crtn.o");
    }

    if (ctx.comp.target != Target.Native) {
        try ctx.args.append(c"--allow-shlib-undefined");
    }

    if (ctx.comp.target.getOs() == builtin.Os.zen) {
        try ctx.args.append(c"-e");
        try ctx.args.append(c"_start");

        try ctx.args.append(c"--image-base=0x10000000");
    }
}

fn addPathJoin(ctx: *Context, dirname: []const u8, basename: []const u8) !void {
    const full_path = try std.os.path.join(&ctx.arena.allocator, dirname, basename);
    const full_path_with_null = try std.cstr.addNullByte(&ctx.arena.allocator, full_path);
    try ctx.args.append(full_path_with_null.ptr);
}

fn constructLinkerArgsCoff(ctx: *Context) !void {
    try ctx.args.append(c"-NOLOGO");

    if (!ctx.comp.strip) {
        try ctx.args.append(c"-DEBUG");
    }

    switch (ctx.comp.target.getArch()) {
        builtin.Arch.i386 => try ctx.args.append(c"-MACHINE:X86"),
        builtin.Arch.x86_64 => try ctx.args.append(c"-MACHINE:X64"),
        builtin.Arch.aarch64v8 => try ctx.args.append(c"-MACHINE:ARM"),
        else => return error.UnsupportedLinkArchitecture,
    }

    if (ctx.comp.windows_subsystem_windows) {
        try ctx.args.append(c"/SUBSYSTEM:windows");
    } else if (ctx.comp.windows_subsystem_console) {
        try ctx.args.append(c"/SUBSYSTEM:console");
    }

    const is_library = ctx.comp.kind == Compilation.Kind.Lib;

    const out_arg = try std.fmt.allocPrint(&ctx.arena.allocator, "-OUT:{}\x00", ctx.out_file_path.toSliceConst());
    try ctx.args.append(out_arg.ptr);

    if (ctx.comp.haveLibC()) {
        try ctx.args.append((try std.fmt.allocPrint(&ctx.arena.allocator, "-LIBPATH:{}\x00", ctx.libc.msvc_lib_dir.?)).ptr);
        try ctx.args.append((try std.fmt.allocPrint(&ctx.arena.allocator, "-LIBPATH:{}\x00", ctx.libc.kernel32_lib_dir.?)).ptr);
        try ctx.args.append((try std.fmt.allocPrint(&ctx.arena.allocator, "-LIBPATH:{}\x00", ctx.libc.lib_dir.?)).ptr);
    }

    if (ctx.link_in_crt) {
        const lib_str = if (ctx.comp.is_static) "lib" else "";
        const d_str = if (ctx.comp.build_mode == builtin.Mode.Debug) "d" else "";

        if (ctx.comp.is_static) {
            const cmt_lib_name = try std.fmt.allocPrint(&ctx.arena.allocator, "libcmt{}.lib\x00", d_str);
            try ctx.args.append(cmt_lib_name.ptr);
        } else {
            const msvcrt_lib_name = try std.fmt.allocPrint(&ctx.arena.allocator, "msvcrt{}.lib\x00", d_str);
            try ctx.args.append(msvcrt_lib_name.ptr);
        }

        const vcruntime_lib_name = try std.fmt.allocPrint(&ctx.arena.allocator, "{}vcruntime{}.lib\x00", lib_str, d_str);
        try ctx.args.append(vcruntime_lib_name.ptr);

        const crt_lib_name = try std.fmt.allocPrint(&ctx.arena.allocator, "{}ucrt{}.lib\x00", lib_str, d_str);
        try ctx.args.append(crt_lib_name.ptr);

        // Visual C++ 2015 Conformance Changes
        // https://msdn.microsoft.com/en-us/library/bb531344.aspx
        try ctx.args.append(c"legacy_stdio_definitions.lib");

        // msvcrt depends on kernel32
        try ctx.args.append(c"kernel32.lib");
    } else {
        try ctx.args.append(c"-NODEFAULTLIB");
        if (!is_library) {
            try ctx.args.append(c"-ENTRY:WinMainCRTStartup");
            // TODO
            //if (g->have_winmain) {
            //    lj->args.append("-ENTRY:WinMain");
            //} else {
            //    lj->args.append("-ENTRY:WinMainCRTStartup");
            //}
        }
    }

    if (is_library and !ctx.comp.is_static) {
        try ctx.args.append(c"-DLL");
    }

    //for (size_t i = 0; i < g->lib_dirs.length; i += 1) {
    //    const char *lib_dir = g->lib_dirs.at(i);
    //    lj->args.append(buf_ptr(buf_sprintf("-LIBPATH:%s", lib_dir)));
    //}

    for (ctx.comp.link_objects) |link_object| {
        const link_obj_with_null = try std.cstr.addNullByte(&ctx.arena.allocator, link_object);
        try ctx.args.append(link_obj_with_null.ptr);
    }
    try addFnObjects(ctx);

    switch (ctx.comp.kind) {
        Compilation.Kind.Exe, Compilation.Kind.Lib => {
            if (!ctx.comp.haveLibC()) {
                @panic("TODO");
                //Buf *builtin_o_path = build_o(g, "builtin");
                //lj->args.append(buf_ptr(builtin_o_path));
            }

            // msvc compiler_rt is missing some stuff, so we still build it and rely on weak linkage
            // TODO
            //Buf *compiler_rt_o_path = build_compiler_rt(g);
            //lj->args.append(buf_ptr(compiler_rt_o_path));
        },
        Compilation.Kind.Obj => {},
    }

    //Buf *def_contents = buf_alloc();
    //ZigList<const char *> gen_lib_args = {0};
    //for (size_t lib_i = 0; lib_i < g->link_libs_list.length; lib_i += 1) {
    //    LinkLib *link_lib = g->link_libs_list.at(lib_i);
    //    if (buf_eql_str(link_lib->name, "c")) {
    //        continue;
    //    }
    //    if (link_lib->provided_explicitly) {
    //        if (lj->codegen->zig_target.env_type == ZigLLVM_GNU) {
    //            Buf *arg = buf_sprintf("-l%s", buf_ptr(link_lib->name));
    //            lj->args.append(buf_ptr(arg));
    //        }
    //        else {
    //            lj->args.append(buf_ptr(link_lib->name));
    //        }
    //    } else {
    //        buf_resize(def_contents, 0);
    //        buf_appendf(def_contents, "LIBRARY %s\nEXPORTS\n", buf_ptr(link_lib->name));
    //        for (size_t exp_i = 0; exp_i < link_lib->symbols.length; exp_i += 1) {
    //            Buf *symbol_name = link_lib->symbols.at(exp_i);
    //            buf_appendf(def_contents, "%s\n", buf_ptr(symbol_name));
    //        }
    //        buf_appendf(def_contents, "\n");

    //        Buf *def_path = buf_alloc();
    //        os_path_join(g->cache_dir, buf_sprintf("%s.def", buf_ptr(link_lib->name)), def_path);
    //        os_write_file(def_path, def_contents);

    //        Buf *generated_lib_path = buf_alloc();
    //        os_path_join(g->cache_dir, buf_sprintf("%s.lib", buf_ptr(link_lib->name)), generated_lib_path);

    //        gen_lib_args.resize(0);
    //        gen_lib_args.append("link");

    //        coff_append_machine_arg(g, &gen_lib_args);
    //        gen_lib_args.append(buf_ptr(buf_sprintf("-DEF:%s", buf_ptr(def_path))));
    //        gen_lib_args.append(buf_ptr(buf_sprintf("-OUT:%s", buf_ptr(generated_lib_path))));
    //        Buf diag = BUF_INIT;
    //        if (!zig_lld_link(g->zig_target.oformat, gen_lib_args.items, gen_lib_args.length, &diag)) {
    //            fprintf(stderr, "%s\n", buf_ptr(&diag));
    //            exit(1);
    //        }
    //        lj->args.append(buf_ptr(generated_lib_path));
    //    }
    //}
}

fn constructLinkerArgsMachO(ctx: *Context) !void {
    try ctx.args.append(c"-demangle");

    if (ctx.comp.linker_rdynamic) {
        try ctx.args.append(c"-export_dynamic");
    }

    const is_lib = ctx.comp.kind == Compilation.Kind.Lib;
    const shared = !ctx.comp.is_static and is_lib;
    if (ctx.comp.is_static) {
        try ctx.args.append(c"-static");
    } else {
        try ctx.args.append(c"-dynamic");
    }

    //if (is_lib) {
    //    if (!g->is_static) {
    //        lj->args.append("-dylib");

    //        Buf *compat_vers = buf_sprintf("%" ZIG_PRI_usize ".0.0", g->version_major);
    //        lj->args.append("-compatibility_version");
    //        lj->args.append(buf_ptr(compat_vers));

    //        Buf *cur_vers = buf_sprintf("%" ZIG_PRI_usize ".%" ZIG_PRI_usize ".%" ZIG_PRI_usize,
    //            g->version_major, g->version_minor, g->version_patch);
    //        lj->args.append("-current_version");
    //        lj->args.append(buf_ptr(cur_vers));

    //        // TODO getting an error when running an executable when doing this rpath thing
    //        //Buf *dylib_install_name = buf_sprintf("@rpath/lib%s.%" ZIG_PRI_usize ".dylib",
    //        //    buf_ptr(g->root_out_name), g->version_major);
    //        //lj->args.append("-install_name");
    //        //lj->args.append(buf_ptr(dylib_install_name));

    //        if (buf_len(&lj->out_file) == 0) {
    //            buf_appendf(&lj->out_file, "lib%s.%" ZIG_PRI_usize ".%" ZIG_PRI_usize ".%" ZIG_PRI_usize ".dylib",
    //                buf_ptr(g->root_out_name), g->version_major, g->version_minor, g->version_patch);
    //        }
    //    }
    //}

    try ctx.args.append(c"-arch");
    const darwin_arch_str = try std.cstr.addNullByte(
        &ctx.arena.allocator,
        ctx.comp.target.getDarwinArchString(),
    );
    try ctx.args.append(darwin_arch_str.ptr);

    const platform = try DarwinPlatform.get(ctx.comp);
    switch (platform.kind) {
        DarwinPlatform.Kind.MacOS => try ctx.args.append(c"-macosx_version_min"),
        DarwinPlatform.Kind.IPhoneOS => try ctx.args.append(c"-iphoneos_version_min"),
        DarwinPlatform.Kind.IPhoneOSSimulator => try ctx.args.append(c"-ios_simulator_version_min"),
    }
    const ver_str = try std.fmt.allocPrint(&ctx.arena.allocator, "{}.{}.{}\x00", platform.major, platform.minor, platform.micro);
    try ctx.args.append(ver_str.ptr);

    if (ctx.comp.kind == Compilation.Kind.Exe) {
        if (ctx.comp.is_static) {
            try ctx.args.append(c"-no_pie");
        } else {
            try ctx.args.append(c"-pie");
        }
    }

    try ctx.args.append(c"-o");
    try ctx.args.append(ctx.out_file_path.ptr());

    //for (size_t i = 0; i < g->rpath_list.length; i += 1) {
    //    Buf *rpath = g->rpath_list.at(i);
    //    add_rpath(lj, rpath);
    //}
    //add_rpath(lj, &lj->out_file);

    if (shared) {
        try ctx.args.append(c"-headerpad_max_install_names");
    } else if (ctx.comp.is_static) {
        try ctx.args.append(c"-lcrt0.o");
    } else {
        switch (platform.kind) {
            DarwinPlatform.Kind.MacOS => {
                if (platform.versionLessThan(10, 5)) {
                    try ctx.args.append(c"-lcrt1.o");
                } else if (platform.versionLessThan(10, 6)) {
                    try ctx.args.append(c"-lcrt1.10.5.o");
                } else if (platform.versionLessThan(10, 8)) {
                    try ctx.args.append(c"-lcrt1.10.6.o");
                }
            },
            DarwinPlatform.Kind.IPhoneOS => {
                if (ctx.comp.target.getArch() == builtin.Arch.aarch64v8) {
                    // iOS does not need any crt1 files for arm64
                } else if (platform.versionLessThan(3, 1)) {
                    try ctx.args.append(c"-lcrt1.o");
                } else if (platform.versionLessThan(6, 0)) {
                    try ctx.args.append(c"-lcrt1.3.1.o");
                }
            },
            DarwinPlatform.Kind.IPhoneOSSimulator => {}, // no crt1.o needed
        }
    }

    //for (size_t i = 0; i < g->lib_dirs.length; i += 1) {
    //    const char *lib_dir = g->lib_dirs.at(i);
    //    lj->args.append("-L");
    //    lj->args.append(lib_dir);
    //}

    for (ctx.comp.link_objects) |link_object| {
        const link_obj_with_null = try std.cstr.addNullByte(&ctx.arena.allocator, link_object);
        try ctx.args.append(link_obj_with_null.ptr);
    }
    try addFnObjects(ctx);

    //// compiler_rt on darwin is missing some stuff, so we still build it and rely on LinkOnce
    //if (g->out_type == OutTypeExe || g->out_type == OutTypeLib) {
    //    Buf *compiler_rt_o_path = build_compiler_rt(g);
    //    lj->args.append(buf_ptr(compiler_rt_o_path));
    //}

    if (ctx.comp.target == Target.Native) {
        for (ctx.comp.link_libs_list.toSliceConst()) |lib| {
            if (mem.eql(u8, lib.name, "c")) {
                // on Darwin, libSystem has libc in it, but also you have to use it
                // to make syscalls because the syscall numbers are not documented
                // and change between versions.
                // so we always link against libSystem
                try ctx.args.append(c"-lSystem");
            } else {
                if (mem.indexOfScalar(u8, lib.name, '/') == null) {
                    const arg = try std.fmt.allocPrint(&ctx.arena.allocator, "-l{}\x00", lib.name);
                    try ctx.args.append(arg.ptr);
                } else {
                    const arg = try std.cstr.addNullByte(&ctx.arena.allocator, lib.name);
                    try ctx.args.append(arg.ptr);
                }
            }
        }
    } else {
        try ctx.args.append(c"-undefined");
        try ctx.args.append(c"dynamic_lookup");
    }

    if (platform.kind == DarwinPlatform.Kind.MacOS) {
        if (platform.versionLessThan(10, 5)) {
            try ctx.args.append(c"-lgcc_s.10.4");
        } else if (platform.versionLessThan(10, 6)) {
            try ctx.args.append(c"-lgcc_s.10.5");
        }
    } else {
        @panic("TODO");
    }

    //for (size_t i = 0; i < g->darwin_frameworks.length; i += 1) {
    //    lj->args.append("-framework");
    //    lj->args.append(buf_ptr(g->darwin_frameworks.at(i)));
    //}
}

fn constructLinkerArgsWasm(ctx: *Context) void {
    @panic("TODO");
}

fn addFnObjects(ctx: *Context) !void {
    // at this point it's guaranteed nobody else has this lock, so we circumvent it
    // and avoid having to be a coroutine
    const fn_link_set = &ctx.comp.fn_link_set.private_data;

    var it = fn_link_set.first;
    while (it) |node| {
        const fn_val = node.data orelse {
            // handle the tombstone. See Value.Fn.destroy.
            it = node.next;
            fn_link_set.remove(node);
            ctx.comp.gpa().destroy(node);
            continue;
        };
        try ctx.args.append(fn_val.containing_object.ptr());
        it = node.next;
    }
}

const DarwinPlatform = struct.{
    kind: Kind,
    major: u32,
    minor: u32,
    micro: u32,

    const Kind = enum.{
        MacOS,
        IPhoneOS,
        IPhoneOSSimulator,
    };

    fn get(comp: *Compilation) !DarwinPlatform {
        var result: DarwinPlatform = undefined;
        const ver_str = switch (comp.darwin_version_min) {
            Compilation.DarwinVersionMin.MacOS => |ver| blk: {
                result.kind = Kind.MacOS;
                break :blk ver;
            },
            Compilation.DarwinVersionMin.Ios => |ver| blk: {
                result.kind = Kind.IPhoneOS;
                break :blk ver;
            },
            Compilation.DarwinVersionMin.None => blk: {
                assert(comp.target.getOs() == builtin.Os.macosx);
                result.kind = Kind.MacOS;
                break :blk "10.10";
            },
        };

        var had_extra: bool = undefined;
        try darwinGetReleaseVersion(
            ver_str,
            &result.major,
            &result.minor,
            &result.micro,
            &had_extra,
        );
        if (had_extra or result.major != 10 or result.minor >= 100 or result.micro >= 100) {
            return error.InvalidDarwinVersionString;
        }

        if (result.kind == Kind.IPhoneOS) {
            switch (comp.target.getArch()) {
                builtin.Arch.i386,
                builtin.Arch.x86_64,
                => result.kind = Kind.IPhoneOSSimulator,
                else => {},
            }
        }
        return result;
    }

    fn versionLessThan(self: DarwinPlatform, major: u32, minor: u32) bool {
        if (self.major < major)
            return true;
        if (self.major > major)
            return false;
        if (self.minor < minor)
            return true;
        return false;
    }
};

/// Parse (([0-9]+)(.([0-9]+)(.([0-9]+)?))?)? and return the
/// grouped values as integers. Numbers which are not provided are set to 0.
/// return true if the entire string was parsed (9.2), or all groups were
/// parsed (10.3.5extrastuff).
fn darwinGetReleaseVersion(str: []const u8, major: *u32, minor: *u32, micro: *u32, had_extra: *bool) !void {
    major.* = 0;
    minor.* = 0;
    micro.* = 0;
    had_extra.* = false;

    if (str.len == 0)
        return error.InvalidDarwinVersionString;

    var start_pos: usize = 0;
    for ([]*u32.{ major, minor, micro }) |v| {
        const dot_pos = mem.indexOfScalarPos(u8, str, start_pos, '.');
        const end_pos = dot_pos orelse str.len;
        v.* = std.fmt.parseUnsigned(u32, str[start_pos..end_pos], 10) catch return error.InvalidDarwinVersionString;
        start_pos = (dot_pos orelse return) + 1;
        if (start_pos == str.len) return;
    }
    had_extra.* = true;
}
