const std = @import("std");
const Allocator = std.mem.Allocator;

pub const std_options = .{
    .logFn = logOverride,
};

var log_file: ?std.fs.File = null;

fn logOverride(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const f = if (log_file) |f| f else f: {
        const f = std.fs.cwd().createFile("libfuzzer.log", .{}) catch @panic("failed to open fuzzer log file");
        log_file = f;
        break :f f;
    };
    const prefix1 = comptime level.asText();
    const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";
    f.writer().print(prefix1 ++ prefix2 ++ format ++ "\n", args) catch @panic("failed to write to fuzzer log");
}

export threadlocal var __sancov_lowest_stack: usize = 0;

export fn __sanitizer_cov_8bit_counters_init(start: [*]u8, stop: [*]u8) void {
    std.log.debug("__sanitizer_cov_8bit_counters_init start={*}, stop={*}", .{ start, stop });
}

export fn __sanitizer_cov_pcs_init(pc_start: [*]const usize, pc_end: [*]const usize) void {
    std.log.debug("__sanitizer_cov_pcs_init pc_start={*}, pc_end={*}", .{ pc_start, pc_end });
    fuzzer.pc_range = .{
        .start = @intFromPtr(pc_start),
        .end = @intFromPtr(pc_start),
    };
}

export fn __sanitizer_cov_trace_const_cmp1(arg1: u8, arg2: u8) void {
    handleCmp(@returnAddress(), arg1, arg2);
}

export fn __sanitizer_cov_trace_cmp1(arg1: u8, arg2: u8) void {
    handleCmp(@returnAddress(), arg1, arg2);
}

export fn __sanitizer_cov_trace_const_cmp2(arg1: u16, arg2: u16) void {
    handleCmp(@returnAddress(), arg1, arg2);
}

export fn __sanitizer_cov_trace_cmp2(arg1: u16, arg2: u16) void {
    handleCmp(@returnAddress(), arg1, arg2);
}

export fn __sanitizer_cov_trace_const_cmp4(arg1: u32, arg2: u32) void {
    handleCmp(@returnAddress(), arg1, arg2);
}

export fn __sanitizer_cov_trace_cmp4(arg1: u32, arg2: u32) void {
    handleCmp(@returnAddress(), arg1, arg2);
}

export fn __sanitizer_cov_trace_const_cmp8(arg1: u64, arg2: u64) void {
    handleCmp(@returnAddress(), arg1, arg2);
}

export fn __sanitizer_cov_trace_cmp8(arg1: u64, arg2: u64) void {
    handleCmp(@returnAddress(), arg1, arg2);
}

export fn __sanitizer_cov_trace_switch(val: u64, cases_ptr: [*]u64) void {
    const pc = @returnAddress();
    const len = cases_ptr[0];
    const val_size_in_bits = cases_ptr[1];
    const cases = cases_ptr[2..][0..len];
    _ = val;
    _ = pc;
    _ = val_size_in_bits;
    _ = cases;
    //std.log.debug("0x{x}: switch on value {d} ({d} bits) with {d} cases", .{
    //    pc, val, val_size_in_bits, cases.len,
    //});
}

export fn __sanitizer_cov_trace_pc_indir(callee: usize) void {
    const pc = @returnAddress();
    _ = callee;
    _ = pc;
    //std.log.debug("0x{x}: indirect call to 0x{x}", .{ pc, callee });
}

fn handleCmp(pc: usize, arg1: u64, arg2: u64) void {
    _ = pc;
    _ = arg1;
    _ = arg2;
    //std.log.debug("0x{x}: comparison of {d} and {d}", .{ pc, arg1, arg2 });
}

const Fuzzer = struct {
    gpa: Allocator,
    rng: std.Random.DefaultPrng,
    input: std.ArrayListUnmanaged(u8),
    pc_range: PcRange,
    count: usize,

    const Slice = extern struct {
        ptr: [*]const u8,
        len: usize,

        fn toZig(s: Slice) []const u8 {
            return s.ptr[0..s.len];
        }

        fn fromZig(s: []const u8) Slice {
            return .{
                .ptr = s.ptr,
                .len = s.len,
            };
        }
    };

    const PcRange = struct {
        start: usize,
        end: usize,
    };

    fn next(f: *Fuzzer) ![]const u8 {
        const gpa = f.gpa;

        // Prepare next input.
        const rng = fuzzer.rng.random();
        const len = rng.uintLessThan(usize, 64);
        try f.input.resize(gpa, len);
        rng.bytes(f.input.items);
        f.resetCoverage();
        f.count += 1;
        return f.input.items;
    }

    fn resetCoverage(f: *Fuzzer) void {
        _ = f;
    }
};

var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .{};

var fuzzer: Fuzzer = .{
    .gpa = general_purpose_allocator.allocator(),
    .rng = std.Random.DefaultPrng.init(0),
    .input = .{},
    .pc_range = .{ .start = 0, .end = 0 },
    .count = 0,
};

export fn fuzzer_next() Fuzzer.Slice {
    return Fuzzer.Slice.fromZig(fuzzer.next() catch |err| switch (err) {
        error.OutOfMemory => @panic("out of memory"),
    });
}
