(function() {
    var domStatus = document.getElementById("status");
    var domSectNav = document.getElementById("sectNav");
    var domListNav = document.getElementById("listNav");
    var domSectPkgs = document.getElementById("sectPkgs");
    var domListPkgs = document.getElementById("listPkgs");
    var domSectTypes = document.getElementById("sectTypes");
    var domListTypes = document.getElementById("listTypes");
    var domSectErrSets = document.getElementById("sectErrSets");
    var domListErrSets = document.getElementById("listErrSets");
    var domSectFns = document.getElementById("sectFns");
    var domListFns = document.getElementById("listFns");
    var domSectFields = document.getElementById("sectFields");
    var domListFields = document.getElementById("listFields");
    var domSectGlobalVars = document.getElementById("sectGlobalVars");
    var domListGlobalVars = document.getElementById("listGlobalVars");
    var domFnProto = document.getElementById("fnProto");
    var domFnProtoCode = document.getElementById("fnProtoCode");
    var domFnDocs = document.getElementById("fnDocs");
    var domSectFnErrors = document.getElementById("sectFnErrors");
    var domListFnErrors = document.getElementById("listFnErrors");
    var domTableFnErrors = document.getElementById("tableFnErrors");
    var domFnErrorsAnyError = document.getElementById("fnErrorsAnyError");
    var domFnExamples = document.getElementById("fnExamples");
    var domFnNoExamples = document.getElementById("fnNoExamples");
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
    var typeKindPtrId;
    var typeKindFloatId;
    var typeKindIntId;
    var typeKindBoolId;
    var typeKindVoidId;
    var typeKindErrSetId;
    var typeKindErrUnionId;
    findTypeKinds();

    // for each package, is an array with packages to get to this one
    var canonPkgPaths = computeCanonicalPackagePaths();
    // for each decl, is an array with {declNames, pkgNames} to get to this one
    var canonDeclPaths = null; // lazy; use getCanonDeclPath
    // for each type, is an array with {declNames, pkgNames} to get to this one
    var canonTypeDecls = null; // lazy; use getCanonTypeDecl

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

    // map of decl index to list of non-generic fn indexes
    var nodesToFnsMap = indexNodesToFns();
    // map of decl index to list of comptime fn calls
    var nodesToCallsMap = indexNodesToCalls();

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
        domSectErrSets.classList.add("hidden");
        domSectFns.classList.add("hidden");
        domSectFields.classList.add("hidden");
        domSectSearchResults.classList.add("hidden");
        domSectSearchNoResults.classList.add("hidden");
        domSectInfo.classList.add("hidden");
        domHdrName.classList.add("hidden");
        domSectNav.classList.add("hidden");
        domSectFnErrors.classList.add("hidden");
        domFnExamples.classList.add("hidden");
        domFnNoExamples.classList.add("hidden");
        domFnErrorsAnyError.classList.add("hidden");
        domTableFnErrors.classList.add("hidden");
        domSectGlobalVars.classList.add("hidden");

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
        if (lastDecl.kind === 'var') {
            return renderVar(lastDecl);
        }
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

    function typeIsErrSet(typeIndex) {
        var typeObj = zigAnalysis.types[typeIndex];
        return typeObj.kind === typeKindErrSetId;
    }

    function typeIsGenericFn(typeIndex) {
        var typeObj = zigAnalysis.types[typeIndex];
        if (typeObj.kind !== typeKindFnId) {
            return false;
        }
        return typeObj.generic;
    }

    function renderFn(fnDecl) {
        domFnProtoCode.innerHTML = typeIndexName(fnDecl.type, true, true, fnDecl);

        var docsSource = null;
        var srcNode = zigAnalysis.astNodes[fnDecl.src];
        if (srcNode.docs != null) {
            docsSource = srcNode.docs;
        }

        var typeObj = zigAnalysis.types[fnDecl.type];
        var errSetTypeIndex = null;
        if (typeObj.ret != null) {
            var retType = zigAnalysis.types[typeObj.ret];
            if (retType.kind === typeKindErrSetId) {
                errSetTypeIndex = typeObj.ret;
            } else if (retType.kind === typeKindErrUnionId) {
                errSetTypeIndex = retType.err;
            }
        }
        if (errSetTypeIndex != null) {
            var errSetType = zigAnalysis.types[errSetTypeIndex];
            if (errSetType.errors == null) {
                domFnErrorsAnyError.classList.remove("hidden");
            } else {
                var errorList = [];
                for (var i = 0; i < errSetType.errors.length; i += 1) {
                    var errObj = zigAnalysis.errors[errSetType.errors[i]];
                    var srcObj = zigAnalysis.astNodes[errObj.src];
                    errorList.push({
                        err: errObj,
                        docs: srcObj.docs,
                    });
                }
                errorList.sort(function(a, b) {
                    return operatorCompare(a.err.name.toLowerCase(), b.err.name.toLowerCase());
                });

                resizeDomList(domListFnErrors, errorList.length, '<tr><td></td><td></td></tr>');
                for (var i = 0; i < errorList.length; i += 1) {
                    var trDom = domListFnErrors.children[i];
                    var nameTdDom = trDom.children[0];
                    var descTdDom = trDom.children[1];
                    nameTdDom.textContent = errorList[i].err.name;
                    var docs = errorList[i].docs;
                    if (docs != null) {
                        descTdDom.innerHTML = markdown(docs);
                    } else {
                        descTdDom.textContent = "";
                    }
                }
                domTableFnErrors.classList.remove("hidden");
            }
            domSectFnErrors.classList.remove("hidden");
        }

        var protoSrcIndex;
        if (typeIsGenericFn(fnDecl.type)) {
            protoSrcIndex = fnDecl.value;

            var instantiations = nodesToFnsMap[protoSrcIndex];
            var calls = nodesToCallsMap[protoSrcIndex];
            if (instantiations == null && calls == null) {
                domFnNoExamples.classList.remove("hidden");
            } else {
                // TODO show examples
                domFnExamples.classList.remove("hidden");
            }
        } else {
            protoSrcIndex = zigAnalysis.fns[fnDecl.value].src;

            domFnExamples.classList.add("hidden");
            domFnNoExamples.classList.add("hidden");
        }

        var protoSrcNode = zigAnalysis.astNodes[protoSrcIndex];
        if (docsSource == null && protoSrcNode != null && protoSrcNode.docs != null) {
            docsSource = protoSrcNode.docs;
        }
        if (docsSource != null) {
            domFnDocs.innerHTML = markdown(docsSource);
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
            var pkgIndex = rootPkg.table[key];
            if (zigAnalysis.packages[pkgIndex] == null) continue;
            list.push({
                name: key,
                pkg: pkgIndex,
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
                if (list[i].name === curNav.pkgNames[0]) {
                    aDom.classList.add("active");
                } else {
                    aDom.classList.remove("active");
                }
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

    function typeIndexName(typeIndex, wantHtml, wantLink, fnDecl, skipFnName) {
        var typeObj = zigAnalysis.types[typeIndex];
        if (wantLink) {
            var declIndex = getCanonTypeDecl(typeIndex);
            var declPath = getCanonDeclPath(declIndex);
            var haveLink = declPath != null;
            var typeNameHtml = typeName(typeObj, true, !haveLink, fnDecl, skipFnName);
            if (haveLink) {
                return '<a href="' + navLink(declPath.pkgNames, declPath.declNames) + '">' + typeNameHtml + '</a>';
            } else {
                return typeNameHtml;
            }
        } else {
            return typeName(typeObj, wantHtml, false, fnDecl, skipFnName);
        }
    }

    function typeName(typeObj, wantHtml, wantSubLink, fnDecl, skipFnName) {
        switch (typeObj.kind) {
            case typeKindPtrId:
                var name = "";
                switch (typeObj.len) {
                    case 0:
                    default:
                        name += "*";
                        break;
                    case 1:
                        name += "[*]";
                        break;
                    case 2:
                        name += "[]";
                        break;
                    case 3:
                        name += "[*c]";
                        break;
                }
                if (typeObj['const']) {
                    if (wantHtml) {
                        name += '<span class="tok-kw">const</span> ';
                    } else {
                        name += "const ";
                    }
                }
                if (typeObj['volatile']) {
                    if (wantHtml) {
                        name += '<span class="tok-kw">volatile</span> ';
                    } else {
                        name += "volatile ";
                    }
                }
                if (typeObj.align != null) {
                    if (wantHtml) {
                        name += '<span class="tok-kw">align</span>(';
                    } else {
                        name += "align(";
                    }
                    if (wantHtml) {
                        name += '<span class="tok-number">' + typeObj.align + '</span>';
                    } else {
                        name += typeObj.align;
                    }
                    if (typeObj.hostIntBytes != null) {
                        name += ":";
                        if (wantHtml) {
                            name += '<span class="tok-number">' + typeObj.bitOffsetInHost + '</span>';
                        } else {
                            name += typeObj.bitOffsetInHost;
                        }
                        name += ":";
                        if (wantHtml) {
                            name += '<span class="tok-number">' + typeObj.hostIntBytes + '</span>';
                        } else {
                            name += typeObj.hostIntBytes;
                        }
                    }
                    name += ") ";
                }
                name += typeIndexName(typeObj.elem, wantHtml, wantSubLink, null);
                return name;
            case typeKindFloatId:
                if (wantHtml) {
                    return '<span class="tok-type">f' + typeObj.bits + '</span>';
                } else {
                    return "f" + typeObj.bits;
                }
            case typeKindIntId:
                var signed = (typeObj.i != null) ? 'i' : 'u';
                var bits = typeObj[signed];
                if (wantHtml) {
                    return '<span class="tok-type">' + signed + bits + '</span>';
                } else {
                    return signed + bits;
                }
            case typeKindTypeId:
                if (wantHtml) {
                    return '<span class="tok-type">type</span>';
                } else {
                    return "type";
                }
            case typeKindBoolId:
                if (wantHtml) {
                    return '<span class="tok-type">bool</span>';
                } else {
                    return "bool";
                }
            case typeKindVoidId:
                if (wantHtml) {
                    return '<span class="tok-type">void</span>';
                } else {
                    return "void";
                }
            case typeKindErrSetId:
                if (typeObj.errors == null) {
                    if (wantHtml) {
                        return '<span class="tok-type">anyerror</span>';
                    } else {
                        return "anyerror";
                    }
                } else {
                    if (wantHtml) {
                        return escapeHtml(typeObj.name);
                    } else {
                        return typeObj.name;
                    }
                }
            case typeKindErrUnionId:
                var errSetTypeObj = zigAnalysis.types[typeObj.err];
                var payloadHtml = typeIndexName(typeObj.payload, wantHtml, wantSubLink, null);
                if (fnDecl != null && errSetTypeObj.fn === fnDecl.value) {
                    // function index parameter supplied and this is the inferred error set of it
                    return "!" + payloadHtml;
                } else {
                    return typeIndexName(typeObj.err, wantHtml, wantSubLink, null) + "!" + payloadHtml;
                }
            case typeKindFnId:
                var payloadHtml = "";
                if (wantHtml) {
                    payloadHtml += '<span class="tok-kw">fn</span>';
                    if (fnDecl != null && !skipFnName) {
                        payloadHtml += ' <span class="tok-fn">' + escapeHtml(fnDecl.name) + '</span>';
                    }
                } else {
                    payloadHtml += 'fn'
                }
                payloadHtml += '(';
                if (typeObj.args != null) {
                    for (var i = 0; i < typeObj.args.length; i += 1) {
                        if (i != 0) {
                            payloadHtml += ', ';
                        }
                        var argTypeIndex = typeObj.args[i];
                        if (argTypeIndex != null) {
                            payloadHtml += typeIndexName(argTypeIndex, wantHtml, wantSubLink);
                        } else if (wantHtml) {
                            payloadHtml += '<span class="tok-kw">var</span>';
                        } else {
                            payloadHtml += 'var';
                        }
                    }
                }

                payloadHtml += ') ';
                if (typeObj.ret != null) {
                    payloadHtml += typeIndexName(typeObj.ret, wantHtml, wantSubLink, fnDecl);
                } else if (wantHtml) {
                    payloadHtml += '<span class="tok-kw">var</span>';
                } else {
                    payloadHtml += 'var';
                }
                return payloadHtml;
            default:
                if (wantHtml) {
                    return escapeHtml(typeObj.name);
                } else {
                    return typeObj.name;
                }
        }
    }

    function renderType(typeObj) {
        var name = typeName(typeObj, false, false);
        if (name != null && name != "") {
            domHdrName.innerText = zigAnalysis.typeKinds[typeObj.kind] + " " + name;
            domHdrName.classList.remove("hidden");
        }
    }

    function allCompTimeFnCallsHaveTypeResult(typeIndex, value) {
        var srcIndex = typeIsGenericFn(typeIndex) ? value : zigAnalysis.fns[value].src;
        var calls = nodesToCallsMap[srcIndex];
        if (calls == null) return false;
        for (var i = 0; i < calls.length; i += 1) {
            var call = zigAnalysis.calls[calls[i]];
            if (call.result.type !== typeTypeId) return false;
        }
        return true;
    }

    function renderVar(decl) {
        domFnProtoCode.innerHTML = '<span class="tok-kw">pub</span> <span class="tok-kw">var</span> ' +
            escapeHtml(decl.name) + ': ' + typeIndexName(decl.type, true, true);

        var docs = zigAnalysis.astNodes[decl.src].docs;
        if (docs != null) {
            domFnDocs.innerHTML = markdown(docs);
            domFnDocs.classList.remove("hidden");
        }

        domFnProto.classList.remove("hidden");
    }

    function renderContainer(container) {
        var typesList = [];
        var errSetsList = [];
        var fnsList = [];
        var varsList = [];
        for (var i = 0; i < container.pubDecls.length; i += 1) {
            var decl = zigAnalysis.decls[container.pubDecls[i]];
            if (decl.kind === 'var') {
                varsList.push(decl);
                continue;
            }
            if (decl.type != null) {
                if (decl.type == typeTypeId) {
                    if (typeIsErrSet(decl.value)) {
                        errSetsList.push(decl);
                    } else {
                        typesList.push(decl);
                    }
                } else {
                    var typeKind = zigAnalysis.types[decl.type].kind;
                    if (typeKind === typeKindFnId) {
                        if (allCompTimeFnCallsHaveTypeResult(decl.type, decl.value)) {
                            typesList.push(decl);
                        } else {
                            fnsList.push(decl);
                        }
                    }
                }
            }
        }
        typesList.sort(function(a, b) {
            return operatorCompare(a.name, b.name);
        });
        errSetsList.sort(function(a, b) {
            return operatorCompare(a.name, b.name);
        });
        fnsList.sort(function(a, b) {
            return operatorCompare(a.name, b.name);
        });
        varsList.sort(function(a, b) {
            return operatorCompare(a.name, b.name);
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

        if (errSetsList.length !== 0) {
            resizeDomList(domListErrSets, errSetsList.length, '<li><a href="#"></a></li>');
            for (var i = 0; i < errSetsList.length; i += 1) {
                var liDom = domListErrSets.children[i];
                var aDom = liDom.children[0];
                var decl = errSetsList[i];
                aDom.textContent = decl.name;
                aDom.setAttribute('href', navLinkDecl(decl.name));
            }
            domSectErrSets.classList.remove("hidden");
        }

        if (fnsList.length !== 0) {
            resizeDomList(domListFns, fnsList.length,
                '<tr><td><a href="#"></a></td><td></td><td></td></tr>');
            for (var i = 0; i < fnsList.length; i += 1) {
                var decl = fnsList[i];
                var trDom = domListFns.children[i];

                var tdName = trDom.children[0];
                var tdNameA = tdName.children[0];
                var tdType = trDom.children[1];
                var tdDesc = trDom.children[2];

                tdNameA.setAttribute('href', navLinkDecl(decl.name));
                tdNameA.textContent = decl.name;

                tdType.innerHTML = typeIndexName(decl.type, true, true, decl, true);

                var docs = zigAnalysis.astNodes[decl.src].docs;
                if (docs != null) {
                    tdDesc.innerHTML = shortDescMarkdown(docs);
                } else {
                    tdDesc.textContent = "";
                }
            }
            domSectFns.classList.remove("hidden");
        }

        if (container.fields.length !== 0) {
            resizeDomList(domListFields, container.fields.length, '<li></li>');
            for (var i = 0; i < container.fields.length; i += 1) {
                var liDom = domListFields.children[i];
                var field = container.fields[i];

                var protoHtml = escapeHtml(field.name) + ": ";
                protoHtml += typeIndexName(field.type, true, true);
                liDom.innerHTML = protoHtml;
            }
            domSectFields.classList.remove("hidden");
        }

        if (varsList.length !== 0) {
            resizeDomList(domListGlobalVars, varsList.length,
                '<tr><td><a href="#"></a></td><td></td><td></td></tr>');
            for (var i = 0; i < varsList.length; i += 1) {
                var decl = varsList[i];
                var trDom = domListGlobalVars.children[i];

                var tdName = trDom.children[0];
                var tdNameA = tdName.children[0];
                var tdType = trDom.children[1];
                var tdDesc = trDom.children[2];

                tdNameA.setAttribute('href', navLinkDecl(decl.name));
                tdNameA.textContent = decl.name;

                tdType.innerHTML = typeIndexName(decl.type, true, true);

                var docs = zigAnalysis.astNodes[decl.src].docs;
                if (docs != null) {
                    tdDesc.innerHTML = shortDescMarkdown(docs);
                } else {
                    tdDesc.textContent = "";
                }
            }
            domSectGlobalVars.classList.remove("hidden");
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
        if (stdPkg == null) return false;
        return rootPkg.file === stdPkg.file;
    }

    function findTypeKinds() {
        for (var i = 0; i < zigAnalysis.typeKinds.length; i += 1) {
            if (zigAnalysis.typeKinds[i] === "Type") {
                typeKindTypeId = i;
            } else if (zigAnalysis.typeKinds[i] === "Fn") {
                typeKindFnId = i;
            } else if (zigAnalysis.typeKinds[i] === "Pointer") {
                typeKindPtrId = i;
            } else if (zigAnalysis.typeKinds[i] === "Float") {
                typeKindFloatId = i;
            } else if (zigAnalysis.typeKinds[i] === "Int") {
                typeKindIntId = i;
            } else if (zigAnalysis.typeKinds[i] === "Bool") {
                typeKindBoolId = i;
            } else if (zigAnalysis.typeKinds[i] === "Void") {
                typeKindVoidId = i;
            } else if (zigAnalysis.typeKinds[i] === "ErrorSet") {
                typeKindErrSetId = i;
            } else if (zigAnalysis.typeKinds[i] === "ErrorUnion") {
                typeKindErrUnionId = i;
            }
        }
        if (typeKindTypeId == null) {
            throw new Error("No type kind 'Type' found");
        }
        if (typeKindFnId == null) {
            throw new Error("No type kind 'Fn' found");
        }
        if (typeKindPtrId == null) {
            throw new Error("No type kind 'Pointer' found");
        }
        if (typeKindFloatId == null) {
            throw new Error("No type kind 'Float' found");
        }
        if (typeKindIntId == null) {
            throw new Error("No type kind 'Int' found");
        }
        if (typeKindBoolId == null) {
            throw new Error("No type kind 'Bool' found");
        }
        if (typeKindVoidId == null) {
            throw new Error("No type kind 'Void' found");
        }
        if (typeKindErrSetId == null) {
            throw new Error("No type kind 'ErrorSet' found");
        }
        if (typeKindErrUnionId == null) {
            throw new Error("No type kind 'ErrorUnion' found");
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
                var childPkg = zigAnalysis.packages[childPkgIndex];
                if (childPkg == null) continue;

                var newPath = item.path.concat([key])
                list[childPkgIndex] = newPath;
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
        canonTypeDecls = new Array(zigAnalysis.types.length);

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
                        if (decl.type === typeTypeId) {
                            canonTypeDecls[decl.value] = mainDeclIndex;
                        }
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

    function getCanonTypeDecl(index) {
        getCanonDeclPath(0);
        return canonTypeDecls[index];
    }

    function escapeHtml(text) {
        return text.replace(/[&"<>]/g, function (m) {
            return escapeHtmlReplacements[m];
        });
    }

    function shortDescMarkdown(docs) {
        var parts = docs.trim().split("\n");
        var firstLine = parts[0];
        return markdown(firstLine);
    }

    function markdown(mdText) {
        // TODO implement more
        return escapeHtml(mdText);
    }

    function onSearchKeyDown(ev) {
        switch (ev.which) {
            case 13:
                var liDom = domListSearchResults.children[curSearchIndex];
                if (liDom == null && domListSearchResults.children.length !== 0) {
                    liDom = domListSearchResults.children[0];
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
                domSearch.select();
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
            var fullPathSearchText = lastPkgName + "." + canonPath.declNames.join('.');
            var astNode = zigAnalysis.astNodes[decl.src];
            var fileAndDocs = zigAnalysis.files[astNode.file];
            if (astNode.docs != null) {
                fileAndDocs += "\n" + astNode.docs;
            }
            var fullPathSearchTextLower = fullPathSearchText;
            if (ignoreCase) {
                fullPathSearchTextLower = fullPathSearchTextLower.toLowerCase();
                fileAndDocs = fileAndDocs.toLowerCase();
            }

            var points = 0;
            for (var termIndex = 0; termIndex < terms.length; termIndex += 1) {
                var term = terms[termIndex];

                // exact, case sensitive match of full decl path
                if (fullPathSearchText === term) {
                    points += 4;
                    continue;
                }
                // exact, case sensitive match of just decl name
                if (decl.name == term) {
                    points += 3;
                    continue;
                }
                // substring, case insensitive match of full decl path
                if (fullPathSearchTextLower.indexOf(term) >= 0) {
                    points += 2;
                    continue;
                }
                if (fileAndDocs.indexOf(term) >= 0) {
                    points += 1;
                    continue;
                }

                continue decl_loop;
            }

            matchedItems.push({
                decl: decl,
                path: canonPath,
                points: points,
            });
        }

        if (matchedItems.length !== 0) {
            resizeDomList(domListSearchResults, matchedItems.length, '<li><a href="#"></a></li>');

            matchedItems.sort(function(a, b) {
                var cmp = operatorCompare(b.points, a.points);
                if (cmp != 0) return cmp;
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

    function indexNodesToFns() {
        var map = {};
        for (var i = 0; i < zigAnalysis.fns.length; i += 1) {
            var fn = zigAnalysis.fns[i];
            if (typeIsGenericFn(fn.type)) continue;
            if (map[fn.src] == null) {
                map[fn.src] = [i];
            } else {
                map[fn.src].push(i);
            }
        }
        return map;
    }

    function indexNodesToCalls() {
        var map = {};
        for (var i = 0; i < zigAnalysis.calls.length; i += 1) {
            var call = zigAnalysis.calls[i];
            var fn = zigAnalysis.fns[call.fn];
            if (map[fn.src] == null) {
                map[fn.src] = [i];
            } else {
                map[fn.src].push(i);
            }
        }
        return map;
    }
})();
