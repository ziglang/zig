import py
from rpython.rlib.parsing.tree import Nonterminal, Symbol, RPythonVisitor
from rpython.rlib.parsing.parsing import PackratParser, Symbol, ParseError, Rule
from rpython.rlib.parsing.ebnfparse import parse_ebnf, make_parse_function
from rpython.rlib.parsing.test.test_parse import EvaluateVisitor

from sets import Set

def test_simple():
    regexs, rules, transformer = parse_ebnf("""
IGNORE: " ";
DECIMAL: "0|[1-9][0-9]*";
additive: multitive "+" additive | multitive;
multitive: primary "*" multitive | primary; #nonsense!
# the following too!
primary: "(" additive ")" | DECIMAL;
""")
    class MyEvalVisitor(EvaluateVisitor):
        def visit_primary(self, node):
            if len(node.children) == 3:
                return node.children[1].visit(self)
            return int(node.children[0].additional_info)
    parse = make_parse_function(regexs, rules)
    tree = parse("0 + 10 + 999")
    assert tree.visit(MyEvalVisitor()) == 10 + 999
    tree = parse("22 * 12 + 44)")
    r = tree.visit(MyEvalVisitor())
    assert r == 22 * 12 + 44
    tree = parse("2*(3+5*2*(2+61))")
    assert tree.visit(MyEvalVisitor()) == 2 * (3 + 5 * 2 * (2 + 61))
    tree = parse("12 + 4 * 5)")

def test_long_inline_quotes():
    regexs, rules, transformer = parse_ebnf("""
DECIMAL: "0|[1-9][0-9]*";
IGNORE: " ";
additive: multitive "+!" additive | multitive;
multitive: primary "*!" multitive | primary; #nonsense!
primary: "(" additive ")" | DECIMAL;
""")
    class MyEvalVisitor(EvaluateVisitor):
        def visit_primary(self, node):
            if len(node.children) == 3:
                return node.children[1].visit(self)
            return int(node.children[0].additional_info)
    parse = make_parse_function(regexs, rules)
    tree = parse("0 +! 10 +! 999")
    assert tree.visit(MyEvalVisitor()) == 10 + 999

def test_toast():
    regexs, rules, ToAST = parse_ebnf("""
DECIMAL: "0|[1-9][0-9]*";
IGNORE: " ";
additive: multitive ["+!"] additive | <multitive>;
multitive: primary ["*!"] multitive | <primary>; #nonsense!
primary: "(" <additive> ")" | <DECIMAL>;
""")
    parse = make_parse_function(regexs, rules)
    tree = parse("(0 +! 10) *! (999 +! 10) +! 1")
    tree = tree.visit(ToAST())[0]
    assert len(tree.children) == 2
    assert tree.children[0].children[0].symbol == "additive"
    assert tree.children[1].symbol == "DECIMAL"

def test_eof():
    grammar = """
DECIMAL: "0|[1-9][0-9]*";
IGNORE: " ";
expr: additive0_9 EOF;
additive0_9: multitive "+!" additive0_9 | multitive;
multitive: primary "*!" multitive | primary; #nonsense!
primary: "(" additive0_9 ")" | DECIMAL;
"""
    regexs, rules, ToAST = parse_ebnf(grammar)
    class MyEvalVisitor(EvaluateVisitor):
        def visit_primary(self, node):
            if len(node.children) == 3:
                return node.children[1].visit(self)
            return int(node.children[0].additional_info)
        def visit_expr(self, node):
            return node.children[0].visit(self)
        visit_additive0_9 = EvaluateVisitor.visit_additive
    parse = make_parse_function(regexs, rules, eof=True)
    tree = parse("0 +! 10 +! 999")
    assert tree.visit(MyEvalVisitor()) == 10 + 999
    py.test.raises(ParseError, parse, "0 +! 10 +! 999 0000")
    grammar += "some garbage here"
    py.test.raises(ParseError, parse_ebnf, grammar)


def test_prolog():
    regexs, rules, ToAST = parse_ebnf("""
ATOM: "[a-z]([a-zA-Z0-9]|_)*";
VAR: "[A-Z]([a-zA-Z0-9]|_)*|_";
NUMBER: "0|[1-9][0-9]*";
IGNORE: "[ \\n\\t]";
file: fact file | fact;
fact: complexterm "." | complexterm ":-" compoundexpr ".";
compoundexpr: complexterm "," compoundexpr | complexterm ";" compoundexpr | complexterm;
complexterm: ATOM "(" exprlist ")" | ATOM;
exprlist: expr "," exprlist | expr;
expr: complexterm | ATOM | NUMBER | VAR;
""")
    parse = make_parse_function(regexs, rules)
    tree = parse("prefix(\n\tlonger(and_nested(term(X))), Xya, _, X0, _).")
    assert tree.children[0].children[0].children[2].children[0].getsourcepos().lineno == 1
    assert tree is not None
    tree = parse("""
foo(X, Y) :- bar(Y, X), bar(Y, X) ; foobar(X, Y, 1234, atom).""")
    assert tree is not None

def test_toast_bigger():
    regexs, rules, ToAST = parse_ebnf("""
BOOLCONST: "TRUE|FALSE";
IDENTIFIER: "[a-zA-Z_][a-zA-Z0-9_]*";
NUMBER: "0|[1-9][0-9]*";
IGNORE: " ";
# expression
expr: <intexpr> | <boolexpr>;
intexpr: multitive "+" intexpr | multitive "-" intexpr | <multitive>;
multitive: primary "*" unaryexpr | primary "/" unaryexpr |
           primary "%" unaryexpr | <unaryexpr>;
unaryexpr: "+" unaryexpr | "-" unaryexpr | <primary>;
primary: "(" <intexpr> ")" | <NUMBER> | <IDENTIFIER>;
boolexpr: <BOOLCONST>; #strange thing
""")
    parse = make_parse_function(regexs, rules)
    tree = parse("x * floor + 1")
    tree = ToAST().transform(tree)
    assert tree.children[2].symbol == "NUMBER"

def test_parser_repr_is_evalable():
    regexs, rules, ToAST = parse_ebnf("""
BOOLCONST: "TRUE|FALSE";
IDENTIFIER: "[a-zA-Z_][a-zA-Z0-9_]*";
NUMBER: "0|[1-9][0-9]*";
IGNORE: " ";
# expression
expr: <intexpr> | <boolexpr>;
intexpr: multitive "+" intexpr | multitive "-" intexpr | <multitive>;
multitive: primary "*" unaryexpr | primary "/" unaryexpr |
           primary "%" unaryexpr | <unaryexpr>;
unaryexpr: "+" unaryexpr | "-" unaryexpr | <primary>;
primary: "(" <intexpr> ")" | <NUMBER> | <IDENTIFIER>;
boolexpr: <BOOLCONST>; #strange thing

""")
    parser = PackratParser(rules, rules[0].nonterminal)
    s = repr(parser)
    print s
    newparser = eval(s)
    assert repr(newparser) == s

def test_lexer_end_string_corner_case():
    regexs, rules, ToAST = parse_ebnf("""
NUMBER: "[0-9]*(\.[0-9]+)?";
ATOM: "\.";
IGNORE: " ";
expr: NUMBER ATOM EOF;
""")
    parse = make_parse_function(regexs, rules, eof=True)
    t = parse("2.")
    assert t.children[0].additional_info == "2"
    assert t.children[1].additional_info == "."

def test_escape_quotes():
    regexs, rules, ToAST = parse_ebnf("""
QUOTE: "a\\"";
IGNORE: " ";
expr: QUOTE "\\"" EOF;""")
    parse = make_parse_function(regexs, rules, eof=True)
    t = parse('a" "')
    assert t.children[0].additional_info == 'a"'
    assert t.children[1].additional_info == '"'

def test_leftrecursion():
    regexs, rules, ToAST = parse_ebnf("""
A: "a";
B: "b";
IGNORE: " |\n";
expr1: A | expr2 A;
expr2: expr1 B;
""")
    py.test.raises(AssertionError, make_parse_function, regexs, rules, True)

def test_jsonparse():
    source = """
    STRING: "\\"[^\\\\"]*\\"";
    NUMBER: "\-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][\+\-]?[0-9]+)?";
    IGNORE: " |\n";
    value: <STRING> | <NUMBER> | <object> | <array> | <"null"> |
           <"true"> | <"false">;
    object: ["{"] (entry [","])* entry ["}"];
    array: ["["] (value [","])* value ["]"];
    entry: STRING [":"] value;
"""
    regexs, rules, ToAST = parse_ebnf(source)
    parse = make_parse_function(regexs, rules, eof=True)
    t = parse("""
{
    "type": "SCRIPT",
    "0": {
        "type": "SEMICOLON",
        "end": "5",
        "expression": {
            "type": "ASSIGN",
            "0": {
                "type": "IDENTIFIER",
                "assignOp": "null",
                "end": "1",
                "lineno": "1",
                "start": "0",
                "tokenizer": "[object Object]",
                "value": "x"
            } ,
            "1": {
                "type": "NUMBER",
                "end": "5",
                "lineno": "1",
                "start": "4",
                "tokenizer": "[object Object]",
                "value": "1"
            } ,
            "end": "5",
            "length": "2",
            "lineno": "1",
            "start": "0",
            "tokenizer": "[object Object]",
            "value": "="
        } ,
        "lineno": "1",
        "start": "0",
        "tokenizer": "[object Object]",
        "value": "x"
    } ,
    "funDecls": "",
    "length": "1",
    "lineno": "1",
    "tokenizer": "[object Object]",
    "varDecls": ""
}""")
    t = ToAST().transform(t)
    t = parse('{"a": "5", "b": [1, null, 3, true, {"f": "g", "h": 6}]}')
    print "".join(list(t.dot()))
    t = ToAST().transform(t)
    print "\n".join(list(t.dot()))

def test_starparse():
    regexs, rules, ToAST = parse_ebnf("""
    QUOTED_STRING: "'[^\\']*'";
    IGNORE: " |\n";
    list: ["["] (QUOTED_STRING [","])* QUOTED_STRING ["]"];
""")
    parse = make_parse_function(regexs, rules, eof=True)
    t = parse("""['a', 'b', 'c']""")
    t = ToAST().transform(t)
    assert t.symbol == "list"
    assert len(t.children) == 3
    assert [c.symbol for c in t.children] == ["QUOTED_STRING"] * 3
    t = parse("['a']")
    t = ToAST().transform(t)
    assert t.symbol == "list"
    assert len(t.children) == 1
    assert [c.symbol for c in t.children] == ["QUOTED_STRING"] * 1

def test_double_star():
    regexs, rules, ToAST = parse_ebnf("""
    IGNORE: " |\n";
    start: "a"* "b"* "c";
""")
    parse = make_parse_function(regexs, rules, eof=True)
    for s in ["a a a b b c", "a b b c", "a a c", "b b c", "c"]:
        t = parse(s)
        t = ToAST().transform(t)
        assert [c.additional_info for c in t.children] == s.split()

def test_transform_star():
    #py.test.skip("This needs to be fixed - generated transformer is buggy")
    regexs, rules, ToAST = parse_ebnf("""
    IGNORE: " ";
    ATOM: "[\+a-zA-Z_][a-zA-Z0-9_]*";

    sexpr: ATOM | list;
    list: "(" sexpr* ")";
""")
    parse = make_parse_function(regexs, rules)
    tree = parse("()")
    list_expr = tree.visit(ToAST())[0].children[0]
    assert list_expr.symbol == 'list'
    # should have two children, "(" and ")"
    assert len(list_expr.children) == 2
    assert list_expr.children[0].additional_info == '('
    assert list_expr.children[1].additional_info == ')'
    tree = parse("(a b c)")
    list_expr = ToAST().transform(tree)


def test_quoting():
    regexs, rules, ToAST = parse_ebnf("""
    ATOM: "[a-z]*";
    IGNORE: " ";
    list: ATOM "\n" ATOM;
""")
    parse = make_parse_function(regexs, rules, eof=True)
    t = parse("""abc
  abd""")
    assert len(t.children) == 3
    assert t.children[1].additional_info == "\n"

def test_check_for_missing_names():
    regexs, rules, ToAST = parse_ebnf("""
IGNORE: " ";
DECIMAL: "0|[1-9][0-9]*";
additive: multitive "+" additive | multitive;
multitive: primary "*" multitive | primari; # observe the typo
# the following too!
primary: "(" additive ")" | DECIMAL;
""")
    excinfo = py.test.raises(ValueError, make_parse_function, regexs, rules)
    assert "primari" in str(excinfo.value)

def test_starred_star():
    regexs, rules, ToAST = parse_ebnf("""
IGNORE: " ";
start: ("b"* "a")* EOF;
    """)
    parse = make_parse_function(regexs, rules, eof=True)
    for s in ["b b b b a b b a", "b a b a", "a a", ""]:
        t = parse(s)
        t = ToAST().transform(t)
        assert [c.additional_info for c in t.children] == (s + " EOF").split()

def test_transform_greater_than():
    regexs, rules, ToAST = parse_ebnf("""
IGNORE: " ";
x: ["a"] >b< "c";
b: "A" "A";
    """)
    parse = make_parse_function(regexs, rules)
    t = parse("a A A c")
    t = ToAST().transform(t)
    assert len(t.children) == 3
    assert t.children[0].additional_info == "A"
    assert t.children[1].additional_info == "A"
    assert t.children[2].additional_info == "c"

def test_plus():
    regexs, rules, ToAST = parse_ebnf("""
IGNORE: " ";
x: "A"+ "B";
    """)
    parse = make_parse_function(regexs, rules)
    t = parse("A A B")
    t = ToAST().transform(t)
    assert len(t.children) == 3
    assert t.children[0].additional_info == "A"
    assert t.children[1].additional_info == "A"
    assert t.children[2].additional_info == "B"
    py.test.raises(ParseError, parse, "B")

def test_questionmark():
    regexs, rules, ToAST = parse_ebnf("""
IGNORE: " ";
x: ["A"] ("B" ["C"] "D")? "E";
    """)
    parse = make_parse_function(regexs, rules)
    t = parse("A B C D E")
    py.test.raises(ParseError, parse, "A B C D B C D E")
    t = ToAST().transform(t)
    assert len(t.children) == 3
    assert t.children[0].additional_info == "B"
    assert t.children[1].additional_info == "D"
    assert t.children[2].additional_info == "E"
    t = parse("A  E")
    t = ToAST().transform(t)
    assert len(t.children) == 1
    assert t.children[0].additional_info == "E"

def test_grouping_only_parens():
    regexs, rules, ToAST = parse_ebnf("""
IGNORE: " ";
x: ["m"] ("a" "b") "c" | <y>;
y: ["n"] "a" "b" "c";
    """)
    parse = make_parse_function(regexs, rules)
    t0 = ToAST().transform(parse("m a b c"))
    t1 = ToAST().transform(parse("n a b c"))
    assert len(t0.children) == len(t1.children)

def test_mix_star_and_questionmark():
    regexs, rules, ToAST = parse_ebnf("""
IGNORE: " ";
y: x "END";
x: "B" ("A" "B")* "A"?;
    """)
    parse = make_parse_function(regexs, rules)
    t = ToAST().transform(parse("B A B END"))
    assert len(t.children[0].children) == 3

def test_nest_star_and_questionmark():
    regexs, rules, ToAST = parse_ebnf("""
IGNORE: " ";
y: x "END";
x: "B" ("A" "B"?)*;
    """)
    parse = make_parse_function(regexs, rules)
    t = ToAST().transform(parse("B A B A B END"))
    t = ToAST().transform(parse("B A A A END"))

def test_clash_literal_nonterminal():
    regexs, rules, ToAST = parse_ebnf("""
IGNORE: " ";
y: x "END";
x: "y";
a: "x";
    """)
    parse = make_parse_function(regexs, rules)
    py.test.raises(ParseError, parse, "x END")
    parse("y END")

def test_example1():
    regexs, rules, ToAST = parse_ebnf("""
IGNORE: " ";
n: "a" "b" "c" m;
m: "(" <n> ")" | "d";
    """)
    parse = make_parse_function(regexs, rules)
    t = parse("a b c (a b c d)")
    t = ToAST().transform(t)

def test_example2():
    regexs, rules, ToAST = parse_ebnf("""
IGNORE: " ";
DECIMAL: "0|[1-9][0-9]*";
list: DECIMAL >list< | DECIMAL;
    """)
    parse = make_parse_function(regexs, rules)
    t = parse("1 2 3 4 5")
    t = ToAST().transform(t)

def test_bug():
    # this could be seen as using the transformer in the wrong way
    # but I have no clue how to detect this situation
    py.test.skip("fix me somehow")
    regexs, rules, ToAST = parse_ebnf("""
IGNORE: " ";
DECIMAL: "0|[1-9][0-9]*";
list: DECIMAL >list< | <DECIMAL>;
    """)
    parse = make_parse_function(regexs, rules)
    t = parse("1 2 3 4 5")
    t = ToAST().transform(t)

def test_empty_production():
    # this could be seen as using the transformer in the wrong way
    # but I have no clue how to detect this situation
    regexs, rules, ToAST = parse_ebnf("""
IGNORE: " ";
DECIMAL: "0|[1-9][0-9]*";
file: <stuff> EOF;
stuff: "a" >stuff< "a" | "y" | >empty<;
empty: ;
    """)
    parse = make_parse_function(regexs, rules, eof=True)
    t = parse(" ")
    t = ToAST().transform(t)
    assert isinstance(t, Nonterminal)
    assert len(t.children) == 0
    t = parse(" a  a  a  a a    a ")
    t = ToAST().transform(t)
    assert len(t.children) == 6
    excinfo = py.test.raises(ParseError, parse, "a")

def test_zero_repetition_production():
    grammar = """
IGNORE: " ";
foo: "A"?;
"""
    excinfo = py.test.raises(ValueError, parse_ebnf, grammar)
    assert "foo" in str(excinfo.value)
