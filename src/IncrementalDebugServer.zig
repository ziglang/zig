//! This is a simple TCP server which exposes a REPL useful for debugging incremental compilation
//! issues. Eventually, this logic should move into `std.zig.Client`/`std.zig.Server` or something
//! similar, but for now, this works. The server is enabled by the '--debug-incremental' CLI flag.
//! The easiest way to interact with the REPL is to use `telnet`:
//! ```
//! telnet "::1" 7623
//! ```
//! 'help' will list available commands. When the debug server is enabled, the compiler tracks a lot
//! of extra state (see `Zcu.IncrementalDebugState`), so note that RSS will be higher than usual.

comptime {
    // This file should only be referenced when debug extensions are enabled.
    std.debug.assert(@import("build_options").enable_debug_extensions and !@import("builtin").single_threaded);
}

zcu: *Zcu,
thread: ?std.Thread,
running: std.atomic.Value(bool),
/// Held by our owner when an update is in-progress, and held by us when responding to a command.
/// So, essentially guards all access to `Compilation`, including `Zcu`.
mutex: std.Thread.Mutex,

pub fn init(zcu: *Zcu) IncrementalDebugServer {
    return .{
        .zcu = zcu,
        .thread = null,
        .running = .init(true),
        .mutex = .{},
    };
}

pub fn deinit(ids: *IncrementalDebugServer) void {
    if (ids.thread) |t| {
        ids.running.store(false, .monotonic);
        t.join();
    }
}

const port = 7623;
pub fn spawn(ids: *IncrementalDebugServer) void {
    std.debug.print("spawning incremental debug server on port {d}\n", .{port});
    ids.thread = std.Thread.spawn(.{ .allocator = ids.zcu.comp.arena }, runThread, .{ids}) catch |err|
        std.process.fatal("failed to spawn incremental debug server: {s}", .{@errorName(err)});
}
fn runThread(ids: *IncrementalDebugServer) void {
    const gpa = ids.zcu.gpa;

    var cmd_buf: [1024]u8 = undefined;
    var text_out: std.ArrayListUnmanaged(u8) = .empty;
    defer text_out.deinit(gpa);

    const addr = std.net.Address.parseIp6("::", port) catch unreachable;
    var server = addr.listen(.{}) catch @panic("IncrementalDebugServer: failed to listen");
    defer server.deinit();
    const conn = server.accept() catch @panic("IncrementalDebugServer: failed to accept");
    defer conn.stream.close();

    while (ids.running.load(.monotonic)) {
        conn.stream.writeAll("zig> ") catch @panic("IncrementalDebugServer: failed to write");
        var fbs = std.io.fixedBufferStream(&cmd_buf);
        conn.stream.reader().streamUntilDelimiter(fbs.writer(), '\n', cmd_buf.len) catch |err| switch (err) {
            error.EndOfStream => break,
            else => @panic("IncrementalDebugServer: failed to read command"),
        };
        const cmd_and_arg = std.mem.trim(u8, fbs.getWritten(), " \t\r\n");
        const cmd: []const u8, const arg: []const u8 = if (std.mem.indexOfScalar(u8, cmd_and_arg, ' ')) |i|
            .{ cmd_and_arg[0..i], cmd_and_arg[i + 1 ..] }
        else
            .{ cmd_and_arg, "" };

        text_out.clearRetainingCapacity();
        {
            if (!ids.mutex.tryLock()) {
                conn.stream.writeAll("waiting for in-progress update to finish...\n") catch @panic("IncrementalDebugServer: failed to write");
                ids.mutex.lock();
            }
            defer ids.mutex.unlock();
            handleCommand(ids.zcu, &text_out, cmd, arg) catch @panic("IncrementalDebugServer: out of memory");
        }
        text_out.append(gpa, '\n') catch @panic("IncrementalDebugServer: out of memory");
        conn.stream.writeAll(text_out.items) catch @panic("IncrementalDebugServer: failed to write");
    }
    std.debug.print("closing incremental debug server\n", .{});
}

const help_str: []const u8 =
    \\[str] arguments are any string.
    \\[id] arguments are a numeric ID/index, like an InternPool index.
    \\[unit] arguments are strings like 'func 1234' where '1234' is the relevant index (in this case an InternPool index).
    \\
    \\MISC
    \\  summary
    \\    Dump some information about the whole ZCU.
    \\  nav_info [id]
    \\    Dump basic info about a NAV.
    \\
    \\SEARCHING
    \\  find_type [str]
    \\    Find types (including dead ones) whose names contain the given substring.
    \\    Starting with '^' or ending with '$' anchors to the start/end of the name.
    \\  find_nav [str]
    \\    Find NAVs (including dead ones) whose names contain the given substring.
    \\    Starting with '^' or ending with '$' anchors to the start/end of the name.
    \\
    \\UNITS
    \\  unit_info [unit]
    \\    Dump basic info about an analysis unit.
    \\  unit_dependencies [unit]
    \\    List all units which an analysis unit depends on.
    \\  unit_trace [unit]
    \\    Dump the current reference trace of an analysis unit.
    \\
    \\TYPES
    \\  type_info [id]
    \\    Dump basic info about a type.
    \\  type_namespace [id]
    \\    List all declarations in the namespace of a type.
    \\
;

fn handleCommand(zcu: *Zcu, output: *std.ArrayListUnmanaged(u8), cmd_str: []const u8, arg_str: []const u8) Allocator.Error!void {
    const ip = &zcu.intern_pool;
    const gpa = zcu.gpa;
    const w = output.writer(gpa);
    if (std.mem.eql(u8, cmd_str, "help")) {
        try w.writeAll(help_str);
    } else if (std.mem.eql(u8, cmd_str, "summary")) {
        try w.print(
            \\last generation: {d}
            \\total container types: {d}
            \\total NAVs: {d}
            \\total units: {d}
            \\
        , .{
            zcu.generation - 1,
            zcu.incremental_debug_state.types.count(),
            zcu.incremental_debug_state.navs.count(),
            zcu.incremental_debug_state.units.count(),
        });
    } else if (std.mem.eql(u8, cmd_str, "nav_info")) {
        const nav_index: InternPool.Nav.Index = @enumFromInt(parseIndex(arg_str) orelse return w.writeAll("malformed nav index"));
        const create_gen = zcu.incremental_debug_state.navs.get(nav_index) orelse return w.writeAll("unknown nav index");
        const nav = ip.getNav(nav_index);
        try w.print(
            \\name: '{}'
            \\fqn: '{}'
            \\status: {s}
            \\created on generation: {d}
            \\
        , .{
            nav.name.fmt(ip),
            nav.fqn.fmt(ip),
            @tagName(nav.status),
            create_gen,
        });
        switch (nav.status) {
            .unresolved => {},
            .type_resolved, .fully_resolved => {
                try w.writeAll("type: ");
                try printType(.fromInterned(nav.typeOf(ip)), zcu, w);
                try w.writeByte('\n');
            },
        }
    } else if (std.mem.eql(u8, cmd_str, "find_type")) {
        if (arg_str.len == 0) return w.writeAll("bad usage");
        const anchor_start = arg_str[0] == '^';
        const anchor_end = arg_str[arg_str.len - 1] == '$';
        const query = arg_str[@intFromBool(anchor_start) .. arg_str.len - @intFromBool(anchor_end)];
        var num_results: usize = 0;
        for (zcu.incremental_debug_state.types.keys()) |type_ip_index| {
            const ty: Type = .fromInterned(type_ip_index);
            const ty_name = ty.containerTypeName(ip).toSlice(ip);
            const success = switch (@as(u2, @intFromBool(anchor_start)) << 1 | @intFromBool(anchor_end)) {
                0b00 => std.mem.indexOf(u8, ty_name, query) != null,
                0b01 => std.mem.endsWith(u8, ty_name, query),
                0b10 => std.mem.startsWith(u8, ty_name, query),
                0b11 => std.mem.eql(u8, ty_name, query),
            };
            if (success) {
                num_results += 1;
                try w.print("* type {d} ('{s}')\n", .{ @intFromEnum(type_ip_index), ty_name });
            }
        }
        try w.print("Found {d} results\n", .{num_results});
    } else if (std.mem.eql(u8, cmd_str, "find_nav")) {
        if (arg_str.len == 0) return w.writeAll("bad usage");
        const anchor_start = arg_str[0] == '^';
        const anchor_end = arg_str[arg_str.len - 1] == '$';
        const query = arg_str[@intFromBool(anchor_start) .. arg_str.len - @intFromBool(anchor_end)];
        var num_results: usize = 0;
        for (zcu.incremental_debug_state.navs.keys()) |nav_index| {
            const nav = ip.getNav(nav_index);
            const nav_fqn = nav.fqn.toSlice(ip);
            const success = switch (@as(u2, @intFromBool(anchor_start)) << 1 | @intFromBool(anchor_end)) {
                0b00 => std.mem.indexOf(u8, nav_fqn, query) != null,
                0b01 => std.mem.endsWith(u8, nav_fqn, query),
                0b10 => std.mem.startsWith(u8, nav_fqn, query),
                0b11 => std.mem.eql(u8, nav_fqn, query),
            };
            if (success) {
                num_results += 1;
                try w.print("* nav {d} ('{s}')\n", .{ @intFromEnum(nav_index), nav_fqn });
            }
        }
        try w.print("Found {d} results\n", .{num_results});
    } else if (std.mem.eql(u8, cmd_str, "unit_info")) {
        const unit = parseAnalUnit(arg_str) orelse return w.writeAll("malformed anal unit");
        const unit_info = zcu.incremental_debug_state.units.get(unit) orelse return w.writeAll("unknown anal unit");
        var ref_str_buf: [32]u8 = undefined;
        const ref_str: []const u8 = ref: {
            const refs = try zcu.resolveReferences();
            const ref = refs.get(unit) orelse break :ref "<unreferenced>";
            const referencer = (ref orelse break :ref "<analysis root>").referencer;
            break :ref printAnalUnit(referencer, &ref_str_buf);
        };
        const has_err: []const u8 = err: {
            if (zcu.failed_analysis.contains(unit)) break :err "true";
            if (zcu.transitive_failed_analysis.contains(unit)) break :err "true (transitive)";
            break :err "false";
        };
        try w.print(
            \\last update generation: {d}
            \\current referencer: {s}
            \\has error: {s}
            \\
        , .{
            unit_info.last_update_gen,
            ref_str,
            has_err,
        });
    } else if (std.mem.eql(u8, cmd_str, "unit_dependencies")) {
        const unit = parseAnalUnit(arg_str) orelse return w.writeAll("malformed anal unit");
        const unit_info = zcu.incremental_debug_state.units.get(unit) orelse return w.writeAll("unknown anal unit");
        for (unit_info.deps.items, 0..) |dependee, i| {
            try w.print("[{d}] ", .{i});
            switch (dependee) {
                .src_hash, .namespace, .namespace_name, .zon_file, .embed_file => try w.print("{}", .{zcu.fmtDependee(dependee)}),
                .nav_val, .nav_ty => |nav| try w.print("{s} {d}", .{ @tagName(dependee), @intFromEnum(nav) }),
                .interned => |ip_index| switch (ip.indexToKey(ip_index)) {
                    .struct_type, .union_type, .enum_type => try w.print("type {d}", .{@intFromEnum(ip_index)}),
                    .func => try w.print("func {d}", .{@intFromEnum(ip_index)}),
                    else => unreachable,
                },
                .memoized_state => |stage| try w.print("memoized_state {s}", .{@tagName(stage)}),
            }
            try w.writeByte('\n');
        }
    } else if (std.mem.eql(u8, cmd_str, "unit_trace")) {
        const unit = parseAnalUnit(arg_str) orelse return w.writeAll("malformed anal unit");
        if (!zcu.incremental_debug_state.units.contains(unit)) return w.writeAll("unknown anal unit");
        const refs = try zcu.resolveReferences();
        if (!refs.contains(unit)) return w.writeAll("not referenced");
        var opt_cur: ?AnalUnit = unit;
        while (opt_cur) |cur| {
            var buf: [32]u8 = undefined;
            try w.print("* {s}\n", .{printAnalUnit(cur, &buf)});
            opt_cur = if (refs.get(cur).?) |ref| ref.referencer else null;
        }
    } else if (std.mem.eql(u8, cmd_str, "type_info")) {
        const ip_index: InternPool.Index = @enumFromInt(parseIndex(arg_str) orelse return w.writeAll("malformed ip index"));
        const create_gen = zcu.incremental_debug_state.types.get(ip_index) orelse return w.writeAll("unknown type");
        try w.print(
            \\name: '{}'
            \\created on generation: {d}
            \\
        , .{
            Type.fromInterned(ip_index).containerTypeName(ip).fmt(ip),
            create_gen,
        });
    } else if (std.mem.eql(u8, cmd_str, "type_namespace")) {
        const ip_index: InternPool.Index = @enumFromInt(parseIndex(arg_str) orelse return w.writeAll("malformed ip index"));
        if (!zcu.incremental_debug_state.types.contains(ip_index)) return w.writeAll("unknown type");
        const ns = zcu.namespacePtr(Type.fromInterned(ip_index).getNamespaceIndex(zcu));
        try w.print("{d} pub decls:\n", .{ns.pub_decls.count()});
        for (ns.pub_decls.keys()) |nav| {
            try w.print("* nav {d}\n", .{@intFromEnum(nav)});
        }
        try w.print("{d} non-pub decls:\n", .{ns.priv_decls.count()});
        for (ns.priv_decls.keys()) |nav| {
            try w.print("* nav {d}\n", .{@intFromEnum(nav)});
        }
        try w.print("{d} comptime decls:\n", .{ns.comptime_decls.items.len});
        for (ns.comptime_decls.items) |id| {
            try w.print("* comptime {d}\n", .{@intFromEnum(id)});
        }
        try w.print("{d} tests:\n", .{ns.test_decls.items.len});
        for (ns.test_decls.items) |nav| {
            try w.print("* nav {d}\n", .{@intFromEnum(nav)});
        }
    } else {
        try w.writeAll("command not found; run 'help' for a command list");
    }
}

fn parseIndex(str: []const u8) ?u32 {
    return std.fmt.parseInt(u32, str, 10) catch null;
}
fn parseAnalUnit(str: []const u8) ?AnalUnit {
    const split_idx = std.mem.indexOfScalar(u8, str, ' ') orelse return null;
    const kind = str[0..split_idx];
    const idx_str = str[split_idx + 1 ..];
    if (std.mem.eql(u8, kind, "comptime")) {
        return .wrap(.{ .@"comptime" = @enumFromInt(parseIndex(idx_str) orelse return null) });
    } else if (std.mem.eql(u8, kind, "nav_val")) {
        return .wrap(.{ .nav_val = @enumFromInt(parseIndex(idx_str) orelse return null) });
    } else if (std.mem.eql(u8, kind, "nav_ty")) {
        return .wrap(.{ .nav_ty = @enumFromInt(parseIndex(idx_str) orelse return null) });
    } else if (std.mem.eql(u8, kind, "type")) {
        return .wrap(.{ .type = @enumFromInt(parseIndex(idx_str) orelse return null) });
    } else if (std.mem.eql(u8, kind, "func")) {
        return .wrap(.{ .func = @enumFromInt(parseIndex(idx_str) orelse return null) });
    } else if (std.mem.eql(u8, kind, "memoized_state")) {
        return .wrap(.{ .memoized_state = std.meta.stringToEnum(
            InternPool.MemoizedStateStage,
            idx_str,
        ) orelse return null });
    } else {
        return null;
    }
}
fn printAnalUnit(unit: AnalUnit, buf: *[32]u8) []const u8 {
    const idx: u32 = switch (unit.unwrap()) {
        .memoized_state => |stage| return std.fmt.bufPrint(buf, "memoized_state {s}", .{@tagName(stage)}) catch unreachable,
        inline else => |i| @intFromEnum(i),
    };
    return std.fmt.bufPrint(buf, "{s} {d}", .{ @tagName(unit.unwrap()), idx }) catch unreachable;
}
fn printType(ty: Type, zcu: *const Zcu, w: anytype) !void {
    const ip = &zcu.intern_pool;
    switch (ip.indexToKey(ty.toIntern())) {
        .int_type => |int| try w.print("{c}{d}", .{
            @as(u8, if (int.signedness == .unsigned) 'u' else 'i'),
            int.bits,
        }),
        .tuple_type => try w.writeAll("(tuple)"),
        .error_set_type => try w.writeAll("(error set)"),
        .inferred_error_set_type => try w.writeAll("(inferred error set)"),
        .func_type => try w.writeAll("(function)"),
        .anyframe_type => try w.writeAll("(anyframe)"),
        .vector_type => {
            try w.print("@Vector({d}, ", .{ty.vectorLen(zcu)});
            try printType(ty.childType(zcu), zcu, w);
            try w.writeByte(')');
        },
        .array_type => {
            try w.print("[{d}]", .{ty.arrayLen(zcu)});
            try printType(ty.childType(zcu), zcu, w);
        },
        .opt_type => {
            try w.writeByte('?');
            try printType(ty.optionalChild(zcu), zcu, w);
        },
        .error_union_type => {
            try printType(ty.errorUnionSet(zcu), zcu, w);
            try w.writeByte('!');
            try printType(ty.errorUnionPayload(zcu), zcu, w);
        },
        .ptr_type => {
            try w.writeAll("*(attrs) ");
            try printType(ty.childType(zcu), zcu, w);
        },
        .simple_type => |simple| try w.writeAll(@tagName(simple)),

        .struct_type,
        .union_type,
        .enum_type,
        .opaque_type,
        => try w.print("{}[{d}]", .{ ty.containerTypeName(ip).fmt(ip), @intFromEnum(ty.toIntern()) }),

        else => unreachable,
    }
}

const std = @import("std");
const Allocator = std.mem.Allocator;

const Compilation = @import("Compilation.zig");
const Zcu = @import("Zcu.zig");
const InternPool = @import("InternPool.zig");
const Type = @import("Type.zig");
const AnalUnit = InternPool.AnalUnit;

const IncrementalDebugServer = @This();
