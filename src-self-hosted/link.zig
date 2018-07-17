const std = @import("std");
const c = @import("c.zig");
const builtin = @import("builtin");
const ObjectFormat = builtin.ObjectFormat;
const Compilation = @import("compilation.zig").Compilation;

const Context = struct {
    comp: *Compilation,
    arena: std.heap.ArenaAllocator,
    args: std.ArrayList([*]const u8),
    link_in_crt: bool,

    link_err: error{OutOfMemory}!void,
    link_msg: std.Buffer,
};

pub fn link(comp: *Compilation) !void {
    var ctx = Context{
        .comp = comp,
        .arena = std.heap.ArenaAllocator.init(comp.gpa()),
        .args = undefined,
        .link_in_crt = comp.haveLibC() and comp.kind == Compilation.Kind.Exe,
        .link_err = {},
        .link_msg = undefined,
    };
    defer ctx.arena.deinit();
    ctx.args = std.ArrayList([*]const u8).init(&ctx.arena.allocator);
    ctx.link_msg = std.Buffer.initNull(&ctx.arena.allocator);

    // even though we're calling LLD as a library it thinks the first
    // argument is its own exe name
    try ctx.args.append(c"lld");

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
    //if (g->libc_link_lib != nullptr) {
    //    find_libc_lib_path(g);
    //}

    //if (g->linker_script) {
    //    lj->args.append("-T");
    //    lj->args.append(g->linker_script);
    //}

    //if (g->no_rosegment_workaround) {
    //    lj->args.append("--no-rosegment");
    //}
    //lj->args.append("--gc-sections");

    //lj->args.append("-m");
    //lj->args.append(getLDMOption(&g->zig_target));

    //bool is_lib = g->out_type == OutTypeLib;
    //bool shared = !g->is_static && is_lib;
    //Buf *soname = nullptr;
    //if (g->is_static) {
    //    if (g->zig_target.arch.arch == ZigLLVM_arm || g->zig_target.arch.arch == ZigLLVM_armeb ||
    //        g->zig_target.arch.arch == ZigLLVM_thumb || g->zig_target.arch.arch == ZigLLVM_thumbeb)
    //    {
    //        lj->args.append("-Bstatic");
    //    } else {
    //        lj->args.append("-static");
    //    }
    //} else if (shared) {
    //    lj->args.append("-shared");

    //    if (buf_len(&lj->out_file) == 0) {
    //        buf_appendf(&lj->out_file, "lib%s.so.%" ZIG_PRI_usize ".%" ZIG_PRI_usize ".%" ZIG_PRI_usize "",
    //                buf_ptr(g->root_out_name), g->version_major, g->version_minor, g->version_patch);
    //    }
    //    soname = buf_sprintf("lib%s.so.%" ZIG_PRI_usize "", buf_ptr(g->root_out_name), g->version_major);
    //}

    //lj->args.append("-o");
    //lj->args.append(buf_ptr(&lj->out_file));

    //if (lj->link_in_crt) {
    //    const char *crt1o;
    //    const char *crtbegino;
    //    if (g->is_static) {
    //        crt1o = "crt1.o";
    //        crtbegino = "crtbeginT.o";
    //    } else {
    //        crt1o = "Scrt1.o";
    //        crtbegino = "crtbegin.o";
    //    }
    //    lj->args.append(get_libc_file(g, crt1o));
    //    lj->args.append(get_libc_file(g, "crti.o"));
    //    lj->args.append(get_libc_static_file(g, crtbegino));
    //}

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

    //if (g->libc_link_lib != nullptr) {
    //    lj->args.append("-L");
    //    lj->args.append(buf_ptr(g->libc_lib_dir));

    //    lj->args.append("-L");
    //    lj->args.append(buf_ptr(g->libc_static_lib_dir));
    //}

    //if (!g->is_static) {
    //    if (g->dynamic_linker != nullptr) {
    //        assert(buf_len(g->dynamic_linker) != 0);
    //        lj->args.append("-dynamic-linker");
    //        lj->args.append(buf_ptr(g->dynamic_linker));
    //    } else {
    //        Buf *resolved_dynamic_linker = get_dynamic_linker_path(g);
    //        lj->args.append("-dynamic-linker");
    //        lj->args.append(buf_ptr(resolved_dynamic_linker));
    //    }
    //}

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

    //// libc dep
    //if (g->libc_link_lib != nullptr) {
    //    if (g->is_static) {
    //        lj->args.append("--start-group");
    //        lj->args.append("-lgcc");
    //        lj->args.append("-lgcc_eh");
    //        lj->args.append("-lc");
    //        lj->args.append("-lm");
    //        lj->args.append("--end-group");
    //    } else {
    //        lj->args.append("-lgcc");
    //        lj->args.append("--as-needed");
    //        lj->args.append("-lgcc_s");
    //        lj->args.append("--no-as-needed");
    //        lj->args.append("-lc");
    //        lj->args.append("-lm");
    //        lj->args.append("-lgcc");
    //        lj->args.append("--as-needed");
    //        lj->args.append("-lgcc_s");
    //        lj->args.append("--no-as-needed");
    //    }
    //}

    //// crt end
    //if (lj->link_in_crt) {
    //    lj->args.append(get_libc_static_file(g, "crtend.o"));
    //    lj->args.append(get_libc_file(g, "crtn.o"));
    //}

    //if (!g->is_native_target) {
    //    lj->args.append("--allow-shlib-undefined");
    //}

    //if (g->zig_target.os == OsZen) {
    //    lj->args.append("-e");
    //    lj->args.append("_start");

    //    lj->args.append("--image-base=0x10000000");
    //}
}

fn constructLinkerArgsCoff(ctx: *Context) void {
    @panic("TODO");
}

fn constructLinkerArgsMachO(ctx: *Context) void {
    @panic("TODO");
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
