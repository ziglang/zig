import py, sys, zlib, re
from pypy.tool import gdb_pypy

class FakeGdb(object):

    COMMAND_NONE = -1
    #
    TYPE_CODE_PTR = 1
    TYPE_CODE_ARRAY = 2
    TYPE_CODE_STRUCT = 3

    def __init__(self, typeids, exprs):
        self.typeids_z = zlib.compress(typeids)
        exprs['*(long*)pypy_g_rpython_memory_gctypelayout_GCData'
              '.gcd_inst_typeids_z'] = len(self.typeids_z)
        self.exprs = exprs
        self._parsed = []

    def parse_and_eval(self, expr):
        self._parsed.append(expr)
        return self.exprs[expr]

    def execute(self, command):
        r = re.compile(r"dump binary memory (\S+) (\S+) (\S+)$")
        match = r.match(command)
        assert match
        fn, start, stop = match.groups()
        assert start == (
            '(char*)(((long*)pypy_g_rpython_memory_gctypelayout_GCData'
            '.gcd_inst_typeids_z)+1)')
        assert stop == (
            '(char*)(((long*)pypy_g_rpython_memory_gctypelayout_GCData'
            '.gcd_inst_typeids_z)+1)+%d' % (len(self.typeids_z),))
        with open(fn, 'wb') as f:
            f.write(self.typeids_z)


class Mock(object):
    def __init__(self, **attrs):
        self.__dict__.update(attrs)

class Field(Mock):
    pass

class Struct(object):
    code = FakeGdb.TYPE_CODE_STRUCT

    def __init__(self, fieldnames, tag):
        self._fields = [Field(name=name) for name in fieldnames]
        self.tag = tag

    def fields(self):
        return self._fields[:]

class Pointer(object):
    code = FakeGdb.TYPE_CODE_PTR

    def __init__(self, target):
        self._target = target

    def target(self):
        return self._target

class Value(dict):
    def __init__(self, *args, **kwds):
        type_tag = kwds.pop('type_tag', None)
        dict.__init__(self, *args, **kwds)
        self.type = Struct(self.keys(), type_tag)
        for key, val in self.iteritems():
            if isinstance(val, dict):
                self[key] = Value(val)

class PtrValue(Value):
    def __init__(self, *args, **kwds):
        # in python gdb, we can use [] to access fields either if we have an
        # actual struct or a pointer to it, so we just reuse Value here
        Value.__init__(self, *args, **kwds)
        self.type = Pointer(self.type)

def test_mock_objects():
    d = {'a': 1,
         'b': 2,
         'super': {
            'c': 3,
            }
         }
    val = Value(d)
    assert val['a'] == 1
    assert val['b'] == 2
    assert isinstance(val['super'], Value)
    assert val['super']['c'] == 3
    fields = val.type.fields()
    names = [f.name for f in fields]
    assert sorted(names) == ['a', 'b', 'super']

def test_find_field_with_suffix():
    obj = Value(x_foo = 1,
                y_bar = 2,
                z_foobar = 3)
    assert gdb_pypy.find_field_with_suffix(obj, 'foo') == 1
    assert gdb_pypy.find_field_with_suffix(obj, 'foobar') == 3
    py.test.raises(KeyError, "gdb_pypy.find_field_with_suffix(obj, 'bar')")
    py.test.raises(KeyError, "gdb_pypy.find_field_with_suffix(obj, 'xxx')")

def test_lookup():
    d = {'r_super': {
            '_gcheader': {
                'h_tid': 123,
                }
            },
         'r_foo': 42,
         }
    obj = Value(d)
    assert gdb_pypy.lookup(obj, 'foo') == 42
    hdr = gdb_pypy.lookup(obj, 'gcheader')
    assert hdr['h_tid'] == 123

def exprmember(n):
    if sys.maxint < 2**32:
        TIDT = "int*"
    else:
        TIDT = "char*"
    return ('((%s)(&pypy_g_typeinfo.member%d)) - (%s)&pypy_g_typeinfo'
            % (TIDT, n, TIDT))

def test_load_typeids(tmpdir):
    typeids = """
member0    ?
member1    GcStruct xxx {}
""".lstrip()
    exprs = {exprmember(1): 111}
    gdb = FakeGdb(typeids, exprs)
    cmd = gdb_pypy.RPyType(gdb)
    typeids = cmd.load_typeids()
    assert typeids[0] == '(null typeid)'
    assert typeids[111] == 'GcStruct xxx {}'
    py.test.raises(KeyError, "typeids[50]")
    py.test.raises(KeyError, "typeids[150]")

def test_RPyType(tmpdir):
    typeids = """
member0    ?
member1    GcStruct xxx {}
member2    GcStruct yyy {}
member3    GcStruct zzz {}
""".lstrip()
    #
    d = {'r_super': {
            '_gcheader': {
                'h_tid': 123,
                }
            },
         'r_foo': 42,
         }
    myvar = Value(d)
    exprs = {
        '*myvar': myvar,
        exprmember(1): 0,
        exprmember(2): 123,
        exprmember(3): 456,
        }
    gdb = FakeGdb(typeids, exprs)
    cmd = gdb_pypy.RPyType(gdb)
    assert cmd.do_invoke('*myvar', True) == 'GcStruct yyy {}'

def test_pprint_string(monkeypatch):
    d = {'_gcheader': {
            'h_tid': 123
            },
         'rs_hash': 456,
         'rs_chars': {
            'length': 6,
            'items': map(ord, 'foobar'),
            }
         }
    p_string = PtrValue(d, type_tag='pypy_rpy_string0')
    printer = gdb_pypy.RPyStringPrinter.lookup(p_string, FakeGdb)
    assert printer.to_string() == "r'foobar'"
    monkeypatch.setattr(gdb_pypy, 'MAX_DISPLAY_LENGTH', 5)
    assert printer.to_string() == "r'fooba...'"

def test_pprint_list():
    d = {'_gcheader': {
            'h_tid': 123
            },
         'l_length': 3, # the lenght of the rpython list
         'l_items':
             # this is the array which contains the items
             {'_gcheader': {
                'h_tid': 456
                },
              'length': 5, # the lenght of the underlying array
              'items': [40, 41, 42, -1, -2],
              }
         }
    mylist = PtrValue(d, type_tag='pypy_list0')
    printer = gdb_pypy.RPyListPrinter.lookup(mylist, FakeGdb)
    assert printer.to_string() == 'r[40, 41, 42] (len=3, alloc=5)'
    #
    mylist.type.target().tag = 'pypy_list1234'
    printer = gdb_pypy.RPyListPrinter.lookup(mylist, FakeGdb)
    assert printer.to_string() == 'r[40, 41, 42] (len=3, alloc=5)'

    mylist.type.target().tag = None
    assert gdb_pypy.RPyListPrinter.lookup(mylist, FakeGdb) is None

def test_pprint_array():
    d = {'_gcheder': {'h_tid': 234}, 'length': 3, 'items': [20, 21, 22]}
    mylist = PtrValue(d, type_tag='pypy_array1')
    printer = gdb_pypy.RPyListPrinter.lookup(mylist, FakeGdb)
    assert printer.to_string() == 'r[20, 21, 22] (len=3)'

def test_pprint_null_list():
    mylist = PtrValue({}, type_tag='pypy_list1')
    printer = gdb_pypy.RPyListPrinter.lookup(mylist, FakeGdb)
    assert printer.to_string() == 'r(null_list)'

def test_pprint_null_array():
    mylist = PtrValue({}, type_tag='pypy_array1')
    printer = gdb_pypy.RPyListPrinter.lookup(mylist, FakeGdb)
    assert printer.to_string() == 'r(null_array)'

def test_typeidsmap():
    gdb = FakeGdb('', {exprmember(1): 111,
                       exprmember(2): 222,
                       exprmember(3): 333})
    typeids = gdb_pypy.TypeIdsMap(["member0  ?\n",
                                   "member1  FooBar\n",
                                   "member2  Baz\n",
                                   "member3  Bok\n"], gdb)
    assert gdb._parsed == []
    assert typeids.get(111) == "FooBar"
    assert gdb._parsed == [exprmember(2), exprmember(1)]
    assert typeids.get(222) == "Baz"
    assert gdb._parsed == [exprmember(2), exprmember(1)]
    assert typeids.get(333) == "Bok"
    assert gdb._parsed == [exprmember(2), exprmember(1), exprmember(3)]
    assert typeids.get(400) == None
    assert typeids.get(300) == None
    assert typeids.get(200) == None
    assert typeids.get(100) == None
