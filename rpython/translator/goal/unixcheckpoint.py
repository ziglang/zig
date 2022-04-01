import os, sys

def restart_process():
    import sys
    os.execv(sys.executable, [sys.executable] + sys.argv)

def restartable_point_fork(auto=None, extra_msg=None):
    while True:
        while True:
            if extra_msg:
                print extra_msg
            print '---> Checkpoint: cont / restart-it-all / quit / pdb ?'
            if auto:
                print 'auto-%s' % (auto,)
                line = auto
                auto = None
            else:
                try:
                    line = raw_input().strip().lower()
                except (KeyboardInterrupt, EOFError) as e:
                    print '(%s ignored)' % e.__class__.__name__
                    continue
            if line in ('run', 'cont'):
                break
            if line == 'quit':
                raise SystemExit
            if line == 'pdb':
                try:
                    import pdb; pdb.set_trace()
                    dummy_for_pdb = 1    # for pdb to land
                except Exception as e:
                    print '(%s ignored)' % e.__class__.__name__
                    continue
            if line == 'restart-it-all':
                restart_process()

        try:
            pid = os.fork()
        except AttributeError:
            # windows case
            return
        if pid != 0:
            # in parent
            while True:
                try:
                    pid, status = os.waitpid(pid, 0)
                except KeyboardInterrupt:
                    continue
                else:
                    break
            print
            print '_'*78
            print 'Child %d exited' % pid,
            if os.WIFEXITED(status):
                print '(exit code %d)' % os.WEXITSTATUS(status)
            elif os.WIFSIGNALED(status):
                print '(caught signal %d)' % os.WTERMSIG(status)
            else:
                print 'abnormally (status 0x%x)' % status
            continue

        # in child
        print '_'*78
        break

# special version for win32 which does not have fork() at all,
# but epople can simulate it by hand using VMware

def restartable_point_nofork(auto=None):
    # auto ignored, no way to automate VMware, yet
    restartable_point_fork(None, '+++ this system does not support fork +++\n'
        'if you have a virtual machine, you can save a snapshot now')

if sys.platform == 'win32':
    restartable_point = restartable_point_nofork
else:
    restartable_point = restartable_point_fork

if __name__ == '__main__':
    print 'doing stuff...'
    print 'finished'
    restartable_point()
    print 'doing more stuff'
    print 'press Enter to quit...'
    raw_input()
