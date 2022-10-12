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
const Opaque = opaque {};

// error
// backend=stage2
// target=native
//
// :2:8: error: variable of type '*const comptime_int' must be const or comptime
// :6:8: error: variable of type '@TypeOf(undefined)' must be const or comptime
// :10:8: error: variable of type 'comptime_int' must be const or comptime
// :10:8: note: to modify this variable at runtime, it must be given an explicit fixed-size number type
// :14:8: error: variable of type 'comptime_float' must be const or comptime
// :14:8: note: to modify this variable at runtime, it must be given an explicit fixed-size number type
// :18:8: error: variable of type '@TypeOf(null)' must be const or comptime
// :22:19: error: values of type 'tmp.Opaque' must be comptime-known, but operand value is runtime-known
// :22:19: note: opaque type 'tmp.Opaque' has undefined size
// :26:8: error: variable of type 'type' must be const or comptime
// :26:8: note: types are not available at runtime
