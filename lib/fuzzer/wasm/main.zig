const std = @import("std");
const assert = std.debug.assert;
const abi = std.Build.Fuzz.abi;
const gpa = std.heap.wasm_allocator;
const log = std.log;
const Coverage = std.debug.Coverage;

const Walk = @import("Walk");
const Decl = Walk.Decl;
const html_render = @import("html_render");

const js = struct {
    extern "js" fn log(ptr: [*]const u8, len: usize) void;
    extern "js" fn panic(ptr: [*]const u8, len: usize) noreturn;
    extern "js" fn emitSourceIndexChange() void;
    extern "js" fn emitCoverageUpdate() void;
    extern "js" fn emitEntryPointsUpdate() void;
};

pub const std_options: std.Options = .{
    .logFn = logFn,
};

pub fn panic(msg: []const u8, st: ?*std.builtin.StackTrace, addr: ?usize) noreturn {
    _ = st;
    _ = addr;
    log.err("panic: {s}", .{msg});
    @trap();
}

fn logFn(
    comptime message_level: log.Level,
    comptime scope: @TypeOf(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const level_txt = comptime message_level.asText();
    const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";
    var buf: [500]u8 = undefined;
    const line = std.fmt.bufPrint(&buf, level_txt ++ prefix2 ++ format, args) catch l: {
        buf[buf.len - 3 ..][0..3].* = "...".*;
        break :l &buf;
    };
    js.log(line.ptr, line.len);
}

export fn alloc(n: usize) [*]u8 {
    const slice = gpa.alloc(u8, n) catch @panic("OOM");
    return slice.ptr;
}

var message_buffer: std.ArrayListAlignedUnmanaged(u8, @alignOf(u64)) = .{};

/// Resizes the message buffer to be the correct length; returns the pointer to
/// the query string.
export fn message_begin(len: usize) [*]u8 {
    message_buffer.resize(gpa, len) catch @panic("OOM");
    return message_buffer.items.ptr;
}

export fn message_end() void {
    const msg_bytes = message_buffer.items;

    const tag: abi.ToClientTag = @enumFromInt(msg_bytes[0]);
    switch (tag) {
        .source_index => return sourceIndexMessage(msg_bytes) catch @panic("OOM"),
        .coverage_update => return coverageUpdateMessage(msg_bytes) catch @panic("OOM"),
        .entry_points => return entryPointsMessage(msg_bytes) catch @panic("OOM"),
        _ => unreachable,
    }
}

export fn unpack(tar_ptr: [*]u8, tar_len: usize) void {
    const tar_bytes = tar_ptr[0..tar_len];
    log.debug("received {d} bytes of tar file", .{tar_bytes.len});

    unpackInner(tar_bytes) catch |err| {
        fatal("unable to unpack tar: {s}", .{@errorName(err)});
    };
}

/// Set by `set_input_string`.
var input_string: std.ArrayListUnmanaged(u8) = .{};
var string_result: std.ArrayListUnmanaged(u8) = .{};

export fn set_input_string(len: usize) [*]u8 {
    input_string.resize(gpa, len) catch @panic("OOM");
    return input_string.items.ptr;
}

/// Looks up the root struct decl corresponding to a file by path.
/// Uses `input_string`.
export fn find_file_root() Decl.Index {
    const file: Walk.File.Index = @enumFromInt(Walk.files.getIndex(input_string.items) orelse return .none);
    return file.findRootDecl();
}

export fn decl_source_html(decl_index: Decl.Index) String {
    const decl = decl_index.get();

    string_result.clearRetainingCapacity();
    html_render.fileSourceHtml(decl.file, &string_result, decl.ast_node, .{}) catch |err| {
        fatal("unable to render source: {s}", .{@errorName(err)});
    };
    return String.init(string_result.items);
}

export fn lowestStack() String {
    const header: *abi.CoverageUpdateHeader = @ptrCast(recent_coverage_update.items[0..@sizeOf(abi.CoverageUpdateHeader)]);
    string_result.clearRetainingCapacity();
    string_result.writer(gpa).print("0x{d}", .{header.lowest_stack}) catch @panic("OOM");
    return String.init(string_result.items);
}

export fn totalSourceLocations() usize {
    return coverage_source_locations.items.len;
}

export fn coveredSourceLocations() usize {
    const covered_bits = recent_coverage_update.items[@sizeOf(abi.CoverageUpdateHeader)..];
    var count: usize = 0;
    for (covered_bits) |byte| count += @popCount(byte);
    return count;
}

export fn totalRuns() u64 {
    const header: *abi.CoverageUpdateHeader = @ptrCast(recent_coverage_update.items[0..@sizeOf(abi.CoverageUpdateHeader)]);
    return header.n_runs;
}

export fn uniqueRuns() u64 {
    const header: *abi.CoverageUpdateHeader = @ptrCast(recent_coverage_update.items[0..@sizeOf(abi.CoverageUpdateHeader)]);
    return header.unique_runs;
}

const String = Slice(u8);

fn Slice(T: type) type {
    return packed struct(u64) {
        ptr: u32,
        len: u32,

        fn init(s: []const T) @This() {
            return .{
                .ptr = @intFromPtr(s.ptr),
                .len = s.len,
            };
        }
    };
}

fn unpackInner(tar_bytes: []u8) !void {
    var fbs = std.io.fixedBufferStream(tar_bytes);
    var file_name_buffer: [1024]u8 = undefined;
    var link_name_buffer: [1024]u8 = undefined;
    var it = std.tar.iterator(fbs.reader(), .{
        .file_name_buffer = &file_name_buffer,
        .link_name_buffer = &link_name_buffer,
    });
    while (try it.next()) |tar_file| {
        switch (tar_file.kind) {
            .file => {
                if (tar_file.size == 0 and tar_file.name.len == 0) break;
                if (std.mem.endsWith(u8, tar_file.name, ".zig")) {
                    log.debug("found file: '{s}'", .{tar_file.name});
                    const file_name = try gpa.dupe(u8, tar_file.name);
                    if (std.mem.indexOfScalar(u8, file_name, '/')) |pkg_name_end| {
                        const pkg_name = file_name[0..pkg_name_end];
                        const gop = try Walk.modules.getOrPut(gpa, pkg_name);
                        const file: Walk.File.Index = @enumFromInt(Walk.files.entries.len);
                        if (!gop.found_existing or
                            std.mem.eql(u8, file_name[pkg_name_end..], "/root.zig") or
                            std.mem.eql(u8, file_name[pkg_name_end + 1 .. file_name.len - ".zig".len], pkg_name))
                        {
                            gop.value_ptr.* = file;
                        }
                        const file_bytes = tar_bytes[fbs.pos..][0..@intCast(tar_file.size)];
                        assert(file == try Walk.add_file(file_name, file_bytes));
                    }
                } else {
                    log.warn("skipping: '{s}' - the tar creation should have done that", .{tar_file.name});
                }
            },
            else => continue,
        }
    }
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    var buf: [500]u8 = undefined;
    const line = std.fmt.bufPrint(&buf, format, args) catch l: {
        buf[buf.len - 3 ..][0..3].* = "...".*;
        break :l &buf;
    };
    js.panic(line.ptr, line.len);
}

fn sourceIndexMessage(msg_bytes: []u8) error{OutOfMemory}!void {
    const Header = abi.SourceIndexHeader;
    const header: Header = @bitCast(msg_bytes[0..@sizeOf(Header)].*);

    const directories_start = @sizeOf(Header);
    const directories_end = directories_start + header.directories_len * @sizeOf(Coverage.String);
    const files_start = directories_end;
    const files_end = files_start + header.files_len * @sizeOf(Coverage.File);
    const source_locations_start = files_end;
    const source_locations_end = source_locations_start + header.source_locations_len * @sizeOf(Coverage.SourceLocation);
    const string_bytes = msg_bytes[source_locations_end..][0..header.string_bytes_len];

    const directories: []const Coverage.String = @alignCast(std.mem.bytesAsSlice(Coverage.String, msg_bytes[directories_start..directories_end]));
    const files: []const Coverage.File = @alignCast(std.mem.bytesAsSlice(Coverage.File, msg_bytes[files_start..files_end]));
    const source_locations: []const Coverage.SourceLocation = @alignCast(std.mem.bytesAsSlice(Coverage.SourceLocation, msg_bytes[source_locations_start..source_locations_end]));

    try updateCoverage(directories, files, source_locations, string_bytes);
    js.emitSourceIndexChange();
}

fn coverageUpdateMessage(msg_bytes: []u8) error{OutOfMemory}!void {
    recent_coverage_update.clearRetainingCapacity();
    recent_coverage_update.appendSlice(gpa, msg_bytes) catch @panic("OOM");
    js.emitCoverageUpdate();
}

var entry_points: std.ArrayListUnmanaged(u32) = .{};

fn entryPointsMessage(msg_bytes: []u8) error{OutOfMemory}!void {
    const header: abi.EntryPointHeader = @bitCast(msg_bytes[0..@sizeOf(abi.EntryPointHeader)].*);
    entry_points.resize(gpa, header.flags.locs_len) catch @panic("OOM");
    @memcpy(entry_points.items, std.mem.bytesAsSlice(u32, msg_bytes[@sizeOf(abi.EntryPointHeader)..]));
    js.emitEntryPointsUpdate();
}

export fn entryPoints() Slice(u32) {
    return Slice(u32).init(entry_points.items);
}

var coverage = Coverage.init;
var coverage_source_locations: std.ArrayListUnmanaged(Coverage.SourceLocation) = .{};
/// Contains the most recent coverage update message, unmodified.
var recent_coverage_update: std.ArrayListUnmanaged(u8) = .{};

fn updateCoverage(
    directories: []const Coverage.String,
    files: []const Coverage.File,
    source_locations: []const Coverage.SourceLocation,
    string_bytes: []const u8,
) !void {
    coverage.directories.clearRetainingCapacity();
    coverage.files.clearRetainingCapacity();
    coverage.string_bytes.clearRetainingCapacity();
    coverage_source_locations.clearRetainingCapacity();

    try coverage_source_locations.appendSlice(gpa, source_locations);
    try coverage.string_bytes.appendSlice(gpa, string_bytes);

    try coverage.files.entries.resize(gpa, files.len);
    @memcpy(coverage.files.entries.items(.key), files);
    try coverage.files.reIndexContext(gpa, .{ .string_bytes = coverage.string_bytes.items });

    try coverage.directories.entries.resize(gpa, directories.len);
    @memcpy(coverage.directories.entries.items(.key), directories);
    try coverage.directories.reIndexContext(gpa, .{ .string_bytes = coverage.string_bytes.items });
}

export fn sourceLocationLinkHtml(index: u32) String {
    const sl = coverage_source_locations.items[index];
    const file_name = coverage.stringAt(coverage.fileAt(sl.file).basename);

    string_result.clearRetainingCapacity();
    string_result.writer(gpa).print("{s}:{d}:{d}", .{
        file_name, sl.line, sl.column,
    }) catch @panic("OOM");
    return String.init(string_result.items);
}
