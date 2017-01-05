const assert = @import("std").debug.assert;

fn gotoAndLabels() {
    @setFnTest(this);

    gotoLoop();
    assert(goto_counter == 10);
}
fn gotoLoop() {
    var i: i32 = 0;
    goto cond;
loop:
    i += 1;
cond:
    if (!(i < 10)) goto end;
    goto_counter += 1;
    goto loop;
end:
}
var goto_counter: i32 = 0;



fn gotoLeaveDeferScope() {
    @setFnTest(this);

    testGotoLeaveDeferScope(true);
}
fn testGotoLeaveDeferScope(b: bool) {
    var it_worked = false;

    goto entry;
exit:
    if (it_worked) {
        return;
    }
    @unreachable();
entry:
    defer it_worked = true;
    if (b) goto exit;
}
