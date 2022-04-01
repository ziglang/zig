from __future__ import division
import cPickle as pickle

from rpython.tool.ansicolor import red, yellow, green
from rpython.rtyper.lltypesystem.lltype import typeOf, _ptr, Ptr, ContainerType
from rpython.rtyper.lltypesystem.lltype import GcOpaqueType
from rpython.rtyper.lltypesystem import llmemory
from rpython.memory.lltypelayout import convert_offset_to_int

class Info:
    pass

class ModuleReport:
    def __init__(self, modulename, totalsize, typereports):
        self.modulename = modulename
        self.totalsize = totalsize
        self.typereports = typereports

    def __repr__(self):
        return 'ModuleReport(%s, %d, ...)' % (self.modulename, self.totalsize)

    def __cmp__(self, other):
        return cmp((self.totalsize, self.modulename), (other.totalsize, other.modulename))

class TypeReport:
    def __init__(self, typename, size, numobjects):
        self.typename = typename
        self.size = size
        self.numobjects = numobjects

    def __repr__(self):
        return 'TypeReport(%s, %d, %d)' % (self.typename, self.size, self.numobjects)

    def __cmp__(self, other):
        return cmp((self.size, self.typename), (other.size, other.typename))


## Functions used by translate.py
def guess_module(graph):
    func = getattr(graph, 'func', None)
    name = None
    if func is not None:
        newname = func.__globals__.get('__name__',  None)
        if newname is not None:
            name = newname
        else:
            if func.__module__:
                name = func.__module__
    return name


def values_to_nodes(database, values):
    nodes = []
    for value in values:
        if isinstance(typeOf(value), Ptr):
            container = value._obj
            if isinstance(typeOf(container), ContainerType):
                if isinstance(typeOf(container), GcOpaqueType):
                    container = container.container
                node = database.getcontainernode(container)
                if node.nodekind != 'func':
                    nodes.append(node)
        elif isinstance(typeOf(value), ContainerType): # inlined container
            nodes.extend(values_to_nodes(database, database.getcontainernode(value).enum_dependencies()))
    return nodes


def guess_size_obj(obj):
    TYPE = typeOf(obj)
    ptr = _ptr(Ptr(TYPE), obj)
    if TYPE._is_varsize():
        arrayfld = getattr(TYPE, '_arrayfld', None)
        if arrayfld:
            length = len(getattr(ptr, arrayfld))
        else:
            try:
                length = len(ptr)
            except TypeError:
                print "couldn't find size of", ptr
                return 0
    else:
        length = None
    #print obj, ', length =', length
    r = convert_offset_to_int(llmemory.sizeof(TYPE, length))
    #print '\tr =', r
    return r


def guess_size(database, node, recursive=None):
    obj = node.obj
    size = guess_size_obj(obj)
    if recursive is None:
        return size
    if node in recursive:
        return 0
    recursive.add(node)
    for dep in values_to_nodes(database, node.enum_dependencies()):
        size += guess_size(database, dep, recursive)
    return size


def by_lltype(obj):
    return repr(typeOf(obj))

def group_static_size(database, nodes, grouper=by_lltype, recursive=None):
    totalsize = {}
    numobjects = {}
    for node in nodes:
        obj = node.obj
        group = grouper(obj)
        totalsize[group] = totalsize.get(group, 0) + guess_size(database, node, recursive)
        numobjects[group] = numobjects.get(group, 0) + 1
    return totalsize, numobjects

def make_report_static_size(database, nodes, grouper, recursive=None):
    from rpython.rtyper.lltypesystem import lltype
    # sort structs that belongs to user-defined RPython classes first
    def nodekey(node):
        if isinstance(node.T, lltype.Struct) and node.T._name.startswith('pypy.'):
            return (0, node)
        else:
            return (1, node)

    nodes = sorted(nodes, key=nodekey)
    totalsize, numobjects = group_static_size(database, nodes, grouper, recursive)
    l = [(size, key) for key, size in totalsize.iteritems()]
    l.sort()
    l.reverse()
    sizesum = 0
    typereports = []
    for size, key in l:
        sizesum += size
        typereports.append(TypeReport(key, size, numobjects[key]))
    return sizesum, typereports

def get_unknown_graphs(database):
    funcnodes = [node for node in database.globalcontainers() if node.nodekind == "func"]
    for node in funcnodes:
        graph = getattr(node.obj, 'graph', None)
        if not graph or not getattr(graph, 'func', None):
            continue
        if not guess_module(graph):
            yield graph

def get_unknown_graphs_names(database):
    return [getattr(graph, 'name', '???') for graph in get_unknown_graphs(database)]

def aggregate_values_by_type(database):
    nodes = [node for node in database.globalcontainers() if node.nodekind != "func"]
    size, typereports = make_report_static_size(database, nodes, by_lltype)
    return [ModuleReport('<global>', size, typereports)]

def aggregate_values_by_module_and_type(database, count_modules_separately=False):
    " Reports all objects by module and by lltype. "
    modules = {}
    reports = []
    funcnodes = [node for node in database.globalcontainers()
                     if node.nodekind == "func"]
    # extract all prebuilt nodes per module
    for node in funcnodes:
        graph = getattr(node.obj, 'graph', None)
        if not graph:
            continue
        nodes_set = modules.setdefault(guess_module(graph) or '<unknown>', set())
        assert len(node.funcgens) == 1
        nodes_set.update(values_to_nodes(database, node.funcgens[0].all_cached_consts))
    modules = modules.items()
    # make sure that gc modules are reported latest to avoid them eating all objects
    def gc_module_key(tup):
        if "module.gc" in tup[0]:
            return ("\xff", ) + tup
        return tup
    modules.sort(key=gc_module_key)

    # report sizes per module
    seen = set()
    reachables = set()
    for modulename, nodes in modules:
        if count_modules_separately:
            seen = set()
        if not nodes:
            continue
        size, typereports = make_report_static_size(database, nodes, by_lltype, seen)
        reachables.update(seen)
        reports.append(ModuleReport(modulename, size, typereports))

    
    allnodes = set([node for node in database.globalcontainers() if node.nodekind != "func"])
    unreachables = allnodes-reachables
    if count_modules_separately:
        seen = set()
    size, typereports = make_report_static_size(database, unreachables, by_lltype, seen)
    reports.append(ModuleReport('<unreachable nodes>', size, typereports))


    reports.sort()
    reports.reverse()
    return reports

def dump_static_data_info(log, database, targetdir):
    info = Info()
    info.by_module_with_duplicates = aggregate_values_by_module_and_type(database, False)
    info.by_module_without_duplicates = aggregate_values_by_module_and_type(database, True)
    info.by_type = aggregate_values_by_type(database)
    info.unknown_graphs = get_unknown_graphs_names(database)
    infofile = targetdir.join('staticdata.info')
    f = infofile.open('w')
    pickle.dump(info, f)
    f.close()
    log.info('static data information dumped to %s' % infofile)
    return infofile


## Functions used by the reportstaticdata.py script
def format_typereport(rep, human_readable=True):
    size = format_size(rep.size, human_readable)
    return format_line(rep.typename[:65], size, rep.numobjects)

def format_line(a, b, c):
    return '    %65s %10s %6s' % (a, b, c)

def format_size(size, human_readable=False):
    KB = 1024.0
    MB = KB*KB
    if human_readable:
        if size >= MB:
            return '%.2fM' % (size/MB)
        if size >= KB:
            return '%.2fK' % (size/KB)
        return '%d' % size
    return size

def print_report(filename,
                 kind='by_module_with_duplicates',
                 summary=False,
                 show_unknown_graphs=False,
                 human_readable=False):
    f = open(filename)
    info = pickle.load(f)
    f.close()
    reports = getattr(info, kind)
    globalsize = 0
    for report in reports:
        if report.totalsize == 0:
            continue
        size = format_size(report.totalsize, human_readable)
        globalsize += report.totalsize
        if summary:
            print "%d\t%s" % (size, report.modulename)
        else:
            print '%s: %s' % (red(report.modulename), yellow(size))
            print green(format_line('Typename', 'Size', 'Num'))
            for typereport in report.typereports:
                print format_typereport(typereport, human_readable)
            print
    print
    print 'Total size:', format_size(globalsize, human_readable)

    if show_unknown_graphs:
        print
        print green('Unknown graphs:')
        for graphname in info.unknown_graphs:
            print graphname
