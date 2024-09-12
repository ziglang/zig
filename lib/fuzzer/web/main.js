(function() {
  const domStatus = document.getElementById("status");
  const domSectSource = document.getElementById("sectSource");
  const domSectStats = document.getElementById("sectStats");
  const domSourceText = document.getElementById("sourceText");
  const domStatTotalRuns = document.getElementById("statTotalRuns");
  const domStatUniqueRuns = document.getElementById("statUniqueRuns");
  const domStatSpeed = document.getElementById("statSpeed");
  const domStatCoverage = document.getElementById("statCoverage");
  const domEntryPointsList = document.getElementById("entryPointsList");

  let wasm_promise = fetch("main.wasm");
  let sources_promise = fetch("sources.tar").then(function(response) {
    if (!response.ok) throw new Error("unable to download sources");
    return response.arrayBuffer();
  });
  var wasm_exports = null;
  var curNavSearch = null;
  var curNavLocation = null;

  const text_decoder = new TextDecoder();
  const text_encoder = new TextEncoder();

  domStatus.textContent = "Loading WebAssembly...";
  WebAssembly.instantiateStreaming(wasm_promise, {
    js: {
      log: function(ptr, len) {
        const msg = decodeString(ptr, len);
        console.log(msg);
      },
      panic: function (ptr, len) {
          const msg = decodeString(ptr, len);
          throw new Error("panic: " + msg);
      },
      timestamp: function () {
        return BigInt(new Date());
      },
      emitSourceIndexChange: onSourceIndexChange,
      emitCoverageUpdate: onCoverageUpdate,
      emitEntryPointsUpdate: renderStats,
    },
  }).then(function(obj) {
    wasm_exports = obj.instance.exports;
    window.wasm = obj; // for debugging
    domStatus.textContent = "Loading sources tarball...";

    sources_promise.then(function(buffer) {
      domStatus.textContent = "Parsing sources...";
      const js_array = new Uint8Array(buffer);
      const ptr = wasm_exports.alloc(js_array.length);
      const wasm_array = new Uint8Array(wasm_exports.memory.buffer, ptr, js_array.length);
      wasm_array.set(js_array);
      wasm_exports.unpack(ptr, js_array.length);

      window.addEventListener('popstate', onPopState, false);
      onHashChange(null);

      domStatus.textContent = "Waiting for server to send source location metadata...";
      connectWebSocket();
    });
  });

  function onPopState(ev) {
    onHashChange(ev.state);
  }

  function onHashChange(state) {
    history.replaceState({}, "");
    navigate(location.hash);
    if (state == null) window.scrollTo({top: 0});
  }

  function navigate(location_hash) {
    domSectSource.classList.add("hidden");

    curNavLocation = null;
    curNavSearch = null;

    if (location_hash.length > 1 && location_hash[0] === '#') {
      const query = location_hash.substring(1);
      const qpos = query.indexOf("?");
      let nonSearchPart;
      if (qpos === -1) {
        nonSearchPart = query;
      } else {
        nonSearchPart = query.substring(0, qpos);
        curNavSearch = decodeURIComponent(query.substring(qpos + 1));
      }

      if (nonSearchPart[0] == "l") {
        curNavLocation = +nonSearchPart.substring(1);
        renderSource(curNavLocation);
      }
    }

    render();
  }

  function connectWebSocket() {
    const host = document.location.host;
    const pathname = document.location.pathname;
    const isHttps = document.location.protocol === 'https:';
    const match = host.match(/^(.+):(\d+)$/);
    const defaultPort = isHttps ? 443 : 80;
    const port = match ? parseInt(match[2], 10) : defaultPort;
    const hostName = match ? match[1] : host;
    const wsProto = isHttps ? "wss:" : "ws:";
    const wsUrl = wsProto + '//' + hostName + ':' + port + pathname;
    ws = new WebSocket(wsUrl);
    ws.binaryType = "arraybuffer";
    ws.addEventListener('message', onWebSocketMessage, false);
    ws.addEventListener('error', timeoutThenCreateNew, false);
    ws.addEventListener('close', timeoutThenCreateNew, false);
    ws.addEventListener('open', onWebSocketOpen, false);
  }

  function onWebSocketOpen() {
    //console.log("web socket opened");
  }

  function onWebSocketMessage(ev) {
    wasmOnMessage(ev.data);
  }

  function timeoutThenCreateNew() {
    ws.removeEventListener('message', onWebSocketMessage, false);
    ws.removeEventListener('error', timeoutThenCreateNew, false);
    ws.removeEventListener('close', timeoutThenCreateNew, false);
    ws.removeEventListener('open', onWebSocketOpen, false);
    ws = null;
    setTimeout(connectWebSocket, 1000);
  }

  function wasmOnMessage(data) {
    const jsArray = new Uint8Array(data);
    const ptr = wasm_exports.message_begin(jsArray.length);
    const wasmArray = new Uint8Array(wasm_exports.memory.buffer, ptr, jsArray.length);
    wasmArray.set(jsArray);
    wasm_exports.message_end();
  }

  function onSourceIndexChange() {
    render();
    if (curNavLocation != null) renderSource(curNavLocation);
  }

  function onCoverageUpdate() {
    renderStats();
    renderCoverage();
  }

  function render() {
    domStatus.classList.add("hidden");
  }

  function renderStats() {
    const totalRuns = wasm_exports.totalRuns();
    const uniqueRuns = wasm_exports.uniqueRuns();
    const totalSourceLocations = wasm_exports.totalSourceLocations();
    const coveredSourceLocations = wasm_exports.coveredSourceLocations();
    domStatTotalRuns.innerText = totalRuns;
    domStatUniqueRuns.innerText = uniqueRuns + " (" + percent(uniqueRuns, totalRuns) + "%)";
    domStatCoverage.innerText = coveredSourceLocations + " / " + totalSourceLocations + " (" + percent(coveredSourceLocations, totalSourceLocations) + "%)";
    domStatSpeed.innerText = wasm_exports.totalRunsPerSecond().toFixed(0);

    const entryPoints = unwrapInt32Array(wasm_exports.entryPoints());
    resizeDomList(domEntryPointsList, entryPoints.length, "<li></li>");
    for (let i = 0; i < entryPoints.length; i += 1) {
      const liDom = domEntryPointsList.children[i];
      liDom.innerHTML = unwrapString(wasm_exports.sourceLocationLinkHtml(entryPoints[i]));
    }


    domSectStats.classList.remove("hidden");
  }

  function renderCoverage() {
    if (curNavLocation == null) return;
    const sourceLocationIndex = curNavLocation;

    for (let i = 0; i < domSourceText.children.length; i += 1) {
      const childDom = domSourceText.children[i];
      if (childDom.id != null && childDom.id[0] == "l") {
        childDom.classList.add("l");
        childDom.classList.remove("c");
      }
    }
    const coveredList = unwrapInt32Array(wasm_exports.sourceLocationFileCoveredList(sourceLocationIndex));
    for (let i = 0; i < coveredList.length; i += 1) {
      document.getElementById("l" + coveredList[i]).classList.add("c");
    }
  }

  function resizeDomList(listDom, desiredLen, templateHtml) {
    for (let i = listDom.childElementCount; i < desiredLen; i += 1) {
        listDom.insertAdjacentHTML('beforeend', templateHtml);
    }
    while (desiredLen < listDom.childElementCount) {
        listDom.removeChild(listDom.lastChild);
    }
  }

  function percent(a, b) {
    return ((Number(a) / Number(b)) * 100).toFixed(1);
  }

  function renderSource(sourceLocationIndex) {
    const pathName = unwrapString(wasm_exports.sourceLocationPath(sourceLocationIndex));
    if (pathName.length === 0) return;

    const h2 = domSectSource.children[0];
    h2.innerText = pathName;
    domSourceText.innerHTML = unwrapString(wasm_exports.sourceLocationFileHtml(sourceLocationIndex));

    domSectSource.classList.remove("hidden");

    // Empirically, Firefox needs this requestAnimationFrame in order for the scrollIntoView to work.
    requestAnimationFrame(function() {
      const slDom = document.getElementById("l" + sourceLocationIndex);
      if (slDom != null) slDom.scrollIntoView({
        behavior: "smooth",
        block: "center",
      });
    });
  }

  function decodeString(ptr, len) {
    if (len === 0) return "";
    return text_decoder.decode(new Uint8Array(wasm_exports.memory.buffer, ptr, len));
  }

  function unwrapInt32Array(bigint) {
    const ptr = Number(bigint & 0xffffffffn);
    const len = Number(bigint >> 32n);
    if (len === 0) return new Uint32Array();
    return new Uint32Array(wasm_exports.memory.buffer, ptr, len);
  }

  function setInputString(s) {
    const jsArray = text_encoder.encode(s);
    const len = jsArray.length;
    const ptr = wasm_exports.set_input_string(len);
    const wasmArray = new Uint8Array(wasm_exports.memory.buffer, ptr, len);
    wasmArray.set(jsArray);
  }

  function unwrapString(bigint) {
    const ptr = Number(bigint & 0xffffffffn);
    const len = Number(bigint >> 32n);
    return decodeString(ptr, len);
  }
})();
