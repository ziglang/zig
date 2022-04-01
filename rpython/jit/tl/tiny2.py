"""
An interpreter for a strange word-based language: the program is a list
of space-separated words.  Most words push themselves on a stack; some
words have another action.  The result is the space-separated words
from the stack.

    Hello World          => 'Hello World'
    6 7 ADD              => '13'              'ADD' is a special word
    7 * 5 = 7 5 MUL      => '7 * 5 = 35'      '*' and '=' are not special words

Arithmetic on non-integers gives a 'symbolic' result:

    X 2 MUL              => 'X*2'

Input arguments can be passed on the command-line, and used as #1, #2, etc.:

    #1 1 ADD             => one more than the argument on the command-line,
                            or if it was not an integer, concatenates '+1'

You can store back into an (existing) argument index with ->#N:

    #1 5 ADD ->#1

Braces { } delimitate a loop.  Don't forget spaces around each one.
The '}' pops an integer value off the stack and loops if it is not zero:

    { #1 #1 1 SUB ->#1 #1 }    => when called with 5, gives '5 4 3 2 1'

"""
from rpython.rlib.jit import hint, promote, dont_look_inside

#
# See pypy/doc/jit.txt for a higher-level overview of the JIT techniques
# detailed in the following comments.
#


class Box:
    # Although all words are in theory strings, we use two subclasses
    # to represent the strings differently from the words known to be integers.
    # This is an optimization that is essential for the JIT and merely
    # useful for the basic interpreter.
    pass

class IntBox(Box):
    def __init__(self, intval):
        self.intval = intval
    def as_int(self):
        return self.intval
    def as_str(self):
        return str(self.intval)

class StrBox(Box):
    def __init__(self, strval):
        self.strval = strval
    def as_int(self):
        return myint(self.strval)
    def as_str(self):
        return self.strval


def func_add_int(ix, iy): return ix + iy
def func_sub_int(ix, iy): return ix - iy
def func_mul_int(ix, iy): return ix * iy

def func_add_str(sx, sy): return sx + '+' + sy
def func_sub_str(sx, sy): return sx + '-' + sy
def func_mul_str(sx, sy): return sx + '*' + sy

def op2(stack, func_int, func_str):
    # Operate on the top two stack items.  The promotion hints force the
    # class of each arguments (IntBox or StrBox) to turn into a compile-time
    # constant if they weren't already.  The effect we seek is to make the
    # calls to as_int() direct calls at compile-time, instead of indirect
    # ones.  The JIT compiler cannot look into indirect calls, but it
    # can analyze and inline the code in directly-called functions.
    y = stack.pop()
    promote(y.__class__)
    x = stack.pop()
    promote(x.__class__)
    try:
        z = IntBox(func_int(x.as_int(), y.as_int()))
    except ValueError:
        z = StrBox(func_str(x.as_str(), y.as_str()))
    stack.append(z)


def interpret(bytecode, args):
    """The interpreter's entry point and portal function.
    """
    # ------------------------------
    # First a lot of JIT hints...
    #
    # A portal needs a "global merge point" at the beginning, for
    # technical reasons, if it uses promotion hints:
    hint(None, global_merge_point=True)

    # An important hint: 'bytecode' is a list, which is in theory
    # mutable.  Let's tell the JIT compiler that it can assume that the
    # list is entirely frozen, i.e. immutable and only containing immutable
    # objects.  Otherwise, it cannot do anything - it would have to assume
    # that the list can unpredictably change at runtime.
    bytecode = hint(bytecode, deepfreeze=True)

    # Now some strange code that makes a copy of the 'args' list in
    # a complicated way...  this is a workaround forcing the whole 'args'
    # list to be virtual.  It is a way to tell the JIT compiler that it
    # doesn't have to worry about the 'args' list being unpredictably
    # modified.
    oldargs = args
    argcount = promote(len(oldargs))
    args = []
    n = 0
    while n < argcount:
        hint(n, concrete=True)
        args.append(oldargs[n])
        n += 1
    # ------------------------------
    # the real code starts here
    loops = []
    stack = []
    pos = 0
    while pos < len(bytecode):
        # It is a good idea to put another 'global merge point' at the
        # start of each iteration in the interpreter's main loop.  The
        # JIT compiler keeps a table of all the times it passed through
        # the global merge point.  It allows it to detect when it can
        # stop compiling and generate a jump back to some machine code
        # that was already generated earlier.
        hint(None, global_merge_point=True)

        opcode = bytecode[pos]
        hint(opcode, concrete=True)    # same as in tiny1.py
        pos += 1
        if   opcode == 'ADD': op2(stack, func_add_int, func_add_str)
        elif opcode == 'SUB': op2(stack, func_sub_int, func_sub_str)
        elif opcode == 'MUL': op2(stack, func_mul_int, func_mul_str)
        elif opcode[0] == '#':
            n = myint(opcode, start=1)
            stack.append(args[n-1])
        elif opcode.startswith('->#'):
            n = myint(opcode, start=3)
            if n > len(args):
                raise IndexError
            args[n-1] = stack.pop()
        elif opcode == '{':
            loops.append(pos)
        elif opcode == '}':
            if stack.pop().as_int() == 0:
                loops.pop()
            else:
                pos = loops[-1]
                # A common problem when interpreting loops or jumps: the 'pos'
                # above is read out of a list, so the hint-annotator thinks
                # it must be red (not a compile-time constant).  But the
                # hint(opcode, concrete=True) in the next iteration of the
                # loop requires all variables the 'opcode' depends on to be
                # green, including this 'pos'.  We promote 'pos' to a green
                # here, as early as possible.  Note that in practice the 'pos'
                # read out of the 'loops' list will be a compile-time constant
                # because it was pushed as a compile-time constant by the '{'
                # case above into 'loops', which is a virtual list, so the
                promote(pos)
        else:
            stack.append(StrBox(opcode))
    return stack

def repr(stack):
    # this bit moved out of the portal function because JIT'ing it is not
    # very useful, and the JIT generator is confused by the 'for' right now...
    return ' '.join([x.as_str() for x in stack])


# ------------------------------
# Pure workaround code!  It will eventually be unnecessary.
# For now, myint(s, n) is a JIT-friendly way to spell int(s[n:]).
# We don't support negative numbers, though.
@dont_look_inside
def myint_internal(s, start=0):
    if start >= len(s):
        return -1
    res = 0
    while start < len(s):
        c = s[start]
        n = ord(c) - ord('0')
        if not (0 <= n <= 9):
            return -1
        res = res * 10 + n
        start += 1
    return res
def myint(s, start=0):
    n = myint_internal(s, start)
    if n < 0:
        raise ValueError
    return n
# ------------------------------


def test_main():
    main = """#1 5 ADD""".split()
    res = interpret(main, [IntBox(20)])
    assert repr(res) == '25'
    res = interpret(main, [StrBox('foo')])
    assert repr(res) == 'foo+5'

FACTORIAL = """The factorial of #1 is
                  1 { #1 MUL #1 1 SUB ->#1 #1 }""".split()

def test_factorial():
    res = interpret(FACTORIAL, [IntBox(5)])
    assert repr(res) == 'The factorial of 5 is 120'

FIBONACCI = """Fibonacci numbers:
                  { #1 #2 #1 #2 ADD ->#2 ->#1 #3 1 SUB ->#3 #3 }""".split()

def test_fibonacci():
    res = interpret(FIBONACCI, [IntBox(1), IntBox(1), IntBox(10)])
    assert repr(res) == "Fibonacci numbers: 1 1 2 3 5 8 13 21 34 55"
