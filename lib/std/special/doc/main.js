(function() {
    var domStatus = document.getElementById("status");
    var domSectPkgs = document.getElementById("sectPkgs");
    var domListPkgs = document.getElementById("listPkgs");
    var domSectTypes = document.getElementById("sectTypes");
    var domListTypes = document.getElementById("listTypes");

    var curNav = {
        kind: "pkg",
        index: zigAnalysis.rootPkg,
    };

    var rootIsStd = detectRootIsStd();
    var typeKindTypeId = findTypeKindType();
    var typeTypeId = findTypeTypeId();
    render();

    function render() {
        domStatus.classList.add("hidden");

        if (curNav.kind === "pkg") {
            var pkg = zigAnalysis.packages[curNav.index];
            renderPkgList(pkg);
            var pkgStruct = zigAnalysis.types[pkg.main];
            renderContainer(pkgStruct);
        } else {
            throw new Error("TODO");
        }
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

        resizeDomList(domListPkgs, list.length, '<li></li>');
        var domItems = domListPkgs.children;
        for (var i = 0; i < list.length; i += 1) {
            var domItem = domItems[i];
            domItem.textContent = list[i].name;
        }

        domSectPkgs.classList.remove("hidden");
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

        resizeDomList(domListTypes, list.length, '<li></li>');
        for (var i = 0; i < list.length; i += 1) {
            var domItem = domListTypes.children[i];
            var decl = list[i];
            domItem.textContent = decl.name;
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
})();
