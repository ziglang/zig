class SimpleTaskEngine(object):
    def __init__(self):
        self._plan_cache = {}

        self.tasks = tasks = {}

        for name in dir(self):
            if name.startswith('task_'):
                task_name = name[len('task_'):]
                task = getattr(self, name)
                assert callable(task)
                task_deps = getattr(task, 'task_deps', [])

                tasks[task_name] = task, task_deps

    def _plan(self, goals, skip=[]):
        skip = [toskip for toskip in skip if toskip not in goals]

        key = (tuple(goals), tuple(skip))
        try:
            return self._plan_cache[key]
        except KeyError:
            pass
        constraints = []

        def subgoals(task_name):
            taskcallable, deps = self.tasks[task_name]
            for dep in deps:
                if dep.startswith('??'): # optional
                    dep = dep[2:]
                    if dep not in goals:
                        continue
                if dep.startswith('?'): # suggested
                    dep = dep[1:]
                    if dep in skip:
                        continue
                yield dep

        seen = {}

        def consider(subgoal):
            if subgoal in seen:
                return
            else:
                seen[subgoal] = True
            constraints.append([subgoal])
            deps = subgoals(subgoal)
            for dep in deps:
                constraints.append([subgoal, dep])
                consider(dep)

        for goal in goals:
            consider(goal)

        #sort

        plan = []

        while True:
            cands = dict.fromkeys([constr[0] for constr in constraints if constr])
            if not cands:
                break

            for cand in cands:
                for constr in constraints:
                    if cand in constr[1:]:
                        break
                else:
                    break
            else:
                raise RuntimeError("circular dependecy")

            plan.append(cand)
            for constr in constraints:
                if constr and constr[0] == cand:
                    del constr[0]

        plan.reverse()

        self._plan_cache[key] = plan

        return plan

    def _depending_on(self, goal):
        l = []
        for task_name, (task, task_deps) in self.tasks.iteritems():
            if goal in task_deps:
                l.append(task_name)
        return l

    def _depending_on_closure(self, goal):
        d = {}

        def track(goal):
            if goal in d:
                return
            d[goal] = True
            for depending in self._depending_on(goal):
                track(depending)
        track(goal)
        return d.keys()

    def _execute(self, goals, *args, **kwds):
        task_skip = kwds.get('task_skip', [])
        res = None
        goals = self._plan(goals, skip=task_skip)
        for goal in goals:
            taskcallable, _ = self.tasks[goal]
            self._event('planned', goal, taskcallable)
        for goal in goals:
            taskcallable, _ = self.tasks[goal]
            self._event('pre', goal, taskcallable)
            try:
                res = self._do(goal, taskcallable, *args, **kwds)
            except (SystemExit, KeyboardInterrupt):
                raise
            except:
                self._error(goal)
                raise
            self._event('post', goal, taskcallable)
        return res

    def _do(self, goal, func, *args, **kwds):
        return func()

    def _event(self, kind, goal, func):
        pass

    def _error(self, goal):
        pass
