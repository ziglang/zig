fn f() void {
    var x = false;
    if (x)
        gotoFail();
        gotoFail();
}
fn gotoFail() void {}

// error
// backend=stage2
// target=native
//
// :5:9: error: statement indentation mismatched with siblings
// :2:5: note: previous indentation level set here
