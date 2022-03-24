export fn entry() void {
    nosuspend {
        const bar = async foo();
        suspend {}
        resume bar;
    }
}
fn foo() void {}

// combination of nosuspend and async
//
// tmp.zig:4:9: error: suspend inside nosuspend block
// tmp.zig:2:5: note: nosuspend block here
