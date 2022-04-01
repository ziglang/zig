import os
import sys
from pytest import raises, skip

python = sys.executable

if hasattr(os, "execv"):
    def test_execv():
        if not hasattr(os, "fork"):
            skip("Need fork() to test execv()")
        if not os.path.isdir('/tmp'):
            skip("Need '/tmp' for test")
        pid = os.fork()
        if pid == 0:
            os.execv("/usr/bin/env", ["env", python, "-c",
                     ("fid = open('/tmp/onefile0', 'w'); "
                      "fid.write('1'); "
                      "fid.close()")])
        os.waitpid(pid, 0)
        assert open("/tmp/onefile0").read() == "1"
        os.unlink("/tmp/onefile0")

    def test_execv_raising():
        with raises(OSError):
            os.execv("saddsadsadsadsa", ["saddsadsasaddsa"])

    def test_execv_no_args():
        with raises(ValueError):
            os.execv("notepad", [])
        # PyPy needs at least one arg, CPython 2.7 is fine without
        with raises(ValueError):
            os.execve("notepad", [], {})

    def test_execv_raising2():
        for n in 3, [3, "a"]:
            with raises(TypeError):
                os.execv("xxx", n)

    def test_execv_unicode():
        if not hasattr(os, "fork"):
            skip("Need fork() to test execv()")
        if not os.path.isdir('/tmp'):
            skip("Need '/tmp' for test")
        output = u"caf\xe9 \u1234\n"
        pid = os.fork()
        if pid == 0:
            os.execv(u"/bin/sh", ["sh", "-c",
                                  u"echo caf\xe9 \u1234 > /tmp/onefile1"])
        os.waitpid(pid, 0)
        with open("/tmp/onefile1", encoding='utf-8') as fid:
            assert fid.read() == output
        os.unlink("/tmp/onefile1")

    def test_execve():
        if not hasattr(os, "fork"):
            skip("Need fork() to test execve()")
        if not os.path.isdir('/tmp'):
            skip("Need '/tmp' for test")
        pid = os.fork()
        if pid == 0:
            os.execve("/bin/sh",
                      ["sh", "-c", "echo $ddd > /tmp/onefile2"],
                      {'ddd': 'xxx'},
                     )
        os.waitpid(pid, 0)
        with open("/tmp/onefile2") as fid:
            fid.read().rstrip() == "xxx"
        os.unlink("/tmp/onefile2")

    def test_execve_unicode():
        if not hasattr(os, "fork"):
            skip("Need fork() to test execve()")
        if not os.path.isdir('/tmp'):
            skip("Need '/tmp' for test")
        output = u"caf\xe9 \u1234\n"
        pid = os.fork()
        if pid == 0:
            os.execve(u"/bin/sh", ["sh", "-c",
                                   u"echo caf\xe9 \u1234 > /tmp/onefile3"],
                      {'ddd': 'xxx', 'LANG': 'en_US.UTF-8'})
        os.waitpid(pid, 0)
        with open("/tmp/onefile3", encoding="utf-8") as fid:
            assert fid.read() == output
        os.unlink("/tmp/onefile3")
    pass  # <- please, inspect.getsource(), don't crash

if hasattr(os, "spawnv"):
    def test_spawnv():
        ret = os.spawnv(os.P_WAIT, python,
                        [python, '-c', 'raise(SystemExit(42))'])
        assert ret == 42

if hasattr(os, "spawnve") and os.path.exists('/bin/sh'):
    def test_spawnve():
        env = {'FOOBAR': '42'}
        cmd = "exit $FOOBAR"
        ret = os.spawnve(os.P_WAIT, "/bin/sh", ["sh", '-c', cmd], env)
        assert ret == 42
