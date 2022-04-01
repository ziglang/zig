import py

from rpython.rlib.parsing.parsing import PackratParser, Rule
from rpython.rlib.parsing.tree import Nonterminal, RPythonVisitor
from rpython.rlib.parsing.codebuilder import Codebuilder
from rpython.rlib.parsing.regexparse import parse_regex
from rpython.rlib.parsing.regex import StringExpression
from rpython.rlib.parsing.deterministic import DFA
from rpython.rlib.parsing.lexer import Lexer, DummyLexer
from rpython.rlib.objectmodel import we_are_translated


def make_ebnf_parser():
    NONTERMINALNAME = parse_regex("([a-z]|_)[a-z0-9_]*")
    SYMBOLNAME = parse_regex("_*[A-Z]([A-Z]|_)*")
    LONGQUOTED = parse_regex(r'"[^\"]*(\\\"?[^\"]+)*(\\\")?"')
    QUOTEDQUOTE = parse_regex("""'"'""")
    COMMENT = parse_regex("#[^\\n]*\\n")
    names1 = ['SYMBOLNAME', 'NONTERMINALNAME', 'QUOTE', 'QUOTE', 'IGNORE',
              'IGNORE', 'IGNORE', 'IGNORE']
    regexs1 = [SYMBOLNAME, NONTERMINALNAME, LONGQUOTED, QUOTEDQUOTE, COMMENT,
               StringExpression('\n'), StringExpression(' '),
               StringExpression('\t')]
    rs, rules, transformer = parse_ebnf(r"""
    file: list EOF;
    list: element+;
    element: <regex> | <production>;
    regex: SYMBOLNAME ":" QUOTE ";";
    production: NONTERMINALNAME ":" body? ";";
    body: (expansion ["|"])* expansion;
    expansion: decorated+;
    decorated: enclosed "*" |
               enclosed "+" |
               enclosed "?" |
               <enclosed>;
    enclosed: "[" expansion "]" |
              ">" expansion "<" |
              "<" primary ">" |
              "(" <expansion> ")" |
              <primary>;
    primary: NONTERMINALNAME | SYMBOLNAME | QUOTE;
    """)
    names2, regexs2 = zip(*rs)
    lexer = Lexer(regexs1 + list(regexs2), names1 + list(names2),
                  ignore=['IGNORE'])
    parser = PackratParser(rules, "file")
    return parser, lexer, transformer

def parse_ebnf(s):
    visitor = ParserBuilder()
    tokens = lexer.tokenize(s, True)
    #print tokens
    s = parser.parse(tokens)
    s = s.visit(EBNFToAST())
    assert len(s) == 1
    s = s[0]
    s.visit(visitor)

    rules, changes = visitor.get_rules_and_changes()
    maker = TransformerMaker(rules, changes)
    ToAstVisitor = maker.make_transformer()
    return zip(visitor.names, visitor.regexs), rules, ToAstVisitor

def check_for_missing_names(names, regexs, rules):
    known_names = dict.fromkeys(names, True)
    known_names["EOF"] = True
    for rule in rules:
        known_names[rule.nonterminal] = True
    for rule in rules:
        for expansion in rule.expansions:
            for symbol in expansion:
                if symbol not in known_names:
                    raise ValueError("symbol '%s' not known" % (symbol, ))

def make_parse_function(regexs, rules, eof=False):
    from rpython.rlib.parsing.lexer import Lexer
    names, regexs = zip(*regexs)
    if "IGNORE" in names:
        ignore = ["IGNORE"]
    else:
        ignore = []
    check_for_missing_names(names, regexs, rules)
    lexer = Lexer(list(regexs), list(names), ignore=ignore)
    parser = PackratParser(rules, rules[0].nonterminal)
    def parse(s):
        tokens = lexer.tokenize(s, eof=eof)
        s = parser.parse(tokens)
        if not we_are_translated():
            try:
                if py.test.config.option.view:
                    s.view()
            except AttributeError:
                pass

        return s
    return parse

class ParserBuilder(object):
    def __init__(self):
        self.regexs = []
        self.names = []
        self.rules = []
        self.changes = []
        self.maybe_rules = {}
        self.num_plus_symbols = 0
        self.first_rule = None
        self.literals = {}

    def visit_file(self, node):
        return node.children[0].visit(self)

    def visit_list(self, node):
        for child in node.children:
            child.visit(self)

    def visit_regex(self, node):
        regextext = node.children[2].additional_info[1:-1].replace('\\"', '"')
        regex = parse_regex(regextext)
        if regex is None:
            raise ValueError(
                "%s is not a valid regular expression" % regextext)
        self.regexs.append(regex)
        self.names.append(node.children[0].additional_info)

    def visit_production(self, node):
        name = node.children[0].additional_info
        if len(node.children) == 3:
            self.changes.append([])
            self.rules.append(Rule(name, [[]]))
            return
        expansions = node.children[2].visit(self)
        changes = []
        rule_expansions = []
        for expansion in expansions:
            expansion, change = zip(*expansion)
            rule_expansions.append(list(expansion))
            changes.append("".join(change))
        if self.first_rule is None:
            self.first_rule = name
        self.changes.append(changes)
        self.rules.append(Rule(name, rule_expansions))

    def visit_body(self, node):
        expansions = []
        for child in node.children:
            expansion = child.visit(self)
            expansions.append(expansion)
        return expansions

    def visit_expansion(self, node):
        expansions = []
        for child in node.children:
            expansion = child.visit(self)
            expansions += expansion
        return expansions

    def visit_enclosed(self, node):
        result = []
        newchange = node.children[0].additional_info
        for name, change in node.children[1].visit(self):
            assert change == " " or change == newchange
            result.append((name, newchange))
        return result

    def visit_decorated(self, node):
        expansions = node.children[0].visit(self)
        expansions, changes = zip(*expansions)
        expansions, changes = list(expansions), "".join(changes)
        if node.children[1].additional_info == "*":
            name = "_star_symbol%s" % (len(self.maybe_rules), )
            maybe_rule = True
            expansions = [expansions + [name]]
            changes = [changes + ">", changes]
        elif node.children[1].additional_info == "+":
            name = "_plus_symbol%s" % (self.num_plus_symbols, )
            self.num_plus_symbols += 1
            maybe_rule = False
            expansions = [expansions + [name], expansions]
            changes = [changes + ">", changes]
        elif node.children[1].additional_info == "?":
            name = "_maybe_symbol%s" % (len(self.maybe_rules), )
            maybe_rule = True
            expansions = [expansions]
            changes = [changes]
        self.rules.append(Rule(name, expansions))
        self.changes.append(changes)
        if maybe_rule:
            self.maybe_rules[name] = self.rules[-1]
        return [(name, ">")]

    def visit_primary_parens(self, node):
        if len(node.children) == 1:
            return node.children[0].visit(self)
        else:
            return node.children[1].visit(self)

    def visit_primary(self, node):
        if node.children[0].symbol == "QUOTE":
            from rpython.rlib.parsing.regexparse import unescape
            content = node.children[0].additional_info[1:-1]
            expression = unescape(content)
            name = self.get_literal_name(expression)
            return [(name, " ")]
        else:
            return [(node.children[0].additional_info, " ")]

    def get_literal_name(self, expression):
        if expression in self.literals:
            return self.literals[expression]
        name = "__%s_%s" % (len(self.literals), expression)
        self.literals[expression] = name
        self.regexs.insert(0, StringExpression(expression))
        self.names.insert(0, name)
        return name

    def get_rules_and_changes(self):
        self.fix_rule_order()
        return self.add_all_possibilities()

    def fix_rule_order(self):
        if self.rules[0].nonterminal != self.first_rule:
            for i, r in enumerate(self.rules):
                if r.nonterminal == self.first_rule:
                    break
            self.rules[i], self.rules[0] = self.rules[0], self.rules[i]
            self.changes[i], self.changes[0] = self.changes[0], self.changes[i]

    def add_all_possibilities(self):
        all_rules = []
        other_rules = []
        all_changes = []
        other_changes = []
        for rule, changes in zip(self.rules, self.changes):
            if rule.expansions == [[]]:
                all_rules.append(rule)
                all_changes.append([])
                continue
            real_changes = []
            real_expansions = []
            for index, (expansion, change) in enumerate(
                    zip(rule.expansions, changes)):
                maybe_pattern = [symbol in self.maybe_rules
                                     for symbol in expansion]
                n = maybe_pattern.count(True)
                if n == 0:
                    real_expansions.append(expansion)
                    real_changes.append(change)
                    continue
                if n == len(expansion):
                    raise ValueError("Rule %r's expansion needs "
                        "at least one symbol with >0 repetitions"
                        % rule.nonterminal)
                slices = []
                start = 0
                for i, (maybe, symbol) in enumerate(
                        zip(maybe_pattern, expansion)):
                    if maybe:
                        slices.append((start, i + 1))
                        start = i + 1
                rest_slice = (start, i + 1)
                name = rule.nonterminal
                for i, (start, stop) in enumerate(slices):
                    nextname = "__%s_rest_%s_%s" % (rule.nonterminal, index, i)
                    if i < len(slices) - 1:
                        new_expansions = [
                            expansion[start: stop] + [nextname],
                            expansion[start: stop - 1] + [nextname]]
                        new_changes = [change[start: stop] + ">",
                                       change[start: stop - 1] + ">"]
                    else:
                        rest_expansion = expansion[slice(*rest_slice)]
                        new_expansions = [
                            expansion[start: stop] + rest_expansion,
                            expansion[start: stop - 1] + rest_expansion]
                        rest_change = change[slice(*rest_slice)]
                        new_changes = [change[start: stop] + rest_change,
                                       change[start: stop - 1] + rest_change]
                    if i == 0:
                        real_expansions += new_expansions
                        real_changes += new_changes
                    else:
                        other_rules.append(Rule(name, new_expansions))
                        other_changes.append(new_changes)
                    name = nextname
            all_rules.append(Rule(rule.nonterminal, real_expansions))
            all_changes.append(real_changes)
        return all_rules + other_rules, all_changes + other_changes

class TransformerMaker(Codebuilder):
    def __init__(self, rules, changes):
        Codebuilder.__init__(self)
        self.rules = rules
        self.changes = changes
        self.nonterminals = dict.fromkeys([rule.nonterminal for rule in rules])

    def make_transformer(self, print_code=False):
        self.start_block("class ToAST(object):")
        for i in range(len(self.rules)):
            self.create_visit_method(i)
        self.start_block("def transform(self, tree):")
        self.emit("#auto-generated code, don't edit")
        self.emit("assert isinstance(tree, Nonterminal)")
        startsymbol = self.rules[0].nonterminal
        self.emit("assert tree.symbol == %r" % (startsymbol, ))
        self.emit("r = self.visit_%s(tree)" % (startsymbol, ))
        self.emit("assert len(r) == 1")
        self.start_block("if not we_are_translated():")
        self.start_block("try:")
        self.start_block("if py.test.config.option.view:")
        self.emit("r[0].view()")
        self.end_block("option.view")
        self.end_block("try")
        self.start_block("except AttributeError:")
        self.emit("pass")
        self.end_block("except")
        self.end_block("we_are_translated")
        self.emit("return r[0]")
        self.end_block("transform")
        self.end_block("ToAST")
        code = self.get_code()
        if print_code:
            print code
        ns = {"RPythonVisitor": RPythonVisitor, "Nonterminal": Nonterminal,
              "we_are_translated": we_are_translated, "py": py}
        exec(py.code.Source(code).compile(), ns)
        ToAST = ns["ToAST"]
        ToAST.__module__ = "rpython.rlib.parsing.ebnfparse"
        assert isinstance(ToAST, type)
        assert ToAST.__name__ == "ToAST"
        ToAST.source = code
        ToAST.changes = self.changes
        return ToAST

    def dispatch(self, symbol, expr):
        if symbol in self.nonterminals:
            return "self.visit_%s(%s)" % (symbol, expr)
        return "[%s]" % (expr, )

    def create_visit_method(self, index):
        rule = self.rules[index]
        change = self.changes[index]
        self.start_block("def visit_%s(self, node):" % (rule.nonterminal, ))
        self.emit("#auto-generated code, don't edit")
        if len(change) == 0:
            self.emit("return [node]")
            self.end_block(rule.nonterminal)
            return
        for expansion, subchange in self.generate_conditions(index):
            if "<" in subchange:
                i = subchange.index("<")
                assert subchange.count("<") == 1, (
                    "cannot expand more than one node in rule %s" % (rule, ))
                i = subchange.index("<")
                returnval = self.dispatch(
                    expansion[i], "node.children[%s]" % (i, ))
                self.emit("return " + returnval)
            else:
                self.create_returning_code(expansion, subchange)
        self.end_block(rule.nonterminal)

    def create_returning_code(self, expansion, subchange):
        assert len(expansion) == len(subchange)
        self.emit("children = []")
        for i, (symbol, c) in enumerate(zip(expansion, subchange)):
            if c == "[":
                continue
            expr = self.dispatch(symbol, "node.children[%s]" % (i, ))
            if c == " ":
                self.emit("children.extend(%s)" % (expr, ))
            if c == ">":
                self.emit("expr = %s" % (expr, ))
                self.emit("assert len(expr) == 1")
                self.emit("children.extend(expr[0].children)")
        self.emit("return [Nonterminal(node.symbol, children)]")

    def generate_conditions(self, index):
        rule = self.rules[index]
        change = self.changes[index]
        len_partition = {}
        if len(rule.expansions) == 1:
            yield rule.expansions[0], change[0]
            return
        for expansion, subchange in zip(rule.expansions, change):
            len_partition.setdefault(len(expansion), []).append(
                (expansion, subchange))
        len_partition = len_partition.items()
        len_partition.sort()
        last_length = len_partition[-1][0]
        self.emit("length = len(node.children)")
        for length, items in len_partition:
            if length < last_length:
                self.start_block("if length == %s:" % (length, ))
            if len(items) == 1:
                yield items[0]
                if length < last_length:
                    self.end_block("if length ==")
                continue
            # XXX quite bad complexity, might be ok in practice
            while items:
                shorter = False
                for i in range(length):
                    symbols = {}
                    for pos, item in enumerate(items):
                        expansion = item[0]
                        symbol = expansion[i]
                        symbols.setdefault(symbol, []).append((pos, item))
                    symbols = symbols.items()
                    symbols.sort()
                    remove = []
                    for symbol, subitems in symbols:
                        if (len(subitems) == 1 and
                            (len(items) - len(remove)) > 1):
                            self.start_block(
                                "if node.children[%s].symbol == %r:" % (
                                    i, symbol))
                            pos, subitem = subitems[0]
                            yield subitem
                            remove.append(pos)
                            shorter = True
                            self.end_block("if node.children[")
                    remove.sort()
                    for pos in remove[::-1]:
                        items.pop(pos)
                if shorter:
                    if len(items) == 1:
                        yield items[0]
                        items.pop(0)
                    else:
                        continue
                break
            # for the remaining items we do a brute force comparison
            # could be even cleverer, but very unlikely to be useful
            assert len(items) != 1
            for expansion, subchange in items:
                conds = []
                for i, symbol in enumerate(expansion):
                    conds.append("node.children[%s].symbol == %r" % (
                        i, symbol))
                self.start_block("if (%s):" % (" and ".join(conds), ))
                yield expansion, subchange
                self.end_block("if")
            if length < last_length:
                self.end_block("if length ==")



# generated code between this line and its other occurence
class EBNFToAST(object):
    def visit_file(self, node):
        #auto-generated code, don't edit
        children = []
        children.extend(self.visit_list(node.children[0]))
        children.extend([node.children[1]])
        return [Nonterminal(node.symbol, children)]
    def visit__plus_symbol0(self, node):
        #auto-generated code, don't edit
        length = len(node.children)
        if length == 1:
            children = []
            children.extend(self.visit_element(node.children[0]))
            return [Nonterminal(node.symbol, children)]
        children = []
        children.extend(self.visit_element(node.children[0]))
        expr = self.visit__plus_symbol0(node.children[1])
        assert len(expr) == 1
        children.extend(expr[0].children)
        return [Nonterminal(node.symbol, children)]
    def visit_list(self, node):
        #auto-generated code, don't edit
        children = []
        expr = self.visit__plus_symbol0(node.children[0])
        assert len(expr) == 1
        children.extend(expr[0].children)
        return [Nonterminal(node.symbol, children)]
    def visit_element(self, node):
        #auto-generated code, don't edit
        length = len(node.children)
        if node.children[0].symbol == 'production':
            return self.visit_production(node.children[0])
        return self.visit_regex(node.children[0])
    def visit_regex(self, node):
        #auto-generated code, don't edit
        children = []
        children.extend([node.children[0]])
        children.extend([node.children[1]])
        children.extend([node.children[2]])
        children.extend([node.children[3]])
        return [Nonterminal(node.symbol, children)]
    def visit__maybe_symbol0(self, node):
        #auto-generated code, don't edit
        children = []
        children.extend(self.visit_body(node.children[0]))
        return [Nonterminal(node.symbol, children)]
    def visit_production(self, node):
        #auto-generated code, don't edit
        length = len(node.children)
        if length == 3:
            children = []
            children.extend([node.children[0]])
            children.extend([node.children[1]])
            children.extend([node.children[2]])
            return [Nonterminal(node.symbol, children)]
        children = []
        children.extend([node.children[0]])
        children.extend([node.children[1]])
        expr = self.visit__maybe_symbol0(node.children[2])
        assert len(expr) == 1
        children.extend(expr[0].children)
        children.extend([node.children[3]])
        return [Nonterminal(node.symbol, children)]
    def visit__star_symbol1(self, node):
        #auto-generated code, don't edit
        length = len(node.children)
        if length == 2:
            children = []
            children.extend(self.visit_expansion(node.children[0]))
            return [Nonterminal(node.symbol, children)]
        children = []
        children.extend(self.visit_expansion(node.children[0]))
        expr = self.visit__star_symbol1(node.children[2])
        assert len(expr) == 1
        children.extend(expr[0].children)
        return [Nonterminal(node.symbol, children)]
    def visit_body(self, node):
        #auto-generated code, don't edit
        length = len(node.children)
        if length == 1:
            children = []
            children.extend(self.visit_expansion(node.children[0]))
            return [Nonterminal(node.symbol, children)]
        children = []
        expr = self.visit__star_symbol1(node.children[0])
        assert len(expr) == 1
        children.extend(expr[0].children)
        children.extend(self.visit_expansion(node.children[1]))
        return [Nonterminal(node.symbol, children)]
    def visit__plus_symbol1(self, node):
        #auto-generated code, don't edit
        length = len(node.children)
        if length == 1:
            children = []
            children.extend(self.visit_decorated(node.children[0]))
            return [Nonterminal(node.symbol, children)]
        children = []
        children.extend(self.visit_decorated(node.children[0]))
        expr = self.visit__plus_symbol1(node.children[1])
        assert len(expr) == 1
        children.extend(expr[0].children)
        return [Nonterminal(node.symbol, children)]
    def visit_expansion(self, node):
        #auto-generated code, don't edit
        children = []
        expr = self.visit__plus_symbol1(node.children[0])
        assert len(expr) == 1
        children.extend(expr[0].children)
        return [Nonterminal(node.symbol, children)]
    def visit_decorated(self, node):
        #auto-generated code, don't edit
        length = len(node.children)
        if length == 1:
            return self.visit_enclosed(node.children[0])
        if node.children[1].symbol == '__3_*':
            children = []
            children.extend(self.visit_enclosed(node.children[0]))
            children.extend([node.children[1]])
            return [Nonterminal(node.symbol, children)]
        if node.children[1].symbol == '__4_+':
            children = []
            children.extend(self.visit_enclosed(node.children[0]))
            children.extend([node.children[1]])
            return [Nonterminal(node.symbol, children)]
        children = []
        children.extend(self.visit_enclosed(node.children[0]))
        children.extend([node.children[1]])
        return [Nonterminal(node.symbol, children)]
    def visit_enclosed(self, node):
        #auto-generated code, don't edit
        length = len(node.children)
        if length == 1:
            return self.visit_primary(node.children[0])
        if node.children[0].symbol == '__10_(':
            return self.visit_expansion(node.children[1])
        if node.children[0].symbol == '__6_[':
            children = []
            children.extend([node.children[0]])
            children.extend(self.visit_expansion(node.children[1]))
            children.extend([node.children[2]])
            return [Nonterminal(node.symbol, children)]
        if node.children[0].symbol == '__8_>':
            children = []
            children.extend([node.children[0]])
            children.extend(self.visit_expansion(node.children[1]))
            children.extend([node.children[2]])
            return [Nonterminal(node.symbol, children)]
        children = []
        children.extend([node.children[0]])
        children.extend(self.visit_primary(node.children[1]))
        children.extend([node.children[2]])
        return [Nonterminal(node.symbol, children)]
    def visit_primary(self, node):
        #auto-generated code, don't edit
        length = len(node.children)
        if node.children[0].symbol == 'NONTERMINALNAME':
            children = []
            children.extend([node.children[0]])
            return [Nonterminal(node.symbol, children)]
        if node.children[0].symbol == 'QUOTE':
            children = []
            children.extend([node.children[0]])
            return [Nonterminal(node.symbol, children)]
        children = []
        children.extend([node.children[0]])
        return [Nonterminal(node.symbol, children)]
    def transform(self, tree):
        #auto-generated code, don't edit
        assert isinstance(tree, Nonterminal)
        assert tree.symbol == 'file'
        r = self.visit_file(tree)
        assert len(r) == 1
        if not we_are_translated():
            try:
                if py.test.config.option.view:
                    r[0].view()
            except AttributeError:
                pass
        return r[0]
parser = PackratParser([Rule('file', [['list', 'EOF']]),
  Rule('_plus_symbol0', [['element', '_plus_symbol0'], ['element']]),
  Rule('list', [['_plus_symbol0']]),
  Rule('element', [['regex'], ['production']]),
  Rule('regex', [['SYMBOLNAME', '__0_:', 'QUOTE', '__1_;']]),
  Rule('_maybe_symbol0', [['body']]),
  Rule('production', [['NONTERMINALNAME', '__0_:', '_maybe_symbol0', '__1_;'], ['NONTERMINALNAME', '__0_:', '__1_;']]),
  Rule('_star_symbol1', [['expansion', '__2_|', '_star_symbol1'], ['expansion', '__2_|']]),
  Rule('body', [['_star_symbol1', 'expansion'], ['expansion']]),
  Rule('_plus_symbol1', [['decorated', '_plus_symbol1'], ['decorated']]),
  Rule('expansion', [['_plus_symbol1']]),
  Rule('decorated', [['enclosed', '__3_*'], ['enclosed', '__4_+'], ['enclosed', '__5_?'], ['enclosed']]),
  Rule('enclosed', [['__6_[', 'expansion', '__7_]'], ['__8_>', 'expansion', '__9_<'], ['__9_<', 'primary', '__8_>'], ['__10_(', 'expansion', '__11_)'], ['primary']]),
  Rule('primary', [['NONTERMINALNAME'], ['SYMBOLNAME'], ['QUOTE']])],
 'file')
def recognize(runner, i):
    assert i >= 0
    input = runner.text
    state = 0
    while 1:
        if state == 0:
            try:
                char = input[i]
                i += 1
            except IndexError:
                runner.state = 0
                return ~i
            if char == '\t':
                state = 1
            elif char == '\n':
                state = 2
            elif char == ' ':
                state = 3
            elif char == '#':
                state = 4
            elif char == '"':
                state = 5
            elif char == "'":
                state = 6
            elif char == ')':
                state = 7
            elif char == '(':
                state = 8
            elif char == '+':
                state = 9
            elif char == '*':
                state = 10
            elif char == ';':
                state = 11
            elif char == ':':
                state = 12
            elif char == '<':
                state = 13
            elif char == '?':
                state = 14
            elif char == '>':
                state = 15
            elif 'A' <= char <= 'Z':
                state = 16
            elif char == '[':
                state = 17
            elif char == ']':
                state = 18
            elif char == '_':
                state = 19
            elif 'a' <= char <= 'z':
                state = 20
            elif char == '|':
                state = 21
            else:
                break
        if state == 4:
            try:
                char = input[i]
                i += 1
            except IndexError:
                runner.state = 4
                return ~i
            if char == '\n':
                state = 27
            elif '\x00' <= char <= '\t':
                state = 4
                continue
            elif '\x0b' <= char <= '\xff':
                state = 4
                continue
            else:
                break
        if state == 5:
            try:
                char = input[i]
                i += 1
            except IndexError:
                runner.state = 5
                return ~i
            if char == '\\':
                state = 24
            elif char == '"':
                state = 25
            elif '\x00' <= char <= '!':
                state = 5
                continue
            elif '#' <= char <= '[':
                state = 5
                continue
            elif ']' <= char <= '\xff':
                state = 5
                continue
            else:
                break
        if state == 6:
            try:
                char = input[i]
                i += 1
            except IndexError:
                runner.state = 6
                return ~i
            if char == '"':
                state = 22
            else:
                break
        if state == 16:
            runner.last_matched_index = i - 1
            runner.last_matched_state = state
            try:
                char = input[i]
                i += 1
            except IndexError:
                runner.state = 16
                return i
            if char == '_':
                state = 16
                continue
            elif 'A' <= char <= 'Z':
                state = 16
                continue
            else:
                break
        if state == 19:
            runner.last_matched_index = i - 1
            runner.last_matched_state = state
            try:
                char = input[i]
                i += 1
            except IndexError:
                runner.state = 19
                return i
            if 'A' <= char <= 'Z':
                state = 16
                continue
            elif char == '_':
                state = 19
                continue
            elif '0' <= char <= '9':
                state = 20
            elif 'a' <= char <= 'z':
                state = 20
            else:
                break
        if state == 20:
            runner.last_matched_index = i - 1
            runner.last_matched_state = state
            try:
                char = input[i]
                i += 1
            except IndexError:
                runner.state = 20
                return i
            if char == '_':
                state = 20
                continue
            elif '0' <= char <= '9':
                state = 20
                continue
            elif 'a' <= char <= 'z':
                state = 20
                continue
            else:
                break
        if state == 22:
            try:
                char = input[i]
                i += 1
            except IndexError:
                runner.state = 22
                return ~i
            if char == "'":
                state = 23
            else:
                break
        if state == 24:
            try:
                char = input[i]
                i += 1
            except IndexError:
                runner.state = 24
                return ~i
            if char == '\\':
                state = 24
                continue
            elif char == '"':
                state = 26
            elif '\x00' <= char <= '!':
                state = 5
                continue
            elif '#' <= char <= '[':
                state = 5
                continue
            elif ']' <= char <= '\xff':
                state = 5
                continue
            else:
                break
        if state == 26:
            runner.last_matched_index = i - 1
            runner.last_matched_state = state
            try:
                char = input[i]
                i += 1
            except IndexError:
                runner.state = 26
                return i
            if char == '"':
                state = 25
            elif '\x00' <= char <= '!':
                state = 5
                continue
            elif '#' <= char <= '\xff':
                state = 5
                continue
            else:
                break
        runner.last_matched_state = state
        runner.last_matched_index = i - 1
        runner.state = state
        if i == len(input):
            return i
        else:
            return ~i
        break
    runner.state = state
    return ~i
lexer = DummyLexer(recognize, DFA(28,
 {(0, '\t'): 1,
  (0, '\n'): 2,
  (0, ' '): 3,
  (0, '"'): 5,
  (0, '#'): 4,
  (0, "'"): 6,
  (0, '('): 8,
  (0, ')'): 7,
  (0, '*'): 10,
  (0, '+'): 9,
  (0, ':'): 12,
  (0, ';'): 11,
  (0, '<'): 13,
  (0, '>'): 15,
  (0, '?'): 14,
  (0, 'A'): 16,
  (0, 'B'): 16,
  (0, 'C'): 16,
  (0, 'D'): 16,
  (0, 'E'): 16,
  (0, 'F'): 16,
  (0, 'G'): 16,
  (0, 'H'): 16,
  (0, 'I'): 16,
  (0, 'J'): 16,
  (0, 'K'): 16,
  (0, 'L'): 16,
  (0, 'M'): 16,
  (0, 'N'): 16,
  (0, 'O'): 16,
  (0, 'P'): 16,
  (0, 'Q'): 16,
  (0, 'R'): 16,
  (0, 'S'): 16,
  (0, 'T'): 16,
  (0, 'U'): 16,
  (0, 'V'): 16,
  (0, 'W'): 16,
  (0, 'X'): 16,
  (0, 'Y'): 16,
  (0, 'Z'): 16,
  (0, '['): 17,
  (0, ']'): 18,
  (0, '_'): 19,
  (0, 'a'): 20,
  (0, 'b'): 20,
  (0, 'c'): 20,
  (0, 'd'): 20,
  (0, 'e'): 20,
  (0, 'f'): 20,
  (0, 'g'): 20,
  (0, 'h'): 20,
  (0, 'i'): 20,
  (0, 'j'): 20,
  (0, 'k'): 20,
  (0, 'l'): 20,
  (0, 'm'): 20,
  (0, 'n'): 20,
  (0, 'o'): 20,
  (0, 'p'): 20,
  (0, 'q'): 20,
  (0, 'r'): 20,
  (0, 's'): 20,
  (0, 't'): 20,
  (0, 'u'): 20,
  (0, 'v'): 20,
  (0, 'w'): 20,
  (0, 'x'): 20,
  (0, 'y'): 20,
  (0, 'z'): 20,
  (0, '|'): 21,
  (4, '\x00'): 4,
  (4, '\x01'): 4,
  (4, '\x02'): 4,
  (4, '\x03'): 4,
  (4, '\x04'): 4,
  (4, '\x05'): 4,
  (4, '\x06'): 4,
  (4, '\x07'): 4,
  (4, '\x08'): 4,
  (4, '\t'): 4,
  (4, '\n'): 27,
  (4, '\x0b'): 4,
  (4, '\x0c'): 4,
  (4, '\r'): 4,
  (4, '\x0e'): 4,
  (4, '\x0f'): 4,
  (4, '\x10'): 4,
  (4, '\x11'): 4,
  (4, '\x12'): 4,
  (4, '\x13'): 4,
  (4, '\x14'): 4,
  (4, '\x15'): 4,
  (4, '\x16'): 4,
  (4, '\x17'): 4,
  (4, '\x18'): 4,
  (4, '\x19'): 4,
  (4, '\x1a'): 4,
  (4, '\x1b'): 4,
  (4, '\x1c'): 4,
  (4, '\x1d'): 4,
  (4, '\x1e'): 4,
  (4, '\x1f'): 4,
  (4, ' '): 4,
  (4, '!'): 4,
  (4, '"'): 4,
  (4, '#'): 4,
  (4, '$'): 4,
  (4, '%'): 4,
  (4, '&'): 4,
  (4, "'"): 4,
  (4, '('): 4,
  (4, ')'): 4,
  (4, '*'): 4,
  (4, '+'): 4,
  (4, ','): 4,
  (4, '-'): 4,
  (4, '.'): 4,
  (4, '/'): 4,
  (4, '0'): 4,
  (4, '1'): 4,
  (4, '2'): 4,
  (4, '3'): 4,
  (4, '4'): 4,
  (4, '5'): 4,
  (4, '6'): 4,
  (4, '7'): 4,
  (4, '8'): 4,
  (4, '9'): 4,
  (4, ':'): 4,
  (4, ';'): 4,
  (4, '<'): 4,
  (4, '='): 4,
  (4, '>'): 4,
  (4, '?'): 4,
  (4, '@'): 4,
  (4, 'A'): 4,
  (4, 'B'): 4,
  (4, 'C'): 4,
  (4, 'D'): 4,
  (4, 'E'): 4,
  (4, 'F'): 4,
  (4, 'G'): 4,
  (4, 'H'): 4,
  (4, 'I'): 4,
  (4, 'J'): 4,
  (4, 'K'): 4,
  (4, 'L'): 4,
  (4, 'M'): 4,
  (4, 'N'): 4,
  (4, 'O'): 4,
  (4, 'P'): 4,
  (4, 'Q'): 4,
  (4, 'R'): 4,
  (4, 'S'): 4,
  (4, 'T'): 4,
  (4, 'U'): 4,
  (4, 'V'): 4,
  (4, 'W'): 4,
  (4, 'X'): 4,
  (4, 'Y'): 4,
  (4, 'Z'): 4,
  (4, '['): 4,
  (4, '\\'): 4,
  (4, ']'): 4,
  (4, '^'): 4,
  (4, '_'): 4,
  (4, '`'): 4,
  (4, 'a'): 4,
  (4, 'b'): 4,
  (4, 'c'): 4,
  (4, 'd'): 4,
  (4, 'e'): 4,
  (4, 'f'): 4,
  (4, 'g'): 4,
  (4, 'h'): 4,
  (4, 'i'): 4,
  (4, 'j'): 4,
  (4, 'k'): 4,
  (4, 'l'): 4,
  (4, 'm'): 4,
  (4, 'n'): 4,
  (4, 'o'): 4,
  (4, 'p'): 4,
  (4, 'q'): 4,
  (4, 'r'): 4,
  (4, 's'): 4,
  (4, 't'): 4,
  (4, 'u'): 4,
  (4, 'v'): 4,
  (4, 'w'): 4,
  (4, 'x'): 4,
  (4, 'y'): 4,
  (4, 'z'): 4,
  (4, '{'): 4,
  (4, '|'): 4,
  (4, '}'): 4,
  (4, '~'): 4,
  (4, '\x7f'): 4,
  (4, '\x80'): 4,
  (4, '\x81'): 4,
  (4, '\x82'): 4,
  (4, '\x83'): 4,
  (4, '\x84'): 4,
  (4, '\x85'): 4,
  (4, '\x86'): 4,
  (4, '\x87'): 4,
  (4, '\x88'): 4,
  (4, '\x89'): 4,
  (4, '\x8a'): 4,
  (4, '\x8b'): 4,
  (4, '\x8c'): 4,
  (4, '\x8d'): 4,
  (4, '\x8e'): 4,
  (4, '\x8f'): 4,
  (4, '\x90'): 4,
  (4, '\x91'): 4,
  (4, '\x92'): 4,
  (4, '\x93'): 4,
  (4, '\x94'): 4,
  (4, '\x95'): 4,
  (4, '\x96'): 4,
  (4, '\x97'): 4,
  (4, '\x98'): 4,
  (4, '\x99'): 4,
  (4, '\x9a'): 4,
  (4, '\x9b'): 4,
  (4, '\x9c'): 4,
  (4, '\x9d'): 4,
  (4, '\x9e'): 4,
  (4, '\x9f'): 4,
  (4, '\xa0'): 4,
  (4, '\xa1'): 4,
  (4, '\xa2'): 4,
  (4, '\xa3'): 4,
  (4, '\xa4'): 4,
  (4, '\xa5'): 4,
  (4, '\xa6'): 4,
  (4, '\xa7'): 4,
  (4, '\xa8'): 4,
  (4, '\xa9'): 4,
  (4, '\xaa'): 4,
  (4, '\xab'): 4,
  (4, '\xac'): 4,
  (4, '\xad'): 4,
  (4, '\xae'): 4,
  (4, '\xaf'): 4,
  (4, '\xb0'): 4,
  (4, '\xb1'): 4,
  (4, '\xb2'): 4,
  (4, '\xb3'): 4,
  (4, '\xb4'): 4,
  (4, '\xb5'): 4,
  (4, '\xb6'): 4,
  (4, '\xb7'): 4,
  (4, '\xb8'): 4,
  (4, '\xb9'): 4,
  (4, '\xba'): 4,
  (4, '\xbb'): 4,
  (4, '\xbc'): 4,
  (4, '\xbd'): 4,
  (4, '\xbe'): 4,
  (4, '\xbf'): 4,
  (4, '\xc0'): 4,
  (4, '\xc1'): 4,
  (4, '\xc2'): 4,
  (4, '\xc3'): 4,
  (4, '\xc4'): 4,
  (4, '\xc5'): 4,
  (4, '\xc6'): 4,
  (4, '\xc7'): 4,
  (4, '\xc8'): 4,
  (4, '\xc9'): 4,
  (4, '\xca'): 4,
  (4, '\xcb'): 4,
  (4, '\xcc'): 4,
  (4, '\xcd'): 4,
  (4, '\xce'): 4,
  (4, '\xcf'): 4,
  (4, '\xd0'): 4,
  (4, '\xd1'): 4,
  (4, '\xd2'): 4,
  (4, '\xd3'): 4,
  (4, '\xd4'): 4,
  (4, '\xd5'): 4,
  (4, '\xd6'): 4,
  (4, '\xd7'): 4,
  (4, '\xd8'): 4,
  (4, '\xd9'): 4,
  (4, '\xda'): 4,
  (4, '\xdb'): 4,
  (4, '\xdc'): 4,
  (4, '\xdd'): 4,
  (4, '\xde'): 4,
  (4, '\xdf'): 4,
  (4, '\xe0'): 4,
  (4, '\xe1'): 4,
  (4, '\xe2'): 4,
  (4, '\xe3'): 4,
  (4, '\xe4'): 4,
  (4, '\xe5'): 4,
  (4, '\xe6'): 4,
  (4, '\xe7'): 4,
  (4, '\xe8'): 4,
  (4, '\xe9'): 4,
  (4, '\xea'): 4,
  (4, '\xeb'): 4,
  (4, '\xec'): 4,
  (4, '\xed'): 4,
  (4, '\xee'): 4,
  (4, '\xef'): 4,
  (4, '\xf0'): 4,
  (4, '\xf1'): 4,
  (4, '\xf2'): 4,
  (4, '\xf3'): 4,
  (4, '\xf4'): 4,
  (4, '\xf5'): 4,
  (4, '\xf6'): 4,
  (4, '\xf7'): 4,
  (4, '\xf8'): 4,
  (4, '\xf9'): 4,
  (4, '\xfa'): 4,
  (4, '\xfb'): 4,
  (4, '\xfc'): 4,
  (4, '\xfd'): 4,
  (4, '\xfe'): 4,
  (4, '\xff'): 4,
  (5, '\x00'): 5,
  (5, '\x01'): 5,
  (5, '\x02'): 5,
  (5, '\x03'): 5,
  (5, '\x04'): 5,
  (5, '\x05'): 5,
  (5, '\x06'): 5,
  (5, '\x07'): 5,
  (5, '\x08'): 5,
  (5, '\t'): 5,
  (5, '\n'): 5,
  (5, '\x0b'): 5,
  (5, '\x0c'): 5,
  (5, '\r'): 5,
  (5, '\x0e'): 5,
  (5, '\x0f'): 5,
  (5, '\x10'): 5,
  (5, '\x11'): 5,
  (5, '\x12'): 5,
  (5, '\x13'): 5,
  (5, '\x14'): 5,
  (5, '\x15'): 5,
  (5, '\x16'): 5,
  (5, '\x17'): 5,
  (5, '\x18'): 5,
  (5, '\x19'): 5,
  (5, '\x1a'): 5,
  (5, '\x1b'): 5,
  (5, '\x1c'): 5,
  (5, '\x1d'): 5,
  (5, '\x1e'): 5,
  (5, '\x1f'): 5,
  (5, ' '): 5,
  (5, '!'): 5,
  (5, '"'): 25,
  (5, '#'): 5,
  (5, '$'): 5,
  (5, '%'): 5,
  (5, '&'): 5,
  (5, "'"): 5,
  (5, '('): 5,
  (5, ')'): 5,
  (5, '*'): 5,
  (5, '+'): 5,
  (5, ','): 5,
  (5, '-'): 5,
  (5, '.'): 5,
  (5, '/'): 5,
  (5, '0'): 5,
  (5, '1'): 5,
  (5, '2'): 5,
  (5, '3'): 5,
  (5, '4'): 5,
  (5, '5'): 5,
  (5, '6'): 5,
  (5, '7'): 5,
  (5, '8'): 5,
  (5, '9'): 5,
  (5, ':'): 5,
  (5, ';'): 5,
  (5, '<'): 5,
  (5, '='): 5,
  (5, '>'): 5,
  (5, '?'): 5,
  (5, '@'): 5,
  (5, 'A'): 5,
  (5, 'B'): 5,
  (5, 'C'): 5,
  (5, 'D'): 5,
  (5, 'E'): 5,
  (5, 'F'): 5,
  (5, 'G'): 5,
  (5, 'H'): 5,
  (5, 'I'): 5,
  (5, 'J'): 5,
  (5, 'K'): 5,
  (5, 'L'): 5,
  (5, 'M'): 5,
  (5, 'N'): 5,
  (5, 'O'): 5,
  (5, 'P'): 5,
  (5, 'Q'): 5,
  (5, 'R'): 5,
  (5, 'S'): 5,
  (5, 'T'): 5,
  (5, 'U'): 5,
  (5, 'V'): 5,
  (5, 'W'): 5,
  (5, 'X'): 5,
  (5, 'Y'): 5,
  (5, 'Z'): 5,
  (5, '['): 5,
  (5, '\\'): 24,
  (5, ']'): 5,
  (5, '^'): 5,
  (5, '_'): 5,
  (5, '`'): 5,
  (5, 'a'): 5,
  (5, 'b'): 5,
  (5, 'c'): 5,
  (5, 'd'): 5,
  (5, 'e'): 5,
  (5, 'f'): 5,
  (5, 'g'): 5,
  (5, 'h'): 5,
  (5, 'i'): 5,
  (5, 'j'): 5,
  (5, 'k'): 5,
  (5, 'l'): 5,
  (5, 'm'): 5,
  (5, 'n'): 5,
  (5, 'o'): 5,
  (5, 'p'): 5,
  (5, 'q'): 5,
  (5, 'r'): 5,
  (5, 's'): 5,
  (5, 't'): 5,
  (5, 'u'): 5,
  (5, 'v'): 5,
  (5, 'w'): 5,
  (5, 'x'): 5,
  (5, 'y'): 5,
  (5, 'z'): 5,
  (5, '{'): 5,
  (5, '|'): 5,
  (5, '}'): 5,
  (5, '~'): 5,
  (5, '\x7f'): 5,
  (5, '\x80'): 5,
  (5, '\x81'): 5,
  (5, '\x82'): 5,
  (5, '\x83'): 5,
  (5, '\x84'): 5,
  (5, '\x85'): 5,
  (5, '\x86'): 5,
  (5, '\x87'): 5,
  (5, '\x88'): 5,
  (5, '\x89'): 5,
  (5, '\x8a'): 5,
  (5, '\x8b'): 5,
  (5, '\x8c'): 5,
  (5, '\x8d'): 5,
  (5, '\x8e'): 5,
  (5, '\x8f'): 5,
  (5, '\x90'): 5,
  (5, '\x91'): 5,
  (5, '\x92'): 5,
  (5, '\x93'): 5,
  (5, '\x94'): 5,
  (5, '\x95'): 5,
  (5, '\x96'): 5,
  (5, '\x97'): 5,
  (5, '\x98'): 5,
  (5, '\x99'): 5,
  (5, '\x9a'): 5,
  (5, '\x9b'): 5,
  (5, '\x9c'): 5,
  (5, '\x9d'): 5,
  (5, '\x9e'): 5,
  (5, '\x9f'): 5,
  (5, '\xa0'): 5,
  (5, '\xa1'): 5,
  (5, '\xa2'): 5,
  (5, '\xa3'): 5,
  (5, '\xa4'): 5,
  (5, '\xa5'): 5,
  (5, '\xa6'): 5,
  (5, '\xa7'): 5,
  (5, '\xa8'): 5,
  (5, '\xa9'): 5,
  (5, '\xaa'): 5,
  (5, '\xab'): 5,
  (5, '\xac'): 5,
  (5, '\xad'): 5,
  (5, '\xae'): 5,
  (5, '\xaf'): 5,
  (5, '\xb0'): 5,
  (5, '\xb1'): 5,
  (5, '\xb2'): 5,
  (5, '\xb3'): 5,
  (5, '\xb4'): 5,
  (5, '\xb5'): 5,
  (5, '\xb6'): 5,
  (5, '\xb7'): 5,
  (5, '\xb8'): 5,
  (5, '\xb9'): 5,
  (5, '\xba'): 5,
  (5, '\xbb'): 5,
  (5, '\xbc'): 5,
  (5, '\xbd'): 5,
  (5, '\xbe'): 5,
  (5, '\xbf'): 5,
  (5, '\xc0'): 5,
  (5, '\xc1'): 5,
  (5, '\xc2'): 5,
  (5, '\xc3'): 5,
  (5, '\xc4'): 5,
  (5, '\xc5'): 5,
  (5, '\xc6'): 5,
  (5, '\xc7'): 5,
  (5, '\xc8'): 5,
  (5, '\xc9'): 5,
  (5, '\xca'): 5,
  (5, '\xcb'): 5,
  (5, '\xcc'): 5,
  (5, '\xcd'): 5,
  (5, '\xce'): 5,
  (5, '\xcf'): 5,
  (5, '\xd0'): 5,
  (5, '\xd1'): 5,
  (5, '\xd2'): 5,
  (5, '\xd3'): 5,
  (5, '\xd4'): 5,
  (5, '\xd5'): 5,
  (5, '\xd6'): 5,
  (5, '\xd7'): 5,
  (5, '\xd8'): 5,
  (5, '\xd9'): 5,
  (5, '\xda'): 5,
  (5, '\xdb'): 5,
  (5, '\xdc'): 5,
  (5, '\xdd'): 5,
  (5, '\xde'): 5,
  (5, '\xdf'): 5,
  (5, '\xe0'): 5,
  (5, '\xe1'): 5,
  (5, '\xe2'): 5,
  (5, '\xe3'): 5,
  (5, '\xe4'): 5,
  (5, '\xe5'): 5,
  (5, '\xe6'): 5,
  (5, '\xe7'): 5,
  (5, '\xe8'): 5,
  (5, '\xe9'): 5,
  (5, '\xea'): 5,
  (5, '\xeb'): 5,
  (5, '\xec'): 5,
  (5, '\xed'): 5,
  (5, '\xee'): 5,
  (5, '\xef'): 5,
  (5, '\xf0'): 5,
  (5, '\xf1'): 5,
  (5, '\xf2'): 5,
  (5, '\xf3'): 5,
  (5, '\xf4'): 5,
  (5, '\xf5'): 5,
  (5, '\xf6'): 5,
  (5, '\xf7'): 5,
  (5, '\xf8'): 5,
  (5, '\xf9'): 5,
  (5, '\xfa'): 5,
  (5, '\xfb'): 5,
  (5, '\xfc'): 5,
  (5, '\xfd'): 5,
  (5, '\xfe'): 5,
  (5, '\xff'): 5,
  (6, '"'): 22,
  (16, 'A'): 16,
  (16, 'B'): 16,
  (16, 'C'): 16,
  (16, 'D'): 16,
  (16, 'E'): 16,
  (16, 'F'): 16,
  (16, 'G'): 16,
  (16, 'H'): 16,
  (16, 'I'): 16,
  (16, 'J'): 16,
  (16, 'K'): 16,
  (16, 'L'): 16,
  (16, 'M'): 16,
  (16, 'N'): 16,
  (16, 'O'): 16,
  (16, 'P'): 16,
  (16, 'Q'): 16,
  (16, 'R'): 16,
  (16, 'S'): 16,
  (16, 'T'): 16,
  (16, 'U'): 16,
  (16, 'V'): 16,
  (16, 'W'): 16,
  (16, 'X'): 16,
  (16, 'Y'): 16,
  (16, 'Z'): 16,
  (16, '_'): 16,
  (19, '0'): 20,
  (19, '1'): 20,
  (19, '2'): 20,
  (19, '3'): 20,
  (19, '4'): 20,
  (19, '5'): 20,
  (19, '6'): 20,
  (19, '7'): 20,
  (19, '8'): 20,
  (19, '9'): 20,
  (19, 'A'): 16,
  (19, 'B'): 16,
  (19, 'C'): 16,
  (19, 'D'): 16,
  (19, 'E'): 16,
  (19, 'F'): 16,
  (19, 'G'): 16,
  (19, 'H'): 16,
  (19, 'I'): 16,
  (19, 'J'): 16,
  (19, 'K'): 16,
  (19, 'L'): 16,
  (19, 'M'): 16,
  (19, 'N'): 16,
  (19, 'O'): 16,
  (19, 'P'): 16,
  (19, 'Q'): 16,
  (19, 'R'): 16,
  (19, 'S'): 16,
  (19, 'T'): 16,
  (19, 'U'): 16,
  (19, 'V'): 16,
  (19, 'W'): 16,
  (19, 'X'): 16,
  (19, 'Y'): 16,
  (19, 'Z'): 16,
  (19, '_'): 19,
  (19, 'a'): 20,
  (19, 'b'): 20,
  (19, 'c'): 20,
  (19, 'd'): 20,
  (19, 'e'): 20,
  (19, 'f'): 20,
  (19, 'g'): 20,
  (19, 'h'): 20,
  (19, 'i'): 20,
  (19, 'j'): 20,
  (19, 'k'): 20,
  (19, 'l'): 20,
  (19, 'm'): 20,
  (19, 'n'): 20,
  (19, 'o'): 20,
  (19, 'p'): 20,
  (19, 'q'): 20,
  (19, 'r'): 20,
  (19, 's'): 20,
  (19, 't'): 20,
  (19, 'u'): 20,
  (19, 'v'): 20,
  (19, 'w'): 20,
  (19, 'x'): 20,
  (19, 'y'): 20,
  (19, 'z'): 20,
  (20, '0'): 20,
  (20, '1'): 20,
  (20, '2'): 20,
  (20, '3'): 20,
  (20, '4'): 20,
  (20, '5'): 20,
  (20, '6'): 20,
  (20, '7'): 20,
  (20, '8'): 20,
  (20, '9'): 20,
  (20, '_'): 20,
  (20, 'a'): 20,
  (20, 'b'): 20,
  (20, 'c'): 20,
  (20, 'd'): 20,
  (20, 'e'): 20,
  (20, 'f'): 20,
  (20, 'g'): 20,
  (20, 'h'): 20,
  (20, 'i'): 20,
  (20, 'j'): 20,
  (20, 'k'): 20,
  (20, 'l'): 20,
  (20, 'm'): 20,
  (20, 'n'): 20,
  (20, 'o'): 20,
  (20, 'p'): 20,
  (20, 'q'): 20,
  (20, 'r'): 20,
  (20, 's'): 20,
  (20, 't'): 20,
  (20, 'u'): 20,
  (20, 'v'): 20,
  (20, 'w'): 20,
  (20, 'x'): 20,
  (20, 'y'): 20,
  (20, 'z'): 20,
  (22, "'"): 23,
  (24, '\x00'): 5,
  (24, '\x01'): 5,
  (24, '\x02'): 5,
  (24, '\x03'): 5,
  (24, '\x04'): 5,
  (24, '\x05'): 5,
  (24, '\x06'): 5,
  (24, '\x07'): 5,
  (24, '\x08'): 5,
  (24, '\t'): 5,
  (24, '\n'): 5,
  (24, '\x0b'): 5,
  (24, '\x0c'): 5,
  (24, '\r'): 5,
  (24, '\x0e'): 5,
  (24, '\x0f'): 5,
  (24, '\x10'): 5,
  (24, '\x11'): 5,
  (24, '\x12'): 5,
  (24, '\x13'): 5,
  (24, '\x14'): 5,
  (24, '\x15'): 5,
  (24, '\x16'): 5,
  (24, '\x17'): 5,
  (24, '\x18'): 5,
  (24, '\x19'): 5,
  (24, '\x1a'): 5,
  (24, '\x1b'): 5,
  (24, '\x1c'): 5,
  (24, '\x1d'): 5,
  (24, '\x1e'): 5,
  (24, '\x1f'): 5,
  (24, ' '): 5,
  (24, '!'): 5,
  (24, '"'): 26,
  (24, '#'): 5,
  (24, '$'): 5,
  (24, '%'): 5,
  (24, '&'): 5,
  (24, "'"): 5,
  (24, '('): 5,
  (24, ')'): 5,
  (24, '*'): 5,
  (24, '+'): 5,
  (24, ','): 5,
  (24, '-'): 5,
  (24, '.'): 5,
  (24, '/'): 5,
  (24, '0'): 5,
  (24, '1'): 5,
  (24, '2'): 5,
  (24, '3'): 5,
  (24, '4'): 5,
  (24, '5'): 5,
  (24, '6'): 5,
  (24, '7'): 5,
  (24, '8'): 5,
  (24, '9'): 5,
  (24, ':'): 5,
  (24, ';'): 5,
  (24, '<'): 5,
  (24, '='): 5,
  (24, '>'): 5,
  (24, '?'): 5,
  (24, '@'): 5,
  (24, 'A'): 5,
  (24, 'B'): 5,
  (24, 'C'): 5,
  (24, 'D'): 5,
  (24, 'E'): 5,
  (24, 'F'): 5,
  (24, 'G'): 5,
  (24, 'H'): 5,
  (24, 'I'): 5,
  (24, 'J'): 5,
  (24, 'K'): 5,
  (24, 'L'): 5,
  (24, 'M'): 5,
  (24, 'N'): 5,
  (24, 'O'): 5,
  (24, 'P'): 5,
  (24, 'Q'): 5,
  (24, 'R'): 5,
  (24, 'S'): 5,
  (24, 'T'): 5,
  (24, 'U'): 5,
  (24, 'V'): 5,
  (24, 'W'): 5,
  (24, 'X'): 5,
  (24, 'Y'): 5,
  (24, 'Z'): 5,
  (24, '['): 5,
  (24, '\\'): 24,
  (24, ']'): 5,
  (24, '^'): 5,
  (24, '_'): 5,
  (24, '`'): 5,
  (24, 'a'): 5,
  (24, 'b'): 5,
  (24, 'c'): 5,
  (24, 'd'): 5,
  (24, 'e'): 5,
  (24, 'f'): 5,
  (24, 'g'): 5,
  (24, 'h'): 5,
  (24, 'i'): 5,
  (24, 'j'): 5,
  (24, 'k'): 5,
  (24, 'l'): 5,
  (24, 'm'): 5,
  (24, 'n'): 5,
  (24, 'o'): 5,
  (24, 'p'): 5,
  (24, 'q'): 5,
  (24, 'r'): 5,
  (24, 's'): 5,
  (24, 't'): 5,
  (24, 'u'): 5,
  (24, 'v'): 5,
  (24, 'w'): 5,
  (24, 'x'): 5,
  (24, 'y'): 5,
  (24, 'z'): 5,
  (24, '{'): 5,
  (24, '|'): 5,
  (24, '}'): 5,
  (24, '~'): 5,
  (24, '\x7f'): 5,
  (24, '\x80'): 5,
  (24, '\x81'): 5,
  (24, '\x82'): 5,
  (24, '\x83'): 5,
  (24, '\x84'): 5,
  (24, '\x85'): 5,
  (24, '\x86'): 5,
  (24, '\x87'): 5,
  (24, '\x88'): 5,
  (24, '\x89'): 5,
  (24, '\x8a'): 5,
  (24, '\x8b'): 5,
  (24, '\x8c'): 5,
  (24, '\x8d'): 5,
  (24, '\x8e'): 5,
  (24, '\x8f'): 5,
  (24, '\x90'): 5,
  (24, '\x91'): 5,
  (24, '\x92'): 5,
  (24, '\x93'): 5,
  (24, '\x94'): 5,
  (24, '\x95'): 5,
  (24, '\x96'): 5,
  (24, '\x97'): 5,
  (24, '\x98'): 5,
  (24, '\x99'): 5,
  (24, '\x9a'): 5,
  (24, '\x9b'): 5,
  (24, '\x9c'): 5,
  (24, '\x9d'): 5,
  (24, '\x9e'): 5,
  (24, '\x9f'): 5,
  (24, '\xa0'): 5,
  (24, '\xa1'): 5,
  (24, '\xa2'): 5,
  (24, '\xa3'): 5,
  (24, '\xa4'): 5,
  (24, '\xa5'): 5,
  (24, '\xa6'): 5,
  (24, '\xa7'): 5,
  (24, '\xa8'): 5,
  (24, '\xa9'): 5,
  (24, '\xaa'): 5,
  (24, '\xab'): 5,
  (24, '\xac'): 5,
  (24, '\xad'): 5,
  (24, '\xae'): 5,
  (24, '\xaf'): 5,
  (24, '\xb0'): 5,
  (24, '\xb1'): 5,
  (24, '\xb2'): 5,
  (24, '\xb3'): 5,
  (24, '\xb4'): 5,
  (24, '\xb5'): 5,
  (24, '\xb6'): 5,
  (24, '\xb7'): 5,
  (24, '\xb8'): 5,
  (24, '\xb9'): 5,
  (24, '\xba'): 5,
  (24, '\xbb'): 5,
  (24, '\xbc'): 5,
  (24, '\xbd'): 5,
  (24, '\xbe'): 5,
  (24, '\xbf'): 5,
  (24, '\xc0'): 5,
  (24, '\xc1'): 5,
  (24, '\xc2'): 5,
  (24, '\xc3'): 5,
  (24, '\xc4'): 5,
  (24, '\xc5'): 5,
  (24, '\xc6'): 5,
  (24, '\xc7'): 5,
  (24, '\xc8'): 5,
  (24, '\xc9'): 5,
  (24, '\xca'): 5,
  (24, '\xcb'): 5,
  (24, '\xcc'): 5,
  (24, '\xcd'): 5,
  (24, '\xce'): 5,
  (24, '\xcf'): 5,
  (24, '\xd0'): 5,
  (24, '\xd1'): 5,
  (24, '\xd2'): 5,
  (24, '\xd3'): 5,
  (24, '\xd4'): 5,
  (24, '\xd5'): 5,
  (24, '\xd6'): 5,
  (24, '\xd7'): 5,
  (24, '\xd8'): 5,
  (24, '\xd9'): 5,
  (24, '\xda'): 5,
  (24, '\xdb'): 5,
  (24, '\xdc'): 5,
  (24, '\xdd'): 5,
  (24, '\xde'): 5,
  (24, '\xdf'): 5,
  (24, '\xe0'): 5,
  (24, '\xe1'): 5,
  (24, '\xe2'): 5,
  (24, '\xe3'): 5,
  (24, '\xe4'): 5,
  (24, '\xe5'): 5,
  (24, '\xe6'): 5,
  (24, '\xe7'): 5,
  (24, '\xe8'): 5,
  (24, '\xe9'): 5,
  (24, '\xea'): 5,
  (24, '\xeb'): 5,
  (24, '\xec'): 5,
  (24, '\xed'): 5,
  (24, '\xee'): 5,
  (24, '\xef'): 5,
  (24, '\xf0'): 5,
  (24, '\xf1'): 5,
  (24, '\xf2'): 5,
  (24, '\xf3'): 5,
  (24, '\xf4'): 5,
  (24, '\xf5'): 5,
  (24, '\xf6'): 5,
  (24, '\xf7'): 5,
  (24, '\xf8'): 5,
  (24, '\xf9'): 5,
  (24, '\xfa'): 5,
  (24, '\xfb'): 5,
  (24, '\xfc'): 5,
  (24, '\xfd'): 5,
  (24, '\xfe'): 5,
  (24, '\xff'): 5,
  (26, '\x00'): 5,
  (26, '\x01'): 5,
  (26, '\x02'): 5,
  (26, '\x03'): 5,
  (26, '\x04'): 5,
  (26, '\x05'): 5,
  (26, '\x06'): 5,
  (26, '\x07'): 5,
  (26, '\x08'): 5,
  (26, '\t'): 5,
  (26, '\n'): 5,
  (26, '\x0b'): 5,
  (26, '\x0c'): 5,
  (26, '\r'): 5,
  (26, '\x0e'): 5,
  (26, '\x0f'): 5,
  (26, '\x10'): 5,
  (26, '\x11'): 5,
  (26, '\x12'): 5,
  (26, '\x13'): 5,
  (26, '\x14'): 5,
  (26, '\x15'): 5,
  (26, '\x16'): 5,
  (26, '\x17'): 5,
  (26, '\x18'): 5,
  (26, '\x19'): 5,
  (26, '\x1a'): 5,
  (26, '\x1b'): 5,
  (26, '\x1c'): 5,
  (26, '\x1d'): 5,
  (26, '\x1e'): 5,
  (26, '\x1f'): 5,
  (26, ' '): 5,
  (26, '!'): 5,
  (26, '"'): 25,
  (26, '#'): 5,
  (26, '$'): 5,
  (26, '%'): 5,
  (26, '&'): 5,
  (26, "'"): 5,
  (26, '('): 5,
  (26, ')'): 5,
  (26, '*'): 5,
  (26, '+'): 5,
  (26, ','): 5,
  (26, '-'): 5,
  (26, '.'): 5,
  (26, '/'): 5,
  (26, '0'): 5,
  (26, '1'): 5,
  (26, '2'): 5,
  (26, '3'): 5,
  (26, '4'): 5,
  (26, '5'): 5,
  (26, '6'): 5,
  (26, '7'): 5,
  (26, '8'): 5,
  (26, '9'): 5,
  (26, ':'): 5,
  (26, ';'): 5,
  (26, '<'): 5,
  (26, '='): 5,
  (26, '>'): 5,
  (26, '?'): 5,
  (26, '@'): 5,
  (26, 'A'): 5,
  (26, 'B'): 5,
  (26, 'C'): 5,
  (26, 'D'): 5,
  (26, 'E'): 5,
  (26, 'F'): 5,
  (26, 'G'): 5,
  (26, 'H'): 5,
  (26, 'I'): 5,
  (26, 'J'): 5,
  (26, 'K'): 5,
  (26, 'L'): 5,
  (26, 'M'): 5,
  (26, 'N'): 5,
  (26, 'O'): 5,
  (26, 'P'): 5,
  (26, 'Q'): 5,
  (26, 'R'): 5,
  (26, 'S'): 5,
  (26, 'T'): 5,
  (26, 'U'): 5,
  (26, 'V'): 5,
  (26, 'W'): 5,
  (26, 'X'): 5,
  (26, 'Y'): 5,
  (26, 'Z'): 5,
  (26, '['): 5,
  (26, '\\'): 5,
  (26, ']'): 5,
  (26, '^'): 5,
  (26, '_'): 5,
  (26, '`'): 5,
  (26, 'a'): 5,
  (26, 'b'): 5,
  (26, 'c'): 5,
  (26, 'd'): 5,
  (26, 'e'): 5,
  (26, 'f'): 5,
  (26, 'g'): 5,
  (26, 'h'): 5,
  (26, 'i'): 5,
  (26, 'j'): 5,
  (26, 'k'): 5,
  (26, 'l'): 5,
  (26, 'm'): 5,
  (26, 'n'): 5,
  (26, 'o'): 5,
  (26, 'p'): 5,
  (26, 'q'): 5,
  (26, 'r'): 5,
  (26, 's'): 5,
  (26, 't'): 5,
  (26, 'u'): 5,
  (26, 'v'): 5,
  (26, 'w'): 5,
  (26, 'x'): 5,
  (26, 'y'): 5,
  (26, 'z'): 5,
  (26, '{'): 5,
  (26, '|'): 5,
  (26, '}'): 5,
  (26, '~'): 5,
  (26, '\x7f'): 5,
  (26, '\x80'): 5,
  (26, '\x81'): 5,
  (26, '\x82'): 5,
  (26, '\x83'): 5,
  (26, '\x84'): 5,
  (26, '\x85'): 5,
  (26, '\x86'): 5,
  (26, '\x87'): 5,
  (26, '\x88'): 5,
  (26, '\x89'): 5,
  (26, '\x8a'): 5,
  (26, '\x8b'): 5,
  (26, '\x8c'): 5,
  (26, '\x8d'): 5,
  (26, '\x8e'): 5,
  (26, '\x8f'): 5,
  (26, '\x90'): 5,
  (26, '\x91'): 5,
  (26, '\x92'): 5,
  (26, '\x93'): 5,
  (26, '\x94'): 5,
  (26, '\x95'): 5,
  (26, '\x96'): 5,
  (26, '\x97'): 5,
  (26, '\x98'): 5,
  (26, '\x99'): 5,
  (26, '\x9a'): 5,
  (26, '\x9b'): 5,
  (26, '\x9c'): 5,
  (26, '\x9d'): 5,
  (26, '\x9e'): 5,
  (26, '\x9f'): 5,
  (26, '\xa0'): 5,
  (26, '\xa1'): 5,
  (26, '\xa2'): 5,
  (26, '\xa3'): 5,
  (26, '\xa4'): 5,
  (26, '\xa5'): 5,
  (26, '\xa6'): 5,
  (26, '\xa7'): 5,
  (26, '\xa8'): 5,
  (26, '\xa9'): 5,
  (26, '\xaa'): 5,
  (26, '\xab'): 5,
  (26, '\xac'): 5,
  (26, '\xad'): 5,
  (26, '\xae'): 5,
  (26, '\xaf'): 5,
  (26, '\xb0'): 5,
  (26, '\xb1'): 5,
  (26, '\xb2'): 5,
  (26, '\xb3'): 5,
  (26, '\xb4'): 5,
  (26, '\xb5'): 5,
  (26, '\xb6'): 5,
  (26, '\xb7'): 5,
  (26, '\xb8'): 5,
  (26, '\xb9'): 5,
  (26, '\xba'): 5,
  (26, '\xbb'): 5,
  (26, '\xbc'): 5,
  (26, '\xbd'): 5,
  (26, '\xbe'): 5,
  (26, '\xbf'): 5,
  (26, '\xc0'): 5,
  (26, '\xc1'): 5,
  (26, '\xc2'): 5,
  (26, '\xc3'): 5,
  (26, '\xc4'): 5,
  (26, '\xc5'): 5,
  (26, '\xc6'): 5,
  (26, '\xc7'): 5,
  (26, '\xc8'): 5,
  (26, '\xc9'): 5,
  (26, '\xca'): 5,
  (26, '\xcb'): 5,
  (26, '\xcc'): 5,
  (26, '\xcd'): 5,
  (26, '\xce'): 5,
  (26, '\xcf'): 5,
  (26, '\xd0'): 5,
  (26, '\xd1'): 5,
  (26, '\xd2'): 5,
  (26, '\xd3'): 5,
  (26, '\xd4'): 5,
  (26, '\xd5'): 5,
  (26, '\xd6'): 5,
  (26, '\xd7'): 5,
  (26, '\xd8'): 5,
  (26, '\xd9'): 5,
  (26, '\xda'): 5,
  (26, '\xdb'): 5,
  (26, '\xdc'): 5,
  (26, '\xdd'): 5,
  (26, '\xde'): 5,
  (26, '\xdf'): 5,
  (26, '\xe0'): 5,
  (26, '\xe1'): 5,
  (26, '\xe2'): 5,
  (26, '\xe3'): 5,
  (26, '\xe4'): 5,
  (26, '\xe5'): 5,
  (26, '\xe6'): 5,
  (26, '\xe7'): 5,
  (26, '\xe8'): 5,
  (26, '\xe9'): 5,
  (26, '\xea'): 5,
  (26, '\xeb'): 5,
  (26, '\xec'): 5,
  (26, '\xed'): 5,
  (26, '\xee'): 5,
  (26, '\xef'): 5,
  (26, '\xf0'): 5,
  (26, '\xf1'): 5,
  (26, '\xf2'): 5,
  (26, '\xf3'): 5,
  (26, '\xf4'): 5,
  (26, '\xf5'): 5,
  (26, '\xf6'): 5,
  (26, '\xf7'): 5,
  (26, '\xf8'): 5,
  (26, '\xf9'): 5,
  (26, '\xfa'): 5,
  (26, '\xfb'): 5,
  (26, '\xfc'): 5,
  (26, '\xfd'): 5,
  (26, '\xfe'): 5,
  (26, '\xff'): 5},
 set([1, 2, 3, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 23, 25, 26, 27]),
 set([1, 2, 3, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 23, 25, 26, 27]),
 ['0, 0, 0, final*, 0, final*, start*, 0, final*, 0, 1, final*, start*, 0, 0, 0, 0, 0, 0, start|, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0',
  'IGNORE',
  'IGNORE',
  'IGNORE',
  '1, final*, 0, start|, 0, final*, start*, 0, final*, 0, 1, final|, start|, 0, final*, start*, 0, final*, 0, final|, start|, 0, 1, final*, start*, 0',
  '1, final*, 0, final*, start*, start|, 0, final|, final*, start*, final*, 0, 0, start|, 0, final*, 0, final*, 0, 1, final|, final*, 0, final|, final*, start*, final*, 0, 0, start|, 0, final*, start|, 0, start*, final*, 0, final*, final|, final*, 0, 1, final*, start*, final*, 0, 0, final|, start|, 0, start|, 0, start*, final*, 0, 1, final|, start|, 0, final*, start*, final*, 0, final*, 1, final|, final*, 0, start|, 0, final*, start*, final*, start*, final*, 0, final|, start|, 0, 0, final*, 0, final|, start|, 0, 1, final*, start*, final*, 0, final*, final|, 1, final*, 0, start|, 0, final*, start*, final*, start*, final*, 0, final|, start|, 0, 0, 0, final*, start*, final*, start*, final*, 0, final|, start|, 0, final*, 0, 0, final*, 1, final|, final*, 0, start|, 0, final*, start*, final*, start*, final*, 0, final|, start|, 0, final*, 0, 0, final*, final|, 1, final*, 0, start|, 0, final*, start*, final*, start*, final*, 0, final|, start|, 0, final*, 0, 0, final*, final*, 0, 1, final|, start|, 0, 1, final*, start*, final*, start*, final*, 0, final|, start|, 0, final*, 0, 0, final*, final*, 0, final|, start|, 0, final*, start*, final*, start*, final*, 0, final|, start|, 0, final*, 0, 0, final*, 1, final|, final*, 0, 1, final|, start|, 0, 1, final*, start*, final*, start*, final*, 0, final|, start|, 0, final*, 0, 0, final*, final|, 1, final*, 0, final|, start|, final*, 0, 1, final|, start|, 0, final*, start*, final*, 0, final*, 1, final|, final*, 0, 1, final|, start|, 0, final*, start*, final*, start*, final*, 0, final|, start|, 0, 0, final*, 0, final|, start|, 0, 1, final*, start*, final*, 0, final*, final|, 1, final*, 0, final|, start|, 0, 1, final*, start*, final*, start*, final*, 0, final|, start|, 0, 0, final*, 0, 1, final|, start|, 0, final*, start*, final*, 0, final*, final*, 0, 1, final|, start|, 0, final*, start*, final*, start*, final*, 0, final|, start|, 0, 0, final*, 0, final|, start|, 0, 1, final*, start*, final*, 0, final*, final*, 0, final|, start|, 0, 1, final*, start*, final*, start*, final*, 0, final|, start|, 0, 0',
  '1',
  '__11_)',
  '__10_(',
  '__4_+',
  '__3_*',
  '__1_;',
  '__0_:',
  '__9_<',
  '__5_?',
  '__8_>',
  'SYMBOLNAME',
  '__6_[',
  '__7_]',
  'NONTERMINALNAME',
  'NONTERMINALNAME',
  '__2_|',
  '2',
  'QUOTE',
  'final*, 0, 1, final*, 0, final|, start|, 0, final*, 0, final|, start|, 0, 1, final*, 0, final|, start|, 0, 1, final*, start*, final*, start*, final*, 0, final|, start|, 0, 1, 0, final*, 0, final|, start|, 0, 1, final*, start*, final*, 0, 1, final*, 0, final|, start|, 0, 0, start|, 0, final*, start*, final*, 0, final|, start|, 0, 1, 0, final*, 0, final|, start|, 0, 1, final*, start*, final*, 0, 1, final*, 0, final|, start|, 0, final*, 0, start|, 0, final*, 0, final|, start|, 0, 1, final*, start*, final*, start*, final*, 0, final|, start|, 0, 1, 0, final*, 0, final|, start|, 0, 1, final*, start*, final*, 0, 1, final*, 0, final|, start|, 0, final*, 0, final|, start|, 0, 1, final*, 0, start|, 0, final*, start*, final*, start*, final*, 0, final|, start|, 0, 1, 0, final*, 0, final|, start|, 0, 1, final*, start*, final*, 0, 1, final*, 0, final|, start|, 0, final*, 0, final|, start|, 0, 1, final*, 0, final|, start|, 0, 1, final*, start*, final*, start*, final*, 0, final|, start|, 0, 1, 0, final*, 0, 1, final*, 0, final|, start|, 0, final*, 0, start|, 0, final*, 0, final|, start|, 0, 1, final*, start*, final*, start*, final*, 0, final|, start|, 0, 1, 0',
  'QUOTE',
  'QUOTE',
  'IGNORE']), {'IGNORE': None})
# generated code between this line and its other occurence

if __name__ == '__main__':
    f = py.path.local(__file__)
    oldcontent = f.read()
    s = "# GENERATED CODE BETWEEN THIS LINE AND ITS OTHER OCCURENCE\n".lower()
    pre, gen, after = oldcontent.split(s)

    parser, lexer, ToAST = make_ebnf_parser()
    transformer = ToAST.source
    newcontent = "%s%s%s\nparser = %r\n%s\n%s%s" % (
            pre, s, transformer.replace("ToAST", "EBNFToAST"),
            parser, lexer.get_dummy_repr(), s, after)
    print newcontent
    f.write(newcontent)
