from __future__ import division
import py

import random

exclude_files = ["__init__.py", "conftest.py"]

def include_file(path):
    if ("test" in str(path) or "tool" in str(path) or
        "documentation" in str(path) or 
        "_cache" in str(path)):
        return False
    if path.basename in exclude_files:
        return False
    return True

def get_mod_from_path(path):
    dirs = path.get("dirname")[0].split("/")
    pypyindex = dirs.index("pypy")
    return ".".join(dirs[pypyindex:] + path.get("purebasename"))


def find_references(path):
    refs = []
    for line in path.open("r"):
        if line.startswith("    "): # ignore local imports to reduce graph size
            continue
        if "\\" in line: #ignore line continuations
            continue
        line = line.strip()
        line = line.split("#")[0].strip()
        if line.startswith("import pypy."): # import pypy.bla.whatever
            if " as " not in line:
                refs.append((line[7:].strip(), None))
            else: # import pypy.bla.whatever as somethingelse
                assert line.count(" as ") == 1
                line = line.split(" as ")
                refs.append((line[0][7:].strip(), line[1].strip()))
        elif line.startswith("from ") and "pypy" in line: #from pypy.b import a
            line = line[5:]
            if " as " not in line:
                line = line.split(" import ")
                what = line[1].split(",")
                for w in what:
                    refs.append((line[0].strip() + "." + w.strip(), None))
            else: # prom pypy.b import a as c
                if line.count(" as ") != 1 or "," in line:
                    print"can't handle this: " + line
                    continue
                line = line.split(" as ")
                what = line[0].replace(" import ", ".").replace(" ", "")
                refs.append((what, line[1].strip()))
    return refs

def get_module(ref, imports):
    ref = ref.split(".")
    i = len(ref)
    while i:
        possible_mod = ".".join(ref[:i])
        if possible_mod in imports:
            return possible_mod
        i -= 1
    return None

def casteljeau(points, t):
    points = points[:]
    while len(points) > 1:
        for i in range(len(points) - 1):
            points[i] = points[i] * (1 - t) + points[i + 1] * t
        del points[-1]
    return points[0]

def color(t):
    casteljeau([0, 0, 1, 0, 0], t) / 0.375

class ModuleGraph(object):
    def __init__(self, path):
        self.imports = {}
        self.clusters = {}
        self.mod_to_cluster = {}
        for f in path.visit("*.py"):
            if include_file(f):
                self.imports[get_mod_from_path(f)] = find_references(f)
        self.remove_object_refs()
        self.remove_double_refs()
        self.incoming = {}
        for mod in self.imports:
            self.incoming[mod] = set()
        for mod, refs in self.imports.iteritems():
            for ref in refs:
                if ref[0] in self.incoming:
                    self.incoming[ref[0]].add(mod)
        self.remove_single_nodes()
        self.topgraph_properties = ["rankdir=LR"]

    def remove_object_refs(self):
        # reduces cases like import rpython.translator.genc.basetype.CType to
        # import rpython.translator.genc.basetype
        for mod, refs in self.imports.iteritems():
            i = 0
            while i < len(refs):
                if refs[i][0] in self.imports:
                    i += 1
                else:
                    nref = get_module(refs[i][0], self.imports)
                    if nref is None:
                        print "removing", repr(refs[i])
                        del refs[i]
                    else:
                        refs[i] = (nref, None)
                        i += 1

    def remove_double_refs(self):
        # remove several references to the same module
        for mod, refs in self.imports.iteritems():
            i = 0
            seen_refs = set()
            while i < len(refs):
                if refs[i] not in seen_refs:
                    seen_refs.add(refs[i])
                    i += 1
                else:
                    del refs[i]

    def remove_single_nodes(self):
        # remove nodes that have no attached edges
        rem = []
        for mod, refs in self.imports.iteritems():
            if len(refs) == 0 and len(self.incoming[mod]) == 0:
                rem.append(mod)
        for m in rem:
            del self.incoming[m]
            del self.imports[m]

    def create_clusters(self):
        self.topgraph_properties.append("compound=true;")
        self.clustered = True
        hierarchy = [set() for i in range(6)]
        for mod in self.imports:
            for i, d in enumerate(mod.split(".")):
                hierarchy[i].add(d)
        for i in range(6):
            if len(hierarchy[i]) != 1:
                break
        for mod in self.imports:
            cluster = mod.split(".")[i]
            if i == len(mod.split(".")) - 1:
                continue
            if cluster not in self.clusters:
                self.clusters[cluster] = set()
            self.clusters[cluster].add(mod)
            self.mod_to_cluster[mod] = cluster

    def remove_tangling_randomly(self):
        # remove edges to nodes that have a lot incoming edges randomly
        tangled = []
        for mod, incoming in self.incoming.iteritems():
            if len(incoming) > 10:
                tangled.append(mod)
        for mod in tangled:
            remove = set()
            incoming = self.incoming[mod]
            while len(remove) < len(incoming) * 0.80:
                remove.add(random.choice(list(incoming)))
            for rem in remove:
                for i in range(len(self.imports[rem])):
                    if self.imports[rem][i][1] == mod:
                        break
                del self.imports[rem][i]
                incoming.remove(rem)
                print "removing", mod, "<-", rem
        self.remove_single_nodes()

    def dotfile(self, dot):
        f = dot.open("w")
        f.write("digraph G {\n")
        for prop in self.topgraph_properties:
            f.write("\t%s\n" % prop)
        #write clusters and inter-cluster edges
        for cluster, nodes in self.clusters.iteritems():
            f.write("\tsubgraph cluster_%s {\n" % cluster)
            f.write("\t\tstyle=filled;\n\t\tcolor=lightgrey\n")
            for node in nodes:
                f.write('\t\t"%s";\n' % node[5:])
            for mod, refs in self.imports.iteritems():
                for ref in refs:
                    if mod in nodes and ref[0] in nodes:
                        f.write('\t\t"%s" -> "%s";\n' % (mod[5:], ref[0][5:]))
            f.write("\t}\n")
        #write edges between clusters
        for mod, refs in self.imports.iteritems():
            try:
                nodes = self.clusters[self.mod_to_cluster[mod]]
            except KeyError:
                nodes = set()
            for ref in refs:
                if ref[0] not in nodes:
                    f.write('\t"%s" -> "%s";\n' % (mod[5:], ref[0][5:]))
        f.write("}")
        f.close()

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1:
        path = py.path.local(sys.argv[1])
    else:
        path = py.path.local(".")
    gr = ModuleGraph(path)
    gr.create_clusters()
    dot = path.join("import_graph.dot")
    gr.dotfile(dot)
