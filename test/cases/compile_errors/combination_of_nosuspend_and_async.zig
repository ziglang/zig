export fn entry() void {
    nosuspend {
        const bar = async foo();
        suspend {}
        resume bar;
    }
}
fn foo() void {}

// error
// backend=stage2
// target=native
//
// :4:9: error: suspend inside nosuspend block
// :2:5: note: nosuspend block here
