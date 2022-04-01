import sys, os, imp
sys.path.insert(0, os.path.realpath(os.path.join(os.path.dirname(__file__), '..', '..')))
from pypy.tool import slaveproc

class IsolateSlave(slaveproc.Slave):
    mod = None

    def do_cmd(self, cmd):
        cmd, data = cmd
        if cmd == 'load':
            assert self.mod is None
            mod = data
            if isinstance(mod, str):
                mod = __import__(mod, {}, {}, ['__doc__'])
            else:
                dir, name = mod
                file, pathname, description = imp.find_module(name, [dir])
                try:
                    mod = imp.load_module(name, file, pathname, description)
                finally:
                    if file:
                        file.close()
            self.mod = mod
            return 'loaded'
        elif cmd == 'invoke':
            assert self.mod is not None
            func, args = data
            try:
                res = getattr(self.mod, func)(*args)
            except KeyboardInterrupt:
                raise
            except:
                exc_type = sys.exc_info()[0] 
                return ('exc', (exc_type.__module__, exc_type.__name__))
            else:
                return ('ok', res)
        else:
            return 'no-clue'

if __name__ == '__main__':
    IsolateSlave().do()
