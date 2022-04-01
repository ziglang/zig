import py
from rpython.rlib.parsing import deterministic, regex

class Token(object):
    def __init__(self, name, source, source_pos):
        self.name = name
        self.source = source
        self.source_pos = source_pos

    def copy(self):
        return self.__class__(self.name, self.source, self.source_pos)

    def __eq__(self, other):
        # for testing only
        return self.__dict__ == other.__dict__

    def __ne__(self, other):
        # for testing only
        return not self == other

    def __repr__(self):
        return "Token(%r, %r, %r)" % (self.name, self.source, self.source_pos)

class SourcePos(object):
    """An object to record position in source code."""
    def __init__(self, i, lineno, columnno):
        self.i = i                  # index in source string
        self.lineno = lineno        # line number in source
        self.columnno = columnno    # column in line

    def copy(self):
        return SourcePos(self.i, self.lineno, self.columnno)

    def __eq__(self, other):
        # for testing only
        return self.__dict__ == other.__dict__

    def __ne__(self, other):
        # for testing only
        return not self == other

    def __repr__(self):
        return "SourcePos(%r, %r, %r)" % (self.i, self.lineno, self.columnno)

class Lexer(object):
    def __init__(self, token_regexs, names, ignore=None):
        self.token_regexs = token_regexs
        self.names = names
        self.rex = regex.LexingOrExpression(token_regexs, names)
        automaton = self.rex.make_automaton()
        self.automaton = automaton.make_deterministic(names)
        self.automaton.optimize() # XXX not sure whether this is a good idea
        if ignore is None:
            ignore = []
        for ign in ignore:
            assert ign in names
        self.ignore = dict.fromkeys(ignore)
        self.matcher = self.automaton.make_lexing_code()

    def get_runner(self, text, eof=False, token_class=None):
        return LexingDFARunner(self.matcher, self.automaton, text,
                               self.ignore, eof, token_class=token_class)

    def tokenize(self, text, eof=False):
        """Return a list of Token's from text."""
        r = self.get_runner(text, eof)
        result = []
        while 1:
            try:
                tok = r.find_next_token()
                result.append(tok)
            except StopIteration:
                break
        return result

    def get_dummy_repr(self):
        return '%s\nlexer = DummyLexer(recognize, %r, %r)' % (
                py.code.Source(self.matcher),
                self.automaton,
                self.ignore)

    def __getstate__(self):
        return (self.token_regexs, self.names, self.ignore)

    def __setstate__(self, args):
        self.__init__(*args)


class DummyLexer(Lexer):
    def __init__(self, matcher, automaton, ignore):
        self.token_regexs = None
        self.names = None
        self.rex = None
        self.automaton = automaton
        self.ignore = ignore
        self.matcher = matcher

class AbstractLexingDFARunner(deterministic.DFARunner):
    i = 0
    def __init__(self, matcher, automaton, text, eof=False):
        self.automaton = automaton
        self.state = 0
        self.text = text
        self.last_matched_state = 0
        self.last_matched_index = -1
        self.eof = eof
        self.matcher = matcher
        self.lineno = 0
        self.columnno = 0

    def find_next_token(self):
        while 1:
            self.state = 0
            start = self.last_matched_index + 1
            assert start >= 0

            # Handle end of file situation
            if start == len(self.text) and self.eof:
                self.last_matched_index += 1
                return self.make_token(start, -1, "", eof=True)
            elif start >= len(self.text):
                raise StopIteration

            i = self.inner_loop(start)
            if i < 0:
                i = ~i
                stop = self.last_matched_index + 1
                assert stop >= 0
                if start == stop:
                    source_pos = self.token_position_class(i - 1, self.lineno, self.columnno)
                    raise deterministic.LexerError(self.text, self.state,
                                                   source_pos)
                source = self.text[start:stop]
                result = self.make_token(start, self.last_matched_state, source)
                self.adjust_position(source)
                if self.ignore_token(self.last_matched_state):
                    continue
                return result
            if self.last_matched_index == i - 1:
                source = self.text[start: ]
                result = self.make_token(start, self.last_matched_state, source)
                self.adjust_position(source)
                if self.ignore_token(self.last_matched_state):
                    if self.eof:
                        self.last_matched_index += 1
                        return self.make_token(i, -1, "", eof=True)
                    else:
                        raise StopIteration
                return result
            source_pos = self.token_position_class(i - 1, self.lineno, self.columnno)
            raise deterministic.LexerError(self.text, self.state, source_pos)

    def adjust_position(self, token):
        """Update the line# and col# as a result of this token."""
        newlines = token.count("\n")
        self.lineno += newlines
        if newlines==0:
            self.columnno += len(token)
        else:
            self.columnno = token.rfind("\n")

#    def inner_loop(self, i):
#        while i < len(self.text):
#            char = self.text[i]
#            #print i, self.last_matched_index, self.last_matched_state, repr(char)
#            try:
#                state = self.nextstate(char)
#            except KeyError:
#                return ~i
#            if state in self.automaton.final_states:
#                self.last_matched_state = state
#                self.last_matched_index = i
#            i += 1
#        if state not in self.automaton.final_states:
#            return ~i
#        return i

    def inner_loop(self, i):
        return self.matcher(self, i)

    next = find_next_token

    def __iter__(self):
        return self

class LexingDFARunner(AbstractLexingDFARunner):
    def __init__(self, matcher, automaton, text, ignore, eof=False,
                 token_class=None):

        if not token_class:
            self.token_class = Token
            self.token_position_class = SourcePos

        else:
            self.token_class = token_class
            self.token_position_class = token_class.source_position_class

        AbstractLexingDFARunner.__init__(self, matcher, automaton, text, eof)
        self.ignore = ignore

    def ignore_token(self, state):
        return self.automaton.names[state] in self.ignore

    def make_token(self, index, state, text, eof=False):
        assert (eof and state == -1) or 0 <= state < len(self.automaton.names)

        source_pos = self.token_position_class(index, self.lineno, self.columnno)
        if eof:
            return self.token_class("EOF", "EOF", source_pos)

        return self.token_class(self.automaton.names[self.last_matched_state],
                                text, source_pos)
