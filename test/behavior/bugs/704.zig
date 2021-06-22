const xxx = struct {
    pub fn bar(self: *xxx) void {
        _ = self;
    }
};
test "bug 704" {
    var x: xxx = undefined;
    x.bar();
}
