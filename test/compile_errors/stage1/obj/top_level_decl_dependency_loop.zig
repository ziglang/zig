const a : @TypeOf(b) = 0;
const b : @TypeOf(a) = 0;
export fn entry() void {
    const c = a + b;
    _ = c;
}

// top level decl dependency loop
//
// tmp.zig:2:19: error: dependency loop detected
