const Struct = struct { f: bool };
export fn testStruct() void {
    const f: ?Struct = @import("zon/nan.zon");
    _ = f;
}

const Tuple = struct { bool };
export fn testTuple() void {
    const f: ?Tuple = @import("zon/nan.zon");
    _ = f;
}

// error
// imports=zon/nan.zon
//
//nan.zon:1:1: error: expected type '?tmp.Struct'
//tmp.zig:3:32: note: imported here
//nan.zon:1:1: error: expected type '?struct { bool }'
//tmp.zig:9:31: note: imported here
