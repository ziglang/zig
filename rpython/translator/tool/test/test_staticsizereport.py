from rpython.translator.c.test.test_genc import compile
from rpython.translator.tool.staticsizereport import group_static_size, guess_size
from rpython.rtyper.lltypesystem import llmemory, lltype, rffi

class TestStaticSizeReport(object):
    def test_simple(self):
        class A:
            def __init__(self, n):
                if n:
                    self.next = A(n - 1)
                else:
                    self.next = None
                self.key = repr(self)
        a = A(100)
        def f(x):
            if x:
                return a.key
            return a.next.key
        func = compile(f, [int])
        size, num = group_static_size(func.builder.db,
                                      func.builder.db.globalcontainers())
        for key, value in num.iteritems():
            if "staticsizereport.A" in str(key) and "vtable" not in str(key):
                assert value == 101

    def test_large_dict(self):
        d = {}
        d_small = {1:2}
        fixlist = [x for x in range(100)]
        dynlist = [x for x in range(100)]
        test_dict = dict(map(lambda x: (x, hex(x)), range(256, 4096)))
        reverse_dict = dict(map(lambda (x,y): (y,x), test_dict.items()))
        class wrap:
            pass
        for x in xrange(100):
            i = wrap()
            i.x = x
            d[x] = i
        def f(x):
            if x > 42:
                dynlist.append(x)
            return d[x].x + fixlist[x] + d_small[x] + reverse_dict[test_dict[x]]
        func = compile(f, [int])
        db = func.builder.db
        gcontainers = list(db.globalcontainers())
        t = db.translator
        rtyper = t.rtyper
        get_container = lambda x: rtyper.getrepr(t.annotator.bookkeeper.immutablevalue(x)).convert_const(x)._obj
        dictvalnode = db.getcontainernode(get_container(d))
        dictvalnode2 = db.getcontainernode(get_container(d_small))
        fixarrayvalnode = db.getcontainernode(get_container(fixlist))
        dynarrayvalnode = db.getcontainernode(get_container(dynlist))
        test_dictnode = db.getcontainernode(get_container(test_dict))
        reverse_dictnode = db.getcontainernode(get_container(reverse_dict))

        S = rffi.sizeof(lltype.Signed)
        P = rffi.sizeof(rffi.VOIDP)
        B = 1 # bool
        assert guess_size(func.builder.db, dictvalnode, set()) > 100
        assert guess_size(func.builder.db, dictvalnode2, set()) == (
            (4 * S + 2 * P) +     # struct dicttable
            # (S + 16) +          # indexes, length 16, but is absent here
            (S + S + S))          # entries, length 1
        r_set = set()
        dictnode_size = guess_size(db, test_dictnode, r_set)
        assert dictnode_size == (
            (4 * S + 2 * P) +      # struct dicttable
            # (S + 2 * 8192) +     # indexes, length 8192, rffi.USHORT,
                                   # but is absent here during translation
            (S + (S + S) * 3840) + # entries, length 3840
            (S + S + 6) * 3840)    # 3840 strings with 5 chars each (+1 final)
        assert guess_size(func.builder.db, fixarrayvalnode, set()) == 100 * rffi.sizeof(lltype.Signed) + 1 * rffi.sizeof(lltype.Signed)
        assert guess_size(func.builder.db, dynarrayvalnode, set()) == 100 * rffi.sizeof(lltype.Signed) + 2 * rffi.sizeof(lltype.Signed) + 1 * rffi.sizeof(rffi.VOIDP)

