export fn foo() void {
    const S = struct {
        fn doTheTest() void {
            blk: switch (@as(u8, 'a')) {
                '1' => |_| continue :blk '1',
                else => {},
            }
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}

// error
//
// :5:25: error: discard of capture; omit it instead
