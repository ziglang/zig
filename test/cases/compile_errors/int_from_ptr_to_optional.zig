comptime {
    const num: usize = 4;
    const y: ?*const usize = &num;
    _ = @intFromPtr(y);
}

// error
// backend=stage2
// target=native
//
// :4:9: error: unable to evaluate comptime expression
// :4:21: note: operation is runtime due to this operand
// :1:1: note: 'comptime' keyword forces comptime evaluation
