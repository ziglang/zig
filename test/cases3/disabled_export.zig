export fn disabledExternFn() {
    @setFnVisible(this, false);
}

fn callDisabledExternFn() {
    @setFnTest(this);
    disabledExternFn();
}
