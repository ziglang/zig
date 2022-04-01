import py, os
from rpython.tool.udir import udir


def test_interface_to_dump_rpy_heap_str(space):
    filename = str(udir.join('dump_rpy_heap.str'))
    try:
        space.appexec([space.wrap(filename)], """(filename):
            import gc
            gc.dump_rpy_heap(filename)""")
    except NotImplementedError:
        pass
    assert os.path.exists(filename)

def test_interface_to_dump_rpy_heap_file(space):
    filename = str(udir.join('dump_rpy_heap.file'))
    w_f = space.appexec([space.wrap(filename)], """(filename):
            import gc
            f = open(filename, 'wb')
            f.write(b'X')
            return f""")
    assert os.path.getsize(filename) == 0   # the 'X' was not flushed yet
    try:
        space.appexec([w_f], """(f):
            import gc
            gc.dump_rpy_heap(f)""")
    except NotImplementedError:
        pass
    assert os.path.getsize(filename) == 1   # the 'X' was flushed here

def test_interface_to_dump_rpy_heap_fd(space):
    filename = str(udir.join('dump_rpy_heap.fd'))
    f = open(filename, 'wb')
    try:
        space.appexec([space.wrap(f.fileno())], """(fd):
            import gc
            gc.dump_rpy_heap(fd)""")
    except NotImplementedError:
        pass
