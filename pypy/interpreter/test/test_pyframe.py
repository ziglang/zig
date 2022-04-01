from pypy.conftest import option
from pypy.interpreter.gateway import interp2app

def check_no_w_locals(space, w_frame):
    return space.wrap(w_frame.getorcreatedebug().w_locals is None)

class AppTestPyFrame:

    def setup_class(cls):
        space = cls.space
        if not option.runappdirect:
            w_call_further = cls.space.appexec([], """():
                def call_further(f):
                    return f()
                return call_further
            """)
            assert not w_call_further.code.hidden_applevel
            w_call_further.code.hidden_applevel = True       # hack
            cls.w_call_further = w_call_further

            cls.w_check_no_w_locals = space.wrap(interp2app(check_no_w_locals))

    # test for the presence of the attributes, not functionality

    def test_set_lineno(self):
        skip("broken atm")
        import sys
        class JumpTracer:
            def __init__(self, function):
                self.function = function
                self.jumpFrom = function.jump[0]
                self.jumpTo = function.jump[1]
                self.done = False

            def trace(self, frame, event, arg):
                if not self.done and frame.f_code == self.function.__code__:
                    firstLine = frame.f_code.co_firstlineno
                    if event == 'line' and frame.f_lineno == firstLine + self.jumpFrom:
                        # Cope with non-integer self.jumpTo (because of
                        # no_jump_to_non_integers below).
                        try:
                            frame.f_lineno = firstLine + self.jumpTo
                        except TypeError:
                            frame.f_lineno = self.jumpTo
                        self.done = True
                return self.trace

        def run_test(func):
            tracer = JumpTracer(func)
            sys.settrace(tracer.trace)
            output = []
            func(output)
            sys.settrace(None)
            assert func.output == output

        # copied from cpython test suite
        def jump_out_of_block_forwards(output):
            for i in 1, 2:
                output.append(2)
                for j in [3]:  # Also tests jumping over a block
                    output.append(4)
            output.append(5)

        jump_out_of_block_forwards.jump = (3, 5)
        jump_out_of_block_forwards.output = [2, 5]
        run_test(jump_out_of_block_forwards)

        def jump_out_of_block_backwards(output):
            output.append(1)
            for i in [1]:
                output.append(3)
                for j in [2]:  # Also tests jumping over a block
                    output.append(5)
                output.append(6)
            output.append(7)

        jump_out_of_block_backwards.jump = (6, 1)
        jump_out_of_block_backwards.output = [1, 3, 5, 1, 3, 5, 6, 7]
        run_test(jump_out_of_block_backwards)


        def jump_to_codeless_line(output):
            output.append(1)
            # Jumping to this line should skip to the next one.
            output.append(3)
        jump_to_codeless_line.jump = (1, 2)
        jump_to_codeless_line.output = [3]
        run_test(jump_to_codeless_line)

        def jump_in_nested_finally(output):
            try:
                output.append(2)
            finally:
                output.append(4)
                try:
                    output.append(6)
                finally:
                    output.append(8)
                output.append(9)
        jump_in_nested_finally.jump = (4, 9)
        jump_in_nested_finally.output = [2, 9]
        run_test(jump_in_nested_finally)


    def test_f_back_hidden(self):
        if not hasattr(self, 'call_further'):
            skip("not for runappdirect testing")
        import sys
        def f():
            return (sys._getframe(0),
                    sys._getframe(1),
                    sys._getframe(0).f_back)
        def main():
            return self.call_further(f)
        f0, f1, f1bis = main()
        assert f0.f_code.co_name == 'f'
        assert f1.f_code.co_name == 'main'
        assert f1bis is f1
        assert f0.f_back is f1

    def test_fast2locals_called_lazily(self):
        import sys
        class FrameHolder:
            pass
        fh = FrameHolder()
        def trace(frame, what, arg):
            # trivial trace function, does not access f_locals
            fh.frame = frame
            return trace
        def f(x):
            x += 1
            return x
        sys.settrace(trace)
        res = f(1)
        sys.settrace(None)
        assert res == 2
        if hasattr(self, "check_no_w_locals"): # not appdirect
            assert self.check_no_w_locals(fh.frame)

    def test_del_cell_locals_bug(self):
        """
        def f():
            x = object()

            def foo():
                print(x)

            locals()
            del x
            assert "x" not in locals()
        f()
        """

    def test_repr(self):
        import sys
        def a_name(a, b, c):
            a + b + c
            return sys._getframe()
        frame = a_name(5, 6, 4)
        r = repr(frame)
        assert "a_name" in r
