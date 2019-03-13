const xxx = struct {
    pub fn bar(self: *xxx) void {}
};
test "bug 704" {
    var x: xxx = undefined;
    x.bar();
}
