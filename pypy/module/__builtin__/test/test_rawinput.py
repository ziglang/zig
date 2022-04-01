from __future__ import print_function


class AppTestRawInput():

    def test_input_and_raw_input(self):
        import sys, io
        flushed = [False]
        class CheckFlushed(io.StringIO):
            def flush(self):
                flushed[0] = True
                super().flush()
        for prompt, expected in [("def:", "abc/def:/ghi\n"),
                                 ("", "abc//ghi\n"),
                                 (42, "abc/42/ghi\n"),
                                 (None, "abc/None/ghi\n"),
                                 (Ellipsis, "abc//ghi\n")]:
            for inputfn, inputtext, gottext in [
                    (input, "foo\nbar\n", "foo")]:
                save = sys.stdin, sys.stdout, sys.stderr
                try:
                    sys.stdin = io.StringIO(inputtext)
                    out = sys.stdout = io.StringIO()
                    # Ensure that input flushes stderr
                    flushed = [False]
                    err = sys.stderr = CheckFlushed()
                    sys.stderr.write('foo')
                    print("abc", end='')
                    out.write('/')
                    if prompt is Ellipsis:
                        got = inputfn()
                    else:
                        got = inputfn(prompt)
                    out.write('/')
                    print("ghi")
                finally:
                    sys.stdin, sys.stdout, sys.stderr = save
                assert out.getvalue() == expected
                assert flushed[0]
                assert got == gottext

    def test_bad_fileno(self):
        import io
        import sys
        class BadFileno(io.StringIO):
            def fileno(self):
                1 / 0
        stdin, sys.stdin = sys.stdin, BadFileno('foo')
        try:
            result = input()
        finally:
            sys.stdin = stdin
        assert result == 'foo'
