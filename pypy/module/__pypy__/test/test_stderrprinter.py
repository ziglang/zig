def app_test_stderrprinter():
    from __pypy__ import StdErrPrinter

    p = StdErrPrinter(2)
    assert repr(p).startswith("<StdErrPrinter(fd=2) object at")

    p.close()  # this should be a no-op
    p.flush()  # this should be a no-op
    assert p.fileno() == 2
    assert p.write('foo') == 3
    raises(TypeError, p.write, b'foo')

    assert not p.closed
    assert p.encoding is None
    assert p.mode == 'w'
