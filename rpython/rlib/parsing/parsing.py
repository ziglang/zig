import py
from rpython.rlib.parsing.lexer import SourcePos
from rpython.rlib.parsing.tree import Node, Symbol, Nonterminal
from rpython.rlib.objectmodel import not_rpython

class Rule(object):
    def __init__(self, nonterminal, expansions):
        self.nonterminal = nonterminal
        self.expansions = expansions

    def getkey(self):
        return (self.nonterminal, tuple(self.expansions))

#    def __hash__(self):
#        return hash(self.getkey())

    def __eq__(self, other):
        return self.getkey() == other.getkey()

    def __ne__(self, other):
        return not self == other

    def __str__(self):
        return "%s: %s" % (
            self.nonterminal, " | ".join([repr(e) for e in self.expansions]))

    def __repr__(self):
        return "Rule(%r, %r)" % (self.nonterminal, self.expansions)

class LazyInputStream(object):
    def __init__(self, iterator):
        self.iterator = iter(iterator)
        self.data = []

    def __getitem__(self, index):
        assert index >= 0
        while len(self.data) <= index:
            try:
                self.data.append(self.iterator.next())
            except StopIteration:
                raise IndexError("index out of range")
        return self.data[index]

class ParseError(Exception):
    def __init__(self, source_pos, errorinformation):
        self.source_pos = source_pos
        self.errorinformation = errorinformation
        self.args = (source_pos, errorinformation)

    def nice_error_message(self, filename="<unknown>", source=""):
        # + 1 is because source_pos is 0-based and humans 1-based
        result = ["  File %s, line %s" % (filename, self.source_pos.lineno + 1)]
        if source:
            result.append(source.split("\n")[self.source_pos.lineno])
            result.append(" " * self.source_pos.columnno + "^")
        else:
            result.append("<couldn't get source>")
        if self.errorinformation:
            failure_reasons = self.errorinformation.failure_reasons
            if len(failure_reasons) > 1:
                all_but_one = failure_reasons[:-1]
                last = failure_reasons[-1]
                expected = "%s or '%s'" % (
                    ", ".join(["'%s'" % e for e in all_but_one]), last)
            else:
                expected = failure_reasons[0]
            result.append("ParseError: expected %s" % (expected, ))
        else:
            result.append("ParseError")
        return "\n".join(result)


class ErrorInformation(object):
    def __init__(self, pos, failure_reasons=None):
        if failure_reasons is None:
            failure_reasons = []
        self.failure_reasons = failure_reasons
        self.pos = pos

def combine_errors(self, other):
    if self is None:
        return other
    if (other is None or self.pos > other.pos or
        len(other.failure_reasons) == 0):
        return self
    elif other.pos > self.pos or len(self.failure_reasons) == 0:
        return other
    failure_reasons = []
    already_there = {}
    for fr in [self.failure_reasons, other.failure_reasons]:
        for reason in fr:
            if reason not in already_there:
                already_there[reason] = True
                failure_reasons.append(reason)
    return ErrorInformation(self.pos, failure_reasons)

class LazyParseTable(object):
    def __init__(self, input, parser):
        self.parser = parser
        self.input = input
        self.matched = {}
        self.errorinformation = {}

    def match_symbol(self, i, symbol):
        #print i, symbol
        #print self.matched.keys()
        if (i, symbol) in self.matched:
            return self.matched[i, symbol]
        error = None # for the annotator
        if self.parser.is_nonterminal(symbol):
            rule = self.parser.get_rule(symbol)
            subsymbol = None
            error = None
            for expansion in rule.expansions:
                curr = i
                children = []
                for subsymbol in expansion:
                    node, next, error2 = self.match_symbol(curr, subsymbol)
                    if node is None:
                        error = combine_errors(error, error2)
                        break
                    children.append(node)
                    curr = next
                else:
                    assert len(expansion) == len(children)
                    result = (Nonterminal(symbol, children), curr, error)
                    self.matched[i, symbol] = result
                    return result
            self.matched[i, symbol] = None, 0, error
            return None, 0, error
        else:
            try:
                input = self.input[i]
                if self.terminal_equality(symbol, input):
                    result = (Symbol(symbol, input.source, input), i + 1, error)
                    self.matched[i, symbol] = result
                    return result
                else:
                    # XXX hack unnice: handles the sort of token names that
                    # ebnfparse produces
                    if (symbol.startswith("__") and
                        symbol.split("_")[2][0] in "0123456789"):
                        expected = symbol.split("_")[-1]
                    else:
                        expected = symbol
                    error = ErrorInformation(i, [expected])
            except IndexError:
                error = ErrorInformation(i)
        return None, 0, error
    
    def terminal_equality(self, symbol, input):
        return symbol == input.name


class PackratParser(object):
    def __init__(self, rules, startsymbol, parsetablefactory=LazyParseTable,
                 check_for_left_recursion=True):
        self.rules = rules
        self.nonterminal_to_rule = {}
        for rule in rules:
            self.nonterminal_to_rule[rule.nonterminal] = rule
        self.startsymbol = startsymbol
        if check_for_left_recursion:
            assert not self.has_left_recursion()
        self.parsetablefactory = parsetablefactory

    def is_nonterminal(self, symbol):
        return symbol in self.nonterminal_to_rule

    def get_rule(self, symbol):
        return self.nonterminal_to_rule[symbol]

    def parse(self, tokeniterator, lazy=False):
        if lazy:
            input = LazyInputStream(tokeniterator)
        else:
            input = list(tokeniterator)
        table = self.parsetablefactory(input, self)
        result = table.match_symbol(0, self.startsymbol)
        if result[0] is None:
            error = result[2]
            raise ParseError(input[error.pos].source_pos, error)
        return result[0]

    @not_rpython
    def has_left_recursion(self):
        follows = {}
        for rule in self.rules:
            follow = py.builtin.set()
            follows[rule.nonterminal] = follow
            for expansion in rule.expansions:
                if expansion and self.is_nonterminal(expansion[0]):
                    follow.add(expansion[0])
        changed = True
        while changed:
            changed = False
            for nonterminal, follow in follows.iteritems():
                for nt in follow:
                    subfollow = follows[nt]
                    update = subfollow - follow
                    if update:
                        changed = True
                        follow.update(update)
                        break
        for nonterminal, follow in follows.iteritems():
            if nonterminal in follow:
                print "nonterminal %s is in its own follow %s" % (nonterminal, follow)
                return True
        return False

    def __repr__(self):
        from pprint import pformat
        return "%s%s" % (self.__class__.__name__,
                         pformat((self.rules, self.startsymbol)), )

class ParserCompiler(object):
    def __init__(self, parser):
        self.parser = parser
        self.allcode = []
        self.symbol_to_number = {}
        self.made = {}

    def compile(self):
        from rpython.tool.sourcetools import func_with_new_name
        self.allcode.append("class CompileableParser(baseclass):")
        self.make_matcher(self.parser.startsymbol)
        self.make_fixed()
        miniglobals = globals().copy()
        miniglobals["baseclass"] = self.parser.__class__
        #print "\n".join(self.allcode)
        exec(py.code.Source("\n".join(self.allcode)).compile(), miniglobals)
        kls = miniglobals["CompileableParser"]
        # XXX
        parsetable = self.parser.parsetablefactory([], self.parser)
        kls.terminal_equality = func_with_new_name(
            parsetable.terminal_equality.im_func,
            "terminal_equality_compileable")
        return kls

    def get_number(self, symbol):
        if symbol in self.symbol_to_number:
            return self.symbol_to_number[symbol]
        result = len(self.symbol_to_number)
        self.symbol_to_number[symbol] = result
        return result

    def make_matcher(self, symbol):
        if symbol not in self.made:
            self.made[symbol] = True
            if self.parser.is_nonterminal(symbol):
                self.make_nonterminal_matcher(symbol)
            else:
                self.make_terminal_matcher(symbol)

    def make_terminal_matcher(self, symbol):
        number = self.get_number(symbol)
        self.allcode.append("""
    def match_terminal%(number)s(self, i):
        # matcher for terminal %(number)s %(symbol)r
        if i in self.matched_terminals%(number)s:
            return self.matched_terminals%(number)s[i]
        try:
            input = self.input[i]
            if self.terminal_equality(%(symbol)r, input):
                symbol = Symbol(%(symbol)r, input.name, input)
                result = (symbol, i + 1)
                self.matched_terminals%(number)s[i] = result
                return result
        except IndexError:
            pass
        return None, i""" % vars())

    def make_nonterminal_matcher(self, symbol):
        number = self.get_number(symbol)
        rule = self.parser.nonterminal_to_rule[symbol]
        code = []
        code.append("""
    def match_nonterminal%(number)s(self, i):
        # matcher for nonterminal %(number)s %(symbol)s
        if i in self.matched_nonterminals%(number)s:
            return self.matched_nonterminals%(number)s[i]
        last_failed_position = 0
        subsymbol = None
        expansionindex = 0
        while 1:""" % vars())
        for expansionindex, expansion in enumerate(rule.expansions):
            nextindex = expansionindex + 1
            code.append("""\
            if expansionindex == %s:""" % (expansionindex, ))
            if not expansion:
                code.append("""\
                result = (Nonterminal(symbol, []), i)
                self.matched_nonterminals%(number)s[i] = result
                return result""" % vars())
                continue
            code.append("""\
                curr = i
                children = []""")
            for subsymbol in expansion:
                self.make_matcher(subsymbol)
                if self.parser.is_nonterminal(subsymbol):
                    match = "match_nonterminal%s" % self.get_number(subsymbol)
                else:
                    match = "match_terminal%s" % self.get_number(subsymbol)
                code.append("""\
                node, next = self.%(match)s(curr)
                if node is None:
                    last_failed_position = next
                    expansionindex = %(nextindex)s
                    continue
                curr = next""" % vars())
            code.append("""\
                result = (Nonterminal(%(symbol)r, children), curr)
                self.matched_nonterminals%(number)s[i] = result
                return result""" % vars())
        code.append("""\
            if expansionindex == %(nextindex)s:
                result = None, last_failed_position
                self.matched_nonterminals%(number)s[i] = result
                return result""" % vars())
        self.allcode.extend(code)

    def make_fixed(self):
        # __init__
        code = ["""
    def __init__(self):
        self.rules = [] # dummy
        self.nonterminal_to_rule = {} # dummy
        self.startsymbol = "" # dummy
        self.parsetablefactory = None # dummy"""]
        for symbol, number in self.symbol_to_number.iteritems():
            if self.parser.is_nonterminal(symbol):
                name = "matched_nonterminals%s" % number
            else:
                name = "matched_terminals%s" % number
            code.append("""\
        self.%(name)s = {}""" % vars())
        # parse
        startsymbol = self.get_number(self.parser.startsymbol)
        code.append("""
    def parse(self, tokenlist, lazy=True):
        self.input = tokenlist
        result = self.match_nonterminal%(startsymbol)s(0)
        if result[0] is None:
            raise ParseError(None, self.input[result[1]])
        return result[0]""" % (vars()))
        self.allcode.extend(code)

