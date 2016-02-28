const test_runner = @import("test_runner.zig");

pub fn main(args: [][]u8) -> %void {
    return test_runner.run_tests();
}
