pub export fn entry() void {
    ((1 + 1)); // makes sure that the doubled grouped_expression does not cause an endless loop in AstGen.
}

// error
//
// :2:9: error: value of type 'comptime_int' ignored
// :2:9: note: all non-void values must be used
// :2:9: note: to discard the value, assign it to '_'
