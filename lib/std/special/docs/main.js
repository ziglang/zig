(function() {
    var domStatus = document.getElementById("status");
    var domSectNav = document.getElementById("sectNav");
    var domListNav = document.getElementById("listNav");
    var domSectPkgs = document.getElementById("sectPkgs");
    var domListPkgs = document.getElementById("listPkgs");
    var domSectTypes = document.getElementById("sectTypes");
    var domListTypes = document.getElementById("listTypes");
    var domSectFns = document.getElementById("sectFns");
    var domListFns = document.getElementById("listFns");
    var domFnProto = document.getElementById("fnProto");
    var domFnProtoCode = document.getElementById("fnProtoCode");
    var domFnDocs = document.getElementById("fnDocs");
    var domSearch = document.getElementById("search");
    var domSectSearchResults = document.getElementById("sectSearchResults");
    var domListSearchResults = document.getElementById("listSearchResults");
    var domSectSearchNoResults = document.getElementById("sectSearchNoResults");
    var domSectInfo = document.getElementById("sectInfo");
    var domListInfo = document.getElementById("listInfo");
    var domTdTarget = document.getElementById("tdTarget");
    var domTdZigVer = document.getElementById("tdZigVer");
    var domHdrName = document.getElementById("hdrName");
    var domHelpModal = document.getElementById("helpDialog");

    var searchTimer = null;
    var escapeHtmlReplacements = { "&": "&amp;", '"': "&quot;", "<": "&lt;", ">": "&gt;" };

    var typeKindTypeId;
    var typeKindFnId;
    findTypeKinds();

    // for each package, is an array with packages to get to this one
    var canonPkgPaths = computeCanonicalPackagePaths();
    var canonDeclPaths = null; // lazy; use getCanonDeclPath

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
    var curNavSearch = "";
    var curSearchIndex = -1;

    var rootIsStd = detectRootIsStd();
    var typeTypeId = findTypeTypeId();
    domSearch.addEventListener('keydown', onSearchKeyDown, false);
    window.addEventListener('hashchange', onHashChange, false);
    window.addEventListener('keydown', onWindowKeyDown, false);
    onHashChange();

    function renderTitle() {
        var list = curNav.pkgNames.concat(curNav.declNames);
        var suffix = " - Zig";
        if (list.length === 0) {
            if (rootIsStd) {
                document.title = "std" + suffix;
            } else {
                document.title = zigAnalysis.params.rootName + suffix;
            }
        } else {
            document.title = list.join('.') + suffix;
        }
    }

    function render() {
        domStatus.classList.add("hidden");
        domFnProto.classList.add("hidden");
        domFnDocs.classList.add("hidden");
        domSectPkgs.classList.add("hidden");
        domSectTypes.classList.add("hidden");
        domSectFns.classList.add("hidden");
        domSectSearchResults.classList.add("hidden");
        domSectSearchNoResults.classList.add("hidden");
        domSectInfo.classList.add("hidden");
        domHdrName.classList.add("hidden");
        domSectNav.classList.add("hidden");

        renderTitle();
        renderInfo();
        renderPkgList();

        if (curNavSearch !== "") {
            return renderSearch();
        }

        var rootPkg = zigAnalysis.packages[zigAnalysis.rootPkg];
        var pkg = rootPkg;
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

        renderNav();

        var lastDecl = curNav.declObjs[curNav.declObjs.length - 1];
        if (lastDecl.type != null) {
            var typeObj = zigAnalysis.types[lastDecl.type];
            if (typeObj.kind === typeKindFnId) {
                return renderFn(lastDecl);
            }
            throw new Error("docs for this decl which is not a container");
        }
        renderType(lastDecl);
        if (lastDecl.pubDecls != null) {
            renderContainer(lastDecl);
        }
    }

    function renderFn(fnDecl) {
        var typeObj = zigAnalysis.types[fnDecl.type];
        domFnProtoCode.textContent = "fn " + fnDecl.name + typeObj.name.substring(2);

        var srcNode = zigAnalysis.astNodes[fnDecl.src];
        if (srcNode.docs != null) {
            domFnDocs.innerHTML = markdown(srcNode.docs);
            domFnDocs.classList.remove("hidden");
        }

        domFnProto.classList.remove("hidden");
    }

    function renderNav() {
        var len = curNav.pkgNames.length + curNav.declNames.length;
        resizeDomList(domListNav, len, '<li><a href="#"></a></li>');
        var list = [];
        var hrefPkgNames = [];
        var hrefDeclNames = [];
        for (var i = 0; i < curNav.pkgNames.length; i += 1) {
            hrefPkgNames.push(curNav.pkgNames[i]);
            list.push({
                name: curNav.pkgNames[i],
                link: navLink(hrefPkgNames, hrefDeclNames),
            });
        }
        for (var i = 0; i < curNav.declNames.length; i += 1) {
            hrefDeclNames.push(curNav.declNames[i]);
            list.push({
                name: curNav.declNames[i],
                link: navLink(hrefPkgNames, hrefDeclNames),
            });
        }

        for (var i = 0; i < list.length; i += 1) {
            var liDom = domListNav.children[i];
            var aDom = liDom.children[0];
            aDom.textContent = list[i].name;
            aDom.setAttribute('href', list[i].link);
            if (i + 1 == list.length) {
                aDom.classList.add("active");
            } else {
                aDom.classList.remove("active");
            }
        }

        domSectNav.classList.remove("hidden");
    }

    function renderInfo() {
        domTdZigVer.textContent = zigAnalysis.params.zigVersion;
        domTdTarget.textContent = zigAnalysis.params.target;

        domSectInfo.classList.remove("hidden");
    }

    function render404() {
        domStatus.textContent = "404 Not Found";
        domStatus.classList.remove("hidden");
    }

    function renderPkgList() {
        var rootPkg = zigAnalysis.packages[zigAnalysis.rootPkg];
        var list = [];
        for (var key in rootPkg.table) {
            if (key === "root" && rootIsStd) continue;
            list.push({
                name: key,
                pkg: rootPkg.table[key],
            });
        }
        list.sort(function(a, b) {
            return operatorCompare(a.name.toLowerCase(), b.name.toLowerCase());
        });

        if (list.length !== 0) {
            resizeDomList(domListPkgs, list.length, '<li><a href="#"></a></li>');
            for (var i = 0; i < list.length; i += 1) {
                var liDom = domListPkgs.children[i];
                var aDom = liDom.children[0];
                aDom.textContent = list[i].name;
                aDom.setAttribute('href', navLinkPkg(list[i].pkg));
            }

            domSectPkgs.classList.remove("hidden");
        }
    }

    function navLink(pkgNames, declNames) {
        if (pkgNames.length === 0 && declNames.length === 0) {
            return '#';
        } else if (declNames.length === 0) {
            return '#' + pkgNames.join('.');
        } else {
            return '#' + pkgNames.join('.') + ';' + declNames.join('.');
        }
    }

    function navLinkPkg(pkgIndex) {
        return navLink(canonPkgPaths[pkgIndex], []);
    }

    function navLinkDecl(childName) {
        return navLink(curNav.pkgNames, curNav.declNames.concat([childName]));
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

    function renderType(typeObj) {
        if (typeObj.name != null && typeObj.name != "") {
            domHdrName.innerText = zigAnalysis.typeKinds[typeObj.kind] + " " + typeObj.name;
            domHdrName.classList.remove("hidden");
        }
    }

    function renderContainer(container) {
        var typesList = [];
        var fnsList = [];
        for (var i = 0; i < container.pubDecls.length; i += 1) {
            var decl = zigAnalysis.decls[container.pubDecls[i]];
            if (decl.type != null) {
                if (decl.type == typeTypeId) {
                    typesList.push(decl);
                } else {
                    var typeKind = zigAnalysis.types[decl.type].kind;
                    if (typeKind === typeKindFnId) {
                        fnsList.push(decl);
                    }
                }
            }
        }
        typesList.sort(function(a, b) {
            return operatorCompare(a.name.toLowerCase(), b.name.toLowerCase());
        });
        fnsList.sort(function(a, b) {
            return operatorCompare(a.name.toLowerCase(), b.name.toLowerCase());
        });

        if (typesList.length !== 0) {
            resizeDomList(domListTypes, typesList.length, '<li><a href="#"></a></li>');
            for (var i = 0; i < typesList.length; i += 1) {
                var liDom = domListTypes.children[i];
                var aDom = liDom.children[0];
                var decl = typesList[i];
                aDom.textContent = decl.name;
                aDom.setAttribute('href', navLinkDecl(decl.name));
            }
            domSectTypes.classList.remove("hidden");
        }

        if (fnsList.length !== 0) {
            resizeDomList(domListFns, fnsList.length, '<li><a href="#"></a></li>');
            for (var i = 0; i < fnsList.length; i += 1) {
                var liDom = domListFns.children[i];
                var aDom = liDom.children[0];
                var decl = fnsList[i];
                aDom.textContent = decl.name;
                aDom.setAttribute('href', navLinkDecl(decl.name));
            }
            domSectFns.classList.remove("hidden");
        }
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

    function findTypeKinds() {
        for (var i = 0; i < zigAnalysis.typeKinds.length; i += 1) {
            if (zigAnalysis.typeKinds[i] === "Type") {
                typeKindTypeId = i;
            } else if (zigAnalysis.typeKinds[i] === "Fn") {
                typeKindFnId = i;
            }
        }
        if (typeKindTypeId == null) {
            throw new Error("No type kind 'Type' found");
        }
        if (typeKindFnId == null) {
            throw new Error("No type kind 'Fn' found");
        }
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
        curNavSearch = "";

        if (location.hash[0] === '#' && location.hash.length > 1) {
            var query = location.hash.substring(1);
            var qpos = query.indexOf("?");
            if (qpos === -1) {
                nonSearchPart = query;
            } else {
                nonSearchPart = query.substring(0, qpos);
                curNavSearch = decodeURIComponent(query.substring(qpos + 1));
            }

            var parts = nonSearchPart.split(";");
            curNav.pkgNames = decodeURIComponent(parts[0]).split(".");
            if (parts[1] != null) {
                curNav.declNames = decodeURIComponent(parts[1]).split(".");
            }
        }
        if (domSearch.value !== curNavSearch) {
            domSearch.value = curNavSearch;
        }
        render();
    }

    function findSubDecl(parentType, childName) {
        if (parentType.pubDecls == null) throw new Error("parent object has no public decls");
        for (var i = 0; i < parentType.pubDecls.length; i += 1) {
            var declIndex = parentType.pubDecls[i];
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

    function computeCanonicalPackagePaths() {
        var list = new Array(zigAnalysis.packages.length);
        // Now we try to find all the packages from root.
        var rootPkg = zigAnalysis.packages[zigAnalysis.rootPkg];
        // Breadth-first to keep the path shortest possible.
        var stack = [{
            path: [],
            pkg: rootPkg,
        }];
        while (stack.length !== 0) {
            var item = stack.shift();
            for (var key in item.pkg.table) {
                var childPkgIndex = item.pkg.table[key];
                if (list[childPkgIndex] != null) continue;

                var newPath = item.path.concat([key])
                list[childPkgIndex] = newPath;
                var childPkg = zigAnalysis.packages[childPkgIndex];
                stack.push({
                    path: newPath,
                    pkg: childPkg,
                });
            }
        }
        return list;
    }

    function computeCanonDeclPaths() {
        var list = new Array(zigAnalysis.decls.length);

        for (var pkgI = 0; pkgI < zigAnalysis.packages.length; pkgI += 1) {
            if (pkgI === zigAnalysis.rootPkg && rootIsStd) continue;
            var pkg = zigAnalysis.packages[pkgI];
            var pkgNames = canonPkgPaths[pkgI];
            var stack = [{
                declNames: [],
                type: zigAnalysis.types[pkg.main],
            }];
            while (stack.length !== 0) {
                var item = stack.shift();

                if (item.type.pubDecls != null) {
                    for (var declI = 0; declI < item.type.pubDecls.length; declI += 1) {
                        var mainDeclIndex = item.type.pubDecls[declI];
                        if (list[mainDeclIndex] != null) continue;

                        var decl = zigAnalysis.decls[mainDeclIndex];
                        var declNames = item.declNames.concat([decl.name]);
                        list[mainDeclIndex] = {
                            pkgNames: pkgNames,
                            declNames: declNames,
                        };
                        var containerType = getDeclContainerType(decl);
                        if (containerType != null) {
                            stack.push({
                                declNames: declNames,
                                type: containerType,
                            });
                        }
                    }
                }
            }
        }
        return list;
    }

    function getCanonDeclPath(index) {
        if (canonDeclPaths == null) {
            canonDeclPaths = computeCanonDeclPaths();
        }
        return canonDeclPaths[index];
    }

    function markdown(mdText) {
        return mdText.replace(/[&"<>]/g, function (m) {
            return escapeHtmlReplacements[m];
        });
    }

    function onSearchKeyDown(ev) {
        switch (ev.which) {
            case 13:
                var liDom = null;
                if (domListSearchResults.children.length === 1) {
                    liDom = domListSearchResults.children[0];
                } else {
                    liDom = domListSearchResults.children[curSearchIndex];
                }
                if (liDom != null) {
                    var aDom = liDom.children[0];
                    location.href = aDom.getAttribute("href");
                    curSearchIndex = -1;
                    ev.preventDefault();
                    ev.stopPropagation();
                    return;
                }
            case 27:
                domSearch.value = "";
                domSearch.blur();
                curSearchIndex = -1;
                ev.preventDefault();
                ev.stopPropagation();
                startSearch();
                return;
            case 38:
                moveSearchCursor(-1);
                ev.preventDefault();
                ev.stopPropagation();
                return;
            case 40:
                moveSearchCursor(1);
                ev.preventDefault();
                ev.stopPropagation();
                return;
            default:
                curSearchIndex = -1;
                ev.stopPropagation();
                startAsyncSearch();
        }
    }

    function moveSearchCursor(dir) {
        if (curSearchIndex < 0 || curSearchIndex >= domListSearchResults.children.length) {
            if (dir > 0) {
                curSearchIndex = -1 + dir;
            } else if (dir < 0) {
                curSearchIndex = domListSearchResults.children.length + dir;
            }
        } else {
            curSearchIndex += dir;
        }
        if (curSearchIndex < 0) {
            curSearchIndex = 0;
        }
        if (curSearchIndex >= domListSearchResults.children.length) {
            curSearchIndex = domListSearchResults.children.length - 1;
        }
        renderSearchCursor();
    }

    function onWindowKeyDown(ev) {
        switch (ev.which) {
            case 27:
                if (!domHelpModal.classList.contains("hidden")) {
                    domHelpModal.classList.add("hidden");
                    ev.preventDefault();
                    ev.stopPropagation();
                }
                break;
            case 83:
                domSearch.focus();
                ev.preventDefault();
                ev.stopPropagation();
                startAsyncSearch();
                break;
            case 191:
                ev.preventDefault();
                ev.stopPropagation();
                showHelpModal();
                break;
        }
    }

    function showHelpModal() {
        domHelpModal.classList.remove("hidden");
        domHelpModal.style.left = (window.innerWidth / 2 - domHelpModal.clientWidth / 2) + "px";
        domHelpModal.style.top = (window.innerHeight / 2 - domHelpModal.clientHeight / 2) + "px";
        domHelpModal.focus();
    }

    function clearAsyncSearch() {
        if (searchTimer != null) clearTimeout(searchTimer);
    }

    function startAsyncSearch() {
        clearAsyncSearch();
        searchTimer = setTimeout(startSearch, 100);
    }
    function startSearch() {
        var parts = location.hash.split("?");
        var newPart2 = (domSearch.value === "") ? "" : ("?" + domSearch.value);
        if (parts.length === 1) {
            location.hash = location.hash + newPart2;
        } else {
            location.hash = parts[0] + newPart2;
        }
    }
    function renderSearch() {
        var matchedItems = [];
        var ignoreCase = (curNavSearch.toLowerCase() === curNavSearch);
        var terms = curNavSearch.split(/[ \r\n\t]+/);

        decl_loop: for (var declIndex = 0; declIndex < zigAnalysis.decls.length; declIndex += 1) {
            var canonPath = getCanonDeclPath(declIndex);
            if (canonPath == null) continue;

            var decl = zigAnalysis.decls[declIndex];
            var lastPkgName = canonPath.pkgNames[canonPath.pkgNames.length - 1];
            var searchText = lastPkgName + "." + canonPath.declNames.join('.');
            var astNode = zigAnalysis.astNodes[decl.src];
            if (astNode.docs != null) {
                searchText += "\n" + astNode.docs;
            }
            var file = zigAnalysis.files[astNode.file];
            searchText += "\n" + file;
            if (ignoreCase) {
                searchText = searchText.toLowerCase();
            }

            for (var termIndex = 0; termIndex < terms.length; termIndex += 1) {
                var term = terms[termIndex];
                if (searchText.indexOf(term) >= 0) {
                    continue;
                } else {
                    continue decl_loop;
                }
            }

            matchedItems.push({
                decl: decl,
                path: canonPath,
            });
        }

        if (matchedItems.length !== 0) {
            resizeDomList(domListSearchResults, matchedItems.length, '<li><a href="#"></a></li>');

            matchedItems.sort(function(a, b) {
                return operatorCompare(a.decl.name, b.decl.name);
            });

            for (var i = 0; i < matchedItems.length; i += 1) {
                var liDom = domListSearchResults.children[i];
                var aDom = liDom.children[0];
                var match = matchedItems[i];
                var lastPkgName = match.path.pkgNames[match.path.pkgNames.length - 1];
                aDom.textContent = lastPkgName + "." + match.path.declNames.join('.');
                aDom.setAttribute('href', navLink(match.path.pkgNames, match.path.declNames));
            }
            renderSearchCursor();

            domSectSearchResults.classList.remove("hidden");
        } else {
            domSectSearchNoResults.classList.remove("hidden");
        }
    }

    function renderSearchCursor() {
        for (var i = 0; i < domListSearchResults.children.length; i += 1) {
            var liDom = domListSearchResults.children[i];
            if (curSearchIndex === i) {
                liDom.classList.add("selected");
            } else {
                liDom.classList.remove("selected");
            }
        }
    }
})();
