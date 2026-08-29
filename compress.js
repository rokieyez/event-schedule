// 이미지를 지정한 용량 이하로 압축(JPEG로 재인코딩) + EXIF에 촬영 날짜/위치가 있으면
// 사진 우측 하단에 작은 워터마크로 새겨 넣음. exifr 라이브러리가 로드돼 있어야 워터마크가 동작함
// (없어도 압축 기능 자체는 정상 동작).

const _geocodeCache = new Map();

async function _reverseGeocode(lat, lng){
  const key = lat.toFixed(3) + ',' + lng.toFixed(3);
  if (_geocodeCache.has(key)) return _geocodeCache.get(key);

  const timeout = new Promise(resolve => setTimeout(() => resolve(''), 5000));
  const fetchPromise = (async () => {
    try {
      const res = await fetch(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=' + lat + '&lon=' + lng + '&accept-language=ko&zoom=16'
      );
      if (!res.ok) return '';
      const data = await res.json();
      const a = data.address || {};
      const region = a.city || a.town || a.county || a.state || '';
      const district = a.borough || a.suburb || a.city_district || a.village || '';
      const parts = [region, district].filter(Boolean);
      if (parts.length) return parts.join(' ');
      return (data.display_name || '').split(',').slice(0, 2).join(' ').trim();
    } catch (e) { return ''; }
  })();

  const result = await Promise.race([fetchPromise, timeout]);
  _geocodeCache.set(key, result);
  return result;
}

async function _buildWatermarkText(file){
  if (typeof exifr === 'undefined') return '';
  let exif;
  try {
    exif = await exifr.parse(file, { pick: ['DateTimeOriginal', 'CreateDate', 'latitude', 'longitude'] });
  } catch (e) { return ''; }
  if (!exif) return '';

  let dateStr = '';
  const dt = exif.DateTimeOriginal || exif.CreateDate;
  if (dt instanceof Date && !isNaN(dt)) {
    const pad = n => String(n).padStart(2, '0');
    dateStr = dt.getFullYear() + '.' + pad(dt.getMonth() + 1) + '.' + pad(dt.getDate()) + ' ' + pad(dt.getHours()) + ':' + pad(dt.getMinutes());
  }

  let placeStr = '';
  if (typeof exif.latitude === 'number' && typeof exif.longitude === 'number') {
    placeStr = await _reverseGeocode(exif.latitude, exif.longitude);
  }

  return [dateStr, placeStr].filter(Boolean).join('   ');
}

function _drawWatermark(ctx, width, height, text){
  if (!text) return;
  const fontSize = Math.max(16, Math.round(width * 0.02));
  ctx.font = fontSize + 'px -apple-system, sans-serif';
  const paddingX = fontSize * 0.7, paddingY = fontSize * 0.45;
  const textWidth = ctx.measureText(text).width;
  const boxW = textWidth + paddingX * 2;
  const boxH = fontSize + paddingY * 2;
  const margin = fontSize * 0.6;
  const x = width - boxW - margin;
  const y = height - boxH - margin;
  const r = boxH / 2;

  ctx.fillStyle = 'rgba(0,0,0,0.42)';
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + boxW, y, x + boxW, y + boxH, r);
  ctx.arcTo(x + boxW, y + boxH, x, y + boxH, r);
  ctx.arcTo(x, y + boxH, x, y, r);
  ctx.arcTo(x, y, x + boxW, y, r);
  ctx.closePath();
  ctx.fill();

  ctx.fillStyle = '#ffffff';
  ctx.textBaseline = 'middle';
  ctx.fillText(text, x + paddingX, y + boxH / 2 + 1);
}

// 이미 저장돼 있는 사진을 재처리할 때 쓰는 함수. 크기는 그대로 두고 EXIF 워터마크만 새겨 넣음.
// EXIF(날짜/위치)가 없으면 원본 파일을 그대로 반환함(호출 측에서 file === 반환값이면 "건너뜀"으로 판단 가능).
async function addExifWatermark(file){
  if (!file.type || !file.type.startsWith('image/')) return file;

  const watermarkText = await _buildWatermarkText(file);
  if (!watermarkText) return file;

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
    return file;
  }

  const width = img.naturalWidth, height = img.naturalHeight;
  const canvas = document.createElement('canvas');
  canvas.width = width; canvas.height = height;
  const ctx = canvas.getContext('2d');
  ctx.drawImage(img, 0, 0, width, height);
  _drawWatermark(ctx, width, height, watermarkText);
  URL.revokeObjectURL(url);

  const blob = await new Promise(r => canvas.toBlob(r, 'image/jpeg', 0.92));
  if (!blob) return file;
  return new File([blob], file.name.replace(/\.\w+$/, '') + '.jpg', { type: 'image/jpeg' });
}

// 이미지가 아니면 원본 그대로 반환. 목표 용량 이하이면서 워터마크로 찍을 정보도 없으면
// 손대지 않고 원본 그대로 반환(불필요한 화질 손실 방지).
async function compressImageToLimit(file, maxBytes, opts) {
  opts = opts || {};
  const maxDim = opts.maxDim || 2400;

  if (!file.type || !file.type.startsWith('image/')) return file;

  const watermarkText = await _buildWatermarkText(file);
  if (file.size <= maxBytes && !watermarkText) return file;

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
    _drawWatermark(ctx, width, height, watermarkText);
  }

  let quality = 0.9;
  draw();
  let blob = await new Promise(r => canvas.toBlob(r, 'image/jpeg', quality));

  // 화질을 낮춰가며 용량 맞추기 (목표 용량이 지정된 경우에만)
  while (maxBytes && blob && blob.size > maxBytes && quality > 0.4) {
    quality -= 0.1;
    blob = await new Promise(r => canvas.toBlob(r, 'image/jpeg', quality));
  }
  // 그래도 크면 가로세로 크기 자체를 줄여가며 재시도
  while (maxBytes && blob && blob.size > maxBytes && Math.min(width, height) > 500) {
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
