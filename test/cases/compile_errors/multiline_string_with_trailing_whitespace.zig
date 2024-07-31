const S =
    \\Hello, world    
; //              ^^^^^ trailing whitespace here
// error
// backend=stage2
// target=native
//
// :2:5: error: multiline string cannot contain trailing whitespace
