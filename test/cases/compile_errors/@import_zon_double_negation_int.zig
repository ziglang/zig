export fn entry() void {
    const f: i32 = @import("zon/double_negation_int.zon");
    _ = f;
}

// error
// imports=zon/double_negation_int.zon
//
// double_negation_int.zon:1:1: error: expected number or 'inf' after '-'
