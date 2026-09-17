const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const model = vm.createContext({});
vm.runInContext(fs.readFileSync('Model.js', 'utf8').replace('.pragma library', ''), model);

// parseStatus
assert.equal(JSON.stringify(model.parseStatus('{"running":true,"model":"kokoro"}')), JSON.stringify({running:true,model:'kokoro'}));
assert.equal(model.parseStatus('garbage'), null);
assert.equal(JSON.stringify(model.parseStatus('')), JSON.stringify({}));

// parseVoices
assert.equal(JSON.stringify(model.parseVoices('[{"name":"af_alloy","active":true}]')), JSON.stringify([{name:'af_alloy',active:true}]));
assert.equal(JSON.stringify(model.parseVoices('[]')), JSON.stringify([]));
assert.equal(JSON.stringify(model.parseVoices('garbage')), JSON.stringify([]));

// isDaemonRunning
assert.equal(model.isDaemonRunning({running:true}), true);
assert.equal(model.isDaemonRunning({running:false}), false);
assert.equal(model.isDaemonRunning(null), false);

// modelName
assert.equal(model.modelName({model:'kokoro-82m-gguf'}), 'kokoro-82m-gguf');
assert.equal(model.modelName({}), '');

// backendName
assert.equal(model.backendName({backend:{requested:{runtime:'audiocpp',device:'cpu'}}}), 'audiocpp / cpu');
assert.equal(model.backendName({backend:{kind:'openvino'}}), 'openvino');
assert.equal(model.backendName(null), '');

// parseUnitLoadState
assert.equal(model.parseUnitLoadState('loaded\n'), true);
assert.equal(model.parseUnitLoadState('not-found'), false);

// activeVoiceId
assert.equal(model.activeVoiceId({backend:{requests:{active:{voice:3}}}}), 3);
assert.equal(model.activeVoiceId({backend:{requests:{active:{}}}}), -1);
assert.equal(model.activeVoiceId({}), -1);
assert.equal(model.activeVoiceId(null), -1);

console.log('Omaspeak Model tests passed: status, voices, daemon state, backend, unit load, active voice.');
