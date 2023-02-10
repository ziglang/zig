extern var foo: int = 2;

// error
// backend=stage2
// target=native
//
// :1:23: error: extern variables have no initializers
