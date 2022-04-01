from rpython.rlib.parsing.regex import *
from rpython.translator.c.test.test_genc import compile


def compile_rex(rex):
    fda = rex.make_automaton().make_deterministic()
    fda.optimize()
    fn = fda.make_code()
    return compile(fn, [str])


def test_simple():
    r = StringExpression("hallo")
    nda = r.make_automaton()
    fda = nda.make_deterministic()
    r = fda.get_runner()
    assert not r.recognize("halloc")
    assert not r.recognize("asf;a")
    assert not r.recognize("")
    assert r.recognize("hallo")


def test_string_add():
    r1 = StringExpression("Hello")
    r2 = StringExpression(", World!\n")
    fda = (r1 + r2).make_automaton().make_deterministic()
    r = fda.get_runner()
    assert r.recognize("Hello, World!\n")
    assert not r.recognize("asfdasdfasDF")


def test_kleene():
    r1 = StringExpression("ab")
    r2 = r1.kleene()
    nda = r2.make_automaton()
    fda = nda.make_deterministic()
    r = fda.get_runner()
    assert r.recognize("ab")
    assert r.recognize("abab")
    assert not r.recognize("ababababababb")


def test_or():
    r1 = StringExpression("ab").kleene() | StringExpression("cd").kleene()
    nda = r1.make_automaton()
    fda = nda.make_deterministic()
    r = fda.get_runner()
    assert r.recognize("ab")
    assert r.recognize("cd")
    assert r.recognize("")
    assert r.recognize("cdcdcdcdcdcdcd")
    assert r.recognize("ababababab")

def test_plus():
    r1 = +StringExpression("ab")
    nda = r1.make_automaton()
    fda = nda.make_deterministic()
    r = fda.get_runner()
    assert r.recognize("ab")
    assert not r.recognize("")
    assert not r.recognize("aba")
    assert r.recognize("abababababab")

def test_even_number_of_as():
    a = StringExpression("a")
    b = StringExpression("b")
    c = StringExpression("c")
    rex = (b | c).kleene() | ((b | c).kleene() + a + (b | c).kleene() + a + (b | c).kleene()).kleene()
    nda = rex.make_automaton()
    fda = nda.make_deterministic()
    r = fda.get_runner()
    assert r.recognize("abbabbacbabacbabcbabcba")
    assert r.recognize("bcbcbcccbcbcbcbbbcbcbcbcbc")
    assert not r.recognize("aaa")
    assert not r.recognize("acbbcbcaaccacacccc")
    assert r.recognize("aaaa")


def test_bigger_than_101001():
    O = StringExpression("0")
    l = StringExpression("1")
    d = O | l
    rex = ((l + d + d + d + d + d + +d) | (l + l + d + d + d + d) |
           (l + O + l + l + d + d) | (l + O + l + O + l + d))
    nda = rex.make_automaton()
    fda = nda.make_deterministic()
    fda.optimize()
    r = fda.get_runner()
    assert r.recognize("1000000")
    assert r.recognize("101010")
    assert r.recognize("101100")
    assert r.recognize("110000")
    assert not r.recognize("101000")
    assert not r.recognize("100111")
    recognize = fda.make_code()
    assert recognize("1000000")
    assert recognize("101010")
    assert recognize("101100")
    assert recognize("110000")
    fn = compile_rex(rex)
    assert fn("1000000")
    assert fn("101010")
    assert fn("101100")
    assert fn("110000")


def test_even_length():
    a = StringExpression("a")
    b = StringExpression("b")
    rex = ((a | b) + (a | b)).kleene()
    nfa = rex.make_automaton()
    dfa = nfa.make_deterministic()

def test_something():
    a = StringExpression("a")
    b = StringExpression("b")
    bb = StringExpression("bb")
    l = StringExpression("")
    rex = (b | bb | l) + (a + (b | bb | l)).kleene()
    nfa = rex.make_automaton()
    dfa = nfa.make_deterministic()
    dfa.optimize()

def test_range():
    lower = RangeExpression("a", "z")
    upper = RangeExpression("A", "Z")
    atoms = lower + (upper | lower).kleene()
    nfa = atoms.make_automaton()
    dfa = nfa.make_deterministic()
    dfa.optimize()
    r = dfa.get_runner()
    assert r.recognize("aASsdFAASaSFasdfaSFD")
    assert not r.recognize("ASsdFAASaSFasdfaSFD")
    fn = compile_rex(atoms)
    assert fn("a")
    assert fn("aaaaaAAAAaAAzAzaslwer")

def test_not():
    r = NotExpression(StringExpression("a"))
    nda = r.make_automaton()
    fda = nda.make_deterministic()
    r = fda.get_runner()
    assert not r.recognize("a")
    assert r.recognize("b")
    assert r.recognize("bbbbbbbb")
    assert r.recognize("arstiow2ie34nvarstbbbbbbbb")

def test_empty():
    a = StringExpression("a")
    empty = StringExpression("")
    r = a + (empty | a)
    nfa = r.make_automaton()
    dfa = nfa.make_deterministic()
    dfa.optimize()
    r = dfa.get_runner()
    assert r.recognize("a")
    assert r.recognize("aa")
    assert not r.recognize("ab")
    assert not r.recognize("aaa")

def test_big_example():
    digits = RangeExpression("0", "9")
    lower = RangeExpression("a", "z")
    upper = RangeExpression("A", "Z")
    keywords = ExpressionTag(StringExpression("if") | StringExpression("else") | StringExpression("def") | StringExpression("class"), "keyword")
    underscore = StringExpression("_")
    atoms = ExpressionTag(lower + (upper | lower | digits | underscore).kleene(), "atom")
    vars = underscore | (upper + (upper | lower | underscore | digits)).kleene()
    all = keywords | atoms
    nfa = all.make_automaton()
    dfa = nfa.make_deterministic()
    r = dfa.get_runner()
    dfa.optimize()
    fn = compile_rex(all)
