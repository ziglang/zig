export fn foo_array() void {
    comptime {
        var target = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        const slice = target[0..14 :0];
        _ = slice;
    }
}
export fn foo_ptr_array() void {
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target = &buf;
        const slice = target[0..14 :0];
        _ = slice;
    }
}
export fn foo_vector_ConstPtrSpecialBaseArray() void {
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*]u8 = &buf;
        const slice = target[0..14 :0];
        _ = slice;
    }
}
export fn foo_vector_ConstPtrSpecialRef() void {
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*]u8 = @ptrCast(&buf);
        const slice = target[0..14 :0];
        _ = slice;
    }
}
export fn foo_cvector_ConstPtrSpecialBaseArray() void {
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*c]u8 = &buf;
        const slice = target[0..14 :0];
        _ = slice;
    }
}
export fn foo_cvector_ConstPtrSpecialRef() void {
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*c]u8 = @ptrCast(&buf);
        const slice = target[0..14 :0];
        _ = slice;
    }
}
export fn foo_slice() void {
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: []u8 = &buf;
        const slice = target[0..14 :0];
        _ = slice;
    }
}

// error
// backend=stage2
// target=native
//
// :4:33: error: slice sentinel out of bounds: end 14(+1), length 14
// :12:33: error: slice sentinel out of bounds: end 14(+1), length 14
// :20:33: error: slice sentinel out of bounds of reinterpreted memory: end 14(+1), length 14
// :28:33: error: slice sentinel out of bounds of reinterpreted memory: end 14(+1), length 14
// :36:33: error: slice sentinel out of bounds of reinterpreted memory: end 14(+1), length 14
// :44:33: error: slice sentinel out of bounds of reinterpreted memory: end 14(+1), length 14
// :52:33: error: slice sentinel out of bounds: end 14(+1), length 14
