"""
Makes a parser from a grammar source.

Inspired by Guido van Rossum's pgen2.
"""

import StringIO
import tokenize
import token

from pypy.interpreter.pyparser import parser


class PgenError(Exception):

    def __init__(self, msg, location=None):
        Exception.__init__(self, msg)
        self.location = location


class NFA(object):

    def __init__(self):
        self.arcs = []

    def arc(self, to_state, label=None):
        self.arcs.append((label, to_state))

    def find_unlabeled_states(self, into):
        if self in into:
            return
        into.add(self)
        for label, state in self.arcs:
            if label is None:
                state.find_unlabeled_states(into)


class DFA(object):

    def __init__(self, nfa_set, final_state):
        self.nfas = nfa_set
        self.is_final = final_state in nfa_set
        self.arcs = {}

    def arc(self, next, label):
        self.arcs[label] = next

    def unify_state(self, old, new):
        for label, state in self.arcs.iteritems():
            if state is old:
                self.arcs[label] = new

    def __repr__(self):
        return "<DFA arcs=%r>" % self.arcs

    def __eq__(self, other):
        if not isinstance(other, DFA):
            # This shouldn't really happen.
            return NotImplemented
        if other.is_final != self.is_final:
            return False
        if len(self.arcs) != len(other.arcs):
            return False
        for label, state in self.arcs.iteritems():
            try:
                other_state = other.arcs[label]
            except KeyError:
                return False
            else:
                if other_state is not state:
                    return False
        return True


def nfa_to_dfa(start, end):
    """Convert an NFA to a DFA(s)

    Each DFA is initially a set of NFA states without labels.  We start with the
    DFA for the start NFA.  Then we add labeled arcs to it pointing to another
    set of NFAs (the next state).  Finally, we do the same thing to every DFA
    that is found and return the list of states.
    """
    base_nfas = set()
    start.find_unlabeled_states(base_nfas)
    state_stack = [DFA(base_nfas, end)]
    for state in state_stack:
        arcs = {}
        for nfa in state.nfas:
            for label, sub_nfa in nfa.arcs:
                if label is not None:
                    sub_nfa.find_unlabeled_states(arcs.setdefault(label, set()))
        for label, nfa_set in arcs.iteritems():
            for st in state_stack:
                if st.nfas == nfa_set:
                    break
            else:
                st = DFA(nfa_set, end)
                state_stack.append(st)
            state.arc(st, label)
    return state_stack

def simplify_dfa(dfa):
    changed = True
    while changed:
        changed = False
        for i, state in enumerate(dfa):
            for j in xrange(i + 1, len(dfa)):
                other_state = dfa[j]
                if state == other_state:
                    del dfa[j]
                    for sub_state in dfa:
                        sub_state.unify_state(other_state, state)
                    changed = True
                    break


class ParserGenerator(object):
    """NOT_RPYTHON"""

    def __init__(self, grammar_source):
        self.start_symbol = None
        self.dfas = {}
        stream = StringIO.StringIO(grammar_source)
        self.token_stream = tokenize.generate_tokens(stream.readline)
        self.parse()
        self.first = {}
        self.add_first_sets()

    def build_grammar(self, grammar_cls):
        gram = grammar_cls()
        gram.start = self.start_symbol
        names = self.dfas.keys()
        names.sort()
        names.remove(self.start_symbol)
        names.insert(0, self.start_symbol)
        # First, build symbol and id mappings.
        for name in names:
            i = 256 + len(gram.symbol_ids)
            gram.symbol_ids[name] = i
            gram.symbol_names[i] = name
        # Then, iterate through again and finalize labels.
        for name in names:
            dfa = self.dfas[name]
            states = []
            for state in dfa:
                arcs = []
                for label, next in state.arcs.iteritems():
                    arcs.append((self.make_label(gram, label), dfa.index(next)))
                states.append((arcs, state.is_final))
            symbol_id = gram.symbol_ids[name]
            dfa = parser.DFA(gram, symbol_id, states, self.make_first(gram, name))
            gram.dfas.append(dfa)
            assert len(gram.dfas) - 1 == symbol_id - 256
        gram.start = gram.symbol_ids[self.start_symbol]
        return gram

    def make_label(self, gram, label):
        label_index = len(gram.labels)
        if label[0].isalpha():
            # Either a symbol or a token.
            if label in gram.symbol_ids:
                if label in gram.symbol_to_label:
                    return gram.symbol_to_label[label]
                else:
                    gram.labels.append(gram.symbol_ids[label])
                    gram.symbol_to_label[label] = label_index
                    first = self.first[label]
                    if len(first) == 1:
                        first, = first
                        if not first[0].isupper():
                            first = first.strip("\"'")
                            assert label_index not in gram.token_to_error_string
                            gram.token_to_error_string[label_index] = first
                    return label_index
            elif label.isupper():
                token_index = gram.TOKENS[label]
                if token_index in gram.token_ids:
                    return gram.token_ids[token_index]
                else:
                    gram.labels.append(token_index)
                    gram.token_ids[token_index] = label_index
                    return label_index
            else:
                # Probably a rule without a definition.
                raise PgenError("no such rule: %r" % (label,))
        else:
            # A keyword or operator.
            value = label.strip("\"'")
            if value[0].isalpha():
                if value in gram.keyword_ids:
                    return gram.keyword_ids[value]
                else:
                    gram.labels.append(gram.KEYWORD_TOKEN)
                    gram.keyword_ids[value] = label_index
                    result = label_index
            else:
                try:
                    token_index = gram.OPERATOR_MAP[value]
                except KeyError:
                    raise PgenError("no such operator: %r" % (value,))
                if token_index in gram.token_ids:
                    return gram.token_ids[token_index]
                else:
                    gram.labels.append(token_index)
                    gram.token_ids[token_index] = label_index
                    result = label_index
            assert result not in gram.token_to_error_string
            gram.token_to_error_string[result] = value
            return result

    def make_first(self, gram, name):
        original_firsts = self.first[name]
        firsts = dict()
        for label in original_firsts:
            firsts[self.make_label(gram, label)] = None
        return firsts

    def add_first_sets(self):
        for name, dfa in self.dfas.iteritems():
            if name not in self.first:
                self.get_first(name, dfa)

    def get_first(self, name, dfa):
        self.first[name] = None
        state = dfa[0]
        all_labels = set()
        overlap_check = {}
        for label, sub_state in state.arcs.iteritems():
            if label in self.dfas:
                if label in self.first:
                    new_labels = self.first[label]
                    if new_labels is None:
                        raise PgenError("recursion in rule: %r" % (name,))
                else:
                    new_labels = self.get_first(label, self.dfas[label])
                all_labels.update(new_labels)
                overlap_check[label] = new_labels
            else:
                all_labels.add(label)
                overlap_check[label] = set((label,))
        inverse = {}
        for label, their_first in overlap_check.iteritems():
            for sub_label in their_first:
                if sub_label in inverse:
                    raise PgenError("ambiguous symbol with label %s"
                                    % (label,))
                inverse[sub_label] = label
        self.first[name] = all_labels
        return all_labels

    def expect(self, token_type, value=None):
        if token_type != self.type:
            expected = token.tok_name[token_type]
            got = token.tok_name[self.type]
            raise PgenError("expected token %s but got %s" % (expected, got),
                            self.location)
        current_value = self.value
        if value is not None:
            if value != current_value:
                msg = "expected %r but got %r" % (value, current_value)
                raise PgenError(msg,self.location)
        self.advance_token()
        return current_value

    def test_token(self, token_type, value):
        if self.type == token_type and self.value == value:
            return True
        return False

    def advance_token(self):
        data = self.token_stream.next()
        # Ignore comments and non-logical newlines.
        while data[0] in (tokenize.NL, tokenize.COMMENT):
            data = self.token_stream.next()
        self.type, self.value = data[:2]
        self.location = data[2:]

    def parse(self):
        self.advance_token()
        while self.type != token.ENDMARKER:
            # Skip over whitespace.
            while self.type == token.NEWLINE:
                self.advance_token()
            name, start_state, end_state = self.parse_rule()
            dfa = nfa_to_dfa(start_state, end_state)
            simplify_dfa(dfa)
            self.dfas[name] = dfa
            if self.start_symbol is None:
                self.start_symbol = name

    def parse_rule(self):
        # RULE: NAME ':' ALTERNATIVES
        name = self.expect(token.NAME)
        self.expect(token.OP, ":")
        start_state, end_state = self.parse_alternatives()
        self.expect(token.NEWLINE)
        return name, start_state, end_state

    def parse_alternatives(self):
        # ALTERNATIVES: ITEMS ('|' ITEMS)*
        first_state, end_state = self.parse_items()
        if self.test_token(token.OP, "|"):
            # Link all alternatives into a enclosing set of states.
            enclosing_start_state = NFA()
            enclosing_end_state = NFA()
            enclosing_start_state.arc(first_state)
            end_state.arc(enclosing_end_state)
            while self.test_token(token.OP, "|"):
                self.advance_token()
                sub_start_state, sub_end_state = self.parse_items()
                enclosing_start_state.arc(sub_start_state)
                sub_end_state.arc(enclosing_end_state)
            first_state = enclosing_start_state
            end_state = enclosing_end_state
        return first_state, end_state

    def parse_items(self):
        # ITEMS: ITEM+
        first_state, end_state = self.parse_item()
        while self.type in (token.STRING, token.NAME) or \
                           self.test_token(token.OP, "(") or \
                           self.test_token(token.OP, "["):
            sub_first_state, new_end_state = self.parse_item()
            end_state.arc(sub_first_state)
            end_state = new_end_state
        return first_state, end_state

    def parse_item(self):
        # ITEM: '[' ALTERNATIVES ']' | ATOM ['+' | '*']
        if self.test_token(token.OP, "["):
            self.advance_token()
            start_state, end_state = self.parse_alternatives()
            self.expect(token.OP, "]")
            # Bypass the rule if this is optional.
            start_state.arc(end_state)
            return start_state, end_state
        else:
            atom_state, next_state = self.parse_atom()
            # Check for a repeater.
            if self.type == token.OP and self.value in ("+", "*"):
                next_state.arc(atom_state)
                repeat = self.value
                self.advance_token()
                if repeat == "*":
                    # Optionally repeated
                    return atom_state, atom_state
                else:
                    # Required
                    return atom_state, next_state
            else:
                return atom_state, next_state

    def parse_atom(self):
        # ATOM: '(' ALTERNATIVES ')' | NAME | STRING
        if self.test_token(token.OP, "("):
            self.advance_token()
            rule = self.parse_alternatives()
            self.expect(token.OP, ")")
            return rule
        elif self.type in (token.NAME, token.STRING):
            atom_state = NFA()
            next_state = NFA()
            atom_state.arc(next_state, self.value)
            self.advance_token()
            return atom_state, next_state
        else:
            invalid = token.tok_name[self.type]
            raise PgenError("unexpected token: %s" % (invalid,),
                            self.location)
