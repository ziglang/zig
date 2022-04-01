from rpython.rlib.parsing.deterministic import *
from rpython.translator.c.test.test_genc import compile


def test_DFA_simple():
    a = DFA()
    s0 = a.add_state("start")
    s1 = a.add_state()
    s2 = a.add_state(final=True)
    a[s0, "a"] = s0
    a[s0, "c"] = s1
    a[s0, "b"] = s2
    a[s1, "b"] = s2
    r = DFARunner(a)
    assert r.recognize("aaaaaaaaaab")
    assert r.recognize("b")
    assert not r.recognize("a")
    assert not r.recognize("xyza")
    assert r.recognize("aaaacb")
    recognize = a.make_code()
    assert recognize("aaaaaaaaaab")
    assert recognize("b")
    assert py.test.raises(LexerError, "recognize('a')")
    assert py.test.raises(LexerError, "recognize('xzya')")
    assert recognize("aaaacb")


def test_compile_recognizer():
    a = DFA()
    s0 = a.add_state("start")
    s1 = a.add_state()
    s2 = a.add_state(final=True)
    a[s0, "a"] = s0
    a[s0, "c"] = s1
    a[s0, "b"] = s2
    a[s1, "b"] = s2
    recognize = a.make_code()
    cfn = compile(recognize, [str])
    assert cfn("aaaaaaaaaab")
    assert cfn("b")
    assert cfn("aaaacb")


def test_NFA_simple():
    a = NFA()
    z0 = a.add_state("z0", start=True)
    z1 = a.add_state("z1", start=True)
    z2 = a.add_state("z2", final=True)
    a.add_transition(z0, z0, "0")
    a.add_transition(z0, z1, "0")
    a.add_transition(z0, z0, "1")
    a.add_transition(z1, z2, "0")
    r = SetNFARunner(a)
    assert r.recognize("0")
    assert r.recognize("100")
    assert r.recognize("00")
    assert r.recognize("110100100100100")
    assert not r.recognize("11010010010010")
    assert not r.recognize("")
    assert not r.recognize("100101101111")
    r = BacktrackingNFARunner(a)
    assert r.recognize("0")
    assert r.recognize("100")
    assert r.recognize("00")
    assert r.recognize("110100100100100")
    assert not r.recognize("11010010010010")
    assert not r.recognize("")
    assert not r.recognize("100101101111")


def test_NFA_with_epsilon():
    a = NFA()
    z0 = a.add_state("z0", start=True)
    z1 = a.add_state("z1")
    z2 = a.add_state("z2", final=True)
    a.add_transition(z0, z1)
    a.add_transition(z0, z1, "a")
    a.add_transition(z1, z2, "b")
    r = SetNFARunner(a)
    assert r.recognize("b")
    assert r.recognize("ab")
    assert not r.recognize("cab")
    r = BacktrackingNFARunner(a)
    assert r.recognize("b")
    assert r.recognize("ab")
    assert not r.recognize("cab")
    fda = a.make_deterministic()
    r = fda.get_runner()


def test_NFA_to_DFA_simple():
    a = NFA()
    z0 = a.add_state("z0", start=True)
    z1 = a.add_state("z1", start=True)
    z2 = a.add_state("z2", final=True)
    a.add_transition(z0, z0, "0")
    a.add_transition(z0, z1, "0")
    a.add_transition(z0, z0, "1")
    a.add_transition(z1, z2, "0")
    fda = a.make_deterministic()
    r = DFARunner(fda)
    assert r.recognize("0")
    assert r.recognize("100")
    assert r.recognize("00")
    assert r.recognize("110100100100100")
    assert not r.recognize("11010010010010")
    assert not r.recognize("")
    assert not r.recognize("100101101111")


def test_simplify():
    a = DFA()
    z0 = a.add_state("z0")
    z1 = a.add_state("z1")
    z2 = a.add_state("z2")
    z3 = a.add_state("z3")
    z4 = a.add_state("z4", final=True)
    a[z0, "1"] = z2
    a[z0, "0"] = z1
    a[z1, "1"] = z2
    a[z1, "0"] = z4
    a[z2, "1"] = z2
    a[z2, "0"] = z3
    a[z3, "0"] = z4
    a[z3, "1"] = z0
    a[z4, "0"] = z4
    a[z4, "1"] = z4
    a.optimize()
    r = a.get_runner()
    assert r.recognize("11111100")
    assert r.recognize("01001010011100")
    assert not r.recognize("0")
    assert r.recognize("00")
    assert not r.recognize("111111011111111")
    newa = eval(repr(a))
    r = newa.get_runner()
    assert r.recognize("11111100")
    assert r.recognize("01001010011100")
    assert not r.recognize("0")
    assert r.recognize("00")
    assert not r.recognize("111111011111111")


def test_something():
    a = NFA()
    z0 = a.add_state("z0", start=True, final=True)
    z1 = a.add_state("z1")
    z2 = a.add_state("z2", start=True, final=True)
    a.add_transition(z0, z1, "a")
    a.add_transition(z1, z0, "b")
    a.add_transition(z1, z1, "a")
    a.add_transition(z1, z1, "b")
    a.add_transition(z1, z2, "a")
    a.make_deterministic()

def test_compress_char_set():
    import string
    assert compress_char_set("ace") == [('a', 1), ('c', 1), ('e', 1)]
    assert compress_char_set("abcdefg") == [('a', 7)]
    assert compress_char_set("ABCabc") == [('A', 3), ('a', 3)]
    assert compress_char_set("zycba") == [('a',3), ('y',2)]
    assert compress_char_set(string.ascii_letters) == [('A', 26), ('a', 26)]
    assert compress_char_set(string.printable) == [(' ', 95), ('\t', 5)]

def test_make_nice_charset_repr():
    import string
    assert make_nice_charset_repr("ace") == 'ace'
    assert make_nice_charset_repr("abcdefg") == 'a-g'
    assert make_nice_charset_repr("ABCabc") == 'A-Ca-c'
    assert make_nice_charset_repr("zycba") == 'a-cyz'
    assert make_nice_charset_repr(string.ascii_letters) == 'A-Za-z'

    # this next one is ugly because it's being generated from a dict, so the order is not stable
    nice = make_nice_charset_repr(string.printable)
    chunks = ['A-Z','a-z','0-9','\\t','\\x0b','\\n','\\r','\\x0c','\\\\','\\-']
    chunks += list('! #"%$\'&)(+*,/.;:=<?>@[]_^`{}|~')
    for chunk in chunks:
        assert chunk in nice  # make sure every unit is in there, in some order
    assert len(''.join(chunks))==len(nice)  # make sure that's all that's in there
