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
            stderr: function(msg_ptr, msg_len) {
                console.log(makeString(msg_ptr, msg_len));
            },
        },
    };

    WebAssembly.instantiateStreaming(fetch("playground.wasm"), options).then(function(result) {
        zigCallback(null, result);
    }, function(err) {
        zigCallback(err, null);
    });
    function zigCallback(err, result) {
        if (err) {
            document.getElementById('status').textContent = "error: " + err;
            return;
        }
        zig = result.instance;
        zig.exports.zigEval();
    }

    function makeString(ptr, len) {
        var bytes = new Uint8Array(zig.exports.memory.buffer, ptr, len);
        return new TextDecoder().decode(bytes);
    }

    function runCallback(err, result) {
        if (err) {
            document.getElementById('status').textContent = "error: " + err;
            return;
        }
        console.log(result.instance.exports._start());
    }
})();
