const a = 0x1e-4;
const b = 0x1e+4;
const c = 0x1E-4;
const d = 0x1E+4;

// error
// backend=stage2
// target=native
//
// :1:15: error: sign '-' cannot follow digit 'e' in hex base
// :2:15: error: sign '+' cannot follow digit 'e' in hex base
// :3:15: error: sign '-' cannot follow digit 'E' in hex base
// :4:15: error: sign '+' cannot follow digit 'E' in hex base
