import py
import random, sys
from rpython.rlib.rope import *

def make_random_string(operations=10, slicing=True, print_seed=True,
                       unicode=False):
    seed = random.randrange(10000)
    if print_seed:
        print seed
    random.seed(seed)
    st = "abc"
    curr = LiteralStringNode(st)
    if slicing:
        choice = [0, 1, 2]
    else:
        choice = [0, 1]
    for i in range(operations):
        if not unicode:
            a = (chr(random.randrange(ord('a'), ord('z') + 1)) *
                    random.randrange(500))
            node = LiteralStringNode(a)
        else:
            a = (unichr(random.randrange(sys.maxunicode)) *
                        random.randrange(500))
            node = LiteralUnicodeNode(a)
        c = random.choice(choice)
        if c == 0:
            curr = curr + node
            st = st + a
        elif c == 1:
            curr = node + curr
            st = a + st
        else:
            if len(st) < 10:
                continue
            start = random.randrange(len(st) // 3)
            stop = random.randrange(len(st) // 3 * 2, len(st))
            curr = getslice_one(curr, start, stop)
            st = st[start: stop]
    return curr, st


def test_add():
    s = (LiteralStringNode("a" * 32) + LiteralStringNode("bc" * 32) +
         LiteralStringNode("d" * 32) + LiteralStringNode("ef" * 32) +
         LiteralStringNode(""))
    assert s.depth() == 3
    assert s.flatten_string() == "".join([c * 32 for c in "a", "bc", "d", "ef"])
    s = s.rebalance()
    assert s.flatten_string() == "".join([c * 32 for c in "a", "bc", "d", "ef"])

def test_dont_rebalance_again():
    s = (LiteralStringNode("a" * 32) + LiteralStringNode("b" * 32) +
         LiteralStringNode("d" * 32) + LiteralStringNode("e" * 32) +
         LiteralStringNode(""))
    assert s.depth() == 3
    assert s.flatten_string() == "".join([c * 32 for c in "abde"])
    s = s.rebalance()
    assert s.check_balanced()
    assert s.balanced
    assert s.flatten_string() == "".join([c * 32 for c in "abde"])

def test_random_addition_test():
    seed = random.randrange(10000)
    print seed # 4443
    st = "abc"
    curr = LiteralStringNode(st)
    for i in range(1000):
        a = (chr(random.randrange(ord('a'), ord('z') + 1)) *
                random.randrange(100))
        if random.choice([0, 1]):
            curr = curr + LiteralStringNode(a)
            st = st + a
        else:
            curr = LiteralStringNode(a) + curr
            st = a + st
        assert curr.flatten_string() == st
    curr = curr.rebalance()
    assert curr.flatten_string() == st

def test_getitem():
    result = "".join([c * 32 for c in "a", "bc", "d", "ef"])
    s1 = (LiteralStringNode("a" * 32) + LiteralStringNode("bc" * 32) +
          LiteralStringNode("d" * 32) + LiteralStringNode("ef" * 32) +
          LiteralStringNode(""))
    s2 = s1.rebalance()
    for i in range(len(result)):
        for s in [s1, s2]:
            assert s.getchar(i) == result[i]
            assert s.getint(i) == ord(result[i])

def test_getitem_unicode():
    s1, result = make_random_string(200, unicode=True)
    s2 = s1.rebalance()
    for i in range(len(result)):
        for s in [s1, s2]:
            assert s.getunichar(i) == result[i]
            assert s.getint(i) == ord(result[i])

def test_getslice():
    result = "".join([c * 32 for c in "a", "bc", "d", "ef"])
    s1 = (LiteralStringNode("a" * 32) + LiteralStringNode("bc" * 32) +
          LiteralStringNode("d" * 32) + LiteralStringNode("ef" * 32) +
          LiteralStringNode(""))
    s2 = s1.rebalance()
    for s in [s1, s2]:
        for start in range(0, len(result)):
            for stop in range(start, len(result)):
                assert getslice_one(s, start, stop).flatten_string() == result[start:stop]

def test_getslice_bug():
    s1 = LiteralStringNode("/home/arigo/svn/pypy/branch/rope-branch/pypy/bin")
    s2 = LiteralStringNode("/pypy")
    s = s1 + s2
    r = getslice_one(s, 1, 5)
    assert r.flatten_string() == "home"


def test_getslice_step():
    s1 = (LiteralStringNode("abcde") + LiteralStringNode("fghijklm") +
          LiteralStringNode("nopqrstu") + LiteralStringNode("vwxyz") + 
          LiteralStringNode("zyxwvut") + LiteralStringNode("srqpomnlk"))
    s2 = s1.rebalance()
    result = s1.flatten_string()
    assert s2.flatten_string() == result
    for s in [s1, s2]:
        for start in range(0, len(result)):
            for stop in range(start, len(result)):
                for step in range(1, stop - start):
                    assert getslice(s, start, stop, step).flatten_string() == result[start:stop:step]

def test_getslice_step_unicode():
    s1 = (LiteralUnicodeNode(u"\uaaaa") +
          LiteralUnicodeNode(u"\ubbbb" * 5) +
          LiteralUnicodeNode(u"\uaaaa\ubbbb\u1000\u2000") +
          LiteralUnicodeNode(u"vwxyz") + 
          LiteralUnicodeNode(u"zyxwvu\u1234" * 2) +
          LiteralUnicodeNode(u"12355"))
    s2 = s1.rebalance()
    result = s1.flatten_unicode()
    assert s2.flatten_unicode() == result
    for s in [s1, s2]:
        for start in range(0, len(result)):
            for stop in range(start, len(result)):
                for step in range(1, stop - start):
                    assert getslice(s, start, stop, step).flatten_unicode() == result[start:stop:step]

def test_random_addition_and_slicing():
    seed = random.randrange(10000)
    print seed
    random.seed(seed)
    st = "abc"
    curr = LiteralStringNode(st)
    last = None
    all = []
    for i in range(1000):
        a = (chr(random.randrange(ord('a'), ord('z') + 1)) *
                random.randrange(500))
        last = curr
        all.append(curr)
        c = random.choice([0, 1, 2])
        if c == 0:
            curr = curr + LiteralStringNode(a)
            st = st + a
        elif c == 1:
            curr = LiteralStringNode(a) + curr
            st = a + st
        else:
            if len(st) < 10:
                continue
            # get a significant portion of the string
            #import pdb; pdb.set_trace()
            start = random.randrange(len(st) // 3)
            stop = random.randrange(len(st) // 3 * 2, len(st))
            curr = getslice_one(curr, start, stop)
            st = st[start: stop]
        assert curr.flatten_string() == st
    curr = curr.rebalance()
    assert curr.flatten_string() == st

def test_iteration():
    rope, real_st = make_random_string(200)
    iter = ItemIterator(rope)
    for c in real_st:
        c2 = iter.nextchar()
        assert c2 == c
    py.test.raises(StopIteration, iter.nextchar)
    iter = ItemIterator(rope)
    for c in real_st:
        c2 = iter.nextunichar()
        assert c2 == c
    py.test.raises(StopIteration, iter.nextchar)
    iter = ItemIterator(rope)
    for c in real_st:
        c2 = iter.nextint()
        assert c2 == ord(c)
    py.test.raises(StopIteration, iter.nextchar)

def test_iteration_startpos():
    rope, real_st = make_random_string(200)
    for i in range(0, len(real_st), len(real_st) // 20):
        iter = ItemIterator(rope, i)
        x = i
        for c in real_st[i:]:
            x += 1
            c2 = iter.nextchar()
            assert c2 == c
        py.test.raises(StopIteration, iter.nextchar)

def test_iteration_unicode():
    rope, real_st = make_random_string(200, unicode=True)
    iter = ItemIterator(rope)
    for c in real_st:
        c2 = iter.nextunichar()
        assert c2 == c
    py.test.raises(StopIteration, iter.nextchar)
    iter = ItemIterator(rope)
    for c in real_st:
        c2 = iter.nextint()
        assert c2 == ord(c)
    py.test.raises(StopIteration, iter.nextchar)

def test_reverse_iteration():
    rope, real_st = make_random_string(200)
    iter = ReverseItemIterator(rope)
    for c in reversed(real_st):
        c2 = iter.nextchar()
        assert c2 == c
    py.test.raises(StopIteration, iter.nextchar)
    iter = ReverseItemIterator(rope)
    for c in py.builtin.reversed(real_st):
        c2 = iter.nextint()
        assert c2 == ord(c)
    py.test.raises(StopIteration, iter.nextchar)

def test_reverse_iteration_unicode():
    rope, real_st = make_random_string(200, unicode=True)
    iter = ReverseItemIterator(rope)
    for c in reversed(real_st):
        c2 = iter.nextunichar()
        assert c2 == c
    py.test.raises(StopIteration, iter.nextchar)
    iter = ReverseItemIterator(rope)
    for c in reversed(real_st):
        c2 = iter.nextint()
        assert c2 == ord(c)
    py.test.raises(StopIteration, iter.nextchar)

def test_multiply():
    strs = [(LiteralStringNode("a"), "a"), (LiteralStringNode("abc"), "abc"),
            make_random_string(500)]
    times = range(100)
    for i in range(9, 30):
        times.append(i ** 2 - 1)
        times.append(i ** 2)
        times.append(i ** 2 + 1)
        times.append(i ** 2 + 2)
    for r, st in strs:
        for i in times:
            r2 = multiply(r, i)
            assert r2.flatten_string() == st * i

def test_multiply_unicode():
    strs = [(LiteralUnicodeNode(u"\uaaaa"), u"\uaaaa"),
            (LiteralUnicodeNode(u"\uaaaa\ubbbb\ucccc"), u"\uaaaa\ubbbb\ucccc"),
            make_random_string(500)]
    times = range(100)
    for i in range(9, 30):
        times.append(i ** 2 - 1)
        times.append(i ** 2)
        times.append(i ** 2 + 1)
        times.append(i ** 2 + 2)
    for r, st in strs:
        for i in times:
            r2 = multiply(r, i)
            assert r2.flatten_unicode() == st * i

def test_join():
    seps = [(LiteralStringNode("a"), "a"), (LiteralStringNode("abc"), "abc"),
            (LiteralStringNode("d"), "d"), (LiteralStringNode(""), "")]
    l, strs = zip(*[(LiteralStringNode("x"), "x"),
                    (LiteralStringNode("xyz"), "xyz"),
                    (LiteralStringNode("w"), "w")])
    l = list(l)
    for s, st in seps:
        node = join(s, l)
        result1 = node.flatten_string()
        result2 = st.join(strs)
        for i in range(node.length()):
            assert result1[i] == result2[i]

    strings = ['', '<',
               '/home/arigo/svn/pypy/branch/rope-branch/py/code/source.py',
               ':', '213', '>']
    l = [LiteralStringNode(s) for s in strings]
    node = join(LiteralStringNode(""), l)
    assert node.flatten_string() == ''.join(strings)

def test_join_random():
    l, strs = zip(*[make_random_string(10 * i) for i in range(1, 5)])
    l = list(l)
    seps = [(LiteralStringNode("a"), "a"), (LiteralStringNode("abc"), "abc"),
            make_random_string(500)]
    for s, st in seps:
        node = join(s, l)
        result1 = node.flatten_string()
        result2 = st.join(strs)
        for i in range(node.length()):
            assert result1[i] == result2[i]

def test_join_random_unicode():
    l, strs = zip(*[make_random_string(10 * i, unicode=True) for i in range(1, 5)])
    l = list(l)
    seps = [(LiteralStringNode("a"), "a"), (LiteralStringNode("abc"), "abc"),
            make_random_string(500)]
    for s, st in seps:
        node = join(s, l)
        result1 = node.flatten_unicode()
        result2 = st.join(strs)
        for i in range(node.length()):
            assert result1[i] == result2[i]

def test_seekbackward():
    rope = BinaryConcatNode(BinaryConcatNode(LiteralStringNode("abc"),
                                             LiteralStringNode("def")),
                            LiteralStringNode("ghi"))
    iter = SeekableItemIterator(rope)
    for c in "abcdefgh":
        c2 = iter.nextchar()
        assert c2 == c
    for i in range(7):
        iter.seekback(i)
        for c in "abcdefghi"[-1-i:-1]:
            c2 = iter.nextchar()
            assert c2 == c
    c2 = iter.nextchar()
    assert c2 == "i"
    py.test.raises(StopIteration, iter.nextchar)

def test_fringe_iterator():
    ABC = LiteralStringNode("abc")
    DEF = LiteralStringNode("def")
    GHI = LiteralStringNode("ghi")
    rope = BinaryConcatNode(BinaryConcatNode(ABC, DEF), GHI)
    iter = FringeIterator(rope)
    n = iter.next()
    assert n is ABC
    n = iter.next()
    assert n is DEF
    n = iter.next()
    assert n is GHI
    py.test.raises(StopIteration, iter.next)
    iter = FringeIterator(rope)

def test_fringe_iterator_seekforward():
    ABC = LiteralStringNode("abc")
    DEF = LiteralStringNode("def")
    GHI = LiteralStringNode("ghi")
    rope = BinaryConcatNode(BinaryConcatNode(ABC, DEF), GHI)
    iter = FringeIterator(rope)
    n = iter.next()
    assert n is ABC
    i = iter._seekforward(5)
    assert i == 2
    n = iter.next()
    assert n is GHI
    py.test.raises(StopIteration, iter.next)
    iter = FringeIterator(rope)
    i = iter._seekforward(7)
    assert i == 1
    n = iter.next()
    assert n is GHI


def test_seekforward():
    rope = BinaryConcatNode(BinaryConcatNode(LiteralStringNode("abc"),
                                             LiteralStringNode("def")),
                            LiteralStringNode("ghi"))
    rope = rope + rope
    result = rope.flatten_string()
    for j in range(len(result) - 1):
        for i in range(len(result) - 1 - j):
            iter = SeekableItemIterator(rope)
            for c in result[:j]:
                c2 = iter.nextchar()
                assert c2 == c
            iter.seekforward(i)
            for c in result[i + j:]:
                c2 = iter.nextchar()
                assert c2 == c
            py.test.raises(StopIteration, iter.nextchar)

def test_iterbackward():
    rope = BinaryConcatNode(BinaryConcatNode(LiteralStringNode("abc"),
                                             LiteralStringNode("def")),
                            LiteralStringNode("ghi"))
    iter = SeekableItemIterator(rope)
    iter.seekforward(8)
    for c in "abcdefghi"[::-1]:
        c2 = iter.lastchar()
        assert c2 == c
    py.test.raises(StopIteration, iter.lastchar)

def test_find_int():
    rope, st = make_random_string()
    rope = getslice_one(rope, 10, 100)
    st = st[10:100]
    for i in range(len(st)):
        for j in range(i + 1, len(st)):
            c = st[i:j][(j - i) // 2]
            pos = find_int(rope, ord(c), i, j)
            assert pos == st.find(c, i, j)

def test_find_int_bugs():
    r = find_int(LiteralStringNode("ascii"), ord(" "), 0, 5)
    assert r == -1
    r = find_int(LiteralStringNode("a"), ord("a"))
    assert r == 0


def test_restart_positions():
    restart = construct_restart_positions_node(
        BinaryConcatNode(LiteralStringNode("aba"), LiteralStringNode("bcabab")))
    assert restart == [0, 0, 1, 2, 0, 1, 2, 3, 4]
    restart = construct_restart_positions_node(
        BinaryConcatNode(LiteralStringNode("aba"), LiteralStringNode("bcababb")))
    assert restart == [0, 0, 1, 2, 0, 1, 2, 3, 4, 0]
    restart = construct_restart_positions_node(LiteralStringNode("ababb"))
    assert restart == [0, 0, 1, 2, 0]


def test_find():
    node = BinaryConcatNode(LiteralStringNode("aba"),
                            LiteralStringNode("bcabab"))
    pos = find(node, LiteralStringNode("abc"), 0, node.length())
    assert pos == 2
    node = BinaryConcatNode(LiteralStringNode("btffp"),
                            LiteralStringNode("bacbb"))
    pos = find(node, LiteralStringNode("a"), 0, node.length())
    assert pos == 6
    pos = find(node, LiteralStringNode("aaa"), 0, 2)
    assert pos == -1
    pos = find(node, LiteralStringNode("btf"), 0, 3)
    assert pos == 0

def test_find_random():
    py.test.skip("fix me!")
    rope, st = make_random_string(unicode=True)
    rope = getslice_one(rope, 10, 10000)
    st = st[10:10000]
    for i in range(1000):
        searchlength = random.randrange(2, min(len(st) - 1, 1001))
        start = random.randrange(len(st) - searchlength)
        searchstart = random.randrange(len(st))
        searchstop = random.randrange(searchstart, len(st))
        p = st[start:start+searchlength]
        rp = getslice_one(rope, start, start + searchlength)
        pos = find(rope, rp, searchstart, searchstop)
        assert pos == st.find(p, searchstart, searchstop)

def test_find_unicode():
    node = BinaryConcatNode(LiteralUnicodeNode(u"\uaaaa\ubbbb\uaaaa"),
                            LiteralUnicodeNode(u"\ubbbb\ucccc\uaaaa\ubbbb\uaaaa\ubbbb"))
    pos = find(node, LiteralUnicodeNode(u"\uaaaa\ubbbb\ucccc"), 0, node.length())
    assert pos == 2
    node = BinaryConcatNode(LiteralUnicodeNode(u"btffp"),
                            LiteralUnicodeNode(u"b\uaaaacbb"))
    pos = find(node, LiteralUnicodeNode(u"\uaaaa"), 0, node.length())
    assert pos == 6

def test_fromcharlist():
    for i in range(0, 100, 10):
        chars = ["a"] * 50 + ["b"] * i
        node = rope_from_charlist(chars)
        assert node.flatten_string() == "a" * 50  + "b" * i
    assert rope_from_charlist([]).flatten_string() == ""

def test_find_iterator():
    for searchstring in ["abc", "a", "", "x", "xyz", "abababcabcabb"]:
        node = join(LiteralStringNode(searchstring),
                    [LiteralStringNode("cde" * i) for i in range(1, 10)])
        #node.view()
        iter = FindIterator(node, LiteralStringNode(searchstring))
        s = node.flatten_string()
        assert s == searchstring.join(["cde" * i for i in range(1, 10)])
        start = 0
        while 1:
            r2 = s.find(searchstring, start)
            try:
                r1 = iter.next()
            except StopIteration:
                assert r2 == -1
                break
            assert r1 == r2
            start = r2 + max(len(searchstring), 1)


def test_find_iterator_unicode():
    if sys.version_info < (2, 5):
        py.test.skip("bug in unicode.find that was fixed in 2.5")
    for searchstring in [
        u"\uAAAA\uBBBB\uCCCC", u"\uAAAA", u"", u"\u6666",
        u"\u6666\u7777\u8888",
        u"\uAAAA\uBBBB\uAAAA\uBBBB\uAAAA\uBBBB\uCCCC\uAAAA\uBBBB\uCCCC\uAAAA\uBBBB\uBBBB"]:
        node = join(LiteralUnicodeNode(searchstring),
                    [LiteralUnicodeNode(u"\ucccc\udddd" * i)
                        for i in range(1, 10)])
        iter = FindIterator(node, LiteralUnicodeNode(searchstring))
        s = node.flatten_unicode()
        assert s == searchstring.join([u"\ucccc\udddd" * i for i in range(1, 10)])
        start = 0
        while 1:
            r2 = s.find(searchstring, start)
            try:
                r1 = iter.next()
            except StopIteration:
                assert r2 == -1
                break
            assert r1 == r2
            start = r2 + max(len(searchstring), 1)

def test_hash():
    from rpython.rlib.rarithmetic import intmask
    for i in range(10):
        rope, _ = make_random_string()
        if rope.length() == 0:
            assert hash_rope(rope) == -1
            continue
        h = hash_rope(rope)
        x = LiteralStringNode(rope.flatten_string()).hash_part()
        assert x == rope.hash_part()
        x <<= 1
        x ^= rope.getint(0)
        x ^= rope.length()
        assert intmask(x) == h
        # hash again to check for cache effects
        h1 = hash_rope(rope)
        assert h1 == h

def test_hash_collisions_identifiers():
    hashes1 = {}
    hashes2 = {}
    cs = [""] + [chr(i) for i in range(256)]
    cs = "_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    for i in range(50000):
        s = "".join([random.choice(cs)
                         for i in range(random.randrange(1, 15))])
        rope = LiteralStringNode(s)
        h1 = hash_rope(rope)
        hashes1[h1] = hashes1.get(h1, -1) + 1
        h2 = hash(s)
        hashes2[h2] = hashes2.get(h2, -1) + 1
    # hope that there are only ten percent more collisions
    # than with CPython's hash:
    assert sum(hashes1.values()) < sum(hashes2.values()) * 1.10

def test_hash_distribution_tiny_strings():
    hashes = [0 for i in range(256)]
    cs = [""] + [chr(i) for i in range(256)]
    for c1 in cs:
        for c2 in cs:
            rope = LiteralStringNode(c1 + c2)
            h = hash_rope(rope)
            hashes[h & 0xff] += 1
            hashes[(h & 0xff00) >> 8] += 1
            hashes[(h & 0xff0000) >> 16] += 1
    for h in hashes:
        assert h > 300

def test_hash_distribution_small_strings():
    random.seed(42) # prevent randomly failing test
    hashes = [0 for i in range(256)]
    for i in range(20000):
        s = "".join([chr(random.randrange(256))
                         for i in range(random.randrange(1, 15))])
        rope = LiteralStringNode(s)
        h = hash_rope(rope)
        hashes[h & 0xff] += 1
        hashes[(h & 0xff00) >> 8] += 1
        hashes[(h & 0xff0000) >> 16] += 1
    for h in hashes:
        assert h > 180
    print hashes

def test_hash_distribution_big_strings():
    random.seed(42) # prevent randomly failing test
    hashes = [0 for i in range(256)]
    for i in range(4000):
        s = "".join([chr(random.randrange(256))
                         for i in range(random.randrange(20, 500))])
        rope = LiteralStringNode(s)
        h = hash_rope(rope)
        hashes[h & 0xff] += 1
        hashes[(h & 0xff00) >> 8] += 1
        hashes[(h & 0xff0000) >> 16] += 1
    for h in hashes:
        assert h > 29

def test_hash_distribution_identifiers():
    random.seed(42) # prevent randomly failing test
    hashes = [0 for i in range(256)]
    cs = "_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    for i in range(50000):
        s = "".join([random.choice(cs)
                         for i in range(random.randrange(1, 15))])
        rope = LiteralStringNode(s)
        h = hash_rope(rope)
        hashes[h & 0xff] += 1
        hashes[(h & 0xff00) >> 8] += 1
        hashes[(h & 0xff0000) >> 16] += 1
    for h in hashes:
        assert h > 450
    print hashes


def test_hash_part():
    a = "".join([chr(random.randrange(256)) * random.randrange(500)])
    h = None
    for split in range(1, len(a) - 1):
        s1 = LiteralStringNode(a[:split])
        s2 = LiteralStringNode(a[split:])
        s = BinaryConcatNode(s1, s2)
        if h is None:
            h = s.hash_part()
        else:
            # try twice due to caching reasons
            assert s.hash_part() == h
            assert s.hash_part() == h

def test_hash_part_unicode():
    a, st = make_random_string(5, unicode=True)
    h = a.hash_part()
    for split in range(1, len(st) - 1):
        s1 = LiteralUnicodeNode(st[:split])
        s2 = LiteralUnicodeNode(st[split:])
        s = BinaryConcatNode(s1, s2)
        if h is None:
            h = s.hash_part()
        else:
            # try twice due to caching reasons
            assert s.hash_part() == h
            assert s.hash_part() == h

def test_hash_part_more():
    for i in range(100):
        rope, st = make_random_string()
        h = rope.hash_part()
        assert LiteralStringNode(st).hash_part() == h

def test_equality():
    l = [make_random_string() for i in range(3)]
    l.append((LiteralStringNode(""), ""))
    for rope1, st1 in l:
        for rope2, st2 in l:
            assert eq(rope1, rope2) == (st1 == st2)

def test_equality_unicode():
    l = [make_random_string() for i in range(3)]
    l.append((LiteralStringNode(""), ""))
    for rope1, st1 in l:
        for rope2, st2 in l:
            assert eq(rope1, rope2) == (st1 == st2)

def test_compare_random():
    l = [make_random_string() for i in range(3)]
    l.append((LiteralStringNode(""), ""))
    for rope1, st1 in l:
        for rope2, st2 in l:
            c = compare(rope1, rope2)
            if c:
                c = c // abs(c)
            assert c == cmp(st1, st2)

def test_compare_random_unicode():
    l = [make_random_string() for i in range(3)]
    l.append((LiteralStringNode(""), ""))
    for rope1, st1 in l:
        for rope2, st2 in l:
            c = compare(rope1, rope2)
            if c:
                c = c // abs(c)
            assert c == cmp(st1, st2)


def test_power():
    for i in range(0, 60, 13):
        print i
        for j in range(1, 10000, 7):
            assert intmask(i * (1000003**j)) == masked_mul_by_1000003_pow(i, j)


def test_seekable_bug():
    node = BinaryConcatNode(LiteralStringNode("abc"), LiteralStringNode("def"))
    iter = SeekableItemIterator(node)
    c = iter.nextchar(); assert c == "a"
    c = iter.nextchar(); assert c == "b"
    c = iter.nextchar(); assert c == "c"
    iter.seekback(1)
    c = iter.nextchar(); assert c == "c"
    c = iter.nextchar(); assert c == "d"
    c = iter.nextchar(); assert c == "e"
    c = iter.nextchar(); assert c == "f"
    py.test.raises(StopIteration, iter.nextchar)
    node = LiteralStringNode("abcdef")
    iter = SeekableItemIterator(node)
    c = iter.nextchar(); assert c == "a"
    c = iter.nextchar(); assert c == "b"
    c = iter.nextchar(); assert c == "c"
    iter.seekback(3)
    c = iter.nextchar(); assert c == "a"
    c = iter.nextchar(); assert c == "b"
    c = iter.nextchar(); assert c == "c"

def test_strip():
    node = BinaryConcatNode(LiteralStringNode(" \t\n abc "),
                            LiteralStringNode("def    "))
    r = strip(node)
    assert r.flatten_string() == "abc def"
    r = strip(node, left=False)
    assert r.flatten_string() == " \t\n abc def"
    r = strip(node, right=False)
    assert r.flatten_string() == "abc def    "

    node = BinaryConcatNode(LiteralStringNode("aaaYYYYa"),
                            LiteralStringNode("abab"))
    predicate = lambda i: chr(i) in "ab"
    r = strip(node, predicate=predicate)
    assert r.flatten_string() == "YYYY"
    r = strip(node, left=False, predicate=predicate)
    assert r.flatten_string() == "aaaYYYY"
    r = strip(node, right=False, predicate=predicate)
    assert r.flatten_string() == "YYYYaabab"

def test_getrope():
    s1, result = make_random_string(200, unicode=True)
    s2 = s1.rebalance()
    for i in range(len(result)):
        for s in [s1, s2]:
            r = s.getrope(i)
            assert r.length() == 1
            assert r.getint(0) == s.getint(i)
            assert isinstance(r, LiteralNode)
            assert r.getint(0) >= 128 or isinstance(r, LiteralStringNode)
            assert r.getrope(0) is r

def test_split():
    seps = [(LiteralStringNode("a"), "a"), (LiteralStringNode("abc"), "abc"),
            (LiteralStringNode("d"), "d"), (LiteralStringNode(""), "")]
    l, strs = zip(*[(LiteralStringNode("x"), "x"),
                    (LiteralStringNode("xyz"), "xyz"),
                    (LiteralStringNode("w"), "w")])
    l = list(l)
    for s, st in seps:
        node = join(s, l)
        l2 = split(node, s)
        for n1, n2 in zip(l, l2):
            assert n1.flatten_string() == n2.flatten_string()
    for i in range(4):
        l1 = split(LiteralStringNode("ababababa"), LiteralStringNode("b"), i)
        l2 = "ababababa".split("b", i)
        assert len(l1) == len(l2)
        for n, s in zip(l1, l2):
            assert n.flatten_string() == s

def test_splitlines():
    seps = [(LiteralStringNode("\n"), "\n"), (LiteralStringNode("\r"), "\r"),
            (LiteralStringNode("\r\n"), "\r\n")]
    l, strs = zip(*[(LiteralStringNode("xafnarsp"), "xafnarsp"),
                    (LiteralStringNode("xyzaaaa"), "xyzaaaa"),
                    (LiteralStringNode("wxxxx"), "wxxxx")])
    l = list(l)
    for s, st in seps:
        node = join(s, l)
        l2 = splitlines(node)
        for n1, n2 in zip(l, l2):
            assert n1.flatten_string() == n2.flatten_string()
    for keepends in [True, False]:
        l1 = splitlines(LiteralStringNode("ab\nab\n\raba\rba"), keepends)
        l2 = "ab\nab\n\raba\rba".splitlines(keepends)
        assert len(l1) == len(l2)
        for n, s in zip(l1, l2):
            assert n.flatten_string() == s

def test_rope_from_unicode():
    node = rope_from_unicode(u"aaabbbbbcccdddeeefffggggnnn")
    assert node.is_bytestring()
    assert node.is_ascii()
    node = rope_from_unicode(u"a" * 30 + u"\ufffd" * 30 + "x" * 30)
    assert node.length() == 90
    assert not node.is_ascii()
    assert not node.is_bytestring()

def test_encode():
    node = LiteralStringNode("abc")
    assert unicode_encode_ascii(node) is node
    assert unicode_encode_latin1(node) is node
    assert unicode_encode_utf8(node) is node
    node = LiteralStringNode("abc\xff")
    assert unicode_encode_ascii(node) is None
    assert unicode_encode_latin1(node) is node
    assert unicode_encode_utf8(node).s == 'abc\xc3\xbf'
    node = LiteralUnicodeNode(u"\uffffab")
    assert unicode_encode_ascii(node) is None
    assert unicode_encode_latin1(node) is None
    assert unicode_encode_utf8(node).s == '\xef\xbf\xbfab'
    node = BinaryConcatNode(LiteralStringNode("abc"),
                            LiteralUnicodeNode(u"\uffffab"))
    assert unicode_encode_ascii(node) is None
    assert unicode_encode_latin1(node) is None
    res = unicode_encode_utf8(node)
    assert res.left is node.left
    assert res.right.s == '\xef\xbf\xbfab'

def test_decode():
    node = LiteralStringNode("abc")
    assert str_decode_ascii(node) is node
    assert str_decode_latin1(node) is node
    assert str_decode_utf8(node) is node
    node = LiteralStringNode("abc\xff")
    assert str_decode_ascii(node) is None
    assert str_decode_latin1(node) is node

def test_decode_utf8():
    # bad data
    node = LiteralStringNode("\xd7\x50")
    assert str_decode_utf8(node) is None
    node = LiteralStringNode("\xf0\x90\x91")
    assert str_decode_utf8(node) is None

    # correct data in one node
    node = LiteralStringNode('\xef\xbf\xbfab')
    assert str_decode_utf8(node).u == u"\uffffab"

    # binary node, left node can be decoded
    node = BinaryConcatNode(LiteralStringNode('\xef\xbf\xbfab'),
                            LiteralStringNode('\xef\xbf\xbfab'))
    res = str_decode_utf8(node)
    assert res.left.u == u"\uffffab"
    assert res.right.u == u"\uffffab"

    # binary node, left node alone cannot be decoded
    node = BinaryConcatNode(LiteralStringNode('\xef'),
                            LiteralStringNode('\xbf\xbfab'))
    res = str_decode_utf8(node)
    assert res.u == u"\uffffab"

    # binary node, left node cannot be decoded, bad data
    node = BinaryConcatNode(LiteralStringNode("\xf0\x90"),
                            LiteralStringNode("\x91"))
    assert str_decode_utf8(node) is None

    # binary node, incomplete data
    node = BinaryConcatNode(LiteralStringNode('ab\xef'),
                            LiteralStringNode('\xbf'))
    
    res = str_decode_utf8(node)
    assert res is None

def test_multiply_result_needs_no_rebalancing():
    r1 = multiply(LiteralStringNode("s"), 2**31 - 2)
    assert r1.rebalance() is r1
