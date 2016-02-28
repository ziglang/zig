const test_runner = @import("test_runner.zig");

export fn main(argc: c_int, argv: &&u8) -> c_int {
    test_runner.run_tests() %% return -1;
    return 0;
}
