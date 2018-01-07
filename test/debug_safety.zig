const tests = @import("tests.zig");

pub fn addCases(cases: &tests.CompareOutputContext) {
    cases.addDebugSafety("calling panic",
        \\pub fn panic(message: []const u8) -> noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\pub fn main() -> %void {
        \\    @panic("oh no");
        \\}
    );

    cases.addDebugSafety("out of bounds slice access",
        \\pub fn panic(message: []const u8) -> noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\pub fn main() -> %void {
        \\    const a = []i32{1, 2, 3, 4};
        \\    baz(bar(a));
        \\}
        \\fn bar(a: []const i32) -> i32 {
        \\    return a[4];
        \\}
        \\fn baz(a: i32) { }
    );

    cases.addDebugSafety("integer addition overflow",
        \\pub fn panic(message: []const u8) -> noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\error Whatever;
        \\pub fn main() -> %void {
        \\    const x = add(65530, 10);
        \\    if (x == 0) return error.Whatever;
        \\}
        \\fn add(a: u16, b: u16) -> u16 {
        \\    return a + b;
        \\}
    );

    cases.addDebugSafety("integer subtraction overflow",
        \\pub fn panic(message: []const u8) -> noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\error Whatever;
        \\pub fn main() -> %void {
        \\    const x = sub(10, 20);
        \\    if (x == 0) return error.Whatever;
        \\}
        \\fn sub(a: u16, b: u16) -> u16 {
        \\    return a - b;
        \\}
    );

    cases.addDebugSafety("integer multiplication overflow",
        \\pub fn panic(message: []const u8) -> noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\error Whatever;
        \\pub fn main() -> %void {
        \\    const x = mul(300, 6000);
        \\    if (x == 0) return error.Whatever;
        \\}
        \\fn mul(a: u16, b: u16) -> u16 {
        \\    return a * b;
        \\}
    );

    cases.addDebugSafety("integer negation overflow",
        \\pub fn panic(message: []const u8) -> noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\error Whatever;
        \\pub fn main() -> %void {
        \\    const x = neg(-32768);
        \\    if (x == 32767) return error.Whatever;
        \\}
        \\fn neg(a: i16) -> i16 {
        \\    return -a;
        \\}
    );

    cases.addDebugSafety("signed integer division overflow",
        \\pub fn panic(message: []const u8) -> noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\error Whatever;
        \\pub fn main() -> %void {
        \\    const x = div(-32768, -1);
        \\    if (x == 32767) return error.Whatever;
        \\}
        \\fn div(a: i16, b: i16) -> i16 {
        \\    return @divTrunc(a, b);
        \\}
    );

    cases.addDebugSafety("signed shift left overflow",
        \\pub fn panic(message: []const u8) -> noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\error Whatever;
        \\pub fn main() -> %void {
        \\    const x = shl(-16385, 1);
        \\    if (x == 0) return error.Whatever;
        \\}
        \\fn shl(a: i16, b: u4) -> i16 {
        \\    return @shlExact(a, b);
        \\}
    );

    cases.addDebugSafety("unsigned shift left overflow",
        \\pub fn panic(message: []const u8) -> noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\error Whatever;
        \\pub fn main() -> %void {
        \\    const x = shl(0b0010111111111111, 3);
        \\    if (x == 0) return error.Whatever;
        \\}
        \\fn shl(a: u16, b: u4) -> u16 {
        \\    return @shlExact(a, b);
        \\}
    );

    cases.addDebugSafety("signed shift right overflow",
        \\pub fn panic(message: []const u8) -> noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\error Whatever;
        \\pub fn main() -> %void {
        \\    const x = shr(-16385, 1);
        \\    if (x == 0) return error.Whatever;
        \\}
        \\fn shr(a: i16, b: u4) -> i16 {
        \\    return @shrExact(a, b);
        \\}
    );

    cases.addDebugSafety("unsigned shift right overflow",
        \\pub fn panic(message: []const u8) -> noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\error Whatever;
        \\pub fn main() -> %void {
        \\    const x = shr(0b0010111111111111, 3);
        \\    if (x == 0) return error.Whatever;
        \\}
        \\fn shr(a: u16, b: u4) -> u16 {
        \\    return @shrExact(a, b);
        \\}
    );

    cases.addDebugSafety("integer division by zero",
        \\pub fn panic(message: []const u8) -> noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\error Whatever;
        \\pub fn main() -> %void {
        \\    const x = div0(999, 0);
        \\}
        \\fn div0(a: i32, b: i32) -> i32 {
        \\    return @divTrunc(a, b);
        \\}
    );

    cases.addDebugSafety("exact division failure",
        \\pub fn panic(message: []const u8) -> noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\error Whatever;
        \\pub fn main() -> %void {
        \\    const x = divExact(10, 3);
        \\    if (x == 0) return error.Whatever;
        \\}
        \\fn divExact(a: i32, b: i32) -> i32 {
        \\    return @divExact(a, b);
        \\}
    );

    cases.addDebugSafety("cast []u8 to bigger slice of wrong size",
        \\pub fn panic(message: []const u8) -> noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\error Whatever;
        \\pub fn main() -> %void {
        \\    const x = widenSlice([]u8{1, 2, 3, 4, 5});
        \\    if (x.len == 0) return error.Whatever;
        \\}
        \\fn widenSlice(slice: []align(1) const u8) -> []align(1) const i32 {
        \\    return ([]align(1) const i32)(slice);
        \\}
    );

    cases.addDebugSafety("value does not fit in shortening cast",
        \\pub fn panic(message: []const u8) -> noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\error Whatever;
        \\pub fn main() -> %void {
        \\    const x = shorten_cast(200);
        \\    if (x == 0) return error.Whatever;
        \\}
        \\fn shorten_cast(x: i32) -> i8 {
        \\    return i8(x);
        \\}
    );

    cases.addDebugSafety("signed integer not fitting in cast to unsigned integer",
        \\pub fn panic(message: []const u8) -> noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\error Whatever;
        \\pub fn main() -> %void {
        \\    const x = unsigned_cast(-10);
        \\    if (x == 0) return error.Whatever;
        \\}
        \\fn unsigned_cast(x: i32) -> u32 {
        \\    return u32(x);
        \\}
    );

    cases.addDebugSafety("unwrap error",
        \\pub fn panic(message: []const u8) -> noreturn {
        \\    if (@import("std").mem.eql(u8, message, "attempt to unwrap error: Whatever")) {
        \\        @import("std").os.exit(126); // good
        \\    }
        \\    @import("std").os.exit(0); // test failed
        \\}
        \\error Whatever;
        \\pub fn main() -> %void {
        \\    bar() catch unreachable;
        \\}
        \\fn bar() -> %void {
        \\    return error.Whatever;
        \\}
    );

    cases.addDebugSafety("cast integer to error and no code matches",
        \\pub fn panic(message: []const u8) -> noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\pub fn main() -> %void {
        \\    _ = bar(9999);
        \\}
        \\fn bar(x: u32) -> error {
        \\    return error(x);
        \\}
    );

    cases.addDebugSafety("@alignCast misaligned",
        \\pub fn panic(message: []const u8) -> noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\error Wrong;
        \\pub fn main() -> %void {
        \\    var array align(4) = []u32{0x11111111, 0x11111111};
        \\    const bytes = ([]u8)(array[0..]);
        \\    if (foo(bytes) != 0x11111111) return error.Wrong;
        \\}
        \\fn foo(bytes: []u8) -> u32 {
        \\    const slice4 = bytes[1..5];
        \\    const int_slice = ([]u32)(@alignCast(4, slice4));
        \\    return int_slice[0];
        \\}
    );

    cases.addDebugSafety("bad union field access",
        \\pub fn panic(message: []const u8) -> noreturn {
        \\    @import("std").os.exit(126);
        \\}
        \\
        \\const Foo = union {
        \\    float: f32,
        \\    int: u32,
        \\};
        \\
        \\pub fn main() -> %void {
        \\    var f = Foo { .int = 42 };
        \\    bar(&f);
        \\}
        \\
        \\fn bar(f: &Foo) {
        \\    f.float = 12.34;
        \\}
    );
}
