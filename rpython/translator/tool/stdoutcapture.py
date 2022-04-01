"""
A quick hack to capture stdout/stderr.
"""

import os, sys


class Capture:
    
    def __init__(self, mixed_out_err = False):
        "Start capture of the Unix-level stdout and stderr."
        if (sys.platform == 'win32' or # os.tmpfile fails, cpython issue #2232
            not hasattr(os, 'tmpfile') or
            not hasattr(os, 'dup') or
            not hasattr(os, 'dup2') or
            not hasattr(os, 'fdopen')):
            self.dummy = 1
        else:
            self.dummy = 0
            # make new stdout/stderr files if needed
            self.localoutfd = os.dup(1)
            self.localerrfd = os.dup(2)
            if hasattr(sys.stdout, 'fileno') and sys.stdout.fileno() == 1:
                self.saved_stdout = sys.stdout
                sys.stdout = os.fdopen(self.localoutfd, 'w', 1)
            else:
                self.saved_stdout = None
            if hasattr(sys.stderr, 'fileno') and sys.stderr.fileno() == 2:
                self.saved_stderr = sys.stderr
                sys.stderr = os.fdopen(self.localerrfd, 'w', 0)
            else:
                self.saved_stderr = None
            self.tmpout = os.tmpfile()
            if mixed_out_err:
                self.tmperr = self.tmpout
            else:
                self.tmperr = os.tmpfile()
            os.dup2(self.tmpout.fileno(), 1)
            os.dup2(self.tmperr.fileno(), 2)

    def done(self):
        "End capture and return the captured text (stdoutfile, stderrfile)."
        if self.dummy:
            import cStringIO
            return cStringIO.StringIO(), cStringIO.StringIO()
        else:
            os.dup2(self.localoutfd, 1)
            os.dup2(self.localerrfd, 2)
            if self.saved_stdout is not None:
                f = sys.stdout
                sys.stdout = self.saved_stdout
                f.close()
            else:
                os.close(self.localoutfd)
            if self.saved_stderr is not None:
                f = sys.stderr
                sys.stderr = self.saved_stderr
                f.close()
            else:
                os.close(self.localerrfd)
            self.tmpout.seek(0)
            self.tmperr.seek(0)
            return self.tmpout, self.tmperr


if __name__ == '__main__':
    # test
    c = Capture()
    try:
        os.system('echo hello')
    finally:
        fout, ferr = c.done()
    print 'Output:', `fout.read()`
    print 'Error:', `ferr.read()`
