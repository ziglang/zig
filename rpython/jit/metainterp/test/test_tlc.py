import py

from rpython.jit.tl import tlc

from rpython.jit.metainterp.test.support import LLJitMixin


class TLCTests:

    def _get_interp(self, bytecode, pool):
        codes = [bytecode, '']
        pools = [pool, None]
        def interp(i, inputarg):
            args = [tlc.IntObj(inputarg)]
            obj = tlc.interp_eval(codes[i], 0, args, pools[i])
            return obj.int_o()
        return interp

    def exec_code(self, src, inputarg):
        pool = tlc.ConstantPool()
        bytecode = tlc.compile(src, pool)
        interp = self._get_interp(bytecode, pool)
        return self.meta_interp(interp, [0, inputarg])

    def test_method(self):
        code = """
            NEW foo,meth=meth
            PICK 0
            PUSHARG
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
        """
        res = self.exec_code(code, 40)
        assert res == 42

    def test_accumulator(self):
        py.test.skip("buggy interpreter")
        path = py.path.local(tlc.__file__).dirpath('accumulator.tlc.src')
        code = path.read()
        res = self.exec_code(code, 20)
        assert res == sum(range(20))
        res = self.exec_code(code, -10)
        assert res == 10


class TestLLtype(TLCTests, LLJitMixin):
    pass
