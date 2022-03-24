export fn entry1() void {
   var m2 = &2;
   _ = m2;
}
export fn entry2() void {
   var a = undefined;
   _ = a;
}
export fn entry3() void {
   var b = 1;
   _ = b;
}
export fn entry4() void {
   var c = 1.0;
   _ = c;
}
export fn entry5() void {
   var d = null;
   _ = d;
}
export fn entry6(opaque_: *Opaque) void {
   var e = opaque_.*;
   _ = e;
}
export fn entry7() void {
   var f = i32;
   _ = f;
}
export fn entry8() void {
   var h = (Foo {}).bar;
   _ = h;
}
const Opaque = opaque {};
const Foo = struct {
    fn bar(self: *const Foo) void {_ = self;}
};

// non-const variables of things that require const variables
//
// tmp.zig:2:4: error: variable of type '*const comptime_int' must be const or comptime
// tmp.zig:6:4: error: variable of type '@Type(.Undefined)' must be const or comptime
// tmp.zig:10:4: error: variable of type 'comptime_int' must be const or comptime
// tmp.zig:10:4: note: to modify this variable at runtime, it must be given an explicit fixed-size number type
// tmp.zig:14:4: error: variable of type 'comptime_float' must be const or comptime
// tmp.zig:14:4: note: to modify this variable at runtime, it must be given an explicit fixed-size number type
// tmp.zig:18:4: error: variable of type '@Type(.Null)' must be const or comptime
// tmp.zig:22:4: error: variable of type 'Opaque' not allowed
// tmp.zig:26:4: error: variable of type 'type' must be const or comptime
// tmp.zig:30:4: error: variable of type '(bound fn(*const Foo) void)' must be const or comptime
