(function() {
    var domStatus = document.getElementById("status");
    var domSectPkgs = document.getElementById("sectPkgs");
    var domListPkgs = document.getElementById("listPkgs");
    var domSectTypes = document.getElementById("sectTypes");
    var domListTypes = document.getElementById("listTypes");

    var curNav = {
        // each element is a package name, e.g. @import("a") then within there @import("b")
        // starting implicitly from root package
        pkgNames: [],
        // same as above except actual packages, not names
        pkgObjs: [],
        // Each element is a decl name, `a.b.c`, a is 0, b is 1, c is 2, etc.
        // empty array means refers to the package itself
        declNames: [],
        // these will be all types, except the last one may be a type or a decl
        declObjs: [],
    };

    var rootIsStd = detectRootIsStd();
    var typeKindTypeId = findTypeKindType();
    var typeTypeId = findTypeTypeId();
    window.addEventListener('hashchange', onHashChange, false);
    onHashChange();

    function render() {
        domStatus.classList.add("hidden");

        var pkg = zigAnalysis.packages[zigAnalysis.rootPkg];
        curNav.pkgObjs = [pkg];
        for (var i = 0; i < curNav.pkgNames.length; i += 1) {
            var childPkg = zigAnalysis.packages[pkg.table[curNav.pkgNames[i]]];
            if (childPkg == null) {
                return render404();
            }
            pkg = childPkg;
            curNav.pkgObjs.push(pkg);
        }

        var decl = zigAnalysis.types[pkg.main];
        curNav.declObjs = [decl];
        for (var i = 0; i < curNav.declNames.length; i += 1) {
            var childDecl = findSubDecl(decl, curNav.declNames[i]);
            if (childDecl == null) {
                return render404();
            }
            var container = getDeclContainerType(childDecl);
            if (container == null) {
                if (i + 1 === curNav.declNames.length) {
                    curNav.declObjs.push(childDecl);
                    break;
                } else {
                    return render404();
                }
            }
            decl = container;
            curNav.declObjs.push(decl);
        }

        var lastPkg = curNav.pkgObjs[curNav.pkgObjs.length - 1];
        renderPkgList(lastPkg);

        var lastDecl = curNav.declObjs[curNav.declObjs.length - 1];
        if (lastDecl.decls != null) {
            return renderContainer(lastDecl);
        } else {
            throw new Error("docs for this decl which is not a container");
        }
    }

    function render404() {
        domStatus.textContent = "404 Not Found";
        domStatus.classList.remove("hidden");
        domSectPkgs.classList.add("hidden");
        domSectTypes.classList.add("hidden");
    }

    function renderPkgList(pkg) {
        var list = [];
        for (var key in pkg.table) {
            if (key === "root" && rootIsStd) continue;
            list.push({
                name: key,
                pkg: pkg.table[key],
            });
        }
        list.sort(function(a, b) {
            return operatorCompare(a.name.toLowerCase(), b.name.toLowerCase());
        });

        if (list.length === 0) {
            domSectPkgs.classList.add("hidden");
        } else {
            resizeDomList(domListPkgs, list.length, '<li><a href="#"></a></li>');
            for (var i = 0; i < list.length; i += 1) {
                var liDom = domListPkgs.children[i];
                var aDom = liDom.children[0];
                aDom.textContent = list[i].name;
                aDom.setAttribute('href', navLinkPkg(list[i].name));
            }

            domSectPkgs.classList.remove("hidden");
        }
    }

    function navLinkPkg(childName) {
        return '#' + (curNav.pkgNames.concat([childName])).join(',');
    }

    function navLinkDecl(childName) {
        return '#' + curNav.pkgNames.join(",") + ';' + (curNav.declNames.concat([childName])).join(",");
    }

    function resizeDomList(listDom, desiredLen, templateHtml) {
        // add the missing dom entries
        var i, ev;
        for (i = listDom.childElementCount; i < desiredLen; i += 1) {
            listDom.insertAdjacentHTML('beforeend', templateHtml);
        }
        // remove extra dom entries
        while (desiredLen < listDom.childElementCount) {
            listDom.removeChild(listDom.lastChild);
        }
    }

    function renderContainer(container) {
        // Find only the types of this package
        var list = [];
        for (var i = 0; i < container.decls.length; i += 1) {
            var decl = zigAnalysis.decls[container.decls[i]];
            if (decl.type == typeTypeId) {
                list.push(decl);
            }
        }
        list.sort(function(a, b) {
            return operatorCompare(a.name.toLowerCase(), b.name.toLowerCase());
        });

        resizeDomList(domListTypes, list.length, '<li><a href="#"></a></li>');
        for (var i = 0; i < list.length; i += 1) {
            var liDom = domListTypes.children[i];
            var aDom = liDom.children[0];
            var decl = list[i];
            aDom.textContent = decl.name;
            aDom.setAttribute('href', navLinkDecl(decl.name));
        }

        domSectTypes.classList.remove("hidden");
    }

    function operatorCompare(a, b) {
        if (a === b) {
            return 0;
        } else if (a < b) {
            return -1;
        } else {
            return 1;
        }
    }

    function detectRootIsStd() {
        var rootPkg = zigAnalysis.packages[zigAnalysis.rootPkg];
        if (rootPkg.table["std"] == null) {
            // no std mapped into the root package
            return false;
        }
        var stdPkg = zigAnalysis.packages[rootPkg.table["std"]];
        return rootPkg.file === stdPkg.file;
    }

    function findTypeKindType() {
        for (var i = 0; i < zigAnalysis.typeKinds.length; i += 1) {
            if (zigAnalysis.typeKinds[i] === "Type") {
                return i;
            }
        }
        throw new Error("No type kind 'Type' found");
    }

    function findTypeTypeId() {
        for (var i = 0; i < zigAnalysis.types.length; i += 1) {
            if (zigAnalysis.types[i].kind == typeKindTypeId) {
                return i;
            }
        }
        throw new Error("No type 'type' found");
    }

    function onHashChange() {
        curNav = {
            pkgNames: [],
            pkgObjs: [],
            declNames: [],
            declObjs: [],
        };
        if (location.hash[0] === '#') {
            var parts = location.hash.substring(1).split(";");
            curNav.pkgNames = parts[0].split(".");
            if (parts[1] != null) {
                curNav.declNames = parts[1] ? parts[1].split(".") : [];
            }
        }
        render();
    }

    function findSubDecl(parentType, childName) {
        if (parentType.decls == null) throw new Error("parent object has no decls");
        for (var i = 0; i < parentType.decls.length; i += 1) {
            var declIndex = parentType.decls[i];
            var childDecl = zigAnalysis.decls[declIndex];
            if (childDecl.name === childName) {
                return childDecl;
            }
        }
        return null;
    }

    function getDeclContainerType(decl) {
        if (decl.type === typeTypeId) {
            return zigAnalysis.types[decl.value];
        }
        return null;
    }
})();
