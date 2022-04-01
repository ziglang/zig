import pytest
from rpython.flowspace.model import const
from rpython.flowspace.objspace import build_flow
from rpython.translator.simplify import simplify_graph
from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.tool.cparser import parse_source, CTypeSpace

def test_configure():
    decl = """
    typedef ssize_t Py_ssize_t;

    typedef struct {
        Py_ssize_t ob_refcnt;
        Py_ssize_t ob_pypy_link;
        double ob_fval;
    } TestFloatObject;
    """
    cts = parse_source(decl)
    TestFloatObject = cts.definitions['TestFloatObject']
    assert isinstance(TestFloatObject, lltype.Struct)
    assert TestFloatObject.c_ob_refcnt == rffi.SSIZE_T
    assert TestFloatObject.c_ob_pypy_link == rffi.SSIZE_T
    assert TestFloatObject.c_ob_fval == rffi.DOUBLE

def test_simple():
    decl = "typedef ssize_t Py_ssize_t;"
    cts = parse_source(decl)
    assert cts.definitions == {'Py_ssize_t': rffi.SSIZE_T}

def test_win64():
    decl = """
    #ifdef _WIN64
    typedef long long Py_ssize_t;
    #else
    typedef long Py_ssize_t;
    #endif
    """
    cts = parse_source(decl)
    assert cts.definitions == {'Py_ssize_t': rffi.SIGNED}

def test_macro():
    decl = """
    typedef ssize_t Py_ssize_t;

    #define PyObject_HEAD  \
        Py_ssize_t ob_refcnt;        \
        Py_ssize_t ob_pypy_link;     \

    typedef struct {
        PyObject_HEAD
        double ob_fval;
    } PyFloatObject;
    """
    cts = parse_source(decl)
    assert 'PyFloatObject' in cts.definitions
    assert 'PyObject_HEAD' in cts.macros

def test_include():
    cdef1 = """
    typedef ssize_t Py_ssize_t;

    #define PyObject_HEAD  \
        Py_ssize_t ob_refcnt;        \
        Py_ssize_t ob_pypy_link;     \

    typedef struct {
        char *name;
    } Type;
    """
    cdef2 = """
    typedef struct {
        PyObject_HEAD
        Py_ssize_t ob_foo;
        Type *type;
    } Object;
    """
    cts1 = parse_source(cdef1)
    Type = cts1.definitions['Type']
    assert isinstance(Type, lltype.Struct)
    cts2 = parse_source(cdef2, includes=[cts1])
    assert 'Type' not in cts2.definitions
    Object = cts2.definitions['Object']
    assert Object.c_type.TO is Type

def test_multiple_sources():
    cdef1 = """
    typedef ssize_t Py_ssize_t;

    #define PyObject_HEAD  \
        Py_ssize_t ob_refcnt;        \
        Py_ssize_t ob_pypy_link;     \

    typedef struct {
        char *name;
    } Type;
    """
    cdef2 = """
    typedef struct {
        PyObject_HEAD
        Py_ssize_t ob_foo;
        Type *type;
    } Object;
    """
    cts = CTypeSpace()
    cts.parse_source(cdef1)
    Type = cts.definitions['Type']
    assert isinstance(Type, lltype.Struct)
    assert 'Object' not in cts.definitions
    cts.parse_source(cdef2)
    Object = cts.definitions['Object']
    assert Object.c_type.TO is Type

def test_incomplete():
    cdef = """
    typedef ssize_t Py_ssize_t;

    typedef struct {
        Py_ssize_t ob_refcnt;
        Py_ssize_t ob_pypy_link;
        struct _typeobject *ob_type;
    } Object;

    typedef struct {
        void *buf;
        Object *obj;
    } Buffer;

    """
    cts = CTypeSpace()
    cts.parse_source(cdef, configure=False)
    with pytest.raises(ValueError):
        cts.configure_types()

def test_incomplete_struct():
    cdef = """
    typedef struct s *ptr;
    struct s {void* x;};
    """
    cts = parse_source(cdef)
    PTR = cts.gettype("ptr")
    assert isinstance(PTR.TO, lltype.Struct)
    hash(PTR)

def test_recursive():
    cdef = """
    typedef ssize_t Py_ssize_t;

    typedef struct {
        Py_ssize_t ob_refcnt;
        Py_ssize_t ob_pypy_link;
        struct _typeobject *ob_type;
    } Object;

    typedef struct {
        void *buf;
        Object *obj;
    } Buffer;

    typedef struct _typeobject {
        Object *obj;
    } Type;
    """
    cts = parse_source(cdef)
    Object = cts.definitions['Object']
    assert isinstance(Object, lltype.Struct)
    hash(Object)

def test_nested_struct():
    cdef = """
    typedef struct {
        int x;
    } foo;
    typedef struct {
        foo y;
    } bar;
    """
    cts = parse_source(cdef)
    bar = cts.gettype('bar')
    assert isinstance(bar, lltype.Struct)
    hash(bar)  # bar is hashable

def test_nested_struct_2():
    cdef = """
    typedef struct _object {
        int ob_refcnt;
        struct _typeobject *ob_type;
    } PyObject;

    typedef struct  _varobject {
        PyObject ob_base;
        int ob_size;
    } PyVarObject;

    typedef struct _typeobject {
        PyVarObject ob_base;
    } PyTypeObject;
    """
    cts = parse_source(cdef)
    bar = cts.gettype('PyTypeObject')
    assert isinstance(bar, lltype.Struct)
    hash(bar)  # bar is hashable

def test_named_struct():
    cdef = """
    struct foo {
        int x;
    };
    """
    cts = parse_source(cdef)
    foo = cts.gettype('struct foo')
    assert isinstance(foo, lltype.Struct)
    hash(foo)

def test_const():
    cdef = """
    typedef struct {
        const char * const foo;
    } bar;
    """
    cts = parse_source(cdef)
    assert cts.definitions['bar'].c_foo == rffi.CONST_CCHARP != rffi.CCHARP

def test_enum():
    cdef = """
    typedef enum {
        mp_ass_subscript = 3,
        mp_length = 4,
        mp_subscript = 5,
    } Slot;
    """
    cts = parse_source(cdef)
    assert cts.gettype('Slot').mp_length == 4

def test_translate_enum():
    cdef = """
    typedef enum {
        mp_ass_subscript = 3,
        mp_length = 4,
        mp_subscript = 5,
    } Slot;
    """
    cts = parse_source(cdef)
    def f():
        return cts.gettype('Slot').mp_length
    graph = build_flow(f)
    simplify_graph(graph)
    # Check that the result is constant-folded
    assert graph.startblock.operations == []
    [link] = graph.startblock.exits
    assert link.target is graph.returnblock
    assert link.args[0] == const(4)

def test_gettype():
    decl = """
    typedef ssize_t Py_ssize_t;

    #define PyObject_HEAD  \
        Py_ssize_t ob_refcnt;        \
        Py_ssize_t ob_pypy_link;     \

    typedef struct {
        PyObject_HEAD
        double ob_fval;
    } TestFloatObject;
    """
    cts = parse_source(decl)
    assert cts.gettype('Py_ssize_t') == rffi.SSIZE_T
    assert cts.gettype('TestFloatObject *').TO.c_ob_refcnt == rffi.SSIZE_T
    assert cts.cast('Py_ssize_t', 42) == rffi.cast(rffi.SSIZE_T, 42)

def test_parse_funcdecl():
    decl = """
    typedef ssize_t Py_ssize_t;

    #define PyObject_HEAD  \
        Py_ssize_t ob_refcnt;        \
        Py_ssize_t ob_pypy_link;     \

    typedef struct {
        PyObject_HEAD
        double ob_fval;
    } TestFloatObject;

    typedef TestFloatObject* (*func_t)(int, int);
    """
    cts = parse_source(decl)
    func_decl = cts.parse_func("func_t * some_func(TestFloatObject*)")
    assert func_decl.name == 'some_func'
    assert func_decl.get_llresult(cts) == cts.gettype('func_t*')
    assert func_decl.get_llargs(cts) == [cts.gettype('TestFloatObject *')]

def test_struct_in_func_args():
    decl = """
    typedef struct {int x;} obj;
    typedef int (*func)(obj x);
    """
    cts = parse_source(decl)
    OBJ = cts.gettype('obj')
    FUNCPTR = cts.gettype('func')
    assert FUNCPTR.TO.ARGS == (OBJ,)

def test_wchar_t():
    cdef = """
    typedef struct { wchar_t* x; } test;
    """
    cts = parse_source(cdef, headers=['stddef.h'])
    obj = lltype.malloc(cts.gettype('test'), flavor='raw')
    obj.c_x = cts.cast('wchar_t*', 0)
    obj.c_x = lltype.nullptr(rffi.CWCHARP.TO)
    lltype.free(obj, flavor='raw')

def test_translate_cast():
    cdef = "typedef ssize_t Py_ssize_t;"
    cts = parse_source(cdef)

    def f():
        return cts.cast('Py_ssize_t*', 0)
    graph = build_flow(f)
    simplify_graph(graph)
    assert len(graph.startblock.operations) == 1
    op = graph.startblock.operations[0]
    assert op.args[0] == const(rffi.cast)
    assert op.args[1].value is cts.gettype('Py_ssize_t*')

def test_translate_gettype():
    cdef = "typedef ssize_t Py_ssize_t;"
    cts = parse_source(cdef)

    def f():
        return cts.gettype('Py_ssize_t*')
    graph = build_flow(f)
    simplify_graph(graph)
    # Check that the result is constant-folded
    assert graph.startblock.operations == []
    [link] = graph.startblock.exits
    assert link.target is graph.returnblock
    assert link.args[0] == const(rffi.CArrayPtr(rffi.SSIZE_T))
