export fn foo_array() void {
    comptime {
        var target = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        const slice = target[0..15 :1];
        _ = slice;
    }
}
export fn foo_ptr_array() void {
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target = &buf;
        const slice = target[0..15 :0];
        _ = slice;
    }
}
export fn foo_vector_ConstPtrSpecialBaseArray() void {
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*]u8 = &buf;
        const slice = target[0..15 :0];
        _ = slice;
    }
}
export fn foo_vector_ConstPtrSpecialRef() void {
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*]u8 = @ptrCast(&buf);
        const slice = target[0..15 :0];
        _ = slice;
    }
}
export fn foo_cvector_ConstPtrSpecialBaseArray() void {
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*c]u8 = &buf;
        const slice = target[0..15 :0];
        _ = slice;
    }
}
export fn foo_cvector_ConstPtrSpecialRef() void {
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*c]u8 = @ptrCast(&buf);
        const slice = target[0..15 :0];
        _ = slice;
    }
}
export fn foo_slice() void {
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: []u8 = &buf;
        const slice = target[0..15 :0];
        _ = slice;
    }
}

// error
// backend=stage2
// target=native
//
// :4:33: error: slice end index out of bounds: end 15, length 14
// :12:33: error: slice end index out of bounds: end 15, length 14
// :20:37: error: slice sentinel index out of bounds of containing declaration: index 15, length 15
// :28:37: error: slice sentinel index out of bounds of containing declaration: index 15, length 15
// :36:37: error: slice sentinel index out of bounds of containing declaration: index 15, length 15
// :44:37: error: slice sentinel index out of bounds of containing declaration: index 15, length 15
// :52:33: error: slice end index out of bounds: end 15, length 14
