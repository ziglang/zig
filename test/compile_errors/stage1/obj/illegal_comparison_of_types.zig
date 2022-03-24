fn bad_eql_1(a: []u8, b: []u8) bool {
    return a == b;
}
const EnumWithData = union(enum) {
    One: void,
    Two: i32,
};
fn bad_eql_2(a: *const EnumWithData, b: *const EnumWithData) bool {
    return a.* == b.*;
}

export fn entry1() usize { return @sizeOf(@TypeOf(bad_eql_1)); }
export fn entry2() usize { return @sizeOf(@TypeOf(bad_eql_2)); }

// illegal comparison of types
//
// tmp.zig:2:14: error: operator not allowed for type '[]u8'
// tmp.zig:9:16: error: operator not allowed for type 'EnumWithData'
