export fn entry() void {
    const f: union { foo: void } = @import("zon/void.zon");
    _ = f;
}

// error
// imports=zon/void.zon
//
// void.zon:1:11: error: void literals are not available in ZON
// void.zon:1:11: note: void union payloads can be represented by enum literals
