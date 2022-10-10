const T = struct {
    comptime a: u32 = 2,
};
pub export fn entry1() void {
    @offsetOf(T, "a");
}
pub export fn entry2() void {
    @fieldParentPtr(T, "a", undefined);
}

// error
// backend=stage2
// target=native
//
// :5:5: error: no offset available for comptime field
// :8:5: error: cannot get @fieldParentPtr of a comptime field
