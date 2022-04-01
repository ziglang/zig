import sys, os, signal
import threading

def getsignalname(n):
    for name, value in signal.__dict__.items():
        if value == n and name.startswith('SIG'):
            return name
    return 'signal %d' % (n,)

def childkill():
    global timedout
    timedout = True
    sys.stderr.write("==== test running for %d seconds ====\n" % timeout)
    sys.stderr.write("="*26 + "timedout" + "="*26 + "\n")
    try:
        os.kill(pid, signal.SIGTERM)
    except OSError:
        pass

if __name__ == '__main__':
    timeout = float(sys.argv[1])
    timedout = False

    pid = os.fork()
    if pid == 0:
        os.execvp(sys.argv[2], sys.argv[2:])
    else: # parent
        t = threading.Timer(timeout, childkill)
        t.start()
        while True:
            try:
                pid, status = os.waitpid(pid, 0)
            except KeyboardInterrupt:
                continue
            else:
                t.cancel()
                break
        if os.WIFEXITED(status):
            sys.exit(os.WEXITSTATUS(status))
        else:
            assert os.WIFSIGNALED(status)
            sign = os.WTERMSIG(status)
            if timedout and sign == signal.SIGTERM:
                sys.exit(1)
            signame = getsignalname(sign)
            sys.stderr.write("="*26 + "timedout" + "="*26 + "\n")        
            sys.stderr.write("="*25 + " %-08s " %  signame + "="*25 + "\n")
            sys.exit(1)



