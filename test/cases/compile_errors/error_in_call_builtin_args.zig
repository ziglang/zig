fn foo(_: u32, _: u32) void {}
pub export fn entry() void {
    @call(.{}, foo, .{ 12, 12.34 });
}
pub export fn entry1() void {
    const args = .{ 12, 12.34 };
    @call(.{}, foo, args);
}

// error
// backend=stage2
// target=native
//
// :3:28: error: fractional component prevents float value '12.34' from coercion to type 'u32'
// :7:21: error: fractional component prevents float value '12.34' from coercion to type 'u32'
