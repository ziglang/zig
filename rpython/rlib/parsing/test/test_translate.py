from rpython.rlib.parsing.lexer import *
# Unused, but needed for some obscure reason
from rpython.rlib.parsing.makepackrat import BacktrackException, Status
from rpython.rlib.parsing.regex import *
from rpython.rlib.parsing.parsing import *
from rpython.translator.c.test.test_genc import compile


class TestTranslateLexer(object):
    def get_lexer(self, rexs, names, ignore=None):
        return Lexer(rexs, names, ignore)

    def test_translate_simple(self):
        digits = RangeExpression("0", "9")
        lower = RangeExpression("a", "z")
        upper = RangeExpression("A", "Z")
        keywords = StringExpression("if") | StringExpression("else") | StringExpression("def") | StringExpression("class")
        underscore = StringExpression("_")
        atoms = lower + (upper | lower | digits | underscore).kleene()
        vars = underscore | (upper + (upper | lower | underscore | digits).kleene())
        integers = StringExpression("0") | (RangeExpression("1", "9") + digits.kleene())
        white = StringExpression(" ")
        l1 = self.get_lexer([keywords, atoms, vars, integers, white], ["KEYWORD", "ATOM", "VAR", "INT", "WHITE"])
        l2 = self.get_lexer([keywords, atoms, vars, integers, white], ["KEYWORD", "ATOM", "VAR", "INT", "WHITE"], ["WHITE"])
        def lex(s, ignore=False):
            if ignore:
                tokens = l2.tokenize(s)
            else:
                tokens = l1.tokenize(s)
            return "-%-".join([t.name for t in tokens])
        res = lex("if A a 12341 0 else").split("-%-")
        assert res == ("KEYWORD WHITE VAR WHITE ATOM WHITE INT WHITE "
                       "INT WHITE KEYWORD").split()
        res = lex("if A a 12341 0 else", True).split("-%-")
        assert res == "KEYWORD VAR ATOM INT INT KEYWORD".split()
        func = compile(lex, [str, bool])
        res = lex("if A a 12341 0 else", False).split("-%-")
        assert res == ("KEYWORD WHITE VAR WHITE ATOM WHITE INT WHITE "
                       "INT WHITE KEYWORD").split()
        res = lex("if A a 12341 0 else", True).split("-%-")
        assert res == "KEYWORD VAR ATOM INT INT KEYWORD".split()


def test_translate_parser():
    r0 = Rule("expression", [["additive", "EOF"]])
    r1 = Rule("additive", [["multitive", "+", "additive"], ["multitive"]])
    r2 = Rule("multitive", [["primary", "*", "multitive"], ["primary"]])
    r3 = Rule("primary", [["(", "additive", ")"], ["decimal"]])
    r4 = Rule("decimal", [[symb] for symb in "0123456789"])
    p = PackratParser([r0, r1, r2, r3, r4], "expression")
    tree = p.parse([Token(c, i, SourcePos(i, 0, i))
                        for i, c in enumerate(list("2*(3+4)") + ["EOF"])])
    data = [Token(c, i, SourcePos(i, 0, i))
                for i, c in enumerate(list("2*(3+4)") + ["EOF"])]
    print tree
    def parse(choose):
        tree = p.parse(data, lazy=False)
        return tree.symbol + " " + "-%-".join([c.symbol for c in tree.children])
    func = compile(parse, [bool])
    res1 = parse(True)
    res2 = func(True)
    assert res1 == res2


def test_translate_compiled_parser():
    r0 = Rule("expression", [["additive", "EOF"]])
    r1 = Rule("additive", [["multitive", "+", "additive"], ["multitive"]])
    r2 = Rule("multitive", [["primary", "*", "multitive"], ["primary"]])
    r3 = Rule("primary", [["(", "additive", ")"], ["decimal"]])
    r4 = Rule("decimal", [[symb] for symb in "0123456789"])
    p = PackratParser([r0, r1, r2, r3, r4], "expression")
    compiler = ParserCompiler(p)
    kls = compiler.compile()
    p = kls()
    tree = p.parse([Token(c, i, SourcePos(i, 0, i))
                        for i, c in enumerate(list("2*(3+4)") + ["EOF"])])
    data = [Token(c, i, SourcePos(i, 0, i))
               for i, c in enumerate(list("2*(3+4)") + ["EOF"])]
    print tree
    p = kls()
    def parse(choose):
        tree = p.parse(data)
        return tree.symbol + " " + "-%-".join([c.symbol for c in tree.children])
    func = compile(parse, [bool])
    res1 = parse(True)
    res2 = func(True)
    assert res1 == res2


def test_translate_ast_visitor():
    from rpython.rlib.parsing.ebnfparse import parse_ebnf, make_parse_function
    regexs, rules, ToAST = parse_ebnf("""
DECIMAL: "0|[1-9][0-9]*";
IGNORE: " ";
additive: multitive ["+!"] additive | <multitive>;
multitive: primary ["*!"] multitive | <primary>; #nonsense!
primary: "(" <additive> ")" | <DECIMAL>;
""")
    parse = make_parse_function(regexs, rules)
    def f():
        tree = parse("(0 +! 10) *! (999 +! 10) +! 1")
        tree = ToAST().visit_additive(tree)
        assert len(tree) == 1
        tree = tree[0]
        return tree.symbol + " " + "-&-".join([c.symbol for c in tree.children])
    res1 = f()
    func = compile(f, [])
    res2 = func()
    assert res1 == res2


def test_translate_pypackrat():
    from rpython.rlib.parsing.pypackrat import PackratParser
    class parser(PackratParser):
        """
        expr:
            additive;
        additive:
            a = additive
            '-'
            b = multitive
            return {'(%s - %s)' % (a, b)}
          | multitive;
        multitive:
            a = multitive
            '*'
            b = simple
            return {'(%s * %s)' % (a, b)}
          | simple;
        simple:
            ('0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9');
        """
    print parser._code
    def parse(s):
        p = parser(s)
        return p.expr()
    res = parse("5-5-5")
    assert res == '((5 - 5) - 5)'
    func = compile(parse, [str])
    res = func("5-5-5")
    assert res == '((5 - 5) - 5)'

def test_translate_pypackrat_regex():
    from rpython.rlib.parsing.pypackrat import PackratParser
    class parser(PackratParser):
        """
        num:
            `([1-9][0-9]*)|0`;
        """
    print parser._code
    def parse(s):
        p = parser(s)
        return p.num()
    res = parse("1234")
    assert res == '1234'
    func = compile(parse, [str])
    res = func("12345")
    assert res == '12345'
    res = func("0")
    assert res == '0'
