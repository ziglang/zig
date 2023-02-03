const std = @import("std");
const MyStruct = struct {
    a: i32,
    b: i32,

    pub fn getA(self: *List) i32 {
        return self.items(.c);
    }
};
const List = std.MultiArrayList(MyStruct);
pub export fn entry() void {
    var list = List{};
    _ = MyStruct.getA(&list);
}

// error
// backend=stage2
// target=native
//
// :7:28: error: no field named 'c' in enum 'meta.FieldEnum(tmp.MyStruct)'
// :?:?: note: enum declared here
