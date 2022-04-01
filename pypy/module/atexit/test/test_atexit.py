class AppTestAtexit:

    def test_args(self):
        import atexit
        import io
        import sys
        stdout, stderr = sys.stdout, sys.stderr
        try:
            sys.stdout = sys.stderr = capture = io.StringIO()
            def h1():
                print("h1")
            def h2():
                print("h2")
            atexit.register(h1)
            atexit.register(h2)
            assert atexit._ncallbacks() == 2
            atexit._run_exitfuncs()
            assert atexit._ncallbacks() == 0
            assert capture.getvalue() == 'h2\nh1\n'
        finally:
            sys.stdout = stdout
            sys.stderr = stderr

    def test_badargs(self):
        import atexit
        atexit.register(lambda: 1, 0, 0, (x for x in (1,2)), 0, 0)
        raises(TypeError, atexit._run_exitfuncs)

    def test_systemexit(self):
        import atexit
        def f():
            raise SystemExit()
        atexit.register(f)
        raises(SystemExit, atexit._run_exitfuncs)
