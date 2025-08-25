fn foo(_: u32, _: u32) void {}
pub export fn entry() void {
    @call(.auto, foo, .{ 12, 12.34 });
}
pub export fn entry1() void {
    const args = .{ 12, 12.34 };
    @call(.auto, foo, args);
}

// error
// backend=stage2
// target=native
//
// :3:30: error: fractional component prevents float value '12.34' from coercion to type 'u32'
// :7:23: error: fractional component prevents float value '12.34' from coercion to type 'u32'
