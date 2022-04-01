import py
from rpython.jit.tl.tlopcode import compile, NEW, RETURN
from rpython.jit.tl.test import test_tl
from rpython.jit.tl.tlc import ConstantPool
    
def test_constant_pool():
    pool = ConstantPool()
    bytecode = compile("""
        NEW foo,bar,meth=f
      f:
        RETURN
    """, pool)
    expected = test_tl.list2bytecode([NEW, 0, RETURN])
    assert expected == bytecode
    assert len(pool.classdescrs) == 1
    descr = pool.classdescrs[0]
    assert descr.attributes == ['foo', 'bar']
    assert descr.methods == [('meth', 2)]

def test_serialization():
    from rpython.jit.tl.tlopcode import serialize_program, decode_program
    pool = ConstantPool()
    bytecode = compile("""
        NEW foo,bar,meth=f
        SETATTR foobar
      f:
        RETURN
    """, pool)
    s = serialize_program(bytecode, pool)
    bytecode2, pool2 = decode_program(s)
    assert bytecode == bytecode2
    assert pool == pool2

class TestTLC(object):
    @staticmethod
    def interp(code='', pc=0, inputarg=0):
        from rpython.jit.tl.tlc import interp
        return interp(code, pc, inputarg)

    def test_unconditional_branch(self):
        bytecode = compile("""
    main:
        BR target
        PUSH 123
        RETURN
    target:
        PUSH 42
        RETURN
    """)
        res = self.interp(bytecode, 0, 0)
        assert res == 42

    def test_basic_cons_cell(self):
        bytecode = compile("""
            NIL
            PUSHARG
            CONS
            PUSH 1
            CONS
            CDR
            CAR
        """)

        res = self.interp(bytecode, 0, 42)
        assert res == 42

    def test_nth(self):
        bytecode = compile("""
            NIL
            PUSH 4
            CONS
            PUSH 2
            CONS
            PUSH 1
            CONS
            PUSHARG
            DIV
        """)

        res = self.interp(bytecode, 0, 0)
        assert res == 1
        res = self.interp(bytecode, 0, 1)
        assert res == 2
        res = self.interp(bytecode, 0, 2)
        assert res == 4

        py.test.raises(IndexError, self.interp, bytecode, 0, 3)
            
    def test_concat(self):
        bytecode = compile("""
            NIL
            PUSH 4
            CONS
            PUSH 2
            CONS
            NIL
            PUSH 5
            CONS
            PUSH 3
            CONS
            PUSH 1
            CONS
            ADD
            PUSHARG
            DIV
        """)

        for i, n in enumerate([2, 4, 1, 3, 5]):
            res = self.interp(bytecode, 0, i)
            assert res == n

    def test_concat_errors(self):
        bytecode = compile("""
            NIL
            PUSH 4
            ADD
        """)
        py.test.raises(TypeError, self.interp, bytecode, 0, 0)

        bytecode = compile("""
            PUSH 4
            NIL
            ADD
        """)
        py.test.raises(TypeError, self.interp, bytecode, 0, 0)


        bytecode = compile("""
            NIL
            PUSH 1
            CONS
            PUSH 4
            ADD
        """)
        py.test.raises(TypeError, self.interp, bytecode, 0, 0)

        bytecode = compile("""
            PUSH 4
            NIL
            PUSH 1
            CONS
            ADD
        """)
        py.test.raises(TypeError, self.interp, bytecode, 0, 0)


        bytecode = compile("""
            PUSH 2
            PUSH 1
            CONS
            NIL
            ADD
        """)
        py.test.raises(TypeError, self.interp, bytecode, 0, 0)

    def test_new_obj(self):
        from rpython.jit.tl.tlc import interp_eval, InstanceObj, nil
        pool = ConstantPool()
        bytecode = compile("""
            NEW foo,bar
        """, pool)
        obj = interp_eval(bytecode, 0, [nil], pool)
        assert isinstance(obj, InstanceObj)
        assert len(obj.values) == 2
        assert sorted(obj.cls.attributes.keys()) == ['bar', 'foo']

    def test_setattr(self):
        from rpython.jit.tl.tlc import interp_eval, nil
        pool = ConstantPool()
        bytecode = compile("""
            NEW foo,bar
            PICK 0
            PUSH 42
            SETATTR foo
        """, pool)
        obj = interp_eval(bytecode, 0, [nil], pool)
        assert obj.values[0].int_o() == 42
        assert obj.values[1] is nil

    def test_getattr(self):
        from rpython.jit.tl.tlc import interp_eval, nil
        pool = ConstantPool()
        bytecode = compile("""
            NEW foo,bar
            PICK 0
            PUSH 42
            SETATTR bar
            GETATTR bar
        """, pool)
        res = interp_eval(bytecode, 0, [nil], pool)
        assert res.int_o() == 42

    def test_obj_truth(self):
        from rpython.jit.tl.tlc import interp_eval, nil
        pool = ConstantPool()
        bytecode = compile("""
            NEW foo,bar
            BR_COND true
            PUSH 12
            PUSH 1
            BR_COND exit
        true:
            PUSH 42
        exit:
            RETURN
        """, pool)
        res = interp_eval(bytecode, 0, [nil], pool)
        assert res.int_o() == 42

    def test_obj_equality(self):
        from rpython.jit.tl.tlc import interp_eval, nil
        pool = ConstantPool()
        bytecode = compile("""
            NEW foo,bar
            NEW foo,bar
            EQ
        """, pool)
        res = interp_eval(bytecode, 0, [nil], pool)
        assert res.int_o() == 0

    def test_method(self):
        from rpython.jit.tl.tlc import interp_eval, nil
        pool = ConstantPool()
        bytecode = compile("""
            NEW foo,meth=meth
            PICK 0
            PUSH 42
            SETATTR foo
            SEND meth/0
            RETURN
        meth:
            PUSHARG
            GETATTR foo
            RETURN
        """, pool)
        res = interp_eval(bytecode, 0, [nil], pool)
        assert res.int_o() == 42

    def test_method_arg(self):
        from rpython.jit.tl.tlc import interp_eval, nil
        pool = ConstantPool()
        bytecode = compile("""
            NEW foo,meth=meth
            PICK 0
            PUSH 40
            SETATTR foo
            PUSH 2
            SEND meth/1
            RETURN
        meth:
            PUSHARG
            GETATTR foo
            PUSHARGN 1
            ADD
            RETURN
        """, pool)
        res = interp_eval(bytecode, 0, [nil], pool)
        assert res.int_o() == 42

    def test_call_without_return_value(self):
        from rpython.jit.tl.tlc import interp_eval, nil
        pool = ConstantPool()
        bytecode = compile("""
            CALL foo
            PUSH 42
            RETURN
        foo:
            RETURN
        """, pool)
        res = interp_eval(bytecode, 0, [nil], pool)
        assert res.int_o() == 42

    def compile(self, filename):
        from rpython.jit.tl.tlc import interp_eval, IntObj
        pool = ConstantPool()
        path = py.path.local(__file__).join(filename)
        src = path.read()
        bytecode = compile(src, pool)
        def fn(n):
            obj = IntObj(n)
            res = interp_eval(bytecode, 0, [obj], pool)
            return res.int_o()
        return fn

    def test_binarytree(self):
        search = self.compile('../../binarytree.tlc.src')
        assert search(20)
        assert search(10)
        assert search(15)
        assert search(30)
        assert not search(1)
        assert not search(40)
        assert not search(12)
        assert not search(27)

    def test_fibo(self):
        fibo = self.compile('../../fibo.tlc.src')
        assert fibo(1) == 1
        assert fibo(2) == 1
        assert fibo(3) == 2
        assert fibo(7) == 13

    def test_accumulator(self):
        acc = self.compile('../../accumulator.tlc.src')
        assert acc(0) == 0
        assert acc(1) == 0
        assert acc(10) == sum(range(10))
        assert acc(20) == sum(range(20))
        assert acc(-1) == 1
        assert acc(-2) == 2
        assert acc(-10) == 10
