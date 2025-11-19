// Server timestamp.
var start_fuzzing_timestamp: i64 = undefined;

const js = struct {
    extern "fuzz" fn requestSources() void;
    extern "fuzz" fn ready() void;

    extern "fuzz" fn updateStats(html_ptr: [*]const u8, html_len: usize) void;
    extern "fuzz" fn updateEntryPoints(html_ptr: [*]const u8, html_len: usize) void;
    extern "fuzz" fn updateSource(html_ptr: [*]const u8, html_len: usize) void;
    extern "fuzz" fn updateCoverage(covered_ptr: [*]const SourceLocationIndex, covered_len: u32) void;
};

pub fn sourceIndexMessage(msg_bytes: []u8) error{OutOfMemory}!void {
    Walk.files.clearRetainingCapacity();
    Walk.decls.clearRetainingCapacity();
    Walk.modules.clearRetainingCapacity();
    recent_coverage_update.clearRetainingCapacity();
    selected_source_location = null;

    js.requestSources();

    const Header = abi.fuzz.SourceIndexHeader;
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

    start_fuzzing_timestamp = header.start_timestamp;
    try updateCoverageSources(directories, files, source_locations, string_bytes);
    js.ready();
}

var coverage = Coverage.init;
/// Index of type `SourceLocationIndex`.
var coverage_source_locations: std.ArrayListUnmanaged(Coverage.SourceLocation) = .empty;
/// Contains the most recent coverage update message, unmodified.
var recent_coverage_update: std.ArrayListAlignedUnmanaged(u8, .of(u64)) = .empty;

fn updateCoverageSources(
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

pub fn coverageUpdateMessage(msg_bytes: []u8) error{OutOfMemory}!void {
    recent_coverage_update.clearRetainingCapacity();
    recent_coverage_update.appendSlice(gpa, msg_bytes) catch @panic("OOM");
    try updateStats();
    try updateCoverage();
}

var entry_points: std.ArrayListUnmanaged(SourceLocationIndex) = .empty;

pub fn entryPointsMessage(msg_bytes: []u8) error{OutOfMemory}!void {
    const header: abi.fuzz.EntryPointHeader = @bitCast(msg_bytes[0..@sizeOf(abi.fuzz.EntryPointHeader)].*);
    const slis: []align(1) const SourceLocationIndex = @ptrCast(msg_bytes[@sizeOf(abi.fuzz.EntryPointHeader)..]);
    assert(slis.len == header.locsLen());
    try entry_points.resize(gpa, slis.len);
    @memcpy(entry_points.items, slis);
    try updateEntryPoints();
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
        out: *std.ArrayList(u8),
        focused: bool,
    ) error{OutOfMemory}!void {
        const sl = sli.ptr();
        try out.print(gpa, "<code{s}>", .{
            @as([]const u8, if (focused) " class=\"status-running\"" else ""),
        });
        try sli.appendPath(out);
        try out.print(gpa, ":{d}:{d} </code><button class=\"linkish\" onclick=\"wasm_exports.fuzzSelectSli({d});\">View</button>", .{
            sl.line,
            sl.column,
            @intFromEnum(sli),
        });
    }

    fn appendPath(sli: SourceLocationIndex, out: *std.ArrayList(u8)) error{OutOfMemory}!void {
        const sl = sli.ptr();
        const file = coverage.fileAt(sl.file);
        const file_name = coverage.stringAt(file.basename);
        const dir_name = coverage.stringAt(coverage.directories.keys()[file.directory_index]);
        try html_render.appendEscaped(out, dir_name);
        try out.appendSlice(gpa, "/");
        try html_render.appendEscaped(out, file_name);
    }

    fn toWalkFile(sli: SourceLocationIndex) ?Walk.File.Index {
        var buf: std.ArrayListUnmanaged(u8) = .empty;
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
        var annotations: std.ArrayListUnmanaged(html_render.Annotation) = .empty;
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
    var locs: std.ArrayListUnmanaged(SourceLocationIndex) = .empty;
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

export fn fuzzUnpackSources(tar_ptr: [*]u8, tar_len: usize) void {
    const tar_bytes = tar_ptr[0..tar_len];
    log.debug("received {d} bytes of sources.tar", .{tar_bytes.len});

    unpackSourcesInner(tar_bytes) catch |err| {
        fatal("unable to unpack sources.tar: {s}", .{@errorName(err)});
    };
}

fn unpackSourcesInner(tar_bytes: []u8) !void {
    var tar_reader: std.Io.Reader = .fixed(tar_bytes);
    var file_name_buffer: [1024]u8 = undefined;
    var link_name_buffer: [1024]u8 = undefined;
    var it: std.tar.Iterator = .init(&tar_reader, .{
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
                    // This is a hack to guess modules from the tar file contents. To handle modules
                    // properly, the build system will need to change the structure here to have one
                    // directory per module. This in turn requires compiler enhancements to allow
                    // the build system to actually discover the required information.
                    const mod_name, const is_module_root = p: {
                        if (std.mem.find(u8, file_name, "std/")) |i| break :p .{ "std", std.mem.eql(u8, file_name[i + 4 ..], "std.zig") };
                        if (std.mem.endsWith(u8, file_name, "/builtin.zig")) break :p .{ "builtin", true };
                        break :p .{ "root", std.mem.endsWith(u8, file_name, "/root.zig") };
                    };
                    const gop = try Walk.modules.getOrPut(gpa, mod_name);
                    const file: Walk.File.Index = @enumFromInt(Walk.files.entries.len);
                    if (!gop.found_existing or is_module_root) gop.value_ptr.* = file;
                    const file_bytes = tar_reader.take(@intCast(tar_file.size)) catch unreachable;
                    it.unread_file_bytes = 0; // we have read the whole thing
                    assert(file == try Walk.add_file(file_name, file_bytes));
                } else {
                    log.warn("skipping: '{s}' - the tar creation should have done that", .{tar_file.name});
                }
            },
            else => continue,
        }
    }
}

fn updateStats() error{OutOfMemory}!void {
    @setFloatMode(.optimized);

    if (recent_coverage_update.items.len == 0) return;

    const hdr: *abi.fuzz.CoverageUpdateHeader = @ptrCast(@alignCast(
        recent_coverage_update.items[0..@sizeOf(abi.fuzz.CoverageUpdateHeader)],
    ));

    const covered_src_locs: usize = n: {
        var n: usize = 0;
        const covered_bits = recent_coverage_update.items[@sizeOf(abi.fuzz.CoverageUpdateHeader)..];
        for (covered_bits) |byte| n += @popCount(byte);
        break :n n;
    };
    const total_src_locs = coverage_source_locations.items.len;

    const avg_speed: f64 = speed: {
        const ns_elapsed: f64 = @floatFromInt(nsSince(start_fuzzing_timestamp));
        const n_runs: f64 = @floatFromInt(hdr.n_runs);
        break :speed n_runs / (ns_elapsed / std.time.ns_per_s);
    };

    const html = try std.fmt.allocPrint(gpa,
        \\<span slot="stat-total-runs">{d}</span>
        \\<span slot="stat-unique-runs">{d} ({d:.1}%)</span>
        \\<span slot="stat-coverage">{d} / {d} ({d:.1}%)</span>
        \\<span slot="stat-speed">{d:.0}</span>
    , .{
        hdr.n_runs,
        hdr.unique_runs,
        @as(f64, @floatFromInt(hdr.unique_runs)) / @as(f64, @floatFromInt(hdr.n_runs)),
        covered_src_locs,
        total_src_locs,
        @as(f64, @floatFromInt(covered_src_locs)) / @as(f64, @floatFromInt(total_src_locs)),
        avg_speed,
    });
    defer gpa.free(html);

    js.updateStats(html.ptr, html.len);
}

fn updateEntryPoints() error{OutOfMemory}!void {
    var html: std.ArrayList(u8) = .empty;
    defer html.deinit(gpa);
    for (entry_points.items) |sli| {
        try html.appendSlice(gpa, "<li>");
        try sli.sourceLocationLinkHtml(&html, selected_source_location == sli);
        try html.appendSlice(gpa, "</li>\n");
    }
    js.updateEntryPoints(html.items.ptr, html.items.len);
}

fn updateCoverage() error{OutOfMemory}!void {
    if (recent_coverage_update.items.len == 0) return;
    const want_file = (selected_source_location orelse return).ptr().file;

    var covered: std.ArrayListUnmanaged(SourceLocationIndex) = .empty;
    defer covered.deinit(gpa);

    // This code assumes 64-bit elements, which is incorrect if the executable
    // being fuzzed is not a 64-bit CPU. It also assumes little-endian which
    // can also be incorrect.
    comptime assert(abi.fuzz.CoverageUpdateHeader.trailing[0] == .pc_bits_usize);
    const n_bitset_elems = (coverage_source_locations.items.len + @bitSizeOf(u64) - 1) / @bitSizeOf(u64);
    const covered_bits = std.mem.bytesAsSlice(
        u64,
        recent_coverage_update.items[@sizeOf(abi.fuzz.CoverageUpdateHeader)..][0 .. n_bitset_elems * @sizeOf(u64)],
    );
    var sli: SourceLocationIndex = @enumFromInt(0);
    for (covered_bits) |elem| {
        try covered.ensureUnusedCapacity(gpa, 64);
        for (0..@bitSizeOf(u64)) |i| {
            if ((elem & (@as(u64, 1) << @intCast(i))) != 0) {
                if (sli.ptr().file == want_file) {
                    covered.appendAssumeCapacity(sli);
                }
            }
            sli = @enumFromInt(@intFromEnum(sli) + 1);
        }
    }

    js.updateCoverage(covered.items.ptr, covered.items.len);
}

fn updateSource() error{OutOfMemory}!void {
    if (recent_coverage_update.items.len == 0) return;
    const file_sli = selected_source_location.?;
    var html: std.ArrayListUnmanaged(u8) = .empty;
    defer html.deinit(gpa);
    file_sli.fileHtml(&html) catch |err| switch (err) {
        error.OutOfMemory => |e| return e,
        error.SourceUnavailable => {},
    };
    js.updateSource(html.items.ptr, html.items.len);
}

var selected_source_location: ?SourceLocationIndex = null;

/// This function is not used directly by `main.js`, but a reference to it is
/// emitted by `SourceLocationIndex.sourceLocationLinkHtml`.
export fn fuzzSelectSli(sli: SourceLocationIndex) void {
    if (!sli.haveCoverage()) return;
    selected_source_location = sli;
    updateEntryPoints() catch @panic("out of memory"); // highlights the selected one green
    updateSource() catch @panic("out of memory");
    updateCoverage() catch @panic("out of memory");
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const Coverage = std.debug.Coverage;
const abi = std.Build.abi;
const assert = std.debug.assert;
const gpa = std.heap.wasm_allocator;

const Walk = @import("Walk");
const html_render = @import("html_render");

const nsSince = @import("main.zig").nsSince;
const Slice = @import("main.zig").Slice;
const fatal = @import("main.zig").fatal;
const log = std.log;
const String = Slice(u8);
