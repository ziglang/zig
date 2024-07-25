const std = @import("std");
const InternPool = @import("InternPool.zig");
const Zcu = @import("Zcu.zig");
const TimeTrace = @This();

gpa: std.mem.Allocator,
enabled: bool = false,
start_time: std.time.Instant,
events: std.ArrayListUnmanaged(Event) = .{},
mutex: std.Thread.Mutex = .{},

pub const EventDesc = union(enum) {
    // Sema events:
    fn_body: InternPool.Index,
    decl: Zcu.Decl.Index,

    // Codegen events:
    codegen_func: InternPool.Index,
    codegen_decl: Zcu.Decl.Index,

    end: void,
};

const Event = struct {
    time: std.time.Instant,
    pt: Zcu.PerThread,
    desc: EventDesc,
};

pub fn init(gpa: std.mem.Allocator) TimeTrace {
    return .{
        .gpa = gpa,
        .start_time = undefined, // set in enable
        .enabled = false,
    };
}

pub fn enable(self: *TimeTrace) void {
    std.debug.assert(!self.enabled);
    self.start_time = std.time.Instant.now() catch @panic("Failed to record time");
    self.enabled = true;
}

pub fn deinit(self: *TimeTrace) void {
    self.clearData();
    self.* = undefined;
}

fn clearData(self: *TimeTrace) void {
    self.events.deinit(self.gpa);
    self.events = .{};
}

pub fn dumpReportAndClear(self: *TimeTrace, path: []const u8) void {
    if (self.enabled) {
        self.dumpFlameGraph(path);
        self.clearData();
    }
}

fn dumpFlameGraph(self: *TimeTrace, path: []const u8) void {
    const file = std.fs.cwd().createFile(path, .{}) catch @panic("Failed to create time-trace .json file");
    defer file.close();

    var buffered = std.io.bufferedWriter(file.writer());
    self.writeFlameGraphOrError(buffered.writer()) catch @panic("Failed to write time-trace .json file");
    buffered.flush() catch @panic("Failed to write time-trace .json file");
}

fn writeFlameGraphOrError(self: *TimeTrace, writer: anytype) @TypeOf(writer).Error!void {
    try writer.writeAll("[");
    for (self.events.items, 0..) |*evt, i| {
        const time_us = evt.time.since(self.start_time) / 1000;
        switch (evt.desc) {
            .codegen_decl, .decl => |decl_idx| {
                const decl = evt.pt.zcu.declPtr(decl_idx);
                const cat = switch (evt.desc) {
                    .decl => "sema,decl",
                    .codegen_decl => "codegen,decl",
                    else => unreachable,
                };
                try writeEvent(writer, cat, decl.fqn, time_us, evt.pt);
            },
            .fn_body, .codegen_func => |fn_index| {
                const func = evt.pt.zcu.funcInfo(fn_index);
                const decl_index = func.owner_decl;
                const decl = evt.pt.zcu.declPtr(decl_index);
                const cat = switch (evt.desc) {
                    .fn_body => "sema,fn_body",
                    .codegen_func => "codegen,func",
                    else => unreachable,
                };
                try writeEvent(writer, cat, decl.fqn, time_us, evt.pt);
            },
            .end => {
                try writer.print("{{\"ph\":\"E\",\"ts\":{},\"pid\":0,\"tid\":{d}}}{s}", .{
                    time_us, @intFromEnum(evt.pt.tid), if (i == self.events.items.len) "" else ",",
                });
            },
        }
    }
    try writer.writeAll("]");
}

fn writeEvent(
    writer: anytype,
    category: []const u8,
    fq_index: InternPool.NullTerminatedString,
    time_us: u64,
    pt: Zcu.PerThread,
) @TypeOf(writer).Error!void {
    try writer.print("{{\"name\":\"{s} ", .{category});
    try std.json.encodeJsonStringChars(fq_index.toSlice(&pt.zcu.intern_pool), .{}, writer);
    try writer.print(
        "\",\"cat\":\"{s}\",\"ph\":\"B\",\"ts\":{},\"pid\":0,\"tid\":{d}}},",
        .{ category, time_us, @intFromEnum(pt.tid) },
    );
}

pub inline fn event(
    self: *TimeTrace,
    evt: EventDesc,
    pt: Zcu.PerThread,
) void {
    if (!self.enabled) return;

    // it's rare that decls begin analysis/codegen at the exact same time
    // so there shouldn't be much contention.
    self.mutex.lock();
    defer self.mutex.unlock();

    const now = std.time.Instant.now() catch @panic("unsupported");
    self.events.append(self.gpa, .{ .time = now, .desc = evt, .pt = pt }) catch @panic("out of memory");
}
