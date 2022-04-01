from rpython.rlib.parsing.lexer import Token, SourcePos
from rpython.rlib.parsing.parsing import *

class EvaluateVisitor(object):
    def visit_additive(self, node):
        if len(node.children) == 1:
            return node.children[0].visit(self)
        else:
            return node.children[0].visit(self) + node.children[2].visit(self)
    def visit_multitive(self, node):
        if len(node.children) == 1:
            return node.children[0].visit(self)
        else:
            return node.children[0].visit(self) * node.children[2].visit(self)
    def visit_primary(self, node):
        if len(node.children) == 1:
            return node.children[0].visit(self)
        else:
            return node.children[1].visit(self)
    def visit_decimal(self, node):
        return int(node.children[0].symbol)

def test_simple_packrat():
    class ToAstVisistor(object):
        def visit_additive(self, node):
            if len(node.children) == 1:
                return node.children[0].visit(self)
            return Nonterminal(
                "additive", [node.children[0].visit(self),
                             node.children[2].visit(self)])
        def visit_multitive(self, node):
            if len(node.children) == 1:
                return node.children[0].visit(self)
            return Nonterminal(
                "multitive", [node.children[0].visit(self),
                              node.children[2].visit(self)])
        def visit_primary(self, node):
            if len(node.children) == 1:
                return node.children[0].visit(self)
            return node.children[1].visit(self)
        def visit_decimal(self, node):
            return Nonterminal(
                    "decimal",
                    [Symbol(int(node.children[0].symbol), "", None)])
    r1 = Rule("additive", [["multitive", "+", "additive"], ["multitive"]])
    r2 = Rule("multitive", [["primary", "*", "multitive"], ["primary"]])
    r3 = Rule("primary", [["(", "additive", ")"], ["decimal"]])
    r4 = Rule("decimal", [[symb] for symb in "0123456789"])
    p = PackratParser([r1, r2, r3, r4], "additive")
    print p.parse([Token(c, c, SourcePos(i, 0, i)) for i, c in enumerate("2*(3+4)")])
    tree = p.parse([Token(c, c, SourcePos(i, 0, i)) for i, c in enumerate("2*2*2*(7*3+4+5*6)")])
    ast = tree.visit(ToAstVisistor())
    tree = p.parse([Token(c, c, SourcePos(i, 0, i)) for i, c in enumerate("2*(3+4)")])
    r = tree.visit(EvaluateVisitor())
    assert r == 14
    tree = p.parse([Token(c, c, SourcePos(i, 0, i)) for i, c in enumerate("2*(3+5*2*(2+6))")])
    print tree
    r = tree.visit(EvaluateVisitor())
    assert r == 166

def test_bad():
    r1 = Rule("S", [["x", "S", "x"], ["x"]])
    p = PackratParser([r1], "S")
    assert p.parse([Token(c, c, SourcePos(i, 0, i)) for i, c in enumerate("xxxxxxxxxxxxxxx")]) is not None
    
def test_leftrecursion_detection():
    r1 = Rule("A", [["A"]])
    py.test.raises(AssertionError, PackratParser, [r1], "A")
    r1 = Rule("A", [["B"]])
    r2 = Rule("B", [["A"]])
    py.test.raises(AssertionError, PackratParser, [r1, r2], "B")

def test_epsilon():
    r1 = Rule("S", [["x", "S", "x"], ["y"], []])
    p = PackratParser([r1], "S")
    assert p.parse([Token(c, i, SourcePos(i, 0, i))
                        for i, c, in enumerate("xyx")]) is not None
    assert p.parse([Token(c, i, SourcePos(i, 0, i))
                        for i, c, in enumerate("xx")]) is not None
    t = p.parse([Token(c, i, SourcePos(i, 0, i))
                     for i, c, in enumerate("xxxxxx")])
