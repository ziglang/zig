from __future__ import with_statement
import py
import sys
from rpython.rlib.parsing.tree import Nonterminal, Symbol, RPythonVisitor
from rpython.rlib.parsing.codebuilder import Codebuilder
from rpython.rlib.objectmodel import we_are_translated

class BacktrackException(Exception):
    def __init__(self, error=None):
        self.error = error
        if not we_are_translated():
            Exception.__init__(self, error)



class TreeOptimizer(RPythonVisitor):
    def visit_or(self, t):
        if len(t.children) == 1:
            return self.dispatch(t.children[0])
        return self.general_nonterminal_visit(t)

    visit_commands = visit_or

    def visit_negation(self, t):
        child = self.dispatch(t.children[0])
        if child.symbol == "negation":
            child.symbol = "lookahead"
            return child
        t.children[0] = child
        return t

    def general_nonterminal_visit(self, t):
        for i in range(len(t.children)):
            t.children[i] = self.dispatch(t.children[i])
        return t

    def general_visit(self, t):
        return t


syntax = r"""
NAME:
    `[a-zA-Z_][a-zA-Z0-9_]*`;

SPACE:
    ' ';

COMMENT:
    `( *#[^\n]*\n)+`;

IGNORE:
    `(#[^\n]*\n)|\n|\t| `;

newline:
    COMMENT
  | `( *\n *)*`;


REGEX:
    r = `\`[^\\\`]*(\\.[^\\\`]*)*\``
    return {Symbol('REGEX', r, None)};

QUOTE:
    r = `'[^\']*'`
    return {Symbol('QUOTE', r, None)};

PYTHONCODE:
    r = `\{[^\n\}]*\}`
    return {Symbol('PYTHONCODE', r, None)};

EOF:
    !__any__;

file:
    IGNORE*
    list
    [EOF];

list:
    content = production+
    return {Nonterminal('list', content)};

production:
    name = NAME
    SPACE*
    args = productionargs
    ':'
    IGNORE*
    what = or_
    IGNORE*
    ';'
    IGNORE*
    return {Nonterminal('production', [name, args, what])};

productionargs:
    '('
    IGNORE*
    args = (
        NAME
        [
            IGNORE*
            ','
            IGNORE*
        ]
    )*
    arg = NAME
    IGNORE*
    ')'
    IGNORE*
    return {Nonterminal('productionargs', args + [arg])}
  | return {Nonterminal('productionargs', [])};


or_:
    l = (commands ['|' IGNORE*])+
    last = commands
    return {Nonterminal('or', l + [last])}
  | commands;

commands:
    cmd = command
    newline
    cmds = (command [newline])+
    return {Nonterminal('commands', [cmd] + cmds)}
  | command;

command:
    simplecommand;

simplecommand:
    return_
  | if_
  | named_command
  | repetition
  | choose
  | negation;

return_:
    'return'
    SPACE*
    code = PYTHONCODE
    IGNORE*
    return {Nonterminal('return', [code])};

if_:
    'do'
    newline
    cmd = command
    SPACE*
    'if'
    SPACE*
    condition = PYTHONCODE
    IGNORE*
    return {Nonterminal('if', [cmd, condition])}
  | 'if'
    SPACE*
    condition = PYTHONCODE
    IGNORE*
    return {Nonterminal('if', [condition])};

choose:
    'choose'
    SPACE*
    name = NAME
    SPACE*
    'in'
    SPACE*
    expr = PYTHONCODE
    IGNORE*
    cmds = commands
    return {Nonterminal('choose', [name, expr, cmds])};

commandchain:
    result = simplecommand+
    return {Nonterminal('commands', result)};

named_command:
    name = NAME
    SPACE*
    '='
    SPACE*
    cmd = command
    return {Nonterminal('named_command', [name, cmd])};

repetition:
    what = enclosed
    SPACE* '?' IGNORE*
    return {Nonterminal('maybe', [what])}
  | what = enclosed
    SPACE*
    repetition = ('*' | '+')
    IGNORE*
    return {Nonterminal('repetition', [repetition, what])};

negation:
    '!'
    SPACE*
    what = negation
    IGNORE*
    return {Nonterminal('negation', [what])}
  | enclosed;

enclosed:
    '<'
    IGNORE*
    what = primary
    IGNORE*
    '>'
    IGNORE*
    return {Nonterminal('exclusive', [what])}
  | '['
    IGNORE*
    what = or_
    IGNORE*
    ']'
    IGNORE*
    return {Nonterminal('ignore', [what])}
  | ['(' IGNORE*] or_ [')' IGNORE*]
  |  primary;

primary:
    call | REGEX [IGNORE*] | QUOTE [IGNORE*];

call:
    x = NAME
    args = arguments
    IGNORE*
    return {Nonterminal("call", [x, args])};

arguments:
    '('
    IGNORE*
    args = (
        PYTHONCODE
        [IGNORE* ',' IGNORE*]
    )*
    last = PYTHONCODE
    ')'
    IGNORE*
    return {Nonterminal("args", args + [last])}
  | return {Nonterminal("args", [])};
"""

class ErrorInformation(object):
    def __init__(self, pos, expected=None):
        if expected is None:
            expected = []
        self.expected = expected
        self.pos = pos

    def __str__(self):
        return "ErrorInformation(%s, %s)" % (self.pos, self.expected)

    def get_line_column(self, source):
        pos = self.pos
        assert pos >= 0
        uptoerror = source[:pos]
        lineno = uptoerror.count("\n")
        columnno = pos - uptoerror.rfind("\n")
        return lineno, columnno

    def nice_error_message(self, filename='<filename>', source=""):
        if source:
            lineno, columnno = self.get_line_column(source)
            result = ["  File %s, line %s" % (filename, lineno + 1)]
            result.append(source.split("\n")[lineno])
            result.append(" " * columnno + "^")
        else:
            result.append("<couldn't get source>")
        if self.expected:
            failure_reasons = self.expected
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

class Status(object):
    # status codes:
    NORMAL = 0
    ERROR = 1
    INPROGRESS = 2
    LEFTRECURSION = 3
    SOMESOLUTIONS = 4

    def __repr__(self):
        return "Status(%s, %s, %s, %s)" % (self.pos, self.result, self.error,
                                           self.status)

    def __init__(self):
        self.pos = 0
        self.error = None
        self.status = self.INPROGRESS
        self.result = None


class ParserBuilder(RPythonVisitor, Codebuilder):
    def __init__(self):
        Codebuilder.__init__(self)
        self.initcode = []
        self.names = {}
        self.matchers = {}

    def make_parser(self):
        m = {'Status': Status,
             'Nonterminal': Nonterminal,
             'Symbol': Symbol,}
        exec(py.code.Source(self.get_code()).compile(), m)
        return m['Parser']

    def memoize_header(self, name, args):
        dictname = "_dict_%s" % (name, )
        self.emit_initcode("self.%s = {}" % (dictname, ))
        if args:
            self.emit("_key = (self._pos, %s)" % (", ".join(args)))
        else:
            self.emit("_key = self._pos")
        self.emit("_status = self.%s.get(_key, None)" % (dictname, ))
        with self.block("if _status is None:"):
            self.emit("_status = self.%s[_key] = Status()" % (
                dictname, ))
        with self.block("else:"):
            self.emit("_statusstatus = _status.status")
            with self.block("if _statusstatus == _status.NORMAL:"):
                self.emit("self._pos = _status.pos")
                self.emit("return _status")
            with self.block("elif _statusstatus == _status.ERROR:"):
                self.emit("raise BacktrackException(_status.error)")
            if self.have_call:
                with self.block(
                    "elif (_statusstatus == _status.INPROGRESS or\n"
                    "      _statusstatus == _status.LEFTRECURSION):"):
                    self.emit("_status.status = _status.LEFTRECURSION")
                    with self.block("if _status.result is not None:"):
                        self.emit("self._pos = _status.pos")
                        self.emit("return _status")
                    with self.block("else:"):
                        self.emit("raise BacktrackException(None)")
                with self.block(
                    "elif _statusstatus == _status.SOMESOLUTIONS:"):
                    self.emit("_status.status = _status.INPROGRESS")
        self.emit("_startingpos = self._pos")
        self.start_block("try:")
        self.emit("_result = None")
        self.emit("_error = None")

    def memoize_footer(self, name, args):
        dictname = "_dict_%s" % (name, )
        if self.have_call:
            with self.block(
                "if _status.status == _status.LEFTRECURSION:"):
                with self.block("if _status.result is not None:"):
                    with self.block("if _status.pos >= self._pos:"):
                        self.emit("_status.status = _status.NORMAL")
                        self.emit("self._pos = _status.pos")
                        self.emit("return _status")
                self.emit("_status.pos = self._pos")
                self.emit("_status.status = _status.SOMESOLUTIONS")
                self.emit("_status.result = %s" % (self.resultname, ))
                self.emit("_status.error = _error")
                self.emit("self._pos = _startingpos")
                self.emit("return self._%s(%s)" % (name, ', '.join(args)))
        else:
            self.emit("assert _status.status != _status.LEFTRECURSION")
        self.emit("_status.status = _status.NORMAL")
        self.emit("_status.pos = self._pos")
        self.emit("_status.result = %s" % (self.resultname, ))
        self.emit("_status.error = _error")
        self.emit("return _status")
        self.end_block("try")
        with self.block("except BacktrackException, _exc:"):
            self.emit("_status.pos = -1")
            self.emit("_status.result = None")
            self.combine_error('_exc.error')
            self.emit("_status.error = _error")
            self.emit("_status.status = _status.ERROR")
            self.emit("raise BacktrackException(_error)")

    def choice_point(self, name=None):
        var = "_choice%s" % (self.namecount, )
        self.namecount += 1
        self.emit("%s = self._pos" % (var, ))
        return var

    def revert(self, var):
        self.emit("self._pos = %s" % (var, ))

    def visit_list(self, t):
        self.start_block("class Parser(object):")
        for elt in t.children:
            self.dispatch(elt)
        with self.block("def __init__(self, inputstream):"):
            for line in self.initcode:
                self.emit(line)
            self.emit("self._pos = 0")
            self.emit("self._inputstream = inputstream")
        if self.matchers:
            self.emit_regex_code()
        self.end_block("class")

    def emit_regex_code(self):
        for regex, matcher in self.matchers.iteritems():
            with  self.block(
                    "def _regex%s(self):" % (abs(hash(regex)), )):
                c = self.choice_point()
                self.emit("_runner = self._Runner(self._inputstream, self._pos)")
                self.emit("_i = _runner.recognize_%s(self._pos)" % (
                    abs(hash(regex)), ))
                self.start_block("if _runner.last_matched_state == -1:")
                self.revert(c)
                self.emit("raise BacktrackException")
                self.end_block("if")
                self.emit("_upto = _runner.last_matched_index + 1")
                self.emit("_pos = self._pos")
                self.emit("assert _pos >= 0")
                self.emit("assert _upto >= 0")
                self.emit("_result = self._inputstream[_pos: _upto]")
                self.emit("self._pos = _upto")
                self.emit("return _result")

        with self.block("class _Runner(object):"):
            with self.block("def __init__(self, text, pos):"):
                self.emit("self.text = text")
                self.emit("self.pos = pos")
                self.emit("self.last_matched_state = -1")
                self.emit("self.last_matched_index = -1")
                self.emit("self.state = -1")
            for regex, matcher in self.matchers.iteritems():
                matcher = str(matcher).replace(
                    "def recognize(runner, i)",
                    "def recognize_%s(runner, i)" % (abs(hash(regex)), ))
                self.emit(str(matcher))

    def visit_production(self, t):
        name = t.children[0]
        if name in self.names:
            raise Exception("name %s appears twice" % (name, ))
        self.names[name] = True
        otherargs = t.children[1].children
        argswithself = ", ".join(["self"] + otherargs)
        argswithoutself = ", ".join(otherargs)
        with self.block("def %s(%s):" % (name, argswithself)):
            self.emit("return self._%s(%s).result" % (name, argswithoutself))
        self.start_block("def _%s(%s):" % (name, argswithself, ))
        self.namecount = 0
        self.resultname = "_result"
        self.have_call = False
        self.created_error = False
        allother = self.store_code_away()
        self.dispatch(t.children[-1])
        subsequent = self.restore_code(allother)
        self.memoize_header(name, otherargs)
        self.add_code(subsequent)
        self.memoize_footer(name, otherargs)
        self.end_block("def")

    def visit_or(self, t, first=False):
        possibilities = t.children
        if len(possibilities) > 1:
            self.start_block("while 1:")
        for i, p in enumerate(possibilities):
            c = self.choice_point()
            with self.block("try:"):
                self.dispatch(p)
                self.emit("break")
            with self.block("except BacktrackException, _exc:"):
                self.combine_error('_exc.error')
                self.revert(c)
                if i == len(possibilities) - 1:
                    self.emit("raise BacktrackException(_error)")
        self.dispatch(possibilities[-1])
        if len(possibilities) > 1:
            self.emit("break")
            self.end_block("while")

    def visit_commands(self, t):
        for elt in t.children:
            self.dispatch(elt)

    def visit_maybe(self, t):
        c = self.choice_point()
        with self.block("try:"):
            self.dispatch(t.children[0])
        with self.block("except BacktrackException:"):
            self.revert(c)

    def visit_repetition(self, t):
        name = "_all%s" % (self.namecount, )
        self.namecount += 1
        self.emit("%s = []" % (name, ))
        if t.children[0] == '+':
            self.dispatch(t.children[1])
            self.emit("%s.append(_result)"  % (name, ))
        with self.block("while 1:"):
            c = self.choice_point()
            with self.block("try:"):
                self.dispatch(t.children[1])
                self.emit("%s.append(_result)" % (name, ))
            with self.block("except BacktrackException, _exc:"):
                self.combine_error('_exc.error')
                self.revert(c)
                self.emit("break")
        self.emit("_result = %s" % (name, ))

    def visit_exclusive(self, t):
        self.resultname = "_enclosed"
        self.dispatch(t.children[0])
        self.emit("_enclosed = _result")

    def visit_ignore(self, t):
        resultname = "_before_discard%i" % (self.namecount, )
        self.namecount += 1
        self.emit("%s = _result" % (resultname, ))
        self.dispatch(t.children[0])
        self.emit("_result = %s" % (resultname, ))

    def visit_negation(self, t):
        c = self.choice_point()
        resultname = "_stored_result%i" % (self.namecount, )
        self.namecount += 1
        child = t.children[0]
        self.emit("%s = _result" % (resultname, ))
        with self.block("try:"):
            self.dispatch(child)
        with self.block("except BacktrackException:"):
            self.revert(c)
            self.emit("_result = %s" % (resultname, ))
        with self.block("else:"):
            # heuristic to get nice error messages sometimes
            if isinstance(child, Symbol) and child.symbol == "QUOTE":

                error = "self._ErrorInformation(%s, ['NOT %s'])" % (
                        c, child.additional_info[1:-1], )
            else:
                error = "None"
            self.emit("raise BacktrackException(%s)" % (error, ))

    def visit_lookahead(self, t):
        resultname = "_stored_result%i" % (self.namecount, )
        self.emit("%s = _result" % (resultname, ))
        c = self.choice_point()
        self.dispatch(t.children[0])
        self.revert(c)
        self.emit("_result = %s" % (resultname, ))

    def visit_named_command(self, t):
        name = t.children[0]
        self.dispatch(t.children[1])
        self.emit("%s = _result" % (name, ))

    def visit_return(self, t):
        self.emit("_result = (%s)" % (t.children[0].additional_info[1:-1], ))

    def visit_if(self, t):
        if len(t.children) == 2:
            self.dispatch(t.children[0])
        with self.block("if not (%s):" % (
            t.children[-1].additional_info[1:-1], )):
            self.emit("raise BacktrackException(")
            self.emit("    self._ErrorInformation(")
            self.emit("         _startingpos, ['condition not met']))")

    def visit_choose(self, t):
        with self.block("for %s in (%s):" % (
            t.children[0], t.children[1].additional_info[1:-1], )):
            with self.block("try:"):
                self.dispatch(t.children[2])
                self.emit("break")
            with self.block("except BacktrackException, _exc:"):
                self.combine_error('_exc.error')
        with self.block("else:"):
            self.emit("raise BacktrackException(_error)")

    def visit_call(self, t):
        self.have_call = True
        args = ", ".join(['(%s)' % (arg.additional_info[1:-1], )
                              for arg in t.children[1].children])
        if t.children[0].startswith("_"):
            callname = t.children[0]
            self.emit("_result = self.%s(%s)" % (callname, args))
        else:
            callname = "_" + t.children[0]
            self.emit("_call_status = self.%s(%s)" % (callname, args))
            self.emit("_result = _call_status.result")
            self.combine_error('_call_status.error')

    def visit_REGEX(self, t):
        r = t.additional_info[1:-1].replace('\\`', '`')
        matcher = self.get_regex(r)
        self.emit("_result = self._regex%s()" % (abs(hash(r)), ))

    def visit_QUOTE(self, t):
        self.emit("_result = self.__chars__(%r)" % (
                    str(t.additional_info[1:-1]), ))

    def get_regex(self, r):
        from rpython.rlib.parsing.regexparse import parse_regex
        if r in self.matchers:
            return self.matchers[r]
        regex = parse_regex(r)
        if regex is None:
            raise ValueError(
                "%s is not a valid regular expression" % regextext)
        automaton = regex.make_automaton().make_deterministic()
        automaton.optimize()
        matcher = automaton.make_lexing_code()
        self.matchers[r] = py.code.Source(matcher)
        return matcher

    def combine_error(self, newerror):
        if self.created_error:
            self.emit(
                "_error = self._combine_errors(_error, %s)" % (newerror, ))
        else:
            self.emit("_error = %s" % (newerror, ))
            self.created_error = True

class MetaPackratParser(type):
    def __new__(cls, name_, bases, dct):
        if '__doc__' not in dct or dct['__doc__'] is None:
            return type.__new__(cls, name_, bases, dct)
        from pypackrat import PyPackratSyntaxParser
        import sys, new, inspect
        frame = sys._getframe(1)
        source = dct['__doc__']
        p = PyPackratSyntaxParser(source)
        try:
            t = p.file()
        except BacktrackException as exc:
            print exc.error.nice_error_message("<docstring>", source)
            lineno, _ = exc.error.get_line_column(source)
            errorline = source.split("\n")[lineno]
            try:
                code = frame.f_code
                source = inspect.getsource(code)
                lineno_in_orig = source.split("\n").index(errorline)
                if lineno_in_orig >= 0:
                    print "probable error position:"
                    print "file:", code.co_filename
                    print "line:", lineno_in_orig + code.co_firstlineno + 1
            except (IOError, ValueError):
                pass
            raise exc
        t = t.visit(TreeOptimizer())
        visitor = ParserBuilder()
        t.visit(visitor)
        pcls = visitor.make_parser()
        forbidden = dict.fromkeys(("__weakref__ __doc__ "
                                   "__dict__ __module__").split())
        initthere = "__init__" in dct

        #XXX XXX XXX
        if 'BacktrackException' not in frame.f_globals:
            raise Exception("must import BacktrackException")
        if 'Status' not in frame.f_globals:
            raise Exception("must import Status")
        result = type.__new__(cls, name_, bases, dct)
        for key, value in pcls.__dict__.iteritems():
            if isinstance(value, type):
                value.__module__ = result.__module__ #XXX help the annotator
            if isinstance(value, type(lambda: None)):
                value = new.function(value.__code__, frame.f_globals)
            if not hasattr(result, key) and key not in forbidden:
                setattr(result, key, value)
        if result.__init__ == object.__init__:
            result.__init__ = pcls.__dict__['__init__']
        result.init_parser = pcls.__dict__['__init__']
        result._code = visitor.get_code()
        return result

class PackratParser(object):
    __metaclass__ = MetaPackratParser

    _ErrorInformation = ErrorInformation
    _BacktrackException = BacktrackException

    def __chars__(self, chars):
        #print '__chars__(%s)' % (chars, ), self._pos
        try:
            for i in range(len(chars)):
                if self._inputstream[self._pos + i] != chars[i]:
                    raise BacktrackException(
                        self._ErrorInformation(self._pos, [chars]))
            self._pos += len(chars)
            return chars
        except IndexError:
            raise BacktrackException(
                self._ErrorInformation(self._pos, [chars]))

    def  __any__(self):
        try:
            result = self._inputstream[self._pos]
            self._pos += 1
            return result
        except IndexError:
            raise BacktrackException(
                self._ErrorInformation(self._pos, ['anything']))

    def _combine_errors(self, error1, error2):
        if error1 is None:
            return error2
        if (error2 is None or error1.pos > error2.pos or
            len(error2.expected) == 0):
            return error1
        elif error2.pos > error1.pos or len(error1.expected) == 0:
            return error2
        expected = []
        already_there = {}
        for ep in [error1.expected, error2.expected]:
            for reason in ep:
                if reason not in already_there:
                    already_there[reason] = True
                    expected.append(reason)
        return ErrorInformation(error1.pos, expected)


def test_generate():
    f = py.path.local(__file__).dirpath().join("pypackrat.py")
    from pypackrat import PyPackratSyntaxParser
    p = PyPackratSyntaxParser(syntax)
    t = p.file()
    t = t.visit(TreeOptimizer())
    visitor = ParserBuilder()
    t.visit(visitor)
    code = visitor.get_code()
    content = """
from rpython.rlib.parsing.tree import Nonterminal, Symbol
from makepackrat import PackratParser, BacktrackException, Status
%s
class PyPackratSyntaxParser(PackratParser):
    def __init__(self, stream):
        self.init_parser(stream)
forbidden = dict.fromkeys(("__weakref__ __doc__ "
                           "__dict__ __module__").split())
initthere = "__init__" in PyPackratSyntaxParser.__dict__
for key, value in Parser.__dict__.iteritems():
    if key not in PyPackratSyntaxParser.__dict__ and key not in forbidden:
        setattr(PyPackratSyntaxParser, key, value)
PyPackratSyntaxParser.init_parser = Parser.__init__.im_func
""" % (code, )
    print content
    f.write(content)
