"""
list of tested expressions / suites (used by test_parser and test_astbuilder)
"""

constants = [
    "0",
    "00",
    "7",
    "-3",
    "0o53",
    "0x18",
    "1.0",
    "3.9",
    "-3.6",
    "1.8e19",
    "90000000000000",
    "90000000000000.",
    "3j"
    ]

expressions = [
    "x = a + 1",
    "x = 1 - a",
    "x = a * b",
    "x = a ** 2",
    "x = a / b",
    "x = a & b",
    "x = a | b",
    "x = a ^ b",
    "x = a // b",
    "x = a * b + 1",
    "x = a + 1 * b",
    "x = a * b / c",
    "x = a * (1 + c)",
    "x, y, z = 1, 2, 3",
    "x = 'a' 'b' 'c'",
    "del foo",
    "del foo[bar]",
    "del foo.bar",
    "l[0]",
    "k[v,]",
    "m[a,b]",
    "a.b.c[d]",
    "file('some.txt').read()",
    "a[0].read()",
    "a[1:1].read()",
    "f('foo')('bar')('spam')",
    "f('foo')('bar')('spam').read()[0]",
    "a.b[0][0]",
    "a.b[0][:]",
    "a.b[0][::]",
    "a.b[0][0].pop()[0].push('bar')('baz').spam",
    "a.b[0].read()[1][2].foo().spam()[0].bar",
    "a**2",
    "a**2**2",
    "a.b[0]**2",
    "a.b[0].read()[1][2].foo().spam()[0].bar ** 2",
    "l[start:end] = l2",
    "l[::] = l2",
    "a = `s`",
    "a = `1 + 2 + f(3, 4)`",
    "[a, b] = c",
    "(a, b) = c",
    "[a, (b,c), d] = e",
    "a, (b, c), d = e",
    ]

# We do not export the following tests because we would have to implement 2.5
# features in the stable compiler (other than just building the AST).
expressions_inbetweenversions = expressions + [
    "1 if True else 2",
    "1 if False else 2",
    ]

funccalls = [
    "l = func()",
    "l = func(10)",
    "l = func(10, 12, a, b=c, *args)",
    "l = func(10, 12, a, b=c, **kwargs)",
    "l = func(10, 12, a, b=c, *args, **kwargs)",
    "l = func(10, 12, a, b=c)",
    "e = l.pop(3)",
    "e = k.l.pop(3)",
    "simplefilter('ignore', category=PendingDeprecationWarning, append=1)",
    """methodmap = dict(subdirs=phase4,
                        same_files=phase3, diff_files=phase3, funny_files=phase3,
                        common_dirs = phase2, common_files=phase2, common_funny=phase2,
                        common=phase1, left_only=phase1, right_only=phase1,
                        left_list=phase0, right_list=phase0)""",
    "odata = b2a_qp(data, quotetabs = quotetabs, header = header)",
    ]

listmakers = [
    "l = []",
    "l = [1, 2, 3]",
    "l = [i for i in range(10)]",
    "l = [i for i in range(10) if i%2 == 0]",
    "l = [i for i in range(10) if i%2 == 0 or i%2 == 1]", # <--
    "l = [i for i in range(10) if i%2 == 0 and i%2 == 1]",
    "l = [i for j in range(10) for i in range(j)]",
    "l = [i for j in range(10) for i in range(j) if j%2 == 0]",
    "l = [i for j in range(10) for i in range(j) if j%2 == 0 and i%2 == 0]",
    "l = [(a, b) for (a,b,c) in l2]",
    "l = [{a:b} for (a,b,c) in l2]",
    "l = [i for j in k if j%2 == 0 if j*2 < 20 for i in j if i%2==0]",
    ]

genexps = [
    "l = (i for i in j)",
    "l = (i for i in j if i%2 == 0)",
    "l = (i for j in k for i in j)",
    "l = (i for j in k for i in j if j%2==0)",
    "l = (i for j in k if j%2 == 0 if j*2 < 20 for i in j if i%2==0)",
    "l = (i for i in [ j*2 for j in range(10) ] )",
    "l = [i for i in ( j*2 for j in range(10) ) ]",
    "l = (i for i in [ j*2 for j in ( k*3 for k in range(10) ) ] )",
    "l = [i for j in ( j*2 for j in [ k*3 for k in range(10) ] ) ]",
    "l = f(i for i in j)",
    ]


dictmakers = [
    "l = {a : b, 'c' : 0}",
    "l = {}",
    ]

backtrackings = [
    "f = lambda x: x+1",
    "f = lambda x,y: x+y",
    "f = lambda x,y=1,z=t: x+y",
    "f = lambda x,y=1,z=t,*args,**kwargs: x+y",
    "f = lambda x,y=1,z=t,*args: x+y",
    "f = lambda x,y=1,z=t,**kwargs: x+y",
    "f = lambda: 1",
    "f = lambda *args: 1",
    "f = lambda **kwargs: 1",
    ]

comparisons = [
    "a < b",
    "a > b",
    "a not in b",
    "a is not b",
    "a in b",
    "a is b",
    "3 < x < 5",
    "(3 < x) < 5",
    "a < b < c < d",
    "(a < b) < (c < d)",
    "a < (b < c) < d",
    ]

multiexpr = [
    'a = b; c = d;',
    'a = b = c = d',
    ]

attraccess = [
    'a.b = 2',
    'x = a.b',
    ]

slices = [
    "l[:]",
    "l[::]",
    "l[1:2]",
    "l[1:]",
    "l[:2]",
    "l[1::]",
    "l[:1:]",
    "l[::1]",
    "l[1:2:]",
    "l[:1:2]",
    "l[1::2]",
    "l[0:1:2]",
    "a.b.l[:]",
    "a.b.l[1:2]",
    "a.b.l[1:]",
    "a.b.l[:2]",
    "a.b.l[0:1:2]",
    "a[1:2:3, 100]",
    "a[:2:3, 100]",
    "a[1::3, 100,]",
    "a[1:2:, 100]",
    "a[1:2, 100]",
    "a[1:, 100,]",
    "a[:2, 100]",
    "a[:, 100]",
    "a[100, 1:2:3,]",
    "a[100, :2:3]",
    "a[100, 1::3]",
    "a[100, 1:2:,]",
    "a[100, 1:2]",
    "a[100, 1:]",
    "a[100, :2,]",
    "a[100, :]",
    ]

imports = [
    'import os',
    'import sys, os',
    'import os.path',
    'import os.path, sys',
    'import sys, os.path as osp',
    'import os.path as osp',
    'import os.path as osp, sys as _sys',
    'import a.b.c.d',
    'import a.b.c.d as abcd',
    'from os import path',
    'from os import path, system',
    ]

imports_newstyle = [
    'from os import path, system',
    'from os import path as P, system as S',
    'from os import (path as P, system as S,)',
    'from os import *',
    ]

if_stmts = [
    "if a == 1: a+= 2",
    """if a == 1:
    a += 2
elif a == 2:
    a += 3
else:
    a += 4
""",
    "if a and not b == c: pass",
    "if a and not not not b == c: pass",
    "if 0: print 'foo'"
    ]

asserts = [
    'assert False',
    'assert a == 1',
    'assert a == 1 and b == 2',
    'assert a == 1 and b == 2, "assertion failed"',
    ]

execs = [
    'exec a',
    'exec "a=b+3"',
    'exec a in f()',
    'exec a in f(), g()',
    ]

prints = [
    'print',
    'print a',
    'print a,',
    'print a, b',
    'print a, "b", c',
    'print >> err',
    'print >> err, "error"',
    'print >> err, "error",',
    'print >> err, "error", a',
    ]

globs = [
    'global a',
    'global a,b,c',
    ]

raises_ = [      # NB. 'raises' creates a name conflict with py.test magic
    'raise',
    'raise ValueError',
    'raise ValueError("error")',
    'raise ValueError, "error"',
    'raise ValueError, "error", foo',
    ]

tryexcepts = [
    """try:
    a
    b
except:
    pass
""",
    """try:
    a
    b
except NameError:
    pass
""",
    """try:
    a
    b
except NameError, err:
    pass
""",
    """try:
    a
    b
except (NameError, ValueError):
    pass
""",
    """try:
    a
    b
except (NameError, ValueError), err:
    pass
""",
    """try:
    a
except NameError, err:
    pass
except ValueError, err:
    pass
""",
    """def f():
    try:
        a
    except NameError, err:
        a = 1
        b = 2
    except ValueError, err:
        a = 2
        return a
"""
    """try:
    a
except NameError, err:
    a = 1
except ValueError, err:
    a = 2
else:
    a += 3
""",
    """try:
    a
finally:
    b
""",
    """def f():
    try:
        return a
    finally:
        a = 3
        return 1
""",

    ]
    
one_stmt_funcdefs = [
    "def f(): return 1",
    "def f(x): return x+1",
    "def f(x,y): return x+y",
    "def f(x,y=1,z=t): return x+y",
    "def f(x,y=1,z=t,*args,**kwargs): return x+y",
    "def f(x,y=1,z=t,*args): return x+y",
    "def f(x,y=1,z=t,**kwargs): return x+y",
    "def f(*args): return 1",
    "def f(**kwargs): return 1",
    "def f(t=()): pass",
    "def f(a, b, (c, d), e): pass",
    "def f(a, b, (c, (d, e), f, (g, h))): pass",
    "def f(a, b, (c, (d, e), f, (g, h)), i): pass",
    "def f((a)): pass",
    ]

one_stmt_classdefs = [
    "class Pdb(bdb.Bdb, cmd.Cmd): pass",
    "class A: pass",
    ]

docstrings = [
    '''def foo(): return 1''',
    '''class Foo: pass''',
    '''class Foo: "foo"''',
    '''def foo():
    """foo docstring"""
    return 1
''',
    '''def foo():
    """foo docstring"""
    a = 1
    """bar"""
    return a
''',
    '''def foo():
    """doc"""; print 1
    a=1
''',
    '''"""Docstring""";print 1''',
    ]

returns = [
    'def f(): return',
    'def f(): return 1',
    'def f(): return a.b',
    'def f(): return a',
    'def f(): return a,b,c,d',
    #'return (a,b,c,d)',      --- this one makes no sense, as far as I can tell
    ]

augassigns = [
    'a=1;a+=2',
    'a=1;a-=2',
    'a=1;a*=2',
    'a=1;a/=2',
    'a=1;a//=2',
    'a=1;a%=2',
    'a=1;a**=2',
    'a=1;a>>=2',
    'a=1;a<<=2',
    'a=1;a&=2',
    'a=1;a^=2',
    'a=1;a|=2',
    
    'a=A();a.x+=2',
    'a=A();a.x-=2',
    'a=A();a.x*=2',
    'a=A();a.x/=2',
    'a=A();a.x//=2',
    'a=A();a.x%=2',
    'a=A();a.x**=2',
    'a=A();a.x>>=2',
    'a=A();a.x<<=2',
    'a=A();a.x&=2',
    'a=A();a.x^=2',
    'a=A();a.x|=2',

    'a=A();a[0]+=2',
    'a=A();a[0]-=2',
    'a=A();a[0]*=2',
    'a=A();a[0]/=2',
    'a=A();a[0]//=2',
    'a=A();a[0]%=2',
    'a=A();a[0]**=2',
    'a=A();a[0]>>=2',
    'a=A();a[0]<<=2',
    'a=A();a[0]&=2',
    'a=A();a[0]^=2',
    'a=A();a[0]|=2',

    'a=A();a[0:2]+=2',
    'a=A();a[0:2]-=2',
    'a=A();a[0:2]*=2',
    'a=A();a[0:2]/=2',
    'a=A();a[0:2]//=2',
    'a=A();a[0:2]%=2',
    'a=A();a[0:2]**=2',
    'a=A();a[0:2]>>=2',
    'a=A();a[0:2]<<=2',
    'a=A();a[0:2]&=2',
    'a=A();a[0:2]^=2',
    'a=A();a[0:2]|=2',
    ]

PY23_TESTS = [
    constants,
    expressions,
    augassigns,
    comparisons,
    funccalls,
    backtrackings,
    listmakers, # ERRORS
    dictmakers,
    multiexpr,
    attraccess,
    slices,
    imports,
    execs,
    prints,
    globs,
    raises_,

    ]

OPTIONAL_TESTS = [
    # expressions_inbetweenversions, 
    genexps,
    imports_newstyle,
    asserts,
    ]

TESTS = PY23_TESTS + OPTIONAL_TESTS


## TESTS = [
##     ["l = [i for i in range(10) if i%2 == 0 or i%2 == 1]"],
##     ]

CHANGES_25_INPUTS = [
    ["class A(): pass"],
    ["def f(): x = yield 3"]
    ]

EXEC_INPUTS = [
    one_stmt_classdefs,
    one_stmt_funcdefs,
    if_stmts,
    tryexcepts,
    docstrings,
    returns,
    ]

SINGLE_INPUTS = [
   one_stmt_funcdefs,
   ['\t # hello\n',
    'print 6*7',
    'if 1:  x\n',
    'x = 5',
    'x = 5 ',
    '''"""Docstring""";print 1''',
    '''"Docstring"''',
    '''"Docstring" "\\x00"''',
    ]
]
