# This is a general algorithm used by the annotator, translator, and other code

# union-find impl, a info object is attached to the roots


class UnionFind(object):
    def __init__(self, info_factory=None):
        self.link_to_parent = {}
        self.weight = {}
        self.info_factory = info_factory
        self.root_info = {}

    # mapping-like [] access
    def __getitem__(self, obj):
        if obj not in self.link_to_parent:
            raise KeyError(obj)

        ignore, rep, info = self.find(obj)

        return info

    def __contains__(self, obj):
        return obj in self.link_to_parent

    def __iter__(self):
        return iter(self.link_to_parent)

    def keys(self):
        return self.link_to_parent.keys()

    def infos(self):
        return self.root_info.values()

    def find_rep(self, obj):
        try:
            # fast path (shortcut for performance reasons)
            parent = self.link_to_parent[obj]
            self.root_info[parent]   # may raise KeyError
            return parent
        except KeyError:
            # general case
            ignore, rep, info = self.find(obj)
            return rep

    def find(self, obj):  # -> new_root, obj, info
        if obj not in self.link_to_parent:
            if self.info_factory:
                info = self.info_factory(obj)
            else:
                info = None
            self.root_info[obj] = info
            self.weight[obj] = 1
            self.link_to_parent[obj] = obj
            return True, obj, info

        to_root = [obj]
        parent = self.link_to_parent[obj]
        while parent is not to_root[-1]:
            to_root.append(parent)
            parent = self.link_to_parent[parent]

        for obj in to_root:
            self.link_to_parent[obj] = parent

        return False, parent, self.root_info[parent]

    def union(self, obj1, obj2): # -> not_noop, rep, info

        new1, rep1, info1 = self.find(obj1)
        new2, rep2, info2 = self.find(obj2)

        if rep1 is rep2:
            return new1 or new2, rep1, info1

        if info1 is not None:
            info1.absorb(info2)

        w1 = self.weight[rep1]
        w2 = self.weight[rep2]
        w = w1 + w2
        if w1 < w2:
            rep1, rep2 = rep2, rep1

        self.link_to_parent[rep2] = rep1
        del self.weight[rep2]
        del self.root_info[rep2]

        self.weight[rep1] = w
        self.root_info[rep1] = info1

        return True, rep1, info1

    def union_list(self, objlist):
        if len(objlist) == 0:
            return
        obj0 = objlist[0]
        self.find(obj0)
        for obj1 in objlist[1:]:
            self.union(obj0, obj1)
