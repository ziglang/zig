const std = @import("std");
const assert = std.debug.assert;
const abi = std.Build.Fuzz.abi;
const gpa = std.heap.wasm_allocator;
const log = std.log;
const Coverage = std.debug.Coverage;
const Allocator = std.mem.Allocator;

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
    const header: *abi.CoverageUpdateHeader = @alignCast(@ptrCast(recent_coverage_update.items[0..@sizeOf(abi.CoverageUpdateHeader)]));
    return header.n_runs;
}

export fn uniqueRuns() u64 {
    const header: *abi.CoverageUpdateHeader = @alignCast(@ptrCast(recent_coverage_update.items[0..@sizeOf(abi.CoverageUpdateHeader)]));
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

/// Index into `coverage_source_locations`.
const SourceLocationIndex = enum(u32) {
    _,

    fn haveCoverage(sli: SourceLocationIndex) bool {
        return @intFromEnum(sli) < coverage_source_locations.items.len;
    }

    fn ptr(sli: SourceLocationIndex) *Coverage.SourceLocation {
        return &coverage_source_locations.items[@intFromEnum(sli)];
    }

    fn sourceLocationLinkHtml(
        sli: SourceLocationIndex,
        out: *std.ArrayListUnmanaged(u8),
    ) Allocator.Error!void {
        const sl = sli.ptr();
        try out.writer(gpa).print("<a href=\"#l{d}\">", .{@intFromEnum(sli)});
        try sli.appendPath(out);
        try out.writer(gpa).print(":{d}:{d}</a>", .{ sl.line, sl.column });
    }

    fn appendPath(sli: SourceLocationIndex, out: *std.ArrayListUnmanaged(u8)) Allocator.Error!void {
        const sl = sli.ptr();
        const file = coverage.fileAt(sl.file);
        const file_name = coverage.stringAt(file.basename);
        const dir_name = coverage.stringAt(coverage.directories.keys()[file.directory_index]);
        try html_render.appendEscaped(out, dir_name);
        try out.appendSlice(gpa, "/");
        try html_render.appendEscaped(out, file_name);
    }

    fn toWalkFile(sli: SourceLocationIndex) ?Walk.File.Index {
        var buf: std.ArrayListUnmanaged(u8) = .{};
        defer buf.deinit(gpa);
        sli.appendPath(&buf) catch @panic("OOM");
        return @enumFromInt(Walk.files.getIndex(buf.items) orelse return null);
    }

    fn fileHtml(
        sli: SourceLocationIndex,
        out: *std.ArrayListUnmanaged(u8),
    ) error{ OutOfMemory, SourceUnavailable }!void {
        const walk_file_index = sli.toWalkFile() orelse return error.SourceUnavailable;
        const root_node = walk_file_index.findRootDecl().get().ast_node;
        var annotations: std.ArrayListUnmanaged(html_render.Annotation) = .{};
        defer annotations.deinit(gpa);
        try computeSourceAnnotations(sli.ptr().file, walk_file_index, &annotations, coverage_source_locations.items);
        html_render.fileSourceHtml(walk_file_index, out, root_node, .{
            .source_location_annotations = annotations.items,
        }) catch |err| {
            fatal("unable to render source: {s}", .{@errorName(err)});
        };
    }
};

fn computeSourceAnnotations(
    cov_file_index: Coverage.File.Index,
    walk_file_index: Walk.File.Index,
    annotations: *std.ArrayListUnmanaged(html_render.Annotation),
    source_locations: []const Coverage.SourceLocation,
) !void {
    // Collect all the source locations from only this file into this array
    // first, then sort by line, col, so that we can collect annotations with
    // O(N) time complexity.
    var locs: std.ArrayListUnmanaged(SourceLocationIndex) = .{};
    defer locs.deinit(gpa);

    for (source_locations, 0..) |sl, sli_usize| {
        if (sl.file != cov_file_index) continue;
        const sli: SourceLocationIndex = @enumFromInt(sli_usize);
        try locs.append(gpa, sli);
    }

    std.mem.sortUnstable(SourceLocationIndex, locs.items, {}, struct {
        pub fn lessThan(context: void, lhs: SourceLocationIndex, rhs: SourceLocationIndex) bool {
            _ = context;
            const lhs_ptr = lhs.ptr();
            const rhs_ptr = rhs.ptr();
            if (lhs_ptr.line < rhs_ptr.line) return true;
            if (lhs_ptr.line > rhs_ptr.line) return false;
            return lhs_ptr.column < rhs_ptr.column;
        }
    }.lessThan);

    const source = walk_file_index.get_ast().source;
    var line: usize = 1;
    var column: usize = 1;
    var next_loc_index: usize = 0;
    for (source, 0..) |byte, offset| {
        if (byte == '\n') {
            line += 1;
            column = 1;
        } else {
            column += 1;
        }
        while (true) {
            if (next_loc_index >= locs.items.len) return;
            const next_sli = locs.items[next_loc_index];
            const next_sl = next_sli.ptr();
            if (next_sl.line > line or (next_sl.line == line and next_sl.column >= column)) break;
            try annotations.append(gpa, .{
                .file_byte_offset = offset,
                .dom_id = @intFromEnum(next_sli),
            });
            next_loc_index += 1;
        }
    }
}

var coverage = Coverage.init;
/// Index of type `SourceLocationIndex`.
var coverage_source_locations: std.ArrayListUnmanaged(Coverage.SourceLocation) = .{};
/// Contains the most recent coverage update message, unmodified.
var recent_coverage_update: std.ArrayListAlignedUnmanaged(u8, @alignOf(u64)) = .{};

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

export fn sourceLocationLinkHtml(index: SourceLocationIndex) String {
    string_result.clearRetainingCapacity();
    index.sourceLocationLinkHtml(&string_result) catch @panic("OOM");
    return String.init(string_result.items);
}

/// Returns empty string if coverage metadata is not available for this source location.
export fn sourceLocationPath(sli: SourceLocationIndex) String {
    string_result.clearRetainingCapacity();
    if (sli.haveCoverage()) sli.appendPath(&string_result) catch @panic("OOM");
    return String.init(string_result.items);
}

export fn sourceLocationFileHtml(sli: SourceLocationIndex) String {
    string_result.clearRetainingCapacity();
    sli.fileHtml(&string_result) catch |err| switch (err) {
        error.OutOfMemory => @panic("OOM"),
        error.SourceUnavailable => {},
    };
    return String.init(string_result.items);
}

export fn sourceLocationFileCoveredList(sli_file: SourceLocationIndex) Slice(SourceLocationIndex) {
    const global = struct {
        var result: std.ArrayListUnmanaged(SourceLocationIndex) = .{};
        fn add(i: u32, want_file: Coverage.File.Index) void {
            const src_loc_index: SourceLocationIndex = @enumFromInt(i);
            if (src_loc_index.ptr().file == want_file) result.appendAssumeCapacity(src_loc_index);
        }
    };
    const want_file = sli_file.ptr().file;
    global.result.clearRetainingCapacity();

    // This code assumes 64-bit elements, which is incorrect if the executable
    // being fuzzed is not a 64-bit CPU. It also assumes little-endian which
    // can also be incorrect.
    comptime assert(abi.CoverageUpdateHeader.trailing[0] == .pc_bits_usize);
    const n_bitset_elems = (coverage_source_locations.items.len + @bitSizeOf(u64) - 1) / @bitSizeOf(u64);
    const covered_bits = std.mem.bytesAsSlice(
        u64,
        recent_coverage_update.items[@sizeOf(abi.CoverageUpdateHeader)..][0 .. n_bitset_elems * @sizeOf(u64)],
    );
    var sli: u32 = 0;
    for (covered_bits) |elem| {
        global.result.ensureUnusedCapacity(gpa, 64) catch @panic("OOM");
        for (0..@bitSizeOf(u64)) |i| {
            if ((elem & (@as(u64, 1) << @intCast(i))) != 0) global.add(sli, want_file);
            sli += 1;
        }
    }
    return Slice(SourceLocationIndex).init(global.result.items);
}
