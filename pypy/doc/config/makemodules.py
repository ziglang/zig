import py
from pypy.config import pypyoption
from rpython.config import translationoption, config

thisdir = py.path.local(__file__).dirpath()

if __name__ == '__main__':
    c = config.Config(pypyoption.pypy_optiondescription).usemodules
    prefix = "objspace.usemodules"
    thisdir.join(prefix + ".rst").ensure()
    for p in c.getpaths(include_groups=True):
        basename = prefix + "." + p + ".rst"
        f = thisdir.join(basename)
        #if f.check() and f.size():
        #    continue
        print "making docs for", p
        text = ["Use the '%s' module. " % (p, )]
        if p in pypyoption.essential_modules:
            text.append("This module is essential, included by default and should not be removed.")
        elif p in pypyoption.default_modules:
            text.append("This module is expected to be working and is included by default.")
        elif p in pypyoption.working_modules:
            text.append("This module is expected to be fully working.")
        text.append("")
        f.write("\n".join(text))


