from rpython.rlib.rshrinklist import AbstractShrinkList

class Item:
    alive = True

class ItemList(AbstractShrinkList):
    def must_keep(self, x):
        return x.alive

def test_simple():
    l = ItemList()
    l2 = [Item() for i in range(150)]
    for x in l2:
        l.append(x)
    assert l.items() == l2
    #
    for x in l2[::2]:
        x.alive = False
    l3 = [Item() for i in range(150 + 16)]
    for x in l3:
        l.append(x)
    assert l.items() == l2[1::2] + l3   # keeps the order

def test_append_dead_items():
    l = ItemList()
    for i in range(150):
        x = Item()
        l.append(x)
        x.alive = False
    assert len(l.items()) <= 16
