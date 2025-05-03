const std = @import("std");

const FuzzerSlice = extern struct {
    ptr: [*]const u8,
    len: usize,

    fn fromSlice(s: []const u8) FuzzerSlice {
        return .{ .ptr = s.ptr, .len = s.len };
    }
};

extern fn fuzzer_set_name(name_ptr: [*]const u8, name_len: usize) void;
extern fn fuzzer_init(cache_dir: FuzzerSlice) void;
extern fn fuzzer_init_corpus_elem(input_ptr: [*]const u8, input_len: usize) void;
extern fn fuzzer_coverage_id() u64;

pub fn main() !void {
    fuzzer_init(FuzzerSlice.fromSlice(""));
    fuzzer_init_corpus_elem("hello".ptr, "hello".len);
    fuzzer_set_name("test".ptr, "test".len);
    _ = fuzzer_coverage_id();
}
