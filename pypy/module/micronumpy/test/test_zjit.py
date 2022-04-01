""" Tests that check if JIT-compiled numpy operations produce reasonably
good assembler
"""

import py
from rpython.jit.metainterp.test.support import LLJitMixin
from rpython.jit.backend.x86.test.test_basic import Jit386Mixin
from rpython.jit.metainterp.warmspot import reset_jit, get_stats
from rpython.jit.metainterp.jitprof import Profiler
from rpython.jit.metainterp import counter
from rpython.rlib.jit import Counters
from rpython.rlib.rarithmetic import intmask
from pypy.module.micronumpy import boxes
from pypy.module.micronumpy.compile import FakeSpace, Parser, InterpreterState
from pypy.module.micronumpy.base import W_NDimArray
from rpython.jit.backend.detect_cpu import getcpuclass

CPU = getcpuclass()
if not CPU.vector_ext:
    py.test.skip("this cpu %s has no implemented vector backend" % CPU)

def get_profiler():
    from rpython.jit.metainterp import pyjitpl
    return pyjitpl._warmrunnerdesc.metainterp_sd.profiler

class TestNumpyJit(LLJitMixin):
    enable_opts = "intbounds:rewrite:virtualize:string:earlyforce:pure:heap:unroll"
    graph = None
    interp = None

    def setup_method(self, method):
        if not self.CPUClass.vector_ext:
            py.test.skip("needs vector extension to run (for now)")

    def assert_float_equal(self, f1, f2, delta=0.0001):
        assert abs(f1-f2) < delta

    def setup_class(cls):
        default = """
        a = [1,2,3,4]
        z = (1, 2)
        c = a + b
        sum(c) -> 1::1
        a -> 3:1:2
        """

        d = {}
        p = Parser()
        allcodes = [p.parse(default)]
        for name, meth in cls.__dict__.iteritems():
            if name.startswith("define_"):
                code = meth()
                d[name[len("define_"):]] = len(allcodes)
                allcodes.append(p.parse(code))
        cls.code_mapping = d
        cls.codes = allcodes

    def compile_graph(self):
        if self.graph is not None:
            return
        space = FakeSpace()
        codes = self.codes

        def f(i):
            interp = InterpreterState(codes[i])
            interp.run(space)
            if not len(interp.results):
                raise Exception("need results")
            w_res = interp.results[-1]
            if isinstance(w_res, W_NDimArray):
                i, s = w_res.create_iter()
                w_res = i.getitem(s)
            if isinstance(w_res, boxes.W_Float64Box):
                return w_res.value
            if isinstance(w_res, boxes.W_Float32Box):
                return float(w_res.value)
            elif isinstance(w_res, boxes.W_Int64Box):
                return float(w_res.value)
            elif isinstance(w_res, boxes.W_Int32Box):
                return float(int(w_res.value))
            elif isinstance(w_res, boxes.W_Int16Box):
                return float(int(w_res.value))
            elif isinstance(w_res, boxes.W_Int8Box):
                return float(int(w_res.value))
            elif isinstance(w_res, boxes.W_UInt64Box):
                return float(intmask(w_res.value))
            elif isinstance(w_res, boxes.W_UInt32Box):
                return float(intmask(w_res.value))
            elif isinstance(w_res, boxes.W_UInt16Box):
                return float(intmask(w_res.value))
            elif isinstance(w_res, boxes.W_UInt8Box):
                return float(intmask(w_res.value))
            elif isinstance(w_res, boxes.W_LongBox):
                return float(w_res.value)
            elif isinstance(w_res, boxes.W_BoolBox):
                return float(w_res.value)
            print "ERROR: did not implement return type for interpreter"
            raise TypeError(w_res)

        if self.graph is None:
            interp, graph = self.meta_interp(f, [0],
                                             listops=True,
                                             listcomp=True,
                                             backendopt=True,
                                             graph_and_interp_only=True,
                                             ProfilerClass=Profiler,
                                             vec=True)
            self.__class__.interp = interp
            self.__class__.graph = graph

    def check_vectorized(self, expected_tried, expected_success):
        profiler = get_profiler()
        tried = profiler.get_counter(Counters.OPT_VECTORIZE_TRY)
        success = profiler.get_counter(Counters.OPT_VECTORIZED)
        assert tried >= success
        assert tried == expected_tried
        assert success == expected_success

    def run(self, name):
        self.compile_graph()
        profiler = get_profiler()
        profiler.start()
        reset_jit()
        i = self.code_mapping[name]
        retval = self.interp.eval_graph(self.graph, [i])
        return retval

    def define_float32_copy():
        return """
        a = astype(|30|, float32)
        x1 = a -> 7
        x2 = a -> 8
        x3 = a -> 9
        x4 = a -> 10
        r = x1 + x2 + x3 + x4
        r
        """
    def test_float32_copy(self):
        result = self.run("float32_copy")
        assert int(result) == 7+8+9+10
        self.check_vectorized(1, 1)

    def define_int32_copy():
        return """
        a = astype(|30|, int32)
        x1 = a -> 7
        x2 = a -> 8
        x3 = a -> 9
        x4 = a -> 10
        x1 + x2 + x3 + x4
        """
    def test_int32_copy(self):
        result = self.run("int32_copy")
        assert int(result) == 7+8+9+10
        self.check_vectorized(1, 1)

    def define_float32_add():
        return """
        a = astype(|30|, float32)
        b = a + a
        b -> 15
        """
    def test_float32_add(self):
        result = self.run("float32_add")
        self.assert_float_equal(result, 15.0 + 15.0)
        self.check_vectorized(2, 2)

    def define_float_add():
        return """
        a = |30|
        b = a + a
        b -> 17
        """
    def test_float_add(self):
        result = self.run("float_add")
        self.assert_float_equal(result, 17.0 + 17.0)
        self.check_vectorized(1, 1)

    def define_uint_add():
        return """
        a = astype(|30|, uint64)
        b = a + a
        b -> 17
        """
    def test_uint_add(self):
        result = self.run("uint_add")
        assert int(result) == 17+17
        self.check_vectorized(2, 1)

    def define_float32_add_const():
        return """
        a = astype(|30|, float32)
        b = a + 77.345
        b -> 29
        """
    def test_float32_add_const(self):
        result = self.run("float32_add_const")
        self.assert_float_equal(result, 29.0 + 77.345)
        self.check_vectorized(2, 2)

    def define_float_add_const():
        return """
        a = |30| + 25.5
        a -> 29
        """
    def test_float_add_const(self):
        result = self.run("float_add_const")
        self.assert_float_equal(result, 29.0 + 25.5)
        self.check_vectorized(1, 1)

    def define_int_add_const():
        return """
        a = astype(|30|, int)
        b = a + 1i
        d = astype(|30|, int)
        c = d + 2.0
        x1 = b -> 7
        x2 = b -> 8
        x3 = c -> 11
        x4 = c -> 12
        x1 + x2 + x3 + x4
        """
    def test_int_add_const(self):
        result = self.run("int_add_const")
        assert int(result) == 7+1+8+1+11+2+12+2
        self.check_vectorized(2, 2)

    def define_int_expand():
        return """
        a = astype(|30|, int)
        c = astype(|1|, int)
        c[0] = 16
        b = a + c
        x1 = b -> 7
        x2 = b -> 8
        x1 + x2
        """
    def test_int_expand(self):
        result = self.run("int_expand")
        assert int(result) == 7+16+8+16
        self.check_vectorized(2, 2)

    def define_int32_expand():
        return """
        a = astype(|30|, int32)
        c = astype(|1|, int32)
        c[0] = 16i
        b = a + c
        x1 = b -> 7
        x2 = b -> 8
        x1 + x2
        """
    def test_int32_expand(self):
        result = self.run("int32_expand")
        assert int(result) == 7+16+8+16
        self.check_vectorized(2, 1)

    def define_int16_expand():
        return """
        a = astype(|30|, int16)
        c = astype(|1|, int16)
        c[0] = 16i
        b = a + c
        d = b -> 7:15
        sum(d)
        """
    def test_int16_expand(self):
        result = self.run("int16_expand")
        i = 8
        assert int(result) == i*16 + sum(range(7,7+i))
        # currently is is not possible to accum for types with < 8 bytes
        self.check_vectorized(3, 0)

    def define_int8_expand():
        return """
        a = astype(|30|, int8)
        c = astype(|1|, int8)
        c[0] = 8i
        b = a + c
        d = b -> 0:17
        sum(d)
        """
    def test_int8_expand(self):
        result = self.run("int8_expand")
        assert int(result) == 17*8 + sum(range(0,17))
        # does not pay off to cast float64 -> int8
        # neither does sum
        # a + c should work, but it is given as a parameter
        # thus the accum must handle this!
        self.check_vectorized(3, 0)

    def define_int32_add_const():
        return """
        a = astype(|30|, int32)
        b = a + 1i
        d = astype(|30|, int32)
        c = d + 2.0
        x1 = b -> 7
        x2 = b -> 8
        x3 = c -> 11
        x4 = c -> 12
        x1 + x2 + x3 + x4
        """
    def test_int32_add_const(self):
        result = self.run("int32_add_const")
        assert int(result) == 7+1+8+1+11+2+12+2
        self.check_vectorized(2, 2)

    def define_float_mul_array():
        return """
        a = astype(|30|, float)
        b = astype(|30|, float)
        c = a * b
        x1 = c -> 7
        x2 = c -> 8
        x3 = c -> 11
        x4 = c -> 12
        x1 + x2 + x3 + x4
        """
    def test_float_mul_array(self):
        result = self.run("float_mul_array")
        assert int(result) == 7*7+8*8+11*11+12*12
        self.check_vectorized(2, 2)

    def define_int32_mul_array():
        return """
        a = astype(|30|, int32)
        b = astype(|30|, int32)
        c = a * b
        x1 = c -> 7
        x2 = c -> 8
        x3 = c -> 11
        x4 = c -> 12
        x1 + x2 + x3 + x4
        """
    def test_int32_mul_array(self):
        result = self.run("int32_mul_array")
        assert int(result) == 7*7+8*8+11*11+12*12
        self.check_vectorized(2, 2)

    def define_float32_mul_array():
        return """
        a = astype(|30|, float32)
        b = astype(|30|, float32)
        c = a * b
        x1 = c -> 7
        x2 = c -> 8
        x3 = c -> 11
        x4 = c -> 12
        x1 + x2 + x3 + x4
        """
    def test_float32_mul_array(self):
        result = self.run("float32_mul_array")
        assert int(result) == 7*7+8*8+11*11+12*12
        self.check_vectorized(2, 2)

    def define_conversion():
        return """
        a = astype(|30|, int8)
        b = astype(|30|, int)
        c = a + b
        sum(c)
        """
    def test_conversion(self):
        result = self.run("conversion")
        assert result == sum(range(30)) + sum(range(30))
        self.check_vectorized(4, 2) # only sum and astype(int) succeed

    def define_sum():
        return """
        a = |30|
        sum(a)
        """
    def test_sum(self):
        result = self.run("sum")
        assert result == sum(range(30))
        self.check_vectorized(1, 0)

    def define_sum_int():
        return """
        a = astype(|65|,int)
        sum(a)
        """
    def test_sum_int(self):
        result = self.run("sum_int")
        assert result == sum(range(65))
        self.check_vectorized(2, 2)

    def define_sum_multi():
        return """
        a = |30|
        b = sum(a)
        c = |60|
        d = sum(c)
        b + d
        """

    def test_sum_multi(self):
        result = self.run("sum_multi")
        assert result == sum(range(30)) + sum(range(60))
        self.check_vectorized(1, 0)

    def define_sum_float_to_int16():
        return """
        a = |30|
        sum(a,int16)
        """
    def test_sum_float_to_int16(self):
        result = self.run("sum_float_to_int16")
        assert result == sum(range(30))

    def define_sum_float_to_int32():
        return """
        a = |30|
        sum(a,int32)
        """
    def test_sum_float_to_int32(self):
        result = self.run("sum_float_to_int32")
        assert result == sum(range(30))

    def define_sum_float_to_float32():
        return """
        a = |30|
        sum(a,float32)
        """
    def test_sum_float_to_float32(self):
        result = self.run("sum_float_to_float32")
        assert result == sum(range(30))
        self.check_vectorized(1, 1)

    def define_sum_float_to_uint64():
        return """
        a = |30|
        sum(a,uint64)
        """
    def test_sum_float_to_uint64(self):
        result = self.run("sum_float_to_uint64")
        assert result == sum(range(30))
        self.check_vectorized(1, 0) # unsigned

    def define_cumsum():
        return """
        a = |30|
        b = cumsum(a)
        b -> 5
        """

    def test_cumsum(self):
        result = self.run("cumsum")
        assert result == 15

    def define_axissum():
        return """
        a = [[1, 2], [3, 4], [5, 6], [7, 8], [9, 10]]
        b = sum(a,0)
        b -> 1
        """

    def test_axissum(self):
        result = self.run("axissum")
        assert result == 30
        # XXX note - the bridge here is fairly crucial and yet it's pretty
        #            bogus. We need to improve the situation somehow.
        self.check_vectorized(1, 0)

    def define_reduce():
        return """
        a = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        sum(a)
        """

    def test_reduce_compile_only_once(self):
        self.compile_graph()
        reset_jit()
        i = self.code_mapping['reduce']
        # run it twice
        retval = self.interp.eval_graph(self.graph, [i])
        assert retval == sum(range(1,11))
        retval = self.interp.eval_graph(self.graph, [i])
        assert retval == sum(range(1,11))
        # check that we got only one loop
        assert len(get_stats().loops) == 1
        self.check_vectorized(2, 0)

    def test_reduce_axis_compile_only_once(self):
        self.compile_graph()
        reset_jit()
        i = self.code_mapping['axissum']
        # run it twice
        retval = self.interp.eval_graph(self.graph, [i])
        retval = self.interp.eval_graph(self.graph, [i])
        # check that we got only one loop
        assert len(get_stats().loops) == 1
        self.check_vectorized(3, 0)

    def define_prod():
        return """
        a = [1,2,3,4,1,2,3,4]
        prod(a)
        """

    def define_prod_zero():
        return """
        a = [1,2,3,4,1,2,3,0]
        prod(a)
        """

    def test_prod(self):
        result = self.run("prod")
        assert int(result) == 576

    def test_prod_zero(self):
        result = self.run("prod_zero")
        assert int(result) == 0


    def define_max():
        return """
        a = |30|
        a[13] = 128.0
        max(a)
        """

    def test_max(self):
        result = self.run("max")
        assert result == 128
        self.check_vectorized(1, 0)

    def define_min():
        return """
        a = |30|
        a[13] = -128
        min(a)
        """

    def test_min(self):
        result = self.run("min")
        assert result == -128
        self.check_vectorized(1, 0)

    def define_any():
        return """
        a = astype([0,0,0,0,0,0,0,1,0,0,0],int8)
        any(a)
        """

    def define_any_int():
        return """
        a = astype([0,0,0,0,256,0,0,0,0,0,0],int16)
        any(a)
        """

    def define_any_ret_0():
        return """
        a = astype([0,0,0,0,0,0,0,0,0,0,0],int64)
        any(a)
        """

    def define_float_any():
        return """
        a = [0,0,0,0,0,0,0,0.1,0,0,0]
        any(a)
        """

    def define_float32_any():
        return """
        a = astype([0,0,0,0,0,0,0,0.1,0,0,0], float32)
        any(a)
        """

    def test_any_float(self):
        result = self.run("float_any")
        assert int(result) == 1
        self.check_vectorized(1, 1)

    def test_any_float32(self):
        result = self.run("float32_any")
        assert int(result) == 1
        self.check_vectorized(2, 2)

    def test_any(self):
        result = self.run("any")
        assert int(result) == 1
        self.check_vectorized(2, 1)

    def test_any_int(self):
        result = self.run("any_int")
        assert int(result) == 1
        self.check_vectorized(2, 1)

    def test_any_ret_0(self):
        result = self.run("any_ret_0")
        assert int(result) == 0
        self.check_vectorized(2, 2)

    def define_all():
        return """
        a = astype([1,1,1,1,1,1,1,1],int32)
        all(a)
        """
    def define_all_int():
        return """
        a = astype([1,100,255,1,3,1,1,1],int32)
        all(a)
        """
    def define_all_ret_0():
        return """
        a = astype([1,1,1,1,1,0,1,1],int32)
        all(a)
        """
    def define_float_all():
        return """
        a = [1,1,1,1,1,1,1,1]
        all(a)
        """
    def define_float32_all():
        return """
        a = astype([1,1,1,1,1,1,1,1],float32)
        all(a)
        """

    def test_all_float(self):
        result = self.run("float_all")
        assert int(result) == 1
        self.check_vectorized(1, 1)

    def test_all_float32(self):
        result = self.run("float32_all")
        assert int(result) == 1
        self.check_vectorized(2, 2)

    def test_all(self):
        result = self.run("all")
        assert int(result) == 1
        self.check_vectorized(2, 2)

    def test_all_int(self):
        result = self.run("all_int")
        assert int(result) == 1
        self.check_vectorized(2, 2)

    def test_all_ret_0(self):
        result = self.run("all_ret_0")
        assert int(result) == 0
        self.check_vectorized(2, 2)

    def define_logical_xor_reduce():
        return """
        a = [1,1,1,1,1,1,1,1]
        logical_xor_reduce(a)
        """

    def test_logical_xor_reduce(self):
        result = self.run("logical_xor_reduce")
        assert result == 0
        self.check_vectorized(0, 0) # TODO reduce

    def define_already_forced():
        return """
        a = |30|
        b = a + 4.5
        b -> 5 # forces
        c = b * 8
        c -> 5
        """

    def test_already_forced(self):
        result = self.run("already_forced")
        assert result == (5 + 4.5) * 8
        self.check_vectorized(2, 2)

    def define_ufunc():
        return """
        a = |30|
        b = unegative(a)
        b -> 3
        """

    def test_ufunc(self):
        result = self.run("ufunc")
        assert result == -3
        self.check_vectorized(1, 1)

    def define_specialization():
        return """
        a = |30|
        b = a + a
        c = unegative(b)
        c -> 3
        d = a * a
        unegative(d)
        d -> 3
        d = a * a
        unegative(d)
        d -> 3
        d = a * a
        unegative(d)
        d -> 3
        d = a * a
        unegative(d)
        d -> 3
        """

    def test_specialization(self):
        result = self.run("specialization")
        assert result == (3*3)
        self.check_vectorized(3, 3)

    def define_multidim():
        return """
        a = [[1, 2], [3, 4], [5, 6], [7, 8], [9, 10]]
        b = a + a
        b -> 1 -> 1
        """

    def test_multidim(self):
        result = self.run('multidim')
        assert result == 8
        self.check_vectorized(1, 1)

    def define_broadcast():
        return """
        a = [[1, 2, 3, 4], [5, 6, 7, 8], [9, 10, 11, 12]]
        b = [1, 2, 3, 4]
        c = a + b
        c -> 1 -> 2
        """

    def test_broadcast(self):
        result = self.run("broadcast")
        assert result == 10
        self.check_vectorized(1, 0) # TODO check on broadcast

    def define_setslice():
        return """
        a = |30|
        b = |10|
        b[1] = 5.5
        a[0:30:3] = b
        a -> 3
        """

    def test_setslice(self):
        result = self.run("setslice")
        assert result == 5.5
        self.check_vectorized(1, 1)

    def define_virtual_slice():
        return """
        a = |30|
        c = a + a
        d = c -> 1:20
        d -> 1
        """

    def test_virtual_slice(self):
        result = self.run("virtual_slice")
        assert result == 4
        self.check_vectorized(1, 1)

    def define_flat_iter():
        return '''
        a = |30|
        b = flat(a)
        c = b + a
        c -> 3
        '''

    def test_flat_iter(self):
        result = self.run("flat_iter")
        assert result == 6
        self.check_vectorized(1, 1)

    def define_flat_getitem():
        return '''
        a = |30|
        b = flat(a)
        b -> 4: -> 6
        '''

    def test_flat_getitem(self):
        result = self.run("flat_getitem")
        assert result == 10.0
        self.check_vectorized(1,1)

    def define_flat_setitem():
        return '''
        a = |30|
        b = flat(a)
        b[4:] = a->:26
        a -> 5
        '''

    def test_flat_setitem(self):
        result = self.run("flat_setitem")
        assert result == 1.0
        self.check_vectorized(1,0) # TODO this can be improved

    def define_dot():
        return """
        a = [[1, 2, 3, 4], [5, 6, 7, 8], [9, 10, 11, 12]]
        b = [[0, 1, 2], [3, 4, 5], [6, 7, 8], [9, 10, 11]]
        c = dot(a, b)
        c -> 1 -> 2
        """

    def test_dot(self):
        result = self.run("dot")
        assert result == 184
        self.check_trace_count(4)
        self.check_vectorized(1,1)

    def define_argsort():
        return """
        a = |30|
        argsort(a)
        a->6
        """

    def test_argsort(self):
        result = self.run("argsort")
        assert result == 6
        self.check_vectorized(1,1) # vec. setslice

    def define_where():
        return """
        a = [1, 0, 1, 0]
        x = [1, 2, 3, 4]
        y = [-10, -20, -30, -40]
        r = where(a, x, y)
        r -> 3
        """

    def test_where(self):
        result = self.run("where")
        assert result == -40

    def define_searchsorted():
        return """
        a = [1, 4, 5, 6, 9]
        b = |30| -> ::-1
        c = searchsorted(a, b)
        c -> -1
        """

    def test_searchsorted(self):
        result = self.run("searchsorted")
        assert result == 0
        self.check_trace_count(6)

    def define_int_mul_array():
        return """
        a = astype(|30|, int32)
        b = astype(|30|, int32)
        c = a * b
        x1 = c -> 7
        x2 = c -> 8
        x3 = c -> 11
        x4 = c -> 12
        x1 + x2 + x3 + x4
        """
    def test_int_mul_array(self):
        # note that int64 mul has not packed machine instr
        # for SSE4 thus int32
        result = self.run("int_mul_array")
        assert int(result) == 7*7+8*8+11*11+12*12
        self.check_vectorized(2, 2)

    def define_slice():
        return """
        a = |30|
        b = a -> ::3
        c = b + b
        c -> 3
        """

    def test_slice(self):
        result = self.run("slice")
        assert result == 18
        self.check_vectorized(1,1)

    def define_multidim_slice():
        return """
        a = [[1, 2, 3, 4], [3, 4, 5, 6], [5, 6, 7, 8], [7, 8, 9, 10], [9, 10, 11, 12], [11, 12, 13, 14], [13, 14, 15, 16], [16, 17, 18, 19]]
        b = a -> ::2
        c = b + b
        d = c -> 1
        d -> 1
        """

    def test_multidim_slice(self):
        result = self.run('multidim_slice')
        assert result == 12
        self.check_trace_count(3)
        # ::2 creates a view object -> needs an inner loop
        # that iterates continous chunks of the matrix
        self.check_vectorized(1,0) 

    def define_dot_matrix():
        return """
        mat = |16|
        m = reshape(mat, [4,4])
        vec = [0,1,2,3]
        a = dot(m, vec)
        a -> 3
        """

    def test_dot_matrix(self):
        result = self.run("dot_matrix")
        assert int(result) == 86
        self.check_vectorized(1, 1)


    # NOT WORKING

    def define_pow():
        return """
        a = |30| ** 2
        a -> 29
        """

    def test_pow(self):
        result = self.run("pow")
        assert result == 29 ** 2
        self.check_trace_count(1)

    def define_pow_int():
        return """
        a = astype(|30|, int)
        b = astype([2], int)
        c = a ** b
        c -> 15 
        """

    def test_pow_int(self):
        result = self.run("pow_int")
        assert result == 15 ** 2
        self.check_trace_count(4)  # extra one for the astype
