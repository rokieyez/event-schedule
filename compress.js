// 이미지를 지정한 용량 이하로 압축 (JPEG로 재인코딩 + 필요시 크기도 축소)
// 이미지가 아니거나 이미 목표 용량 이하면 원본 파일을 그대로 반환함
async function compressImageToLimit(file, maxBytes, opts) {
  opts = opts || {};
  const maxDim = opts.maxDim || 2400;

  if (!file.type || !file.type.startsWith('image/')) return file;
  if (file.size <= maxBytes) return file;

  let img;
  const url = URL.createObjectURL(file);
  try {
    img = await new Promise((resolve, reject) => {
      const im = new Image();
      im.onload = () => resolve(im);
      im.onerror = reject;
      im.src = url;
    });
  } catch (e) {
    URL.revokeObjectURL(url);
    return file; // 디코딩 실패 시 원본 그대로 업로드
  }

  let width = img.naturalWidth, height = img.naturalHeight;
  if (Math.max(width, height) > maxDim) {
    const scale = maxDim / Math.max(width, height);
    width = Math.round(width * scale);
    height = Math.round(height * scale);
  }

  const canvas = document.createElement('canvas');
  const ctx = canvas.getContext('2d');
  function draw() {
    canvas.width = width; canvas.height = height;
    ctx.drawImage(img, 0, 0, width, height);
  }

  let quality = 0.88;
  draw();
  let blob = await new Promise(r => canvas.toBlob(r, 'image/jpeg', quality));

  // 화질을 낮춰가며 용량 맞추기
  while (blob && blob.size > maxBytes && quality > 0.4) {
    quality -= 0.1;
    blob = await new Promise(r => canvas.toBlob(r, 'image/jpeg', quality));
  }
  // 그래도 크면 가로세로 크기 자체를 줄여가며 재시도
  while (blob && blob.size > maxBytes && Math.min(width, height) > 500) {
    width = Math.round(width * 0.85);
    height = Math.round(height * 0.85);
    draw();
    blob = await new Promise(r => canvas.toBlob(r, 'image/jpeg', quality));
  }

  URL.revokeObjectURL(url);

  if (!blob) return file;
  const newName = file.name.replace(/\.\w+$/, '') + '.jpg';
  return new File([blob], newName, { type: 'image/jpeg' });
}
