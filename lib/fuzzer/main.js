(function() {
    const domSectSource = document.getElementById("sectSource");
    const domSourceText = document.getElementById("sourceText");

    let wasm_promise = fetch("main.wasm");
    let sources_promise = fetch("sources.tar").then(function(response) {
      if (!response.ok) throw new Error("unable to download sources");
      return response.arrayBuffer();
    });
    var wasm_exports = null;

    const text_decoder = new TextDecoder();
    const text_encoder = new TextEncoder();

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
      },
    }).then(function(obj) {
      wasm_exports = obj.instance.exports;
      window.wasm = obj; // for debugging

      sources_promise.then(function(buffer) {
        const js_array = new Uint8Array(buffer);
        const ptr = wasm_exports.alloc(js_array.length);
        const wasm_array = new Uint8Array(wasm_exports.memory.buffer, ptr, js_array.length);
        wasm_array.set(js_array);
        wasm_exports.unpack(ptr, js_array.length);

        render();
      });
    });

    function render() {
        domSectSource.classList.add("hidden");

        // TODO this is temporary debugging data
        renderSource("/home/andy/dev/zig/lib/std/zig/tokenizer.zig");
    }

    function renderSource(path) {
      const decl_index = findFileRoot(path);
      if (decl_index == null) throw new Error("file not found: " + path);

      const h2 = domSectSource.children[0];
      h2.innerText = path;
      domSourceText.innerHTML = declSourceHtml(decl_index);

      domSectSource.classList.remove("hidden");
    }

    function findFileRoot(path) {
      setInputString(path);
      const result = wasm_exports.find_file_root();
      if (result === -1) return null;
      return result;
    }

    function decodeString(ptr, len) {
      if (len === 0) return "";
      return text_decoder.decode(new Uint8Array(wasm_exports.memory.buffer, ptr, len));
    }

    function setInputString(s) {
      const jsArray = text_encoder.encode(s);
      const len = jsArray.length;
      const ptr = wasm_exports.set_input_string(len);
      const wasmArray = new Uint8Array(wasm_exports.memory.buffer, ptr, len);
      wasmArray.set(jsArray);
    }

    function declSourceHtml(decl_index) {
      return unwrapString(wasm_exports.decl_source_html(decl_index));
    }

    function unwrapString(bigint) {
      const ptr = Number(bigint & 0xffffffffn);
      const len = Number(bigint >> 32n);
      return decodeString(ptr, len);
    }
})();
