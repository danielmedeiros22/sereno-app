const { readFileSync } = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = readFileSync('web/report_file_save.js', 'utf8');
function setup(picker) {
  const events = [];
  const window = picker ? { showSaveFilePicker: picker } : {};
  vm.runInNewContext(source, {
    window, Blob,
    URL: { createObjectURL: blob => { events.push(blob.type); return 'blob:test'; },
      revokeObjectURL: url => events.push(url) },
    document: { body: { appendChild: () => {} }, createElement: () => ({
      click() { events.push(this.download); }, remove() {} }) },
    setTimeout: callback => callback()
  });
  return { save: window.serenoSaveReport, events };
}
(async () => {
  for (const [mime, extension] of [['application/pdf', '.pdf'], ['text/csv', '.csv']]) {
    const written = [];
    const bytes = new Uint8Array([1, 2, 3]);
    const saver = setup(async options => {
      assert.equal(options.suggestedName, `report${extension}`);
      assert.equal(options.types[0].accept[mime][0], extension);
      return { createWritable: async () => ({
        write: async value => written.push(value), close: async () => written.push('closed')
      }) };
    });
    await saver.save(bytes, `report${extension}`, mime);
    assert.equal(written[0], bytes);
    assert.equal(written[1], 'closed');
    assert.deepEqual(saver.events, []);
    const fallback = setup();
    await fallback.save(bytes, `report${extension}`, mime);
    assert.deepEqual(fallback.events, [mime, `report${extension}`, 'blob:test']);
  }
  const cancelled = setup(async () => { throw Object.assign(new Error(), { name: 'AbortError' }); });
  await cancelled.save(new Uint8Array(), 'report.pdf', 'application/pdf');
  assert.deepEqual(cancelled.events, []);
  const denied = setup(async () => { throw new Error('denied'); });
  await assert.rejects(denied.save(new Uint8Array(), 'report.pdf', 'application/pdf'), /denied/);
  assert.deepEqual(denied.events, []);
  let aborted = false;
  const failedWrite = setup(async () => ({ createWritable: async () => ({
    write: async () => { throw new Error('disk full'); },
    abort: async () => { aborted = true; }
  }) }));
  await assert.rejects(failedWrite.save(new Uint8Array(), 'report.pdf', 'application/pdf'), /disk full/);
  assert.equal(aborted, true);
  assert.deepEqual(failedWrite.events, []);
  console.log('Report saving: PDF/CSV picker, download, cancellation and failures passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
