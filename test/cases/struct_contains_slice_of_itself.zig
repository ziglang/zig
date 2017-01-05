const assert = @import("std").debug.assert;

const Node = struct {
    payload: i32,
    children: []Node,
};

fn structContainsSliceOfItself() {
    @setFnTest(this);

    var nodes = []Node {
        Node {
            .payload = 1,
            .children = []Node{},
        },
        Node {
            .payload = 2,
            .children = []Node{},
        },
        Node {
            .payload = 3,
            .children = []Node{
                Node {
                    .payload = 31,
                    .children = []Node{},
                },
                Node {
                    .payload = 32,
                    .children = []Node{},
                },
            },
        },
    };
    const root = Node {
        .payload = 1234,
        .children = nodes[0...],
    };
    assert(root.payload == 1234);
    assert(root.children[0].payload == 1);
    assert(root.children[1].payload == 2);
    assert(root.children[2].payload == 3);
    assert(root.children[2].children[0].payload == 31);
    assert(root.children[2].children[1].payload == 32);
}
