import pytest

class AppTestBreakpoint:
    def setup_class(cls):
        cls.w_import_mock_pdb = cls.space.appexec([], """():
            import sys
            from contextlib import contextmanager
            from types import ModuleType

            @contextmanager
            def w_import_mock_pdb():
                try:
                    mock_pdb = ModuleType('pdb')
                    mock_pdb.set_trace = None
                    sys.modules['pdb'] = mock_pdb
                    yield mock_pdb
                finally:
                    del sys.modules['pdb']

            return w_import_mock_pdb
        """)

        cls.w_mock_function = cls.space.appexec([], """():
            from contextlib import contextmanager

            class MockedCallable:
                def __init__(self):
                    self.called = 0

                def __call__(self, *args, **kwargs):
                    self.called += 1
                    self.last_call = (args, kwargs)

            @contextmanager
            def mock_function(scope, attr, delete=False):
                old = getattr(scope, attr)
                try:
                    if not delete:
                        new = MockedCallable()
                        setattr(scope, attr, new)
                        yield new
                    else:
                        delattr(scope, attr)
                        yield
                finally:
                    setattr(scope, attr, old)

            return mock_function
        """)


    def test_default(self):
        import sys
        assert sys.breakpointhook is sys.__breakpointhook__

        import os
        assert 'PYTHONBREAKPOINT' not in os.environ

        with self.import_mock_pdb() as pdb:
            with self.mock_function(pdb, 'set_trace') as mocked:
                breakpoint()
                assert mocked.called == 1


    def test_args_kwargs(self):
        import sys
        with self.import_mock_pdb() as pdb:
            with self.mock_function(pdb, 'set_trace') as mocked:
                breakpoint(1, 2, 3, x=4, y=5)
                assert mocked.called == 1
                assert mocked.last_call == ((1, 2, 3), {'x': 4, 'y': 5})


    def test_breakpointhook(self):
        import sys
        with self.import_mock_pdb() as pdb:
            with self.mock_function(sys, 'breakpointhook') as mocked, \
                self.mock_function(pdb, 'set_trace') as mocked_pdb:
                breakpoint()
                assert mocked.called == 1
                assert mocked_pdb.called == 0

            with self.mock_function(pdb, 'set_trace') as mocked_pdb:
                breakpoint()
                assert mocked_pdb.called == 1


    def test_breakpointhook_lost(self):
        import sys
        with self.import_mock_pdb() as pdb:
            with self.mock_function(sys, 'breakpointhook', delete=True):
                with raises(RuntimeError) as excinfo:
                    breakpoint()
                assert str(excinfo.value) == "lost sys.breakpointhook"


    @pytest.mark.dont_track_allocations('putenv intentionally keeps strings alive')
    def test_env_default(self):
        import os
        try:
            os.environ['PYTHONBREAKPOINT'] = ""

            import sys
            with self.import_mock_pdb() as pdb:
                with self.mock_function(pdb, 'set_trace') as mocked:
                    breakpoint()
                    assert mocked.called == 1
        finally:
            del os.environ['PYTHONBREAKPOINT']


    @pytest.mark.dont_track_allocations('putenv intentionally keeps strings alive')
    def test_env_disable(self):
        import os
        try:
            os.environ['PYTHONBREAKPOINT'] = "0"

            import sys
            with self.import_mock_pdb() as pdb:
                with self.mock_function(pdb, 'set_trace') as mocked:
                    breakpoint()
                    assert mocked.called == 0

                with self.mock_function(sys, 'breakpointhook') as mocked:
                    breakpoint()
                    assert mocked.called == 1
        finally:
            del os.environ['PYTHONBREAKPOINT']


    @pytest.mark.dont_track_allocations('putenv intentionally keeps strings alive')
    def test_env_other(self):
        import os
        try:
            os.environ['PYTHONBREAKPOINT'] = 'sys.exit'

            import sys
            with self.import_mock_pdb() as pdb:
                with self.mock_function(sys, 'exit') as mocked, \
                     self.mock_function(pdb, 'set_trace') as mocked_pdb:
                    breakpoint()
                    assert mocked.called == 1
                    assert mocked_pdb.called == 0
        finally:
            del os.environ['PYTHONBREAKPOINT']


    @pytest.mark.dont_track_allocations('putenv intentionally keeps strings alive')
    def test_env_nonexistent(self):
        import os
        import warnings
        try:
            os.environ['PYTHONBREAKPOINT'] = 'blah.bleh'

            import sys
            with self.import_mock_pdb() as pdb:
                with self.mock_function(pdb, 'set_trace') as mocked_pdb, \
                     warnings.catch_warnings(record=True) as w:
                    breakpoint()
                    assert mocked_pdb.called == 0
                    assert len(w) == 1
                    assert str(w[-1].message) == 'Ignoring unimportable $PYTHONBREAKPOINT: "blah.bleh"'
        finally:
            del os.environ['PYTHONBREAKPOINT']
