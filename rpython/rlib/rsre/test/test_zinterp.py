# minimal test: just checks that (parts of) rsre can be translated

from rpython.rtyper.test.test_llinterp import gengraph, interpret
from rpython.rlib.rsre import rsre_core
from rpython.rlib.rsre.rsre_re import compile

def main(n):
    assert n >= 0
    pattern = [n] * n
    string = chr(n) * n
    rsre_core.search(pattern, string)
    #
    unicodestr = unichr(n) * n
    pattern = rsre_core.CompiledPattern(pattern)
    ctx = rsre_core.UnicodeMatchContext(pattern, unicodestr,
                                        0, len(unicodestr), 0)
    rsre_core.search_context(ctx)
    #
    return 0


def test_gengraph():
    t, typer, graph = gengraph(main, [int])

m = compile("(a|b)aaaaa")

def test_match():
    def f(i):
        if i:
            s = "aaaaaa"
        else:
            s = "caaaaa"
        g = m.match(s)
        if g is None:
            return 3
        return int("aaaaaa" == g.group(0))
    assert interpret(f, [3]) == 1
    assert interpret(f, [0]) == 3

def test_translates():
    from rpython.rlib.rsre import rsre_re
    def f(i):
        if i:
            s = "aaaaaa"
        else:
            s = "caaaaa"
        print rsre_re.match("(a|b)aa", s)
        print rsre_re.match("a{4}", s)
        print rsre_re.search("(a|b)aa", s)
        print rsre_re.search("a{4}", s)
        for x in rsre_re.findall("(a|b)a", s):  print x
        for x in rsre_re.findall("a{2}", s):    print x
        for x in rsre_re.finditer("(a|b)a", s): print x
        for x in rsre_re.finditer("a{2}", s):   print x
        for x in rsre_re.split("(a|b)a", s):    print x
        for x in rsre_re.split("a{2}", s):      print x
        return 0
    interpret(f, [3])  # assert does not crash
