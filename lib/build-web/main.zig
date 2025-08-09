const std = @import("std");
const assert = std.debug.assert;
const abi = std.Build.abi;
const gpa = std.heap.wasm_allocator;
const log = std.log;
const Allocator = std.mem.Allocator;

const fuzz = @import("fuzz.zig");
const time_report = @import("time_report.zig");

/// Nanoseconds.
var server_base_timestamp: i64 = 0;
/// Milliseconds.
var client_base_timestamp: i64 = 0;

pub var step_list: []Step = &.{};
/// Not accessed after initialization, but must be freed alongside `step_list`.
pub var step_list_data: []u8 = &.{};

const Step = struct {
    name: []const u8,
    status: abi.StepUpdate.Status,
};

const js = struct {
    extern "core" fn log(ptr: [*]const u8, len: usize) void;
    extern "core" fn panic(ptr: [*]const u8, len: usize) noreturn;
    extern "core" fn timestamp() i64;
    extern "core" fn hello(
        steps_len: u32,
        status: abi.BuildStatus,
        time_report: bool,
    ) void;
    extern "core" fn updateBuildStatus(status: abi.BuildStatus) void;
    extern "core" fn updateStepStatus(step_idx: u32) void;
    extern "core" fn sendWsMessage(ptr: [*]const u8, len: usize) void;
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

var message_buffer: std.ArrayListAlignedUnmanaged(u8, .of(u64)) = .empty;

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
        _ => @panic("malformed message"),

        .hello => return helloMessage(msg_bytes) catch @panic("OOM"),
        .status_update => return statusUpdateMessage(msg_bytes) catch @panic("OOM"),
        .step_update => return stepUpdateMessage(msg_bytes) catch @panic("OOM"),

        .fuzz_source_index => return fuzz.sourceIndexMessage(msg_bytes) catch @panic("OOM"),
        .fuzz_coverage_update => return fuzz.coverageUpdateMessage(msg_bytes) catch @panic("OOM"),
        .fuzz_entry_points => return fuzz.entryPointsMessage(msg_bytes) catch @panic("OOM"),

        .time_report_generic_result => return time_report.genericResultMessage(msg_bytes) catch @panic("OOM"),
        .time_report_compile_result => return time_report.compileResultMessage(msg_bytes) catch @panic("OOM"),
    }
}

const String = Slice(u8);

pub fn Slice(T: type) type {
    return packed struct(u64) {
        ptr: u32,
        len: u32,

        pub fn init(s: []const T) @This() {
            return .{
                .ptr = @intFromPtr(s.ptr),
                .len = s.len,
            };
        }
    };
}

pub fn fatal(comptime format: []const u8, args: anytype) noreturn {
    var buf: [500]u8 = undefined;
    const line = std.fmt.bufPrint(&buf, format, args) catch l: {
        buf[buf.len - 3 ..][0..3].* = "...".*;
        break :l &buf;
    };
    js.panic(line.ptr, line.len);
}

fn helloMessage(msg_bytes: []align(4) u8) Allocator.Error!void {
    if (msg_bytes.len < @sizeOf(abi.Hello)) @panic("malformed Hello message");
    const hdr: *const abi.Hello = @ptrCast(msg_bytes[0..@sizeOf(abi.Hello)]);
    const trailing = msg_bytes[@sizeOf(abi.Hello)..];

    client_base_timestamp = js.timestamp();
    server_base_timestamp = hdr.timestamp;

    const steps = try gpa.alloc(Step, hdr.steps_len);
    errdefer gpa.free(steps);

    const step_name_lens: []align(1) const u32 = @ptrCast(trailing[0 .. steps.len * 4]);

    const step_name_data_len: usize = len: {
        var sum: usize = 0;
        for (step_name_lens) |n| sum += n;
        break :len sum;
    };
    const step_name_data: []const u8 = trailing[steps.len * 4 ..][0..step_name_data_len];
    const step_status_bits: []const u8 = trailing[steps.len * 4 + step_name_data_len ..];

    const duped_step_name_data = try gpa.dupe(u8, step_name_data);
    errdefer gpa.free(duped_step_name_data);

    var name_off: usize = 0;
    for (steps, step_name_lens, 0..) |*step_out, name_len, step_idx| {
        step_out.* = .{
            .name = duped_step_name_data[name_off..][0..name_len],
            .status = @enumFromInt(@as(u2, @truncate(step_status_bits[step_idx / 4] >> @intCast((step_idx % 4) * 2)))),
        };
        name_off += name_len;
    }

    gpa.free(step_list);
    gpa.free(step_list_data);
    step_list = steps;
    step_list_data = duped_step_name_data;

    js.hello(step_list.len, hdr.status, hdr.flags.time_report);
}
fn statusUpdateMessage(msg_bytes: []u8) Allocator.Error!void {
    if (msg_bytes.len < @sizeOf(abi.StatusUpdate)) @panic("malformed StatusUpdate message");
    const msg: *const abi.StatusUpdate = @ptrCast(msg_bytes[0..@sizeOf(abi.StatusUpdate)]);
    js.updateBuildStatus(msg.new);
}
fn stepUpdateMessage(msg_bytes: []u8) Allocator.Error!void {
    if (msg_bytes.len < @sizeOf(abi.StepUpdate)) @panic("malformed StepUpdate message");
    const msg: *const abi.StepUpdate = @ptrCast(msg_bytes[0..@sizeOf(abi.StepUpdate)]);
    if (msg.step_idx >= step_list.len) @panic("malformed StepUpdate message");
    step_list[msg.step_idx].status = msg.bits.status;
    js.updateStepStatus(msg.step_idx);
}

export fn stepName(idx: usize) String {
    return .init(step_list[idx].name);
}
export fn stepStatus(idx: usize) u8 {
    return @intFromEnum(step_list[idx].status);
}

export fn rebuild() void {
    const msg: abi.Rebuild = .{};
    const raw: []const u8 = @ptrCast(&msg);
    js.sendWsMessage(raw.ptr, raw.len);
}

/// Nanoseconds passed since a server timestamp.
pub fn nsSince(server_timestamp: i64) i64 {
    const ms_passed = js.timestamp() - client_base_timestamp;
    const ns_passed = server_base_timestamp - server_timestamp;
    return ns_passed + ms_passed * std.time.ns_per_ms;
}

pub fn fmtEscapeHtml(unescaped: []const u8) HtmlEscaper {
    return .{ .unescaped = unescaped };
}
const HtmlEscaper = struct {
    unescaped: []const u8,
    pub fn format(he: HtmlEscaper, w: *std.Io.Writer) !void {
        for (he.unescaped) |c| switch (c) {
            '&' => try w.writeAll("&amp;"),
            '<' => try w.writeAll("&lt;"),
            '>' => try w.writeAll("&gt;"),
            '"' => try w.writeAll("&quot;"),
            '\'' => try w.writeAll("&#39;"),
            else => try w.writeByte(c),
        };
    }
};
