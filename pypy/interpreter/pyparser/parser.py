"""
A CPython inspired RPython parser.
"""
from rpython.rlib.objectmodel import not_rpython


class Grammar(object):
    """
    Base Grammar object.

    Pass this to ParserGenerator.build_grammar to fill it with useful values for
    the Parser.
    """

    def __init__(self):
        self.symbol_ids = {}
        self.symbol_names = {}
        self.symbol_to_label = {}
        self.keyword_ids = {}
        self.token_to_error_string = {}
        self.dfas = []
        self.labels = [0]
        self.token_ids = {}
        self.start = -1

    def shared_copy(self):
        new = self.__class__()
        new.symbol_ids = self.symbol_ids
        new.symbols_names = self.symbol_names
        new.keyword_ids = self.keyword_ids
        new.token_to_error_string = self.token_to_error_string
        new.dfas = self.dfas
        new.labels = self.labels
        new.token_ids = self.token_ids
        return new


    def classify(self, token):
        """Find the label for a token."""
        if token.token_type == self.KEYWORD_TOKEN:
            label_index = self.keyword_ids.get(token.value, -1)
            if label_index != -1:
                return label_index
        label_index = self.token_ids.get(token.token_type, -1)
        if label_index == -1:
            raise ParseError("invalid token", token)
        return label_index

    def _freeze_(self):
        # Remove some attributes not used in parsing.
        try:
            del self.symbol_to_label
            del self.symbol_names
            del self.symbol_ids
        except AttributeError:
            pass
        return True

class DFA(object):
    def __init__(self, grammar, symbol_id, states, first):
        self.grammar = grammar
        self.symbol_id = symbol_id
        self.states = states
        self.first = self._first_to_string(first)
        self.grammar = grammar

    def could_match_token(self, label_index):
        pos = label_index >> 3
        bit = 1 << (label_index & 0b111)
        return bool(ord(self.first[label_index >> 3]) & bit)

    @staticmethod
    @not_rpython
    def _first_to_string(first):
        l = sorted(first.keys())
        b = bytearray(32)
        for label_index in l:
            pos = label_index >> 3
            bit = 1 << (label_index & 0b111)
            b[pos] |= bit
        return str(b)

class TokenASTBase(object):
    _attrs_ = []

class Token(TokenASTBase):
    def __init__(self, token_type, value, lineno, column, line, end_lineno=-1, end_column=-1):
        self.token_type = token_type
        self.value = value
        self.lineno = lineno
        # 0-based offset
        self.column = column
        self.line = line
        self.end_lineno = end_lineno
        self.end_column = end_column

    def __repr__(self):
        from pypy.interpreter.pyparser.pytoken import token_names
        return "Token(%s, %s)" % (token_names.get(self.token_type, self.token_type), self.value)

    def __eq__(self, other):
        # for tests
        return (
            self.token_type == other.token_type and
            self.value == other.value and
            self.lineno == other.lineno and
            self.column == other.column and
            self.line == other.line and
            self.end_lineno == other.end_lineno and
            self.end_column == other.end_column
        )

    def __ne__(self, other):
        return not self == other


class Node(object):

    __slots__ = ("grammar", "type")

    def __init__(self, grammar, type):
        assert grammar is None or isinstance(grammar, Grammar)
        assert isinstance(type, int)
        self.grammar = grammar
        self.type = type

    def __eq__(self, other):
        raise NotImplementedError("abstract base class")

    def __ne__(self, other):
        return not self == other

    def get_value(self):
        return None

    def get_child(self, i):
        raise NotImplementedError("abstract base class")

    def num_children(self):
        return 0

    def append_child(self, child):
        raise NotImplementedError("abstract base class")

    def get_lineno(self):
        raise NotImplementedError("abstract base class")

    def get_column(self):
        raise NotImplementedError("abstract base class")

    def get_line(self):
        raise NotImplementedError("abstract base class")

    def flatten(self, res=None):
        if res is None:
            res = []
        for i in range(self.num_children()):
            child = self.get_child(i)
            if isinstance(child, Terminal):
                res.append(child)
            else:
                child.flatten(res)
        return res

    def view(self):
        from dotviewer import graphclient
        import pytest
        r = ["digraph G {"]
        self._dot(r)
        r.append("}")
        p = pytest.ensuretemp("pyparser").join("temp.dot")
        p.write("\n".join(r))
        graphclient.display_dot_file(str(p))

    def _dot(self, result):
        raise NotImplementedError("abstract base class")


class Terminal(Node):
    __slots__ = ("value", "lineno", "column", "line", "end_lineno", "end_column")
    def __init__(self, grammar, type, value, lineno, column, line=None, end_lineno=-1, end_column=-1):
        Node.__init__(self, grammar, type)
        self.value = value
        self.lineno = lineno
        self.column = column
        self.line = line
        self.end_lineno = end_lineno
        self.end_column = end_column

    @staticmethod
    def fromtoken(grammar, token):
        return Terminal(
            grammar,
            token.token_type, token.value, token.lineno, token.column,
            token.line, token.end_lineno, token.end_column)

    def __repr__(self):
        return "Terminal(type=%s, value=%r)" % (self.type, self.value)

    def __eq__(self, other):
        # For tests.
        return (type(self) == type(other) and
                self.type == other.type and
                self.value == other.value)

    def get_value(self):
        return self.value

    def get_lineno(self):
        return self.lineno

    def get_column(self):
        return self.column

    def get_end_lineno(self):
        return self.end_lineno

    def get_end_column(self):
        return self.end_column

    def get_line(self):
        return self.line

    def _dot(self, result):
        result.append('%s [label="%r", shape=box];' % (id(self), self.value))


class AbstractNonterminal(Node):
    __slots__ = ()

    def get_lineno(self):
        return self.get_child(0).get_lineno()

    def get_column(self):
        return self.get_child(0).get_column()

    def get_line(self):
        return self.get_child(0).get_line()

    def get_end_lineno(self):
        return self.get_child(self.num_children() - 1).get_end_lineno()

    def get_end_column(self):
        return self.get_child(self.num_children() - 1).get_end_column()

    def __eq__(self, other):
        # For tests.
        # grumble, annoying
        if not isinstance(other, AbstractNonterminal):
            return False
        if self.type != other.type:
            return False
        if self.num_children() != other.num_children():
            return False
        for i in range(self.num_children()):
            if self.get_child(i) != other.get_child(i):
                return False
        return True

    def _dot(self, result):
        for i in range(self.num_children()):
            child = self.get_child(i)
            result.append('%s [label=%s, shape=box]' % (id(self), self.grammar.symbol_names[self.type]))
            result.append('%s -> %s [label="%s"]' % (id(self), id(child), i))
            child._dot(result)


class Nonterminal(AbstractNonterminal):
    __slots__ = ("_children", )
    def __init__(self, grammar, type, children=None):
        Node.__init__(self, grammar, type)
        if children is None:
            children = []
        self._children = children

    def __repr__(self):
        return "Nonterminal(type=%s, children=%r)" % (
            self.grammar.symbol_names[self.type]
                if self.grammar is not None else self.type,
            self._children)

    def get_child(self, i):
        assert self._children is not None
        return self._children[i]

    def num_children(self):
        return len(self._children)

    def append_child(self, child):
        self._children.append(child)


class Nonterminal1(AbstractNonterminal):
    __slots__ = ("_child", )
    def __init__(self, grammar, type, child):
        Node.__init__(self, grammar, type)
        self._child = child

    def __repr__(self):
        return "Nonterminal(type=%s, children=[%r])" % (
            self.grammar.symbol_names[self.type]
                if self.grammar is not None else self.type,
            self._child)

    def get_child(self, i):
        assert i == 0 or i == -1
        return self._child

    def num_children(self):
        return 1

    def append_child(self, child):
        assert 0, "should be unreachable"



class ParseError(Exception):

    def __init__(self, msg, token, expected=-1, expected_str=None):
        self.msg = msg
        self.token = token
        self.expected = expected
        self.expected_str = expected_str

    def __str__(self):
        return "ParserError(%s)" % (self.token, )


class StackEntry(object):
    def __init__(self, next, dfa, state):
        self.next = next
        self.dfa = dfa
        self.state = state
        self.node = None

    def push(self, dfa, state):
        return StackEntry(self, dfa, state)

    def pop(self):
        return self.next

    def node_append_child(self, child):
        node = self.node
        if node is None:
            self.node = Nonterminal1(self.dfa.grammar,
                    self.dfa.symbol_id, child)
        elif isinstance(node, Nonterminal1):
            newnode = self.node = Nonterminal(
                    self.dfa.grammar,
                    self.dfa.symbol_id, [node._child, child])
        else:
            self.node.append_child(child)

    def view(self):
        from dotviewer import graphclient
        import pytest
        r = ["digraph G {"]
        self._dot(r)
        r.append("}")
        p = pytest.ensuretemp("pyparser").join("temp.dot")
        p.write("\n".join(r))
        graphclient.display_dot_file(str(p))

    def _dot(self, result):
        result.append('%s [label=%s, shape=box, color=white]' % (id(self), self.dfa.grammar.symbol_names[self.dfa.symbol_id]))
        if self.next:
            result.append('%s -> %s [label="next"]' % (id(self), id(self.next)))
            self.next._dot(result)
        if self.node:
            result.append('%s -> %s [label="node"]' % (id(self), id(self.node)))
            self.node._dot(result)


class Parser(object):

    def __init__(self, grammar):
        self.grammar = grammar
        self.root = None

    def prepare(self, start=-1):
        """Setup the parser for parsing.

        Takes the starting symbol as an argument.
        """
        if start == -1:
            start = self.grammar.start
        self.root = None
        self.stack = StackEntry(None, self.grammar.dfas[start - 256], 0)

    def add_token(self, token):
        label_index = self.grammar.classify(token)
        sym_id = 0 # for the annotator
        while True:
            dfa = self.stack.dfa
            state_index = self.stack.state
            states = dfa.states
            arcs, is_accepting = states[state_index]
            for i, next_state in arcs:
                sym_id = self.grammar.labels[i]
                if label_index == i:
                    # We matched a non-terminal.
                    self.shift(dfa.grammar, next_state, token)
                    state = states[next_state]
                    # While the only possible action is to accept, pop nodes off
                    # the stack.
                    while state[1] and not state[0]:
                        self.pop()
                        if self.stack is None:
                            # Parsing is done.
                            return True
                        dfa = self.stack.dfa
                        state_index = self.stack.state
                        state = dfa.states[state_index]
                    return False
                elif sym_id >= 256:
                    sub_node_dfa = self.grammar.dfas[sym_id - 256]
                    # Check if this token can start a child node.
                    if sub_node_dfa.could_match_token(label_index):
                        self.push(sub_node_dfa, next_state, sym_id)
                        break
            else:
                # We failed to find any arcs to another state, so unless this
                # state is accepting, it's invalid input.
                if is_accepting:
                    self.pop()
                    if self.stack is None:
                        raise ParseError("too much input", token)
                else:
                    # If only one possible input would satisfy, attach it to the
                    # error.
                    possible_arcs = self._get_possible_arcs(arcs)
                    if len(possible_arcs) == 1:
                        possible_arc = possible_arcs[0]
                        expected = self.grammar.labels[possible_arc[0]]
                        expected_str = self.grammar.token_to_error_string.get(
                                possible_arc[0], None)
                    else:
                        expected = -1
                        expected_str = None
                    raise ParseError("bad input", token, expected, expected_str)

    def _get_possible_arcs(self, arcs):
        """Filter out pseudo tokens from the possible paths to be taken
        in the grammar, in order to determine most precise token type
        for syntax errors."""
        return arcs

    def shift(self, grammar, next_state, token):
        """Shift a non-terminal and prepare for the next state."""
        new_node = Terminal.fromtoken(self.grammar, token)
        self.stack.node_append_child(new_node)
        self.stack.state = next_state

    def push(self, next_dfa, next_state, node_type):
        """Push a terminal and adjust the current state."""
        self.stack.state = next_state
        self.stack = self.stack.push(next_dfa, 0)

    def pop(self):
        """Pop an entry off the stack and make its node a child of the last."""
        top = self.stack
        self.stack = top.pop()
        node = top.node
        assert node is not None
        if self.stack:
            self.stack.node_append_child(node)
        else:
            self.root = node

    def reset(self):
        """Reset the state-bound data"""

