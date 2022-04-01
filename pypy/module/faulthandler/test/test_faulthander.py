class AppTestFaultHandler:
    spaceconfig = {
        "usemodules": ["faulthandler", "_vmprof"]
    }

    def test_enable(self):
        import faulthandler, sys
        faulthandler.enable()
        assert faulthandler.is_enabled() is True
        faulthandler.enable(file=sys.stderr, all_threads=True)
        faulthandler.disable()
        assert faulthandler.is_enabled() is False

    def test_dump_traceback(self):
        import faulthandler, sys
        faulthandler.dump_traceback()
        faulthandler.dump_traceback(file=sys.stderr, all_threads=True)
