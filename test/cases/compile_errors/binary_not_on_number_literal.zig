const TINY_QUANTUM_SHIFT = 4;
const TINY_QUANTUM_SIZE = 1 << TINY_QUANTUM_SHIFT;
var block_aligned_stuff: usize = (4 + TINY_QUANTUM_SIZE) & ~(TINY_QUANTUM_SIZE - 1);

export fn entry() usize {
    return @sizeOf(@TypeOf(block_aligned_stuff));
}

// error
// backend=stage2
// target=native
//
// :3:60: error: unable to perform binary not operation on type 'comptime_int'
