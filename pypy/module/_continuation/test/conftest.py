import sys

def pytest_configure(config):
    if (not config.getoption('runappdirect') and
            not config.getoption('direct_apptest') and
            sys.platform.startswith('linux')):
        from rpython.rlib.rvmprof.cintf import configure_libbacktrace_linux
        configure_libbacktrace_linux()
