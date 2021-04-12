(function() {
    var domStatus = document.getElementById("status");
    var domSectNav = document.getElementById("sectNav");
    var domListNav = document.getElementById("listNav");
    var domSectPkgs = document.getElementById("sectPkgs");
    var domListPkgs = document.getElementById("listPkgs");
    var domSectTypes = document.getElementById("sectTypes");
    var domListTypes = document.getElementById("listTypes");
    var domSectNamespaces = document.getElementById("sectNamespaces");
    var domListNamespaces = document.getElementById("listNamespaces");
    var domSectErrSets = document.getElementById("sectErrSets");
    var domListErrSets = document.getElementById("listErrSets");
    var domSectFns = document.getElementById("sectFns");
    var domListFns = document.getElementById("listFns");
    var domSectFields = document.getElementById("sectFields");
    var domListFields = document.getElementById("listFields");
    var domSectGlobalVars = document.getElementById("sectGlobalVars");
    var domListGlobalVars = document.getElementById("listGlobalVars");
    var domSectValues = document.getElementById("sectValues");
    var domListValues = document.getElementById("listValues");
    var domFnProto = document.getElementById("fnProto");
    var domFnProtoCode = document.getElementById("fnProtoCode");
    var domSectParams = document.getElementById("sectParams");
    var domListParams = document.getElementById("listParams");
    var domTldDocs = document.getElementById("tldDocs");
    var domSectFnErrors = document.getElementById("sectFnErrors");
    var domListFnErrors = document.getElementById("listFnErrors");
    var domTableFnErrors = document.getElementById("tableFnErrors");
    var domFnErrorsAnyError = document.getElementById("fnErrorsAnyError");
    var domFnExamples = document.getElementById("fnExamples");
    var domListFnExamples = document.getElementById("listFnExamples");
    var domFnNoExamples = document.getElementById("fnNoExamples");
    var domDeclNoRef = document.getElementById("declNoRef");
    var domSearch = document.getElementById("search");
    var domSectSearchResults = document.getElementById("sectSearchResults");
    var domListSearchResults = document.getElementById("listSearchResults");
    var domSectSearchNoResults = document.getElementById("sectSearchNoResults");
    var domSectSearchAllResultsLink = document.getElementById("sectSearchAllResultsLink");
    var domSectInfo = document.getElementById("sectInfo");
    var domTdTarget = document.getElementById("tdTarget");
    var domTdZigVer = document.getElementById("tdZigVer");
    var domHdrName = document.getElementById("hdrName");
    var domHelpModal = document.getElementById("helpDialog");

    var searchTimer = null;
    var searchTrimResults = true;
    var escapeHtmlReplacements = { "&": "&amp;", '"': "&quot;", "<": "&lt;", ">": "&gt;" };

    var typeKinds = indexTypeKinds();
    var typeTypeId = findTypeTypeId();
    var pointerSizeEnum = { One: 0, Many: 1, Slice: 2, C: 3 };
    var tokenKinds = {
        Keyword: 'tok-kw',
        String: 'tok-str',
        Builtin: 'tok-builtin',
        Comment: 'tok-comment',
        Function: 'tok-fn',
        Null: 'tok-null',
        Number: 'tok-number',
        Type: 'tok-type',
    };

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

        // (a, b, c, d) comptime call; result is the value the docs refer to
        callName: null,
    };
    var curNavSearch = "";
    var curSearchIndex = -1;
    var imFeelingLucky = false;

    var rootIsStd = detectRootIsStd();

    // map of decl index to list of non-generic fn indexes
    var nodesToFnsMap = indexNodesToFns();
    // map of decl index to list of comptime fn calls
    var nodesToCallsMap = indexNodesToCalls();

    domSearch.addEventListener('keydown', onSearchKeyDown, false);
    domSectSearchAllResultsLink.addEventListener('click', onClickSearchShowAllResults, false);

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
        domSectParams.classList.add("hidden");
        domTldDocs.classList.add("hidden");
        domSectPkgs.classList.add("hidden");
        domSectTypes.classList.add("hidden");
        domSectNamespaces.classList.add("hidden");
        domSectErrSets.classList.add("hidden");
        domSectFns.classList.add("hidden");
        domSectFields.classList.add("hidden");
        domSectSearchResults.classList.add("hidden");
        domSectSearchNoResults.classList.add("hidden");
        domSectSearchAllResultsLink.classList.add("hidden");
        domSectInfo.classList.add("hidden");
        domHdrName.classList.add("hidden");
        domSectNav.classList.add("hidden");
        domSectFnErrors.classList.add("hidden");
        domFnExamples.classList.add("hidden");
        domFnNoExamples.classList.add("hidden");
        domDeclNoRef.classList.add("hidden");
        domFnErrorsAnyError.classList.add("hidden");
        domTableFnErrors.classList.add("hidden");
        domSectGlobalVars.classList.add("hidden");
        domSectValues.classList.add("hidden");

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
        if (lastDecl.pubDecls != null) {
            renderContainer(lastDecl);
        }
        if (lastDecl.kind == null) {
            return renderUnknownDecl(lastDecl);
        } else if (lastDecl.kind === 'var') {
            return renderVar(lastDecl);
        } else if (lastDecl.kind === 'const' && lastDecl.type != null) {
            var typeObj = zigAnalysis.types[lastDecl.type];
            if (typeObj.kind === typeKinds.Fn) {
                return renderFn(lastDecl);
            } else {
                return renderValue(lastDecl);
            }
        } else {
            renderType(lastDecl);
        }
    }

    function renderUnknownDecl(decl) {
        domDeclNoRef.classList.remove("hidden");

        var docs = zigAnalysis.astNodes[decl.src].docs;
        if (docs != null) {
            domTldDocs.innerHTML = markdown(docs);
        } else {
            domTldDocs.innerHTML = '<p>There are no doc comments for this declaration.</p>';
        }
        domTldDocs.classList.remove("hidden");
    }

    function typeIsErrSet(typeIndex) {
        var typeObj = zigAnalysis.types[typeIndex];
        return typeObj.kind === typeKinds.ErrorSet;
    }

    function typeIsStructWithNoFields(typeIndex) {
        var typeObj = zigAnalysis.types[typeIndex];
        if (typeObj.kind !== typeKinds.Struct)
            return false;
        return typeObj.fields == null || typeObj.fields.length === 0;
    }

    function typeIsGenericFn(typeIndex) {
        var typeObj = zigAnalysis.types[typeIndex];
        if (typeObj.kind !== typeKinds.Fn) {
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
        renderFnParamDocs(fnDecl, typeObj);

        var errSetTypeIndex = null;
        if (typeObj.ret != null) {
            var retType = zigAnalysis.types[typeObj.ret];
            if (retType.kind === typeKinds.ErrorSet) {
                errSetTypeIndex = typeObj.ret;
            } else if (retType.kind === typeKinds.ErrorUnion) {
                errSetTypeIndex = retType.err;
            }
        }
        if (errSetTypeIndex != null) {
            var errSetType = zigAnalysis.types[errSetTypeIndex];
            renderErrorSet(errSetType);
        }

        var fnObj = zigAnalysis.fns[fnDecl.value];
        var protoSrcIndex = fnObj.src;
        if (typeIsGenericFn(fnDecl.type)) {
            var instantiations = nodesToFnsMap[protoSrcIndex];
            var calls = nodesToCallsMap[protoSrcIndex];
            if (instantiations == null && calls == null) {
                domFnNoExamples.classList.remove("hidden");
            } else if (calls != null) {
                if (fnObj.combined === undefined) fnObj.combined = allCompTimeFnCallsResult(calls);
                if (fnObj.combined != null) {
                    renderContainer(fnObj.combined, calls.map(function (call) { return zigAnalysis.calls[call].result.value }));
                }

                var domListFnExamplesFragment = createDomListFragment(calls.length, '<li></li>');

                for (var callI = 0; callI < calls.length; callI += 1) {
                    var liDom = domListFnExamplesFragment.children[callI];
                    liDom.innerHTML = getCallHtml(fnDecl, calls[callI]);
                }

                domListFnExamples.innerHTML = "";
                domListFnExamples.appendChild(domListFnExamplesFragment);
                domFnExamples.classList.remove("hidden");
            } else if (instantiations != null) {
                // TODO
            }
        } else {

            domFnExamples.classList.add("hidden");
            domFnNoExamples.classList.add("hidden");
        }

        var protoSrcNode = zigAnalysis.astNodes[protoSrcIndex];
        if (docsSource == null && protoSrcNode != null && protoSrcNode.docs != null) {
            docsSource = protoSrcNode.docs;
        }
        if (docsSource != null) {
            domTldDocs.innerHTML = markdown(docsSource);
            domTldDocs.classList.remove("hidden");
        }
        domFnProto.classList.remove("hidden");
    }

    function renderFnParamDocs(fnDecl, typeObj) {
        var docCount = 0;

        var fnObj = zigAnalysis.fns[fnDecl.value];
        var fnNode = zigAnalysis.astNodes[fnObj.src];
        var fields = fnNode.fields;
        var isVarArgs = fnNode.varArgs;

        for (var i = 0; i < fields.length; i += 1) {
            var field = fields[i];
            var fieldNode = zigAnalysis.astNodes[field];
            if (fieldNode.docs != null) {
                docCount += 1;
            }
        }
        if (docCount == 0) {
            return;
        }

        var domListParamsFragment = createDomListFragment(docCount, '<div></div>');
        var domIndex = 0;

        for (var i = 0; i < fields.length; i += 1) {
            var field = fields[i];
            var fieldNode = zigAnalysis.astNodes[field];
            if (fieldNode.docs == null) {
                continue;
            }
            var divDom = domListParamsFragment.children[domIndex];
            domIndex += 1;
            var argTypeIndex = typeObj.args[i];

            var html = '<pre>' + escapeHtml(fieldNode.name) + ": ";
            if (isVarArgs && i === typeObj.args.length - 1) {
                html += '...';
            } else if (argTypeIndex != null) {
                html += typeIndexName(argTypeIndex, true, true);
            } else {
                html += '<span class="tok-kw">var</span>';
            }

            html += ',</pre>';

            var docs = fieldNode.docs;
            if (docs != null) {
                html += markdown(docs);
            }
            divDom.innerHTML = html;
        }

        domListParams.innerHTML = "";
        domListParams.appendChild(domListParamsFragment);
        domSectParams.classList.remove("hidden");
    }

    function renderNav() {
        var len = curNav.pkgNames.length + curNav.declNames.length;
        var domListNavFragment = createDomListFragment(len, '<li><a href="#"></a></li>');
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
            var liDom = domListNavFragment.children[i];
            var aDom = liDom.children[0];
            aDom.textContent = list[i].name;
            aDom.setAttribute('href', list[i].link);
            if (i + 1 == list.length) {
                aDom.classList.add("active");
            } else {
                aDom.classList.remove("active");
            }
        }

        domListNav.innerHTML = "";
        domListNav.appendChild(domListNavFragment);
        domSectNav.classList.remove("hidden");
    }

    function renderInfo() {
        domTdZigVer.textContent = zigAnalysis.params.zigVersion;
        domTdTarget.textContent = zigAnalysis.params.builds[0].target;

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
            var domListPkgsFragment = createDomListFragment(list.length, '<li><a href="#"></a></li>');
            for (var i = 0; i < list.length; i += 1) {
                var liDom = domListPkgsFragment.children[i];
                var aDom = liDom.children[0];
                aDom.textContent = list[i].name;
                aDom.setAttribute('href', navLinkPkg(list[i].pkg));
                if (list[i].name === curNav.pkgNames[0]) {
                    aDom.classList.add("active");
                } else {
                    aDom.classList.remove("active");
                }
            }

            domListPkgs.innerHTML = "";
            domListPkgs.appendChild(domListPkgsFragment);
            domSectPkgs.classList.remove("hidden");
        }
    }

    function navLink(pkgNames, declNames, callName) {
        if (pkgNames.length === 0 && declNames.length === 0) {
            return '#';
        } else if (declNames.length === 0 && callName == null) {
            return '#' + pkgNames.join('.');
        } else if (callName == null) {
            return '#' + pkgNames.join('.') + ';' + declNames.join('.');
        } else {
            return '#' + pkgNames.join('.') + ';' + declNames.join('.') + ';' + callName;
        }
    }

    function navLinkPkg(pkgIndex) {
        return navLink(canonPkgPaths[pkgIndex], []);
    }

    function navLinkDecl(childName) {
        return navLink(curNav.pkgNames, curNav.declNames.concat([childName]));
    }

    function navLinkCall(callObj) {
        var declNamesCopy = curNav.declNames.concat([]);
        var callName = declNamesCopy.pop();

        callName += '(';
        for (var arg_i = 0; arg_i < callObj.args.length; arg_i += 1) {
            if (arg_i !== 0) callName += ',';
            var argObj = callObj.args[arg_i];
            callName += getValueText(argObj.type, argObj.value, false, false);
        }
        callName += ')';

        declNamesCopy.push(callName);
        return navLink(curNav.pkgNames, declNamesCopy);
    }

    function createDomListFragment(desiredLen, templateHtml) {
        var domTemplate = document.createElement("template");
        domTemplate.innerHTML = templateHtml.repeat(desiredLen);
        return domTemplate.content;
    }

    function typeIndexName(typeIndex, wantHtml, wantLink, fnDecl, linkFnNameDecl, thisTypes) {
        if(thisTypes && thisTypes.includes(typeIndex)){
            return token('@This', tokenKinds.Builtin, wantHtml) + '()';
        }
        var typeObj = zigAnalysis.types[typeIndex];
        var declNameOk = declCanRepresentTypeKind(typeObj.kind);
        if (wantLink) {
            var declIndex = getCanonTypeDecl(typeIndex);
            var declPath = getCanonDeclPath(declIndex);
            if (declPath == null) {
                return typeName(typeObj, wantHtml, wantLink, fnDecl, linkFnNameDecl, thisTypes);
            }
            var name = (wantLink && declCanRepresentTypeKind(typeObj.kind)) ?
                declPath.declNames[declPath.declNames.length - 1] :
                typeName(typeObj, wantHtml, false, fnDecl, linkFnNameDecl, thisTypes);
            if (wantLink && wantHtml) {
                return '<a href="' + navLink(declPath.pkgNames, declPath.declNames) + '">' + name + '</a>';
            } else {
                return name;
            }
        } else {
            return typeName(typeObj, wantHtml, false, fnDecl, linkFnNameDecl, thisTypes);
        }
    }

    function shouldSkipParamName(typeIndex, paramName) {
        var typeObj = zigAnalysis.types[typeIndex];
        if (typeObj.kind === typeKinds.Pointer && getPtrSize(typeObj) === pointerSizeEnum.One) {
            typeIndex = typeObj.elem;
        }
        return typeIndexName(typeIndex, false, true).toLowerCase() === paramName;
    }

    function getPtrSize(typeObj) {
        return (typeObj.len == null) ? pointerSizeEnum.One : typeObj.len;
    }

    function getCallHtml(fnDecl, callIndex) {
        var callObj = zigAnalysis.calls[callIndex];

        // TODO make these links work
        //var html = '<a href="' + navLinkCall(callObj) + '">' + escapeHtml(fnDecl.name) + '</a>(';
        var html = escapeHtml(fnDecl.name) + '(';
        for (var arg_i = 0; arg_i < callObj.args.length; arg_i += 1) {
            if (arg_i !== 0) html += ', ';
            var argObj = callObj.args[arg_i];
            html += getValueText(argObj.type, argObj.value, true, true);
        }
        html += ')';
        return html;
    }

    function getValueText(typeIndex, value, wantHtml, wantLink) {
        var typeObj = zigAnalysis.types[typeIndex];
        switch (typeObj.kind) {
            case typeKinds.Type:
                return typeIndexName(value, wantHtml, wantLink);
            case typeKinds.Fn:
                var fnObj = zigAnalysis.fns[value];
                var declPath = fnObj.decl && getCanonDeclPath(fnObj.decl);
                var fnName = declPath ? declPath.declNames.join('.') : '(unknown)';

                if (!wantHtml) {
                    return fnName;
                }

                var str = '<span class="tok-fn">';
                if (wantLink && declPath != null) {
                  str += '<a href="' + navLink(declPath.pkgNames, declPath.declNames) + '">';
                  str += escapeHtml(fnName);
                  str += '</a>';
                } else {
                  str += escapeHtml(fnName);
                }
                str += '</span>';
                return str;
            case typeKinds.Int:
                return token(value, tokenKinds.Number, wantHtml);
            case typeKinds.Optional:
                if(value === 'null'){
                    return token(value, tokenKinds.Null, wantHtml);
                } else {
                    console.trace("TODO non-null optional value printing");
                    return "TODO";
                }
            case typeKinds.Bool:
                return token(value, tokenKinds.Null, wantHtml);
            default:
                console.trace("TODO implement getValueText for this type:", zigAnalysis.typeKinds[typeObj.kind]);
                return "TODO";
        }
    }

    function typeName(typeObj, wantHtml, wantSubLink, fnDecl, linkFnNameDecl, thisTypes) {
        switch (typeObj.kind) {
            case typeKinds.Array:
                var name = "[";
                name += token(typeObj.len, tokenKinds.Number, wantHtml);
                name += "]";
                name += typeIndexName(typeObj.elem, wantHtml, wantSubLink, null, null, thisTypes);
                return name;
            case typeKinds.Vector:
                var name = "Vector(";
                name += token(typeObj.len, tokenKinds.Number, wantHtml);
                name += ", ";
                name += typeIndexName(typeObj.elem, wantHtml, wantSubLink, null, null, thisTypes);
                name += ")";
                return name;
            case typeKinds.Optional:
                return "?" + typeIndexName(typeObj.child, wantHtml, wantSubLink, fnDecl, linkFnNameDecl, thisTypes);
            case typeKinds.Pointer:
                var name = "";
                switch (typeObj.len) {
                    case pointerSizeEnum.One:
                    default:
                        name += "*";
                        break;
                    case pointerSizeEnum.Many:
                        name += "[*]";
                        break;
                    case pointerSizeEnum.Slice:
                        name += "[]";
                        break;
                    case pointerSizeEnum.C:
                        name += "[*c]";
                        break;
                }
                if (typeObj['const']) {
                    name += token('const', tokenKinds.Keyword, wantHtml) + ' ';
                }
                if (typeObj['volatile']) {
                    name += token('volatile', tokenKinds.Keyword, wantHtml) + ' ';
                }
                if (typeObj.align != null) {
                    name += token('align', tokenKinds.Keyword, wantHtml) + '(';
                    name += token(typeObj.align, tokenKinds.Number, wantHtml);

                    if (typeObj.hostIntBytes != null) {
                        name += ":";
                        name += token(typeObj.bitOffsetInHost, tokenKinds.Number, wantHtml);
                        name += ":";
                        name += token(typeObj.hostIntBytes, tokenKinds.Number, wantHtml);
                    }
                    name += ") ";
                }
                name += typeIndexName(typeObj.elem, wantHtml, wantSubLink, null, null, thisTypes);
                return name;
            case typeKinds.Float:
                return token('f' + typeObj.bits, tokenKinds.Type, wantHtml);
            case typeKinds.Int:
                var signed = (typeObj.i != null) ? 'i' : 'u';
                var bits = typeObj[signed];
                return token(signed + bits, tokenKinds.Type, wantHtml);
            case typeKinds.ComptimeInt:
                return token('comptime_int', tokenKinds.Type, wantHtml);
            case typeKinds.ComptimeFloat:
                return token('comptime_float', tokenKinds.Type, wantHtml);
            case typeKinds.Type:
                return token('type', tokenKinds.Type, wantHtml);
            case typeKinds.Bool:
                return token('bool', tokenKinds.Type, wantHtml);
            case typeKinds.Void:
                return token('void', tokenKinds.Type, wantHtml);
            case typeKinds.EnumLiteral:
                return token('(enum literal)', tokenKinds.Type, wantHtml);
            case typeKinds.NoReturn:
                return token('noreturn', tokenKinds.Type, wantHtml);
            case typeKinds.ErrorSet:
                if (typeObj.errors == null) {
                    return token('anyerror', tokenKinds.Type, wantHtml);
                } else {
                    if (wantHtml) {
                        return escapeHtml(typeObj.name);
                    } else {
                        return typeObj.name;
                    }
                }
            case typeKinds.ErrorUnion:
                var errSetTypeObj = zigAnalysis.types[typeObj.err];
                var payloadHtml = typeIndexName(typeObj.payload, wantHtml, wantSubLink, null, null, thisTypes);
                if (fnDecl != null && errSetTypeObj.fn === fnDecl.value) {
                    // function index parameter supplied and this is the inferred error set of it
                    return "!" + payloadHtml;
                } else {
                    return typeIndexName(typeObj.err, wantHtml, wantSubLink, null, null, thisTypes) + "!" + payloadHtml;
                }
            case typeKinds.Fn:
                var payloadHtml = "";
                if (wantHtml) {
                    payloadHtml += '<span class="tok-kw">fn</span>';
                    if (fnDecl != null) {
                        payloadHtml += ' <span class="tok-fn">';
                        if (linkFnNameDecl != null) {
                            payloadHtml += '<a href="' + linkFnNameDecl + '">' +
                                escapeHtml(fnDecl.name) + '</a>';
                        } else {
                            payloadHtml += escapeHtml(fnDecl.name);
                        }
                        payloadHtml += '</span>';
                    }
                } else {
                    payloadHtml += 'fn'
                }
                payloadHtml += '(';
                if (typeObj.args != null) {
                    var fields = null;
                    var isVarArgs = false;
                    if (fnDecl != null) {
                        var fnObj = zigAnalysis.fns[fnDecl.value];
                        var fnNode = zigAnalysis.astNodes[fnObj.src];
                        fields = fnNode.fields;
                        isVarArgs = fnNode.varArgs;
                    }

                    for (var i = 0; i < typeObj.args.length; i += 1) {
                        if (i != 0) {
                            payloadHtml += ', ';
                        }

                        var argTypeIndex = typeObj.args[i];

                        if (fields != null) {
                            var paramNode = zigAnalysis.astNodes[fields[i]];

                            if (paramNode.varArgs) {
                                payloadHtml += '...';
                                continue;
                            }

                            if (paramNode.noalias) {
                                payloadHtml += token('noalias', tokenKinds.Keyword, wantHtml) + ' ';
                            }

                            if (paramNode.comptime) {
                                payloadHtml += token('comptime', tokenKinds.Keyword, wantHtml) + ' ';
                            }

                            var paramName = paramNode.name;
                            if (paramName != null) {
                                // skip if it matches the type name
                                if (argTypeIndex == null || !shouldSkipParamName(argTypeIndex, paramName)) {
                                    payloadHtml += paramName + ': ';
                                }
                            }
                        }

                        if (isVarArgs && i === typeObj.args.length - 1) {
                            payloadHtml += '...';
                        } else if (argTypeIndex != null) {
                            payloadHtml += typeIndexName(argTypeIndex, wantHtml, wantSubLink, null, null, thisTypes);
                        } else {
                            payloadHtml += token('anytype', tokenKinds.Keyword, wantHtml);
                        }
                    }
                }

                payloadHtml += ') ';
                if (typeObj.ret != null) {
                    payloadHtml += typeIndexName(typeObj.ret, wantHtml, wantSubLink, fnDecl, null, thisTypes);
                } else {
                    payloadHtml += token('anytype', tokenKinds.Keyword, wantHtml);
                }
                return payloadHtml;
            case typeKinds.Frame:
                var fnObj = zigAnalysis.fns[typeObj.fn];
                return '@Frame(' + getValueText(fnObj.type, typeObj.fn, wantHtml, wantSubLink) + ')';
            case typeKinds.AnyFrame:
                var name = token('anyframe', tokenKinds.Keyword, wantHtml);
                if (typeObj.result) {
                  name += "->";
                  name += typeIndexName(typeObj.result, wantHtml, wantSubLink, null, null, thisTypes);
                }
                return name;
            default:
                if (wantHtml) {
                    return escapeHtml(typeObj.name);
                } else {
                    return typeObj.name;
                }
        }
    }

    function renderType(typeObj) {
        var name;
        if (rootIsStd && typeObj === zigAnalysis.types[zigAnalysis.packages[zigAnalysis.rootPkg].main]) {
            name = "std";
        } else {
            name = typeName(typeObj, false, false);
        }
        if (name != null && name != "") {
            domHdrName.innerText = name + " (" + zigAnalysis.typeKinds[typeObj.kind] + ")";
            domHdrName.classList.remove("hidden");
        }
        if (typeObj.kind == typeKinds.ErrorSet) {
            renderErrorSet(typeObj);
        }
    }

    function renderErrorSet(errSetType) {
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

            var domListFnErrorsFragment = createDomListFragment(errorList.length, "<dt></dt><dd></dd>");
            for (var i = 0; i < errorList.length; i += 1) {
                var nameTdDom = domListFnErrorsFragment.children[i * 2 + 0];
                var descTdDom = domListFnErrorsFragment.children[i * 2 + 1];
                nameTdDom.textContent = errorList[i].err.name;
                var docs = errorList[i].docs;
                if (docs != null) {
                    descTdDom.innerHTML = markdown(docs);
                } else {
                    descTdDom.textContent = "";
                }
            }
            domListFnErrors.innerHTML = "";
            domListFnErrors.appendChild(domListFnErrorsFragment);
            domTableFnErrors.classList.remove("hidden");
        }
        domSectFnErrors.classList.remove("hidden");
    }

    function allCompTimeFnCallsHaveTypeResult(typeIndex, value) {
        var srcIndex = zigAnalysis.fns[value].src;
        var calls = nodesToCallsMap[srcIndex];
        if (calls == null) return false;
        for (var i = 0; i < calls.length; i += 1) {
            var call = zigAnalysis.calls[calls[i]];
            if (call.result.type !== typeTypeId) return false;
        }
        return true;
    }

    function allCompTimeFnCallsResult(calls) {
        var firstTypeObj = null;
        var containerObj = {
            privDecls: [],
        };
        for (var callI = 0; callI < calls.length; callI += 1) {
            var call = zigAnalysis.calls[calls[callI]];
            if (call.result.type !== typeTypeId) return null;
            var typeObj = zigAnalysis.types[call.result.value];
            if (!typeKindIsContainer(typeObj.kind)) return null;
            if (firstTypeObj == null) {
                firstTypeObj = typeObj;
                containerObj.src = typeObj.src;
            } else if (firstTypeObj.src !== typeObj.src) {
                return null;
            }

            if (containerObj.fields == null) {
                containerObj.fields = (typeObj.fields || []).concat([]);
            } else for (var fieldI = 0; fieldI < typeObj.fields.length; fieldI += 1) {
                var prev = containerObj.fields[fieldI];
                var next = typeObj.fields[fieldI];
                if (prev === next) continue;
                if (typeof(prev) === 'object') {
                    if (prev[next] == null) prev[next] = typeObj;
                } else {
                    containerObj.fields[fieldI] = {};
                    containerObj.fields[fieldI][prev] = firstTypeObj;
                    containerObj.fields[fieldI][next] = typeObj;
                }
            }

            if (containerObj.pubDecls == null) {
                containerObj.pubDecls = (typeObj.pubDecls || []).concat([]);
            } else for (var declI = 0; declI < typeObj.pubDecls.length; declI += 1) {
                var prev = containerObj.pubDecls[declI];
                var next = typeObj.pubDecls[declI];
                if (prev === next) continue;
                // TODO instead of showing "examples" as the public declarations,
                // do logic like this:
                //if (typeof(prev) !== 'object') {
                //    var newDeclId = zigAnalysis.decls.length;
                //    prev = clone(zigAnalysis.decls[prev]);
                //    prev.id = newDeclId;
                //    zigAnalysis.decls.push(prev);
                //    containerObj.pubDecls[declI] = prev;
                //}
                //mergeDecls(prev, next, firstTypeObj, typeObj);
            }
        }
        for (var declI = 0; declI < containerObj.pubDecls.length; declI += 1) {
            var decl = containerObj.pubDecls[declI];
            if (typeof(decl) === 'object') {
                containerObj.pubDecls[declI] = containerObj.pubDecls[declI].id;
            }
        }
        return containerObj;
    }

    function mergeDecls(declObj, nextDeclIndex, firstTypeObj, typeObj) {
        var nextDeclObj = zigAnalysis.decls[nextDeclIndex];
        if (declObj.type != null && nextDeclObj.type != null && declObj.type !== nextDeclObj.type) {
            if (typeof(declObj.type) !== 'object') {
                var prevType = declObj.type;
                declObj.type = {};
                declObj.type[prevType] = firstTypeObj;
                declObj.value = null;
            }
            declObj.type[nextDeclObj.type] = typeObj;
        } else if (declObj.type == null && nextDeclObj != null) {
            declObj.type = nextDeclObj.type;
        }
        if (declObj.value != null && nextDeclObj.value != null && declObj.value !== nextDeclObj.value) {
            if (typeof(declObj.value) !== 'object') {
                var prevValue = declObj.value;
                declObj.value = {};
                declObj.value[prevValue] = firstTypeObj;
            }
            declObj.value[nextDeclObj.value] = typeObj;
        } else if (declObj.value == null && nextDeclObj.value != null) {
            declObj.value = nextDeclObj.value;
        }
    }

    function renderValue(decl) {
        domFnProtoCode.innerHTML = '<span class="tok-kw">const</span> ' +
            escapeHtml(decl.name) + ': ' + typeIndexName(decl.type, true, true);

        var docs = zigAnalysis.astNodes[decl.src].docs;
        if (docs != null) {
            domTldDocs.innerHTML = markdown(docs);
            domTldDocs.classList.remove("hidden");
        }

        domFnProto.classList.remove("hidden");
    }

    function renderVar(decl) {
        domFnProtoCode.innerHTML = '<span class="tok-kw">var</span> ' +
            escapeHtml(decl.name) + ': ' + typeIndexName(decl.type, true, true);

        var docs = zigAnalysis.astNodes[decl.src].docs;
        if (docs != null) {
            domTldDocs.innerHTML = markdown(docs);
            domTldDocs.classList.remove("hidden");
        }

        domFnProto.classList.remove("hidden");
    }

    function renderContainer(container, thisTypes) {
        var typesList = [];
        var namespacesList = [];
        var errSetsList = [];
        var fnsList = [];
        var varsList = [];
        var valsList = [];

        for (var i = 0; i < container.pubDecls.length; i += 1) {
            var decl = zigAnalysis.decls[container.pubDecls[i]];

            if (decl.kind === 'var') {
                varsList.push(decl);
                continue;
            } else if (decl.kind === 'const' && decl.type != null) {
                if (decl.type === typeTypeId) {
                    if (typeIsErrSet(decl.value)) {
                        errSetsList.push(decl);
                    } else if (typeIsStructWithNoFields(decl.value)) {
                        namespacesList.push(decl);
                    } else {
                        typesList.push(decl);
                    }
                } else {
                    var typeKind = zigAnalysis.types[decl.type].kind;
                    if (typeKind === typeKinds.Fn) {
                        if (allCompTimeFnCallsHaveTypeResult(decl.type, decl.value)) {
                            typesList.push(decl);
                        } else {
                            fnsList.push(decl);
                        }
                    } else {
                        valsList.push(decl);
                    }
                }
            }
        }
        typesList.sort(byNameProperty);
        namespacesList.sort(byNameProperty);
        errSetsList.sort(byNameProperty);
        fnsList.sort(byNameProperty);
        varsList.sort(byNameProperty);
        valsList.sort(byNameProperty);

        if (container.src != null) {
            var docs = zigAnalysis.astNodes[container.src].docs;
            if (docs != null) {
                domTldDocs.innerHTML = markdown(docs);
                domTldDocs.classList.remove("hidden");
            }
        }

        if (typesList.length !== 0) {
            var domListTypesFragment = createDomListFragment(typesList.length, '<li><a href="#"></a></li>');
            for (var i = 0; i < typesList.length; i += 1) {
                var liDom = domListTypesFragment.children[i];
                var aDom = liDom.children[0];
                var decl = typesList[i];
                aDom.textContent = decl.name;
                aDom.setAttribute('href', navLinkDecl(decl.name));
            }
            domListTypes.innerHTML = "";
            domListTypes.appendChild(domListTypesFragment);
            domSectTypes.classList.remove("hidden");
        }
        if (namespacesList.length !== 0) {
            var domListNamespacesFragment = createDomListFragment(namespacesList.length, '<li><a href="#"></a></li>');
            for (var i = 0; i < namespacesList.length; i += 1) {
                var liDom = domListNamespacesFragment.children[i];
                var aDom = liDom.children[0];
                var decl = namespacesList[i];
                aDom.textContent = decl.name;
                aDom.setAttribute('href', navLinkDecl(decl.name));
            }
            domListNamespaces.innerHTML = "";
            domListNamespaces.appendChild(domListNamespacesFragment);
            domSectNamespaces.classList.remove("hidden");
        }

        if (errSetsList.length !== 0) {
            var domListErrSetsFragment = createDomListFragment(errSetsList.length, '<li><a href="#"></a></li>');
            for (var i = 0; i < errSetsList.length; i += 1) {
                var liDom = domListErrSetsFragment.children[i];
                var aDom = liDom.children[0];
                var decl = errSetsList[i];
                aDom.textContent = decl.name;
                aDom.setAttribute('href', navLinkDecl(decl.name));
            }
            domListErrSets.innerHTML = "";
            domListErrSets.appendChild(domListErrSetsFragment);
            domSectErrSets.classList.remove("hidden");
        }

        if (fnsList.length !== 0) {
            var domListFnsFragment = createDomListFragment(fnsList.length, '<tr><td></td><td></td></tr>');
            for (var i = 0; i < fnsList.length; i += 1) {
                var decl = fnsList[i];
                var trDom = domListFnsFragment.children[i];

                var tdFnCode = trDom.children[0];
                var tdDesc = trDom.children[1];

                tdFnCode.innerHTML = typeIndexName(decl.type, true, true, decl, navLinkDecl(decl.name), thisTypes);

                var docs = zigAnalysis.astNodes[decl.src].docs;
                if (docs != null) {
                    tdDesc.innerHTML = shortDescMarkdown(docs);
                } else {
                    tdDesc.textContent = "";
                }
            }
            domListFns.innerHTML = "";
            domListFns.appendChild(domListFnsFragment);
            domSectFns.classList.remove("hidden");
        }

        if (container.fields != null && container.fields.length !== 0) {
            var domListFieldsFragment = createDomListFragment(container.fields.length, '<div></div>');

            var containerNode = zigAnalysis.astNodes[container.src];
            for (var i = 0; i < container.fields.length; i += 1) {
                var field = container.fields[i];
                var fieldNode = zigAnalysis.astNodes[containerNode.fields[i]];
                var divDom = domListFieldsFragment.children[i];

                var html = '<div class="mobile-scroll-container"><pre class="scroll-item">' + escapeHtml(fieldNode.name);

                if (container.kind === typeKinds.Enum) {
                    html += ' = <span class="tok-number">' + field + '</span>';
                } else {
                    html += ": ";
                    if (typeof(field) === 'object') {
                        html += '<span class="tok-kw">var</span>';
                    } else {
                        html += typeIndexName(field, true, true);
                    }
                }

                html += ',</pre></div>';

                var docs = fieldNode.docs;
                if (docs != null) {
                    html += markdown(docs);
                }
                divDom.innerHTML = html;
            }
            domListFields.innerHTML = "";
            domListFields.appendChild(domListFieldsFragment);
            domSectFields.classList.remove("hidden");
        }

        if (varsList.length !== 0) {
            var domListGlobalVarsFragment = createDomListFragment(varsList.length,
                '<tr><td><a href="#"></a></td><td></td><td></td></tr>');
            for (var i = 0; i < varsList.length; i += 1) {
                var decl = varsList[i];
                var trDom = domListGlobalVarsFragment.children[i];

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
            domListGlobalVars.innerHTML = "";
            domListGlobalVars.appendChild(domListGlobalVarsFragment);
            domSectGlobalVars.classList.remove("hidden");
        }

        if (valsList.length !== 0) {
            var domListValuesFragment = createDomListFragment(valsList.length,
                '<tr><td><a href="#"></a></td><td></td><td></td></tr>');
            for (var i = 0; i < valsList.length; i += 1) {
                var decl = valsList[i];
                var trDom = domListValuesFragment.children[i];

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
            domListValues.innerHTML = "";
            domListValues.appendChild(domListValuesFragment);
            domSectValues.classList.remove("hidden");
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

    function indexTypeKinds() {
        var map = {};
        for (var i = 0; i < zigAnalysis.typeKinds.length; i += 1) {
            map[zigAnalysis.typeKinds[i]] = i;
        }
        // This is just for debugging purposes, not needed to function
        var assertList = ["Type","Void","Bool","NoReturn","Int","Float","Pointer","Array","Struct",
            "ComptimeFloat","ComptimeInt","Undefined","Null","Optional","ErrorUnion","ErrorSet","Enum",
            "Union","Fn","BoundFn","Opaque","Frame","AnyFrame","Vector","EnumLiteral"];
        for (var i = 0; i < assertList.length; i += 1) {
            if (map[assertList[i]] == null) throw new Error("No type kind '" + assertList[i] + "' found");
        }
        return map;
    }

    function findTypeTypeId() {
        for (var i = 0; i < zigAnalysis.types.length; i += 1) {
            if (zigAnalysis.types[i].kind == typeKinds.Type) {
                return i;
            }
        }
        throw new Error("No type 'type' found");
    }

    function updateCurNav() {
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

        if (curNav.pkgNames.length === 0 && rootIsStd) {
            curNav.pkgNames = ["std"];
        }
    }

    function onHashChange() {
        updateCurNav();
        if (domSearch.value !== curNavSearch) {
            domSearch.value = curNavSearch;
        }
        render();
        if (imFeelingLucky) {
            imFeelingLucky = false;
            activateSelectedResult();
        }
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

    function typeKindIsContainer(typeKind) {
        return typeKind === typeKinds.Struct ||
            typeKind === typeKinds.Union ||
            typeKind === typeKinds.Enum;
    }

    function declCanRepresentTypeKind(typeKind) {
        return typeKind === typeKinds.ErrorSet || typeKindIsContainer(typeKind);
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
                        if (decl.type === typeTypeId &&
                            declCanRepresentTypeKind(zigAnalysis.types[decl.value].kind))
                        {
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

    function markdown(input) {
        const raw_lines = input.split('\n'); // zig allows no '\r', so we don't need to split on CR
        const lines = [];

        // PHASE 1:
        // Dissect lines and determine the type for each line.
        // Also computes indentation level and removes unnecessary whitespace

        var is_reading_code = false;
        var code_indent = 0;
        for (var line_no = 0; line_no < raw_lines.length; line_no++) {
            const raw_line = raw_lines[line_no];

            const line = {
                indent: 0,
                raw_text: raw_line,
                text: raw_line.trim(),
                type: "p", // p, h1 … h6, code, ul, ol, blockquote, skip, empty
            };

            if (!is_reading_code) {
                while ((line.indent < line.raw_text.length) && line.raw_text[line.indent] == ' ') {
                    line.indent += 1;
                }

                if (line.text.startsWith("######")) {
                    line.type = "h6";
                    line.text = line.text.substr(6);
                }
                else if (line.text.startsWith("#####")) {
                    line.type = "h5";
                    line.text = line.text.substr(5);
                }
                else if (line.text.startsWith("####")) {
                    line.type = "h4";
                    line.text = line.text.substr(4);
                }
                else if (line.text.startsWith("###")) {
                    line.type = "h3";
                    line.text = line.text.substr(3);
                }
                else if (line.text.startsWith("##")) {
                    line.type = "h2";
                    line.text = line.text.substr(2);
                }
                else if (line.text.startsWith("#")) {
                    line.type = "h1";
                    line.text = line.text.substr(1);
                }
                else if (line.text.startsWith("-")) {
                    line.type = "ul";
                    line.text = line.text.substr(1);
                }
                else if (line.text.match(/^\d+\..*$/)) { // if line starts with {number}{dot}
                    const match = line.text.match(/(\d+)\./);
                    line.type = "ul";
                    line.text = line.text.substr(match[0].length);
                    line.ordered_number = Number(match[1].length);
                }
                else if (line.text == "```") {
                    line.type = "skip";
                    is_reading_code = true;
                    code_indent = line.indent;
                }
                else if (line.text == "") {
                    line.type = "empty";
                }
            }
            else {
                if (line.text == "```") {
                    is_reading_code = false;
                    line.type = "skip";
                } else {
                    line.type = "code";
                    line.text = line.raw_text.substr(code_indent); // remove the indent of the ``` from all the code block
                }
            }

            if (line.type != "skip") {
                lines.push(line);
            }
        }

        // PHASE 2:
        // Render HTML from markdown lines.
        // Look at each line and emit fitting HTML code

        function markdownInlines(innerText, stopChar) {

            // inline types:
            // **{INLINE}**       : <strong>
            // __{INLINE}__       : <u>
            // ~~{INLINE}~~       : <s>
            //  *{INLINE}*        : <emph>
            //  _{INLINE}_        : <emph>
            //  `{TEXT}`          : <code>
            //  [{INLINE}]({URL}) : <a>
            // ![{TEXT}]({URL})   : <img>
            // [[std;format.fmt]] : <a> (inner link)

            const formats = [
                {
                    marker: "**",
                    tag: "strong",
                },
                {
                    marker: "~~",
                    tag: "s",
                },
                {
                    marker: "__",
                    tag: "u",
                },
                {
                    marker: "*",
                    tag: "em",
                }
            ];

            // Links, images and inner links don't use the same marker to wrap their content.
            const linksFormat = [
                {
                    prefix: "[",
                    regex: /\[([^\]]*)\]\(([^\)]*)\)/,
                    urlIndex: 2, // Index in the match that contains the link URL
                    textIndex: 1 // Index in the match that contains the link text
                },
                {
                    prefix: "h",
                    regex: /http[s]?:\/\/[^\s]+/,
                    urlIndex: 0,
                    textIndex: 0
                }
            ];

            const stack = [];

            var innerHTML = "";
            var currentRun = "";

            function flushRun() {
                if (currentRun != "") {
                    innerHTML += escapeHtml(currentRun);
                }
                currentRun = "";
            }

            var parsing_code = false;
            var codetag = "";
            var in_code = false;

            for (var i = 0; i < innerText.length; i++) {

                if (parsing_code && in_code) {
                    if (innerText.substr(i, codetag.length) == codetag) {
                        // remove leading and trailing whitespace if string both starts and ends with one.
                        if (currentRun[0] == " " && currentRun[currentRun.length - 1] == " ") {
                            currentRun = currentRun.substr(1, currentRun.length - 2);
                        }
                        flushRun();
                        i += codetag.length - 1;
                        in_code = false;
                        parsing_code = false;
                        innerHTML += "</code>";
                        codetag = "";
                    } else {
                        currentRun += innerText[i];
                    }
                    continue;
                }

                if (innerText[i] == "`") {
                    flushRun();
                    if (!parsing_code) {
                        innerHTML += "<code>";
                    }
                    parsing_code = true;
                    codetag += "`";
                    continue;
                }

                if (parsing_code) {
                    currentRun += innerText[i];
                    in_code = true;
                } else {
                    var foundMatches = false;

                    for (var j = 0; j < linksFormat.length; j++) {
                        const linkFmt = linksFormat[j];

                        if (linkFmt.prefix == innerText[i]) {
                            var remaining = innerText.substring(i);
                            var matches = remaining.match(linkFmt.regex);

                            if (matches) {
                                flushRun();
                                innerHTML += ' <a href="' + matches[linkFmt.urlIndex] + '">' + matches[linkFmt.textIndex] + '</a> ';
                                i += matches[0].length; // Skip the fragment we just consumed
                                foundMatches = true;
                                break;
                            }
                        }
                    }

                    if (foundMatches) {
                        continue;
                    }

                    var any = false;
                    for (var idx = (stack.length > 0 ? -1 : 0); idx < formats.length; idx++) {
                        const fmt = idx >= 0 ? formats[idx] : stack[stack.length - 1];
                        if (innerText.substr(i, fmt.marker.length) == fmt.marker) {
                            flushRun();
                            if (stack[stack.length - 1] == fmt) {
                                stack.pop();
                                innerHTML += "</" + fmt.tag + ">";
                            } else {
                                stack.push(fmt);
                                innerHTML += "<" + fmt.tag + ">";
                            }
                            i += fmt.marker.length - 1;
                            any = true;
                            break;
                        }
                    }
                    if (!any) {
                        currentRun += innerText[i];
                    }
                }
            }
            flushRun();

            while (stack.length > 0) {
                const fmt = stack.pop();
                innerHTML += "</" + fmt.tag + ">";
            }

            return innerHTML;
        }

        var html = "";
        for (var line_no = 0; line_no < lines.length; line_no++) {
            const line = lines[line_no];

            function previousLineIs(type) {
                if (line_no > 0) {
                    return (lines[line_no - 1].type == type);
                } else {
                    return false;
                }
            }

            function nextLineIs(type) {
                if (line_no < (lines.length - 1)) {
                    return (lines[line_no + 1].type == type);
                } else {
                    return false;
                }
            }

            function getPreviousLineIndent() {
                if (line_no > 0) {
                    return lines[line_no - 1].indent;
                } else {
                    return 0;
                }
            }

            function getNextLineIndent() {
                if (line_no < (lines.length - 1)) {
                    return lines[line_no + 1].indent;
                } else {
                    return 0;
                }
            }

            switch (line.type) {
                case "h1":
                case "h2":
                case "h3":
                case "h4":
                case "h5":
                case "h6":
                    html += "<" + line.type + ">" + markdownInlines(line.text) + "</" + line.type + ">\n";
                    break;

                case "ul":
                case "ol":
                    if (!previousLineIs("ul") || getPreviousLineIndent() < line.indent) {
                        html += "<" + line.type + ">\n";
                    }

                    html += "<li>" + markdownInlines(line.text) + "</li>\n";

                    if (!nextLineIs("ul") || getNextLineIndent() < line.indent) {
                        html += "</" + line.type + ">\n";
                    }
                    break;

                case "p":
                    if (!previousLineIs("p")) {
                        html += "<p>\n";
                    }
                    html += markdownInlines(line.text) + "\n";
                    if (!nextLineIs("p")) {
                        html += "</p>\n";
                    }
                    break;

                case "code":
                    if (!previousLineIs("code")) {
                        html += "<pre><code>";
                    }
                    html += escapeHtml(line.text) + "\n";
                    if (!nextLineIs("code")) {
                        html += "</code></pre>\n";
                    }
                    break;
            }
        }

        return html;
    }

    function activateSelectedResult() {
        if (domSectSearchResults.classList.contains("hidden")) {
            return;
        }

        var liDom = domListSearchResults.children[curSearchIndex];
        if (liDom == null && domListSearchResults.children.length !== 0) {
            liDom = domListSearchResults.children[0];
        }
        if (liDom != null) {
            var aDom = liDom.children[0];
            location.href = aDom.getAttribute("href");
            curSearchIndex = -1;
        }
        domSearch.blur();
    }

    function onSearchKeyDown(ev) {
        switch (getKeyString(ev)) {
            case "Enter":
                // detect if this search changes anything
                var terms1 = getSearchTerms();
                startSearch();
                updateCurNav();
                var terms2 = getSearchTerms();
                // we might have to wait for onHashChange to trigger
                imFeelingLucky = (terms1.join(' ') !== terms2.join(' '));
                if (!imFeelingLucky) activateSelectedResult();

                ev.preventDefault();
                ev.stopPropagation();
                return;
            case "Esc":
                domSearch.value = "";
                domSearch.blur();
                curSearchIndex = -1;
                ev.preventDefault();
                ev.stopPropagation();
                startSearch();
                return;
            case "Up":
                moveSearchCursor(-1);
                ev.preventDefault();
                ev.stopPropagation();
                return;
            case "Down":
                moveSearchCursor(1);
                ev.preventDefault();
                ev.stopPropagation();
                return;
            default:
                if (ev.shiftKey || ev.ctrlKey || ev.altKey) return;

                curSearchIndex = -1;
                ev.stopPropagation();
                startAsyncSearch();
                return;
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

    function getKeyString(ev) {
        var name;
        var ignoreShift = false;
        switch (ev.which) {
            case 13:
                name = "Enter";
                break;
            case 27:
                name = "Esc";
                break;
            case 38:
                name = "Up";
                break;
            case 40:
                name = "Down";
                break;
            default:
                ignoreShift = true;
                name = (ev.key != null) ? ev.key : String.fromCharCode(ev.charCode || ev.keyCode);
        }
        if (!ignoreShift && ev.shiftKey) name = "Shift+" + name;
        if (ev.altKey) name = "Alt+" + name;
        if (ev.ctrlKey) name = "Ctrl+" + name;
        return name;
    }

    function onWindowKeyDown(ev) {
        switch (getKeyString(ev)) {
            case "Esc":
                if (!domHelpModal.classList.contains("hidden")) {
                    domHelpModal.classList.add("hidden");
                    ev.preventDefault();
                    ev.stopPropagation();
                }
                break;
            case "s":
                domSearch.focus();
                domSearch.select();
                ev.preventDefault();
                ev.stopPropagation();
                startAsyncSearch();
                break;
            case "?":
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

    function onClickSearchShowAllResults(ev) {
        ev.preventDefault();
        ev.stopPropagation();
        searchTrimResults = false;
        onHashChange();
    }

    function clearAsyncSearch() {
        if (searchTimer != null) {
            clearTimeout(searchTimer);
            searchTimer = null;
        }
    }

    function startAsyncSearch() {
        clearAsyncSearch();
        searchTrimResults = true;
        searchTimer = setTimeout(startSearch, 10);
    }
    function startSearch() {
        clearAsyncSearch();
        var oldHash = location.hash;
        var parts = oldHash.split("?");
        var newPart2 = (domSearch.value === "") ? "" : ("?" + domSearch.value);
        var newHash = (oldHash === "" ? "#" : parts[0]) + newPart2;
        // create a history entry only once per search
        if (parts.length === 1) {
            location.assign(newHash);
        } else {
            location.replace(newHash);
        }
    }
    function getSearchTerms() {
        var list = curNavSearch.trim().split(/[ \r\n\t]+/);
        list.sort();
        return list;
    }
    function renderSearch() {
        var matchedItems = [];
        var ignoreCase = (curNavSearch.toLowerCase() === curNavSearch);
        var terms = getSearchTerms();

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
            matchedItems.sort(function(a, b) {
                var cmp = operatorCompare(b.points, a.points);
                if (cmp != 0) return cmp;
                return operatorCompare(a.decl.name, b.decl.name);
            });

            var searchTrimmed = false
            var searchTrimResultsMaxItems = 200
            if (searchTrimResults && matchedItems.length > searchTrimResultsMaxItems) {
                matchedItems = matchedItems.slice(0, searchTrimResultsMaxItems)
                searchTrimmed = true
            }

            var domListSearchResultsFragment = createDomListFragment(matchedItems.length, '<li><a href="#"></a></li>');
            for (var i = 0; i < matchedItems.length; i += 1) {
                var liDom = domListSearchResultsFragment.children[i];
                var aDom = liDom.children[0];
                var match = matchedItems[i];
                var lastPkgName = match.path.pkgNames[match.path.pkgNames.length - 1];
                aDom.textContent = lastPkgName + "." + match.path.declNames.join('.');
                aDom.setAttribute('href', navLink(match.path.pkgNames, match.path.declNames));
            }

            domListSearchResults.innerHTML = "";
            domListSearchResults.appendChild(domListSearchResultsFragment);
            domSectSearchResults.classList.remove("hidden");

            if (searchTrimmed) {
                domSectSearchAllResultsLink.classList.remove("hidden");
            }

            renderSearchCursor();
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

    function byNameProperty(a, b) {
        return operatorCompare(a.name, b.name);
    }

    function clone(obj) {
        var res = {};
        for (var key in obj) {
            res[key] = obj[key];
        }
        return res;
    }

    function firstObjectKey(obj) {
        for (var key in obj) {
            return key;
        }
    }

    function token(value, tokenClass, wantHtml){
        if(wantHtml){
            return '<span class="' + tokenClass + '">' + value + '</span>';
        } else {
            return value + '';
        }
    }
})();
