from rpython.tool.flattenrec import FlattenRecursion

def test_flattenrec():
    r = FlattenRecursion()
    seen = set()

    def rec(n):
        if n > 0:
            r(rec, n-1)
        seen.add(n)

    rec(10000)
    assert seen == set(range(10001))
