import sys
import types

# Evil implicit relative import.
from kinds import KINDS


def main(argv):
    if len(argv) == 2:
        [_, modname] = argv
        attr = None
    elif len(argv) == 3:
        [_, modname, attr] = argv
    else:
        sys.exit("Wrong number of args")
    __import__(modname)
    obj = sys.modules[modname]

    if attr is not None:
        obj = getattr(obj, attr)

    for name in dir(obj):
        if attr is None and name.startswith("_"):
            continue
        subobj = getattr(obj, name)
        if subobj is None:
            continue
        if isinstance(subobj, types.FunctionType):
            try:
                subobj()
            except NotImplementedError:
                continue
            except:
                pass
        if isinstance(subobj, types.TypeType):
            kind = KINDS["TYPE"]
        else:
            kind = KINDS["UNKNOWN"]
        print kind, ":", name

if __name__ == "__main__":
    main(sys.argv)
