import py
from pypy.config import pypyoption, makerestdoc
from rpython.config import translationoption, config

all_optiondescrs = [pypyoption.pypy_optiondescription,
                    translationoption.translation_optiondescription,
                   ]
start_to_descr = dict([(descr._name, descr) for descr in all_optiondescrs])

def make_cmdline_overview():
    result = []
    txtpath = thisdir.join("commandline.txt")
    for line in txtpath.read().splitlines():
        if line.startswith('.. GENERATE:'):
            start = line[len('.. GENERATE:'):].strip()
            descr = start_to_descr[start]
            line = makerestdoc.make_cmdline_overview(descr, title=False).text()
        result.append(line)
    rstpath = txtpath.new(ext=".rst")
    rstpath.write("\n".join(result))

def make_rst(basename):
    txtpath = thisdir.join(basename)
    txtpath.ensure()
    rstpath = txtpath.new(ext=".rst")

    fullpath = txtpath.purebasename
    start = fullpath.split(".")[0]
    path = fullpath.rsplit(".", 1)[0]
    basedescr = start_to_descr.get(start)
    if basedescr is None:
        return
    if fullpath.count(".") == 0:
        descr = basedescr
        path = ""
    else:
        conf = config.Config(basedescr)
        subconf, step = conf._cfgimpl_get_home_by_path(
                fullpath.split(".", 1)[1])
        descr = getattr(subconf._cfgimpl_descr, step)
    text = unicode(descr.make_rest_doc(path).text())
    if txtpath.check(file=True):
        content = txtpath.read()
        if content:
            text += "\n\n"
            text = u"%s\n\n%s" % (text, unicode(txtpath.read(), "utf-8"))
    rstpath.write(text.encode("utf-8"))


thisdir = py.path.local(__file__).dirpath()

for descr in all_optiondescrs:
    prefix = descr._name
    c = config.Config(descr)
    thisdir.join(prefix + ".txt").ensure()
    make_rst(prefix + ".txt")
    for p in c.getpaths(include_groups=True):
        basename = prefix + "." + p + ".txt"
        make_rst(basename)

make_cmdline_overview()
