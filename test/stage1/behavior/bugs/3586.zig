const NoteParams = struct {};

const Container = struct {
    params: ?NoteParams,
};

test "fixed" {
    var ctr = Container{
        .params = NoteParams{},
    };
}
