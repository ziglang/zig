(function() {
    var zig;
    var options = {
        env: {
            wasmEval: function(code_ptr, code_len) {
                var bytes = new Uint8Array(zig.exports.memory.buffer, code_ptr, code_len);
                WebAssembly.instantiate(bytes).then(function(result) {
                    runCallback(null, result);
                }, function (err) {
                    runCallback(err, null);
                });
            },
            getFile: function(ptr, len) {
                var encodedSrc = (new TextEncoder()).encode(domSrc.value);
                if (len < encodedSrc.length) return encodedSrc.length;
                var dv = new DataView(zig.exports.memory.buffer, ptr, len);
                for (var i = 0; i < len; i += 1) {
                    dv.setUint8(i, encodedSrc[i]);
                }
                return 0;
            },
            stderr: function(msg_ptr, msg_len) {
                domOutput.textContent += makeString(msg_ptr, msg_len) + "\n";
            },
        },
    };
    var domStatus = document.getElementById('status');
    var domOutput = document.getElementById('output');
    var domSrc = document.getElementById('src');
    var domRun = document.getElementById('run');
    var playground_wasm = null;

    fetch("playground.wasm").then(function(result) {
        result.arrayBuffer().then(function(array_buffer) {
            playground_wasm = array_buffer;
            domStatus.textContent = "Ready";
        }, function(err) {
            domStatus.textContent = "unable to fetch compiler array buffer: " + err;
        });
    }, function(err) {
        domStatus.textContent = "unable to fetch compiler: " + err;
    });

    domRun.addEventListener('click', onRun, false);

    function onRun(ev) {
        if (playground_wasm == null) {
            domStatus.textContent = "Compiler not loaded";
            return;
        }
        domStatus.textContent = "Compiling...";

        WebAssembly.instantiate(playground_wasm, options).then(function(result) {
            domStatus.textContent = "Ready";
            domOutput.textContent = "";
            zig = result.instance;
            zig.exports.zigEval();
        }, function(err) {
            domStatus.textContent = "error: " + err;
        });
    }

    function makeString(ptr, len) {
        var bytes = new Uint8Array(zig.exports.memory.buffer, ptr, len);
        return new TextDecoder().decode(bytes);
    }

    function runCallback(err, result) {
        if (err) {
            domOutput.textContent = "error: " + err;
            return;
        }
        var result = result.instance.exports._start();
        domOutput.textContent = result.toString();
    }
})();
