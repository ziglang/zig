import sys
from rpython.rtyper.lltypesystem.lltype import *
from rpython.translator.translator import TranslationContext
from rpython.translator.c.database import LowLevelDatabase
from rpython.flowspace.model import Constant, Variable, SpaceOperation
from rpython.flowspace.model import Block, Link, FunctionGraph
from rpython.rtyper.lltypesystem.lltype import getfunctionptr
from rpython.rtyper.lltypesystem.rffi import VOIDP, INT_real, INT, CArrayPtr


def dump_on_stdout(database):
    print '/*********************************/'
    structdeflist = database.getstructdeflist()
    for node in structdeflist:
        for line in node.definition():
            print line
    print
    for node in database.globalcontainers():
        for line in node.forward_declaration():
            print line
    for node in database.globalcontainers():
        print
        for line in node.implementation():
            print line


def test_primitive():
    db = LowLevelDatabase()
    if is_emulated_long:
        assert db.get(5) == '5LL'
    else:
        assert db.get(5) == '5L'
    assert db.get(True) == '1'

def test_struct():
    db = LowLevelDatabase()
    pfx = db.namespace.global_prefix + 'g_'
    S = GcStruct('test', ('x', Signed))
    s = malloc(S)
    s.x = 42
    assert db.get(s).startswith('(&'+pfx)
    assert db.containernodes.keys() == [s._obj]
    assert db.structdefnodes.keys() == [S]

def test_inlined_struct():
    db = LowLevelDatabase()
    pfx = db.namespace.global_prefix + 'g_'
    S = GcStruct('test', ('x', Struct('subtest', ('y', Signed))))
    s = malloc(S)
    s.x.y = 42
    assert db.get(s).startswith('(&'+pfx)
    assert db.containernodes.keys() == [s._obj]
    db.complete()
    assert len(db.structdefnodes) == 2
    assert S in db.structdefnodes
    assert S.x in db.structdefnodes

def test_complete():
    db = LowLevelDatabase()
    pfx = db.namespace.global_prefix + 'g_'
    T = GcStruct('subtest', ('y', Signed))
    S = GcStruct('test', ('x', Ptr(T)))
    s = malloc(S)
    s.x = malloc(T)
    s.x.y = 42
    assert db.get(s).startswith('(&'+pfx)
    assert db.containernodes.keys() == [s._obj]
    db.complete()
    assert len(db.containernodes) == 2
    assert s._obj in db.containernodes
    assert s.x._obj in db.containernodes
    assert len(db.structdefnodes) == 2
    assert S in db.structdefnodes
    assert S.x.TO in db.structdefnodes

def test_codegen():
    db = LowLevelDatabase()
    U = Struct('inlined', ('z', Signed))
    T = Struct('subtest', ('y', Signed))
    S = Struct('test', ('x', Ptr(T)), ('u', U), ('p', Ptr(U)))
    s = malloc(S, immortal=True)
    s.x = malloc(T, immortal=True)
    s.x.y = 42
    s.u.z = -100
    s.p = s.u
    db.get(s)
    db.complete()
    dump_on_stdout(db)

def test_codegen_2():
    db = LowLevelDatabase()
    A = GcArray(('x', Signed))
    S = GcStruct('test', ('aptr', Ptr(A)))
    a = malloc(A, 3)
    a[0].x = 100
    a[1].x = 101
    a[2].x = 102
    s = malloc(S)
    s.aptr = a
    db.get(s)
    db.complete()
    dump_on_stdout(db)

def test_codegen_3():
    db = LowLevelDatabase()
    A = Struct('varsizedstuff', ('x', Signed), ('y', Array(('i', Signed))))
    S = Struct('test', ('aptr', Ptr(A)),
                       ('anitem', Ptr(A.y.OF)),
                       ('anarray', Ptr(A.y)))
    a = malloc(A, 3, immortal=True)
    a.x = 99
    a.y[0].i = 100
    a.y[1].i = 101
    a.y[2].i = 102
    s = malloc(S, immortal=True)
    s.aptr = a
    s.anitem =  a.y[1]
    s.anarray = a.y
    db.get(s)
    db.complete()
    dump_on_stdout(db)

def test_func_simple():
    # -------------------- flowgraph building --------------------
    #     def f(x):
    #         return x+1
    x = Variable("x")
    x.concretetype = Signed
    result = Variable("result")
    result.concretetype = Signed
    one = Constant(1)
    one.concretetype = Signed
    op = SpaceOperation("int_add", [x, one], result)
    block = Block([x])
    graph = FunctionGraph("f", block)
    block.operations.append(op)
    block.closeblock(Link([result], graph.returnblock))
    graph.getreturnvar().concretetype = Signed
    # --------------------         end        --------------------

    F = FuncType([Signed], Signed)
    f = functionptr(F, "f", graph=graph)
    db = LowLevelDatabase()
    db.get(f)
    db.complete()
    dump_on_stdout(db)

    S = GcStruct('testing', ('fptr', Ptr(F)))
    s = malloc(S)
    s.fptr = f
    db = LowLevelDatabase()
    db.get(s)
    db.complete()
    dump_on_stdout(db)

# ____________________________________________________________

def makegraph(func, argtypes):
    t = TranslationContext()
    t.buildannotator().build_types(func, [int])
    t.buildrtyper().specialize()
    bk = t.annotator.bookkeeper
    graph = bk.getdesc(func).getuniquegraph()
    return t, graph

def test_function_call():
    def g(x, y):
        return x-y
    def f(x):
        return g(1, x)
    t, graph = makegraph(f, [int])

    F = FuncType([Signed], Signed)
    f = functionptr(F, "f", graph=graph)
    db = LowLevelDatabase(t, exctransformer=t.getexceptiontransformer())
    db.get(f)
    db.complete()
    dump_on_stdout(db)


def test_malloc():
    S = GcStruct('testing', ('x', Signed), ('y', Signed))
    def ll_f(x):
        p = malloc(S)
        p.x = x
        p.y = x+1
        return p.x * p.y
    t, graph = makegraph(ll_f, [int])

    db = LowLevelDatabase(t, exctransformer=t.getexceptiontransformer())
    db.get(getfunctionptr(graph))
    db.complete()
    dump_on_stdout(db)

def test_multiple_malloc():
    S1 = GcStruct('testing1', ('x', Signed), ('y', Signed))
    S = GcStruct('testing', ('ptr1', Ptr(S1)),
                            ('ptr2', Ptr(S1)),
                            ('z', Signed))
    def ll_f(x):
        ptr1 = malloc(S1)
        ptr1.x = x
        ptr2 = malloc(S1)
        ptr2.x = x+1
        s = malloc(S)
        s.ptr1 = ptr1
        s.ptr2 = ptr2
        return s.ptr1.x * s.ptr2.x
    t, graph = makegraph(ll_f, [int])

    db = LowLevelDatabase(t, exctransformer=t.getexceptiontransformer())
    db.get(getfunctionptr(graph))
    db.complete()
    dump_on_stdout(db)

def test_array_of_char():
    A = GcArray(Char)
    a = malloc(A, 11)
    for i, c in zip(range(11), 'hello world'):
        a[i] = c
    db = LowLevelDatabase()
    db.get(a)
    db.complete()
    dump_on_stdout(db)

def test_voidp():
    A = VOIDP
    db = LowLevelDatabase()
    assert db.gettype(A) == "void *@"

def test_intlong_unique():
    A = INT_real
    B = Signed
    db = LowLevelDatabase()
    assert db.gettype(A) == "int @"
    assert db.gettype(B) == "Signed @"


def test_recursive_struct():
    S = GcForwardReference()
    S.become(GcStruct('testing', ('p', Ptr(S))))
    p = malloc(S)
    p.p = p
    db = LowLevelDatabase()
    db.get(p)
    db.complete()
    dump_on_stdout(db)

def test_typedef():
    A = Typedef(Signed, 'test4')
    db = LowLevelDatabase()
    assert db.gettype(A) == "test4 @"

    PA = CArrayPtr(A)
    assert db.gettype(PA) == "test4 *@"

    F = FuncType((A,), A)
    assert db.gettype(F) == "test4 (@)(test4)"

