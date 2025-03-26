fn main() void {}

// error
// backend=stage2
// target=x86_64-linux
// output_mode=Exe
//
// : error: 'main' is not marked 'pub'
// :1:1: note: declared here
// : note: called from here
// : note: called from here
