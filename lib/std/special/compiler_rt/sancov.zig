const std = @import("std");

pub fn __sanitizer_dump_coverage(pcs: *const usize, len: usize) callconv(.C) void {

}

pub fn __sanitizer_cov_trace_pc_guard(guard: *const u32) callconv(.C) void {

}

pub fn __sanitizer_cov_trace_pc_guard_init(start: *const u32, end: *const u32) callconv(.C) void {

}

pub fn __sanitizer_dump_trace_pc_guard_coverage() callconv(.C) void {

}

pub fn __sanitizer_cov_dump() callconv(.C) void {

}

pub fn __sanitizer_cov_reset() callconv(.C) void {

}

// Default empty implementations.
pub fn __sanitizer_cov_trace_cmp() callconv(.C) void {}
pub fn __sanitizer_cov_trace_cmp1() callconv(.C) void {}
pub fn __sanitizer_cov_trace_cmp2() callconv(.C) void {}
pub fn __sanitizer_cov_trace_cmp4() callconv(.C) void {}
pub fn __sanitizer_cov_trace_cmp8() callconv(.C) void {}
pub fn __sanitizer_cov_trace_const_cmp1() callconv(.C) void {}
pub fn __sanitizer_cov_trace_const_cmp2() callconv(.C) void {}
pub fn __sanitizer_cov_trace_const_cmp4() callconv(.C) void {}
pub fn __sanitizer_cov_trace_const_cmp8() callconv(.C) void {}
pub fn __sanitizer_cov_trace_switch() callconv(.C) void {}
pub fn __sanitizer_cov_trace_div4() callconv(.C) void {}
pub fn __sanitizer_cov_trace_div8() callconv(.C) void {}
pub fn __sanitizer_cov_trace_gep() callconv(.C) void {}
pub fn __sanitizer_cov_trace_pc_indir() callconv(.C) void {}
pub fn __sanitizer_cov_8bit_counters_init() callconv(.C) void {}
pub fn __sanitizer_cov_bool_flag_init() callconv(.C) void {}
pub fn __sanitizer_cov_pcs_init() callconv(.C) void {}
