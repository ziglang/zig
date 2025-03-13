(() => {
  // DOM Element Types
  // Its easier to write typescript than js. 
  // bun build main_ts.ts --outfile = main_ts.js
  // or 
  // bun build main_ts.ts --outfile=main_ts.js --minify --target=browser
  //
  const domStatus = document.getElementById("status") as HTMLDivElement;
  const domSectSource = document.getElementById("sectSource") as HTMLDivElement;
  const domSectStats = document.getElementById("sectStats") as HTMLDivElement;
  const domSourceText = document.getElementById("sourceText") as HTMLDivElement;
  const domStatTotalRuns = document.getElementById("statTotalRuns") as HTMLSpanElement;
  const domStatUniqueRuns = document.getElementById("statUniqueRuns") as HTMLSpanElement;
  const domStatSpeed = document.getElementById("statSpeed") as HTMLSpanElement;
  const domStatCoverage = document.getElementById("statCoverage") as HTMLSpanElement;
  const domEntryPointsList = document.getElementById("entryPointsList") as HTMLUListElement;

  // WebAssembly exports interface
  interface WasmExports extends WebAssembly.Exports {
    memory: WebAssembly.Memory;
    alloc: (size: number) => number;
    unpack: (ptr: number, length: number) => void;
    message_begin: (length: number) => number;
    message_end: () => void;
    totalRuns: () => number;
    uniqueRuns: () => number;
    totalRunsPerSecond: () => number;
    totalSourceLocations: () => number;
    coveredSourceLocations: () => number;
    entryPoints: () => bigint;
    sourceLocationLinkHtml: (index: number) => bigint;
    sourceLocationFileCoveredList: (index: number) => bigint;
    sourceLocationPath: (index: number) => bigint;
    sourceLocationFileHtml: (index: number) => bigint;
    set_input_string: (length: number) => number;
  }

  // Promises for loading WASM and sources
  const wasm_promise = fetch("main.wasm");
  const sources_promise = fetch("sources.tar").then((response: Response) => {
    if (!response.ok) throw new Error("unable to download sources");
    return response.arrayBuffer();
  });

  let wasm_exports: WasmExports | null = null;
  let curNavSearch: string | null = null;
  let curNavLocation: number | null = null;
  let ws: WebSocket | null = null;

  const text_decoder = new TextDecoder();
  const text_encoder = new TextEncoder();

  domStatus.textContent = "Loading WebAssembly...";
  WebAssembly.instantiateStreaming(wasm_promise, {
    js: {
      log: (ptr: number, len: number): void => {
        const msg = decodeString(ptr, len);
        console.log(msg);
      },
      panic: (ptr: number, len: number): void => {
        const msg = decodeString(ptr, len);
        throw new Error("panic: " + msg);
      },
      timestamp: (): bigint => {
        return BigInt(new Date().getTime());
      },
      emitSourceIndexChange: onSourceIndexChange,
      emitCoverageUpdate: onCoverageUpdate,
      emitEntryPointsUpdate: renderStats,
    },
  }).then((obj) => {
    wasm_exports = obj.instance.exports as WasmExports;
    (window as any).wasm = obj; // for debugging
    domStatus.textContent = "Loading sources tarball...";

    sources_promise.then((buffer: ArrayBuffer) => {
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

  function onPopState(ev: PopStateEvent): void {
    onHashChange(ev.state);
  }

  function onHashChange(state: any): void {
    history.replaceState({}, "");
    navigate(location.hash);
    if (state == null) window.scrollTo({top: 0});
  }

  function navigate(location_hash: string): void {
    domSectSource.classList.add("hidden");

    curNavLocation = null;
    curNavSearch = null;

    if (location_hash.length > 1 && location_hash[0] === '#') {
      const query = location_hash.substring(1);
      const qpos = query.indexOf("?");
      let nonSearchPart: string;
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

  function connectWebSocket(): void {
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

  function onWebSocketOpen(): void {
    //console.log("web socket opened");
  }

  function onWebSocketMessage(ev: MessageEvent): void {
    wasmOnMessage(ev.data);
  }

  function timeoutThenCreateNew(): void {
    if (!ws) return;
    
    ws.removeEventListener('message', onWebSocketMessage, false);
    ws.removeEventListener('error', timeoutThenCreateNew, false);
    ws.removeEventListener('close', timeoutThenCreateNew, false);
    ws.removeEventListener('open', onWebSocketOpen, false);
    ws = null;
    setTimeout(connectWebSocket, 1000);
  }

  function wasmOnMessage(data: ArrayBuffer): void {
    if (!wasm_exports) return;

    const jsArray = new Uint8Array(data);
    const ptr = wasm_exports.message_begin(jsArray.length);
    const wasmArray = new Uint8Array(wasm_exports.memory.buffer, ptr, jsArray.length);
    wasmArray.set(jsArray);
    wasm_exports.message_end();
  }

  function onSourceIndexChange(): void {
    render();
    if (curNavLocation != null) renderSource(curNavLocation);
  }

  function onCoverageUpdate(): void {
    renderStats();
    renderCoverage();
  }

  function render(): void {
    domStatus.classList.add("hidden");
  }

  function renderStats(): void {
    if (!wasm_exports) return;

    const totalRuns = wasm_exports.totalRuns();
    const uniqueRuns = wasm_exports.uniqueRuns();
    const totalSourceLocations = wasm_exports.totalSourceLocations();
    const coveredSourceLocations = wasm_exports.coveredSourceLocations();
    domStatTotalRuns.innerText = totalRuns.toString();
    domStatUniqueRuns.innerText = uniqueRuns + " (" + percent(uniqueRuns, totalRuns) + "%)";
    domStatCoverage.innerText = coveredSourceLocations + " / " + totalSourceLocations + " (" + percent(coveredSourceLocations, totalSourceLocations) + "%)";
    domStatSpeed.innerText = wasm_exports.totalRunsPerSecond().toFixed(0);

    const entryPoints = unwrapInt32Array(wasm_exports.entryPoints());
    resizeDomList(domEntryPointsList, entryPoints.length, "<li></li>");
    for (let i = 0; i < entryPoints.length; i += 1) {
      const liDom = domEntryPointsList.children[i] as HTMLLIElement;
      liDom.innerHTML = unwrapString(wasm_exports.sourceLocationLinkHtml(entryPoints[i]));
    }

    domSectStats.classList.remove("hidden");
  }

  function renderCoverage(): void {
    if (!wasm_exports || curNavLocation == null) return;
    const sourceLocationIndex = curNavLocation;

    for (let i = 0; i < domSourceText.children.length; i += 1) {
      const childDom = domSourceText.children[i] as HTMLElement;
      if (childDom.id != null && childDom.id[0] == "l") {
        childDom.classList.add("l");
        childDom.classList.remove("c");
      }
    }
    
    const coveredList = unwrapInt32Array(wasm_exports.sourceLocationFileCoveredList(sourceLocationIndex));
    for (let i = 0; i < coveredList.length; i += 1) {
      const element = document.getElementById("l" + coveredList[i]);
      if (element) element.classList.add("c");
    }
  }

  function resizeDomList(listDom: HTMLElement, desiredLen: number, templateHtml: string): void {
    for (let i = listDom.childElementCount; i < desiredLen; i += 1) {
      listDom.insertAdjacentHTML('beforeend', templateHtml);
    }
    while (desiredLen < listDom.childElementCount) {
      const lastChild = listDom.lastChild;
      if (lastChild) listDom.removeChild(lastChild);
    }
  }

  function percent(a: number, b: number): string {
    return ((Number(a) / Number(b)) * 100).toFixed(1);
  }

  function renderSource(sourceLocationIndex: number): void {
    if (!wasm_exports) return;
    
    const pathName = unwrapString(wasm_exports.sourceLocationPath(sourceLocationIndex));
    if (pathName.length === 0) return;

    const h2 = domSectSource.children[0] as HTMLHeadingElement;
    h2.innerText = pathName;
    domSourceText.innerHTML = unwrapString(wasm_exports.sourceLocationFileHtml(sourceLocationIndex));

    domSectSource.classList.remove("hidden");

    // Empirically, Firefox needs this requestAnimationFrame in order for the scrollIntoView to work.
    requestAnimationFrame(() => {
      const slDom = document.getElementById("l" + sourceLocationIndex);
      if (slDom != null) slDom.scrollIntoView({
        behavior: "smooth",
        block: "center",
      });
    });
  }

  function decodeString(ptr: number, len: number): string {
    if (!wasm_exports || len === 0) return "";
    return text_decoder.decode(new Uint8Array(wasm_exports.memory.buffer, ptr, len));
  }

  function unwrapInt32Array(bigint: bigint): Uint32Array {
    if (!wasm_exports) return new Uint32Array();
    
    const ptr = Number(bigint & BigInt(0xffffffff));
    const len = Number(bigint >> BigInt(32));
    if (len === 0) return new Uint32Array();
    return new Uint32Array(wasm_exports.memory.buffer, ptr, len);
  }

  function setInputString(s: string): void {
    if (!wasm_exports) return;

    const jsArray = text_encoder.encode(s);
    const len = jsArray.length;
    const ptr = wasm_exports.set_input_string(len);
    const wasmArray = new Uint8Array(wasm_exports.memory.buffer, ptr, len);
    wasmArray.set(jsArray);
  }

  function unwrapString(bigint: bigint): string {
    if (!wasm_exports) return "";
    
    const ptr = Number(bigint & BigInt(0xffffffff));
    const len = Number(bigint >> BigInt(32));
    return decodeString(ptr, len);
  }
})();
