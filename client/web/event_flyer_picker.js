// Local raster file selection. Canvas re-encoding strips metadata and bounds media.
window.communityAccessPickFlyer = () => new Promise((resolve, reject) => {
  const input = document.createElement('input');
  input.type = 'file'; input.accept = 'image/jpeg,image/png'; input.hidden = true;
  const cleanup = () => input.remove();
  input.addEventListener('cancel', () => { cleanup(); resolve(''); }, { once: true });
  input.addEventListener('change', async () => {
    let bitmap;
    try {
      const file = input.files[0];
      if (!file) { resolve(''); return; }
      if (!['image/jpeg','image/png'].includes(file.type) || file.size > 10 * 1024 * 1024) throw new Error('INVALID_IMAGE');
      bitmap = await createImageBitmap(file);
      const ratio = Math.min(1, 1600 / Math.max(bitmap.width, bitmap.height));
      const canvas = document.createElement('canvas');
      canvas.width = Math.max(1, Math.round(bitmap.width * ratio));
      canvas.height = Math.max(1, Math.round(bitmap.height * ratio));
      const ctx = canvas.getContext('2d');
      ctx.fillStyle = '#ffffff'; ctx.fillRect(0,0,canvas.width,canvas.height);
      ctx.drawImage(bitmap,0,0,canvas.width,canvas.height);
      let data;
      for (const quality of [0.88,0.75,0.6,0.45]) {
        data = canvas.toDataURL('image/jpeg',quality);
        if ((data.length - data.indexOf(',') - 1) * 3 / 4 <= 256 * 1024) { resolve(data); return; }
      }
      throw new Error('IMAGE_TOO_LARGE');
    } catch (_) { reject(new Error('INVALID_IMAGE')); }
    finally { bitmap?.close(); cleanup(); }
  }, { once: true });
  document.body.append(input); input.click();
});
