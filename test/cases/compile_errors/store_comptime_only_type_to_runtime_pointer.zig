export fn a() void {
    const p: *fn () void = @ptrFromInt(4);
    p.* = undefined;
}

export fn b(p: *anyopaque) void {
    p.* = undefined;
}

export fn c(p: *anyopaque, q: *anyopaque) void {
    p.* = q.*;
}

const Opaque = opaque {};
export fn d(p: *Opaque) void {
    p.* = undefined;
}

export fn e() void {
    const p: *comptime_int = @ptrFromInt(16);
    p.* = undefined;
}

export fn f() void {
    const p: **comptime_int = @ptrFromInt(16); // double pointer ('*comptime_int' is comptime-only)
    p.* = undefined;
}

// error
//
// :3:9: error: cannot store comptime-only type 'fn () void' at runtime
// :3:6: note: operation is runtime due to this pointer
// :7:11: error: expected type 'anyopaque', found '@TypeOf(undefined)'
// :7:11: note: cannot coerce to 'anyopaque'
// :11:12: error: cannot load opaque type 'anyopaque'
// :16:11: error: expected type 'tmp.Opaque', found '@TypeOf(undefined)'
// :16:11: note: cannot coerce to 'tmp.Opaque'
// :14:16: note: opaque declared here
// :21:9: error: cannot store comptime-only type 'comptime_int' at runtime
// :21:6: note: operation is runtime due to this pointer
// :26:9: error: cannot store comptime-only type '*comptime_int' at runtime
// :26:6: note: operation is runtime due to this pointer
