""" test file to experiment with a an adapted CPython grammar """

import py
from rpython.rlib.parsing.lexer import Lexer, SourcePos, Token
from rpython.rlib.parsing.deterministic import LexerError
from rpython.rlib.parsing.tree import Nonterminal, Symbol, RPythonVisitor
from rpython.rlib.parsing.parsing import PackratParser, Symbol, ParseError, Rule
from rpython.rlib.parsing.ebnfparse import parse_ebnf, make_parse_function

grammar = py.path.local(__file__).dirpath().join("pygrammar.txt").read(mode='rt')


def test_parse_grammar():
    _, rules, ToAST = parse_ebnf(grammar)

def test_parse_python_args():
    regexs, rules, ToAST = parse_ebnf("""
IGNORE: " ";
NAME: "[a-zA-Z_]*";
NUMBER: "0|[1-9][0-9]*";
parameters: ["("] >varargslist<? [")"];
varargslist: (fpdef ("=" test)? [","])* star_or_starstarargs |
             fpdef ("=" test)? ([","] fpdef ("=" test)?)* [","]?;
star_or_starstarargs:  "*" NAME [","] "**" NAME | "*" NAME | "**" NAME;
fpdef: <NAME> | "(" <fplist> ")";
fplist: fpdef ([","] fpdef)* [","]?;
test: NUMBER;
    """)
    parse = make_parse_function(regexs, rules)
    t = parse("(a)").visit(ToAST())[0]
    t = parse("(a,)").visit(ToAST())[0]
    t = parse("(a,b,c,d)").visit(ToAST())[0]
    t = parse("(a,b,c,d,)").visit(ToAST())[0]
    t = parse("((a, b, c),b,c,d,)").visit(ToAST())[0]
    t = parse("((a, b, (d, e, (f, g))), b, *args, **kwargs)").visit(ToAST())[0]
    t = parse("((a, b, c),b,c,d,*args)").visit(ToAST())[0]
    t = parse("((a, b, c),b,c,d,**kwargs)").visit(ToAST())[0]
    t = parse("((a, b, c),b,c,d,*args, **args)").visit(ToAST())[0]
    t = parse("()").visit(ToAST())[0]
    t = parse("(*args, **args)").visit(ToAST())[0]
    t = parse("(a=1)").visit(ToAST())[0]
    t = parse("(a=2,)").visit(ToAST())[0]
    t = parse("(a,b,c,d=3)").visit(ToAST())[0]
    t = parse("(a,b,c,d=4,)").visit(ToAST())[0]
    t = parse("((a, b, c),b,c,(c, d)=1,)").visit(ToAST())[0]
    t = parse("((a, b, c),b,c,d=1,*args)").visit(ToAST())[0]
    t = parse("((a, b, c),b,c,d=2,**kwargs)").visit(ToAST())[0]
    t = parse("((a, b, c),b,c,(c, d)=4,*args, **args)").visit(ToAST())[0]
    t = parse("(self, a, b, args)").visit(ToAST())[0]
    
def test_parse_funcdef():
    regexs, rules, ToAST = parse_ebnf("""
IGNORE: " ";
NAME: "[a-zA-Z_]*";
NUMBER: "0|[1-9][0-9]*";
funcdef: "def" NAME parameters ":" suite;
parameters: ["("] >varargslist< [")"] | ["("] [")"];
varargslist: (fpdef ("=" test)? ",")* star_or_starstarargs |
             fpdef ("=" test)? ("," fpdef ("=" test)?)* ","?;
star_or_starstarargs:  "*" NAME "," "**" NAME | "*" NAME | "**" NAME;
fpdef: NAME | "(" fplist ")";
fplist: fpdef ("," fpdef)* ","?;
test: NUMBER;
suite: simple_stmt | ["NEWLINE"] ["INDENT"] stmt+ ["DEDENT"];
simple_stmt: stmt;
stmt: "pass";
    """)
    parse = make_parse_function(regexs, rules)
    t = parse("def f(a): NEWLINE INDENT pass DEDENT").visit(ToAST())[0]


class TestParser(object):
    def setup_class(cls):
        from rpython.rlib.parsing.parsing import PackratParser
        regexs, rules, ToAST = parse_ebnf(grammar)
        cls.ToAST = ToAST()
        cls.parser = PackratParser(rules, rules[0].nonterminal)
        cls.regexs = regexs
        names, regexs = zip(*regexs)
        cls.lexer = Lexer(list(regexs), list(names))

    def parse(self, source):
        tokens = list(self.tokenize(source))
        s = self.parser.parse(tokens)
        return s

    def tokenize(self, source):
        # use tokenize module but rewrite tokens slightly
        import tokenize, cStringIO
        pos = 0
        readline = cStringIO.StringIO(source).readline
        for token in tokenize.generate_tokens(readline):
            typ, s, (row, col), _, line = token
            row -= 1
            pos += len(s)
            typ = tokenize.tok_name[typ]
            if typ == "ENDMARKER":
                typ = s = "EOF"
            elif typ == "NL":
                continue
            elif typ == "COMMENT":
                continue
            try:
                tokens = self.lexer.tokenize(s, eof=False)
                if len(tokens) == 1:
                    yield tokens[0]
                    continue
            except LexerError:
                pass
            yield Token(typ, s, SourcePos(pos, row, col))


    def test_simple(self):
        t = self.parse("""
def f(x, null=0):
    if x >= null:
        return null + x
    else:
        pass
        return null - x
        """)
        t = self.ToAST.transform(t)

    def test_class(self):
        t = self.parse("""
class A(object):
    def __init__(self, a, b, *args):
        self.a = a
        self.b = b
        if args:
            self.len = len(args)
            self.args = [a, b] + list(args)

    def diagonal(self):
        return (self.a ** 2 + self.b ** 2) ** 0.5
        """)
        t = self.ToAST.transform(t)

    def test_while(self):
        t = self.parse("""
def f(x, null=0):
    i = null
    result = 0
    while i < x:
        result += i
        i += 1
        if result % 625 == 13:
            break
    else:
        return result - 15
    return result
        """)
        t = self.ToAST.transform(t)

    def test_comment(self):
        t = self.parse("""
def f(x):
    # this does some fancy stuff
    return x
""")
        t = self.ToAST.transform(t)

    def test_parse_print(self):
        t = self.parse("""
print >> f, a, b, c,
print >> f, a, b
print >> f
print 
print 1
print 1, 2
print 1, 2,  
""")
        t = self.ToAST.transform(t)
 
    def test_assignment(self):
        t = self.parse("""
a = 1
a = b = c
(a, b) = c
a += 1
b //= 3
""")
        t = self.ToAST.transform(t)

    def test_lists(self):
        t = self.parse("""
l0 = [1, 2, [3, 4, [5, []]]]
l1 = [i for i in range(10)]
l1 = [i for i in range(10) if i ** 2 % 3 == 0]
l2 = [ ]
l3 = [     ]
l4 = []
""")
        t = self.ToAST.transform(t)

    def test_dicts(self):
        t = self.parse("""
{1: 2, 2: {1: 3},}
{}
""")
        t = self.ToAST.transform(t)

    def test_calls(self):
        #XXX horrible trees
        t = self.parse("""
f(a)(b)(c)
f() ** 2
f(x) * 2
f(x, y, z, *args) + 2
f(x, y, abc=34, *arg, **kwargs)
""")
        t = self.ToAST.transform(t)

    def test_trailers(self):
        py.test.skip("in progress")
        t = self.parse("""
(a + b).foo[1 + i - j:](32, *args)
""")
        t = self.ToAST.transform(t)

    def test_errors(self):
        source = """
def f(x):
    if a:
        pass
    else:
        pass
        else:
            pass
"""
        excinfo = py.test.raises(ParseError, self.parse, source)
        error = excinfo.value.errorinformation
        msg = excinfo.value.nice_error_message("<stdin>", source)

    def test_precedence(self):
        source = """
a = 1 - 2 - 3
"""
        t = self.parse(source)
        t = self.ToAST.transform(t)

    def test_parse_this(self):
        filename = __file__
        if filename.lower().endswith('.pyc'):
            filename = filename[:-1]
        s = py.path.local(filename).read()
        t = self.parse(s)
        t = self.ToAST.transform(t)

    def test_parsing(self):
        s = py.path.local(__file__).dirpath().dirpath().join("parsing.py").read()
        t = self.parse(s)
        t = self.ToAST.transform(t)

