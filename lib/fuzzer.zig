const std = @import("std");
const Allocator = std.mem.Allocator;

export threadlocal var __sancov_lowest_stack: usize = 0;

export fn __sanitizer_cov_8bit_counters_init(start: [*]u8, stop: [*]u8) void {
    std.log.debug("__sanitizer_cov_8bit_counters_init start={*}, stop={*}", .{ start, stop });
}

export fn __sanitizer_cov_pcs_init(pcs_beg: [*]const usize, pcs_end: [*]const usize) void {
    std.log.debug("__sanitizer_cov_pcs_init pcs_beg={*}, pcs_end={*}", .{ pcs_beg, pcs_end });
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
    std.log.debug("0x{x}: switch on value {d} ({d} bits) with {d} cases", .{
        pc, val, val_size_in_bits, cases.len,
    });
}

export fn __sanitizer_cov_trace_pc_indir(callee: usize) void {
    const pc = @returnAddress();
    std.log.debug("0x{x}: indirect call to 0x{x}", .{ pc, callee });
}

fn handleCmp(pc: usize, arg1: u64, arg2: u64) void {
    std.log.debug("0x{x}: comparison of {d} and {d}", .{ pc, arg1, arg2 });
}

const Fuzzer = struct {
    gpa: Allocator,
    rng: std.Random.DefaultPrng,
    input: std.ArrayListUnmanaged(u8),

    const Slice = extern struct {
        ptr: [*]const u8,
        len: usize,

        fn toSlice(s: Slice) []const u8 {
            return s.ptr[0..s.len];
        }

        fn fromSlice(s: []const u8) Slice {
            return .{
                .ptr = s.ptr,
                .len = s.len,
            };
        }
    };

    fn next(f: *Fuzzer) ![]const u8 {
        const gpa = f.gpa;
        const rng = fuzzer.rng.random();
        const len = rng.uintLessThan(usize, 64);
        try f.input.resize(gpa, len);
        rng.bytes(f.input.items);
        return f.input.items;
    }
};

var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .{};

var fuzzer: Fuzzer = .{
    .gpa = general_purpose_allocator.allocator(),
    .rng = std.Random.DefaultPrng.init(0),
    .input = .{},
};

export fn fuzzer_next() Fuzzer.Slice {
    return Fuzzer.Slice.fromSlice(fuzzer.next() catch |err| switch (err) {
        error.OutOfMemory => @panic("out of memory"),
    });
}
