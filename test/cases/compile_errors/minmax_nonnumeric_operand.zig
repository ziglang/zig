// zig fmt: off
comptime { _ = @min(0, u32); } // type
comptime { _ = @max(0, {}); } // void
comptime { _ = @min(0, false); } // boolean
comptime { _ = @min(0, &@as(u8, 0)); } // pointer
comptime { _ = @max(0, [0]u8{}); } // array
comptime { _ = @min(0, Struct{}); } // struct
comptime { _ = @max(0, null); } // null
comptime { _ = @min(0, @as(?u8, 0)); } // nullable
comptime { _ = @max(0, @as(error{}!u8, 0)); } // error union
comptime { _ = @min(0, error.Foo); } // error set
comptime { _ = @max(0, Enum.foo); } // enum
comptime { _ = @min(0, Union{ .foo = {} }); } // union
comptime { _ = @max(0, struct { fn func() u8 { return 42; }}.func); }
comptime { _ = @max(0, .foo); } // enum literal

const Struct = struct {};
const Enum = enum { foo };
const Union = union { foo: void };

// error
//
// :2:24: error: expected number, found 'type'
// :3:24: error: expected number, found 'void'
// :4:24: error: expected number, found 'bool'
// :5:24: error: expected number, found '*const u8'
// :6:29: error: expected number, found '[0]u8'
// :7:30: error: expected number, found 'tmp.Struct'
// :17:16: note: struct declared here
// :8:24: error: expected number, found '@TypeOf(null)'
// :9:24: error: expected number, found '?u8'
// :10:24: error: expected number, found 'error{}!u8'
// :11:24: error: expected number, found 'error{Foo}'
// :12:28: error: expected number, found 'tmp.Enum'
// :18:14: note: enum declared here
// :13:29: error: expected number, found 'tmp.Union'
// :19:15: note: union declared here
// :14:61: error: expected number, found 'fn () u8'
// :15:25: error: expected number, found '@EnumLiteral()'
