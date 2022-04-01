from pypy.module.pypyjit.test_pypy_c.test_00_model import BaseTestPyPyC


class TestGetFrame(BaseTestPyPyC):
    def test_getframe_one(self):
        def main(n):
            import sys

            i = 0
            while i < n:
                assert sys._getframe(0).f_code.co_filename == __file__
                i += 1
            return i

        log = self.run(main, [300])
        assert log.result == 300
        loop, = log.loops_by_filename(self.filepath)
        assert loop.match("""
        i54 = int_lt(i47, i28)
        guard_true(i54, descr=...)
        guard_not_invalidated(descr=...)
        i55 = int_add(i47, 1)
        --TICK--
        jump(..., descr=...)
        """)

    def test_current_frames(self):
        def main():
            import sys
            import time
            import _thread as thread

            lst = [0.0] * 1000
            lst[-33] = 3.0
            done = []

            def h1(x):
                time.sleep(lst[x])

            def g1(x):
                h1(x)

            def f1():
                for j in range(1000):
                    g1(j)
                done.append('done')

            for k in range(3):
                thread.start_new_thread(f1, ())

            time.sleep(1)
            d = sys._current_frames()

            time.sleep(3)
            # the captured frames should be finished by now

            done.append(str(len(d)))
            for key, value in d.items():
                while value is not None:
                    name = value.f_code.co_name
                    if len(name) == 2 and name[1] == '1':
                        done.append(name)
                    value = value.f_back
            return repr('-'.join(done))

        log = self.run(main, [])
        assert log.result == 'done-done-done-4-h1-g1-f1-h1-g1-f1-h1-g1-f1'
