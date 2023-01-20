export var test_global: u32 linksection("__DATA,__TestGlobal") = undefined;
export fn testFn() linksection("__TEXT,__TestFn") callconv(.C) void {
    testGenericFn("A");
}
fn testGenericFn(comptime suffix: []const u8) linksection("__TEXT,__TestGenFn" ++ suffix) void {}
