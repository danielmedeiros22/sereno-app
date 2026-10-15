// Invoked directly by the prepared report's button to preserve user activation.
window.serenoSaveReport = async function (bytes, name, mimeType) {
  if (typeof window.showSaveFilePicker === 'function') {
    let handle;
    try {
      handle = await window.showSaveFilePicker({
        suggestedName: name,
        types: [{
          description: mimeType === 'application/pdf' ? 'Relatório PDF' : 'Planilha CSV',
          accept: { [mimeType]: [mimeType === 'application/pdf' ? '.pdf' : '.csv'] }
        }]
      });
    } catch (error) {
      if (error.name === 'AbortError') return;
      throw error;
    }
    const stream = await handle.createWritable();
    try {
      await stream.write(bytes);
      await stream.close();
    } catch (error) {
      try { await stream.abort(); } catch (_) { /* Preserve original failure. */ }
      throw error;
    }
    return;
  }
  // Other desktop browsers use their configured download destination.
  const url = URL.createObjectURL(new Blob([bytes], { type: mimeType }));
  const link = document.createElement('a');
  link.href = url;
  link.download = name;
  document.body.appendChild(link);
  try { link.click(); } finally {
    link.remove();
    setTimeout(() => URL.revokeObjectURL(url), 60000);
  }
};
