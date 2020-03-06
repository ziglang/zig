const std = @import("std");
const mem = std.mem;
const c = @import("c.zig");
const Compilation = @import("compilation.zig").Compilation;
const Target = std.Target;
const ObjectFormat = Target.ObjectFormat;
const LibCInstallation = @import("libc_installation.zig").LibCInstallation;
const assert = std.debug.assert;
const util = @import("util.zig");

const Context = struct {
    comp: *Compilation,
    arena: std.heap.ArenaAllocator,
    args: std.ArrayList([*:0]const u8),
    link_in_crt: bool,

    link_err: error{OutOfMemory}!void,
    link_msg: std.Buffer,

    libc: *LibCInstallation,
    out_file_path: std.Buffer,
};

pub fn link(comp: *Compilation) !void {
    var ctx = Context{
        .comp = comp,
        .arena = std.heap.ArenaAllocator.init(comp.gpa()),
        .args = undefined,
        .link_in_crt = comp.haveLibC() and comp.kind == .Exe,
        .link_err = {},
        .link_msg = undefined,
        .libc = undefined,
        .out_file_path = undefined,
    };
    defer ctx.arena.deinit();
    ctx.args = std.ArrayList([*:0]const u8).init(&ctx.arena.allocator);
    ctx.link_msg = std.Buffer.initNull(&ctx.arena.allocator);

    ctx.out_file_path = try std.Buffer.init(&ctx.arena.allocator, comp.name.toSliceConst());
    switch (comp.kind) {
        .Exe => {
            try ctx.out_file_path.append(comp.target.exeFileExt());
        },
        .Lib => {
            try ctx.out_file_path.append(if (comp.is_static) comp.target.staticLibSuffix() else comp.target.dynamicLibSuffix());
        },
        .Obj => {
            try ctx.out_file_path.append(comp.target.oFileExt());
        },
    }

    // even though we're calling LLD as a library it thinks the first
    // argument is its own exe name
    try ctx.args.append("lld");

    if (comp.haveLibC()) {
        // TODO https://github.com/ziglang/zig/issues/3190
        var libc = ctx.comp.override_libc orelse blk: {
            switch (comp.target) {
                Target.Native => {
                    break :blk comp.zig_compiler.getNativeLibC() catch return error.LibCRequiredButNotProvidedOrFound;
                },
                else => return error.LibCRequiredButNotProvidedOrFound,
            }
        };
        ctx.libc = libc;
    }

    try constructLinkerArgs(&ctx);

    if (comp.verbose_link) {
        for (ctx.args.toSliceConst()) |arg, i| {
            const space = if (i == 0) "" else " ";
            std.debug.warn("{}{s}", .{ space, arg });
        }
        std.debug.warn("\n", .{});
    }

    const extern_ofmt = toExternObjectFormatType(comp.target.getObjectFormat());
    const args_slice = ctx.args.toSlice();

    {
        // LLD is not thread-safe, so we grab a global lock.
        const held = comp.zig_compiler.lld_lock.acquire();
        defer held.release();

        // Not evented I/O. LLD does its own multithreading internally.
        if (!ZigLLDLink(extern_ofmt, args_slice.ptr, args_slice.len, linkDiagCallback, @ptrCast(*c_void, &ctx))) {
            if (!ctx.link_msg.isNull()) {
                // TODO capture these messages and pass them through the system, reporting them through the
                // event system instead of printing them directly here.
                // perhaps try to parse and understand them.
                std.debug.warn("{}\n", .{ctx.link_msg.toSliceConst()});
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

fn linkDiagCallback(context: *c_void, ptr: [*]const u8, len: usize) callconv(.C) void {
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
        .unknown => .ZigLLVM_UnknownObjectFormat,
        .coff => .ZigLLVM_COFF,
        .elf => .ZigLLVM_ELF,
        .macho => .ZigLLVM_MachO,
        .wasm => .ZigLLVM_Wasm,
    };
}

fn constructLinkerArgs(ctx: *Context) !void {
    switch (ctx.comp.target.getObjectFormat()) {
        .unknown => unreachable,
        .coff => return constructLinkerArgsCoff(ctx),
        .elf => return constructLinkerArgsElf(ctx),
        .macho => return constructLinkerArgsMachO(ctx),
        .wasm => return constructLinkerArgsWasm(ctx),
    }
}

fn constructLinkerArgsElf(ctx: *Context) !void {
    // TODO commented out code in this function
    //if (g->linker_script) {
    //    lj->args.append("-T");
    //    lj->args.append(g->linker_script);
    //}
    try ctx.args.append("--gc-sections");
    if (ctx.comp.link_eh_frame_hdr) {
        try ctx.args.append("--eh-frame-hdr");
    }

    //lj->args.append("-m");
    //lj->args.append(getLDMOption(&g->zig_target));

    //bool is_lib = g->out_type == OutTypeLib;
    //bool shared = !g->is_static && is_lib;
    //Buf *soname = nullptr;
    if (ctx.comp.is_static) {
        if (util.isArmOrThumb(ctx.comp.target)) {
            try ctx.args.append("-Bstatic");
        } else {
            try ctx.args.append("-static");
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

    try ctx.args.append("-o");
    try ctx.args.append(ctx.out_file_path.toSliceConst());

    if (ctx.link_in_crt) {
        const crt1o = if (ctx.comp.is_static) "crt1.o" else "Scrt1.o";
        const crtbegino = if (ctx.comp.is_static) "crtbeginT.o" else "crtbegin.o";
        try addPathJoin(ctx, ctx.libc.lib_dir.?, crt1o);
        try addPathJoin(ctx, ctx.libc.lib_dir.?, "crti.o");
        try addPathJoin(ctx, ctx.libc.static_lib_dir.?, crtbegino);
    }

    if (ctx.comp.haveLibC()) {
        try ctx.args.append("-L");
        // TODO addNullByte should probably return [:0]u8
        try ctx.args.append(@ptrCast([*:0]const u8, (try std.cstr.addNullByte(&ctx.arena.allocator, ctx.libc.lib_dir.?)).ptr));

        try ctx.args.append("-L");
        try ctx.args.append(@ptrCast([*:0]const u8, (try std.cstr.addNullByte(&ctx.arena.allocator, ctx.libc.static_lib_dir.?)).ptr));

        if (!ctx.comp.is_static) {
            const dl = blk: {
                if (ctx.libc.dynamic_linker_path) |dl| break :blk dl;
                if (util.getDynamicLinkerPath(ctx.comp.target)) |dl| break :blk dl;
                return error.LibCMissingDynamicLinker;
            };
            try ctx.args.append("-dynamic-linker");
            try ctx.args.append(@ptrCast([*:0]const u8, (try std.cstr.addNullByte(&ctx.arena.allocator, dl)).ptr));
        }
    }

    //if (shared) {
    //    lj->args.append("-soname");
    //    lj->args.append(buf_ptr(soname));
    //}

    // .o files
    for (ctx.comp.link_objects) |link_object| {
        const link_obj_with_null = try std.cstr.addNullByte(&ctx.arena.allocator, link_object);
        try ctx.args.append(@ptrCast([*:0]const u8, link_obj_with_null.ptr));
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
            try ctx.args.append("--start-group");
            try ctx.args.append("-lgcc");
            try ctx.args.append("-lgcc_eh");
            try ctx.args.append("-lc");
            try ctx.args.append("-lm");
            try ctx.args.append("--end-group");
        } else {
            try ctx.args.append("-lgcc");
            try ctx.args.append("--as-needed");
            try ctx.args.append("-lgcc_s");
            try ctx.args.append("--no-as-needed");
            try ctx.args.append("-lc");
            try ctx.args.append("-lm");
            try ctx.args.append("-lgcc");
            try ctx.args.append("--as-needed");
            try ctx.args.append("-lgcc_s");
            try ctx.args.append("--no-as-needed");
        }
    }

    // crt end
    if (ctx.link_in_crt) {
        try addPathJoin(ctx, ctx.libc.static_lib_dir.?, "crtend.o");
        try addPathJoin(ctx, ctx.libc.lib_dir.?, "crtn.o");
    }

    if (ctx.comp.target != Target.Native) {
        try ctx.args.append("--allow-shlib-undefined");
    }
}

fn addPathJoin(ctx: *Context, dirname: []const u8, basename: []const u8) !void {
    const full_path = try std.fs.path.join(&ctx.arena.allocator, &[_][]const u8{ dirname, basename });
    const full_path_with_null = try std.cstr.addNullByte(&ctx.arena.allocator, full_path);
    try ctx.args.append(@ptrCast([*:0]const u8, full_path_with_null.ptr));
}

fn constructLinkerArgsCoff(ctx: *Context) !void {
    try ctx.args.append("-NOLOGO");

    if (!ctx.comp.strip) {
        try ctx.args.append("-DEBUG");
    }

    switch (ctx.comp.target.getArch()) {
        .i386 => try ctx.args.append("-MACHINE:X86"),
        .x86_64 => try ctx.args.append("-MACHINE:X64"),
        .aarch64 => try ctx.args.append("-MACHINE:ARM"),
        else => return error.UnsupportedLinkArchitecture,
    }

    const is_library = ctx.comp.kind == .Lib;

    const out_arg = try std.fmt.allocPrint(&ctx.arena.allocator, "-OUT:{}\x00", .{ctx.out_file_path.toSliceConst()});
    try ctx.args.append(@ptrCast([*:0]const u8, out_arg.ptr));

    if (ctx.comp.haveLibC()) {
        try ctx.args.append(@ptrCast([*:0]const u8, (try std.fmt.allocPrint(&ctx.arena.allocator, "-LIBPATH:{}\x00", .{ctx.libc.msvc_lib_dir.?})).ptr));
        try ctx.args.append(@ptrCast([*:0]const u8, (try std.fmt.allocPrint(&ctx.arena.allocator, "-LIBPATH:{}\x00", .{ctx.libc.kernel32_lib_dir.?})).ptr));
        try ctx.args.append(@ptrCast([*:0]const u8, (try std.fmt.allocPrint(&ctx.arena.allocator, "-LIBPATH:{}\x00", .{ctx.libc.lib_dir.?})).ptr));
    }

    if (ctx.link_in_crt) {
        const lib_str = if (ctx.comp.is_static) "lib" else "";
        const d_str = if (ctx.comp.build_mode == .Debug) "d" else "";

        if (ctx.comp.is_static) {
            const cmt_lib_name = try std.fmt.allocPrint(&ctx.arena.allocator, "libcmt{}.lib\x00", .{d_str});
            try ctx.args.append(@ptrCast([*:0]const u8, cmt_lib_name.ptr));
        } else {
            const msvcrt_lib_name = try std.fmt.allocPrint(&ctx.arena.allocator, "msvcrt{}.lib\x00", .{d_str});
            try ctx.args.append(@ptrCast([*:0]const u8, msvcrt_lib_name.ptr));
        }

        const vcruntime_lib_name = try std.fmt.allocPrint(&ctx.arena.allocator, "{}vcruntime{}.lib\x00", .{
            lib_str,
            d_str,
        });
        try ctx.args.append(@ptrCast([*:0]const u8, vcruntime_lib_name.ptr));

        const crt_lib_name = try std.fmt.allocPrint(&ctx.arena.allocator, "{}ucrt{}.lib\x00", .{ lib_str, d_str });
        try ctx.args.append(@ptrCast([*:0]const u8, crt_lib_name.ptr));

        // Visual C++ 2015 Conformance Changes
        // https://msdn.microsoft.com/en-us/library/bb531344.aspx
        try ctx.args.append("legacy_stdio_definitions.lib");

        // msvcrt depends on kernel32
        try ctx.args.append("kernel32.lib");
    } else {
        try ctx.args.append("-NODEFAULTLIB");
        if (!is_library) {
            try ctx.args.append("-ENTRY:WinMainCRTStartup");
        }
    }

    if (is_library and !ctx.comp.is_static) {
        try ctx.args.append("-DLL");
    }

    for (ctx.comp.link_objects) |link_object| {
        const link_obj_with_null = try std.cstr.addNullByte(&ctx.arena.allocator, link_object);
        try ctx.args.append(@ptrCast([*:0]const u8, link_obj_with_null.ptr));
    }
    try addFnObjects(ctx);

    switch (ctx.comp.kind) {
        .Exe, .Lib => {
            if (!ctx.comp.haveLibC()) {
                @panic("TODO");
            }
        },
        .Obj => {},
    }
}

fn constructLinkerArgsMachO(ctx: *Context) !void {
    try ctx.args.append("-demangle");

    if (ctx.comp.linker_rdynamic) {
        try ctx.args.append("-export_dynamic");
    }

    const is_lib = ctx.comp.kind == .Lib;
    const shared = !ctx.comp.is_static and is_lib;
    if (ctx.comp.is_static) {
        try ctx.args.append("-static");
    } else {
        try ctx.args.append("-dynamic");
    }

    try ctx.args.append("-arch");
    try ctx.args.append(util.getDarwinArchString(ctx.comp.target));

    const platform = try DarwinPlatform.get(ctx.comp);
    switch (platform.kind) {
        .MacOS => try ctx.args.append("-macosx_version_min"),
        .IPhoneOS => try ctx.args.append("-iphoneos_version_min"),
        .IPhoneOSSimulator => try ctx.args.append("-ios_simulator_version_min"),
    }
    const ver_str = try std.fmt.allocPrint(&ctx.arena.allocator, "{}.{}.{}\x00", .{
        platform.major,
        platform.minor,
        platform.micro,
    });
    try ctx.args.append(@ptrCast([*:0]const u8, ver_str.ptr));

    if (ctx.comp.kind == .Exe) {
        if (ctx.comp.is_static) {
            try ctx.args.append("-no_pie");
        } else {
            try ctx.args.append("-pie");
        }
    }

    try ctx.args.append("-o");
    try ctx.args.append(ctx.out_file_path.toSliceConst());

    if (shared) {
        try ctx.args.append("-headerpad_max_install_names");
    } else if (ctx.comp.is_static) {
        try ctx.args.append("-lcrt0.o");
    } else {
        switch (platform.kind) {
            .MacOS => {
                if (platform.versionLessThan(10, 5)) {
                    try ctx.args.append("-lcrt1.o");
                } else if (platform.versionLessThan(10, 6)) {
                    try ctx.args.append("-lcrt1.10.5.o");
                } else if (platform.versionLessThan(10, 8)) {
                    try ctx.args.append("-lcrt1.10.6.o");
                }
            },
            .IPhoneOS => {
                if (ctx.comp.target.getArch() == .aarch64) {
                    // iOS does not need any crt1 files for arm64
                } else if (platform.versionLessThan(3, 1)) {
                    try ctx.args.append("-lcrt1.o");
                } else if (platform.versionLessThan(6, 0)) {
                    try ctx.args.append("-lcrt1.3.1.o");
                }
            },
            .IPhoneOSSimulator => {}, // no crt1.o needed
        }
    }

    for (ctx.comp.link_objects) |link_object| {
        const link_obj_with_null = try std.cstr.addNullByte(&ctx.arena.allocator, link_object);
        try ctx.args.append(@ptrCast([*:0]const u8, link_obj_with_null.ptr));
    }
    try addFnObjects(ctx);

    if (ctx.comp.target == Target.Native) {
        for (ctx.comp.link_libs_list.toSliceConst()) |lib| {
            if (mem.eql(u8, lib.name, "c")) {
                // on Darwin, libSystem has libc in it, but also you have to use it
                // to make syscalls because the syscall numbers are not documented
                // and change between versions.
                // so we always link against libSystem
                try ctx.args.append("-lSystem");
            } else {
                if (mem.indexOfScalar(u8, lib.name, '/') == null) {
                    const arg = try std.fmt.allocPrint(&ctx.arena.allocator, "-l{}\x00", .{lib.name});
                    try ctx.args.append(@ptrCast([*:0]const u8, arg.ptr));
                } else {
                    const arg = try std.cstr.addNullByte(&ctx.arena.allocator, lib.name);
                    try ctx.args.append(@ptrCast([*:0]const u8, arg.ptr));
                }
            }
        }
    } else {
        try ctx.args.append("-undefined");
        try ctx.args.append("dynamic_lookup");
    }

    if (platform.kind == .MacOS) {
        if (platform.versionLessThan(10, 5)) {
            try ctx.args.append("-lgcc_s.10.4");
        } else if (platform.versionLessThan(10, 6)) {
            try ctx.args.append("-lgcc_s.10.5");
        }
    } else {
        @panic("TODO");
    }
}

fn constructLinkerArgsWasm(ctx: *Context) void {
    @panic("TODO");
}

fn addFnObjects(ctx: *Context) !void {
    const held = ctx.comp.fn_link_set.acquire();
    defer held.release();

    var it = held.value.first;
    while (it) |node| {
        const fn_val = node.data orelse {
            // handle the tombstone. See Value.Fn.destroy.
            it = node.next;
            held.value.remove(node);
            ctx.comp.gpa().destroy(node);
            continue;
        };
        try ctx.args.append(fn_val.containing_object.toSliceConst());
        it = node.next;
    }
}

const DarwinPlatform = struct {
    kind: Kind,
    major: u32,
    minor: u32,
    micro: u32,

    const Kind = enum {
        MacOS,
        IPhoneOS,
        IPhoneOSSimulator,
    };

    fn get(comp: *Compilation) !DarwinPlatform {
        var result: DarwinPlatform = undefined;
        const ver_str = switch (comp.darwin_version_min) {
            .MacOS => |ver| blk: {
                result.kind = .MacOS;
                break :blk ver;
            },
            .Ios => |ver| blk: {
                result.kind = .IPhoneOS;
                break :blk ver;
            },
            .None => blk: {
                assert(comp.target.os.tag == .macosx);
                result.kind = .MacOS;
                break :blk "10.14";
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

        if (result.kind == .IPhoneOS) {
            switch (comp.target.cpu.arch) {
                .i386,
                .x86_64,
                => result.kind = .IPhoneOSSimulator,
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
    for ([_]*u32{ major, minor, micro }) |v| {
        const dot_pos = mem.indexOfScalarPos(u8, str, start_pos, '.');
        const end_pos = dot_pos orelse str.len;
        v.* = std.fmt.parseUnsigned(u32, str[start_pos..end_pos], 10) catch return error.InvalidDarwinVersionString;
        start_pos = (dot_pos orelse return) + 1;
        if (start_pos == str.len) return;
    }
    had_extra.* = true;
}
