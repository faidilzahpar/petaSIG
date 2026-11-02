/**
 * TopoMesh Geodetic Surveyor - Core Web & Mobile Engine
 * Multilaterasi BLE, Barometer Diferensial, Delaunay TIN & Kontur Marching Triangles
 */

// State Global
const surveyState = {
  activeCode: 'GL',
  poleHeight: 1.5,
  pointCounter: 7,
  isPlumb: true,
  tiltAngle: 0.8,
  pitch: 0.5,
  roll: 0.6,
  contourInterval: 0.5,
  showTin: true,
  showContours: true,
  is3D: false,
  yaw3D: 45 * Math.PI / 180,
  pitch3D: 30 * Math.PI / 180,

  // Rover Realtime State
  rover: { x: 8.5, y: 6.2, z: 100.8 },
  baseElevation: 100.0,
  baseBaro: 1001.25,
  currentBaro: 1001.25,
  rmse: 0.18,
  gdop: 1.8,

  // 3 Anchor Constellation
  anchors: [
    { id: 'ANC_A', name: 'Anchor A (Base 0,0)', x: 0.0, y: 0.0, z: 100.0, dist: 10.5, rssi: -62, baro: 1001.25 },
    { id: 'ANC_B', name: 'Anchor B (Baseline X)', x: 20.0, y: 0.0, z: 100.2, dist: 13.0, rssi: -65, baro: 1001.22 },
    { id: 'ANC_C', name: 'Anchor C (Triangulasi Y)', x: 10.0, y: 17.32, z: 101.5, dist: 11.2, rssi: -64, baro: 1001.08 },
  ],

  // Surveyed Points
  points: [
    { id: 'PT-001', code: 'BM', x: 2.0, y: 3.0, z: 100.00, rmse: 0.12 },
    { id: 'PT-002', code: 'GL', x: 18.0, y: 2.5, z: 100.30, rmse: 0.15 },
    { id: 'PT-003', code: 'CR', x: 17.5, y: 15.0, z: 101.80, rmse: 0.19 },
    { id: 'PT-004', code: 'TS', x: 3.0, y: 16.0, z: 101.20, rmse: 0.17 },
    { id: 'PT-005', code: 'GL', x: 10.0, y: 8.5, z: 100.90, rmse: 0.14 },
    { id: 'PT-006', code: 'BL', x: 8.0, y: 14.0, z: 101.40, rmse: 0.16 },
  ],

  tinTriangles: [],
  contourSegments: []
};

// ---------------------------------------------------------------------
// 1. Inisialisasi & Event Listeners
// ---------------------------------------------------------------------
document.addEventListener('DOMContentLoaded', () => {
  setupUiListeners();
  setupIosOrientationSensor();
  recomputeSurface();
  startSimulationTicker();
  requestAnimationFrame(renderLoop);
});

function setupUiListeners() {
  // Kode Fitur
  const chips = document.querySelectorAll('.chip');
  chips.forEach(chip => {
    chip.addEventListener('click', () => {
      chips.forEach(c => c.classList.remove('active'));
      chip.classList.add('active');
      surveyState.activeCode = chip.getAttribute('data-code');
    });
  });

  // Tinggi Jalon
  document.getElementById('pole-height-select').addEventListener('change', (e) => {
    surveyState.poleHeight = parseFloat(e.target.value);
    updateHud();
  });

  // Interval Kontur
  document.getElementById('contour-interval-select').addEventListener('change', (e) => {
    surveyState.contourInterval = parseFloat(e.target.value);
    recomputeSurface();
  });

  // Toggle Layer Peta
  document.getElementById('btn-toggle-tin').addEventListener('click', function() {
    this.classList.toggle('active');
    surveyState.showTin = this.classList.contains('active');
  });

  document.getElementById('btn-toggle-contours').addEventListener('click', function() {
    this.classList.toggle('active');
    surveyState.showContours = this.classList.contains('active');
  });

  document.getElementById('btn-toggle-3d').addEventListener('click', function() {
    this.classList.toggle('active');
    surveyState.is3D = this.classList.contains('active');
    this.textContent = surveyState.is3D ? '2D PLAN' : '3D RELIEF';
  });

  // Tombol Rekam Titik
  document.getElementById('log-point-btn').addEventListener('click', recordSurveyPoint);

  // Tombol Ekspor
  document.getElementById('export-csv-btn').addEventListener('click', exportCsv);
  document.getElementById('export-geojson-btn').addEventListener('click', exportGeoJson);
  document.getElementById('export-dxf-btn').addEventListener('click', exportDxf);
}

// ---------------------------------------------------------------------
// 2. Sensor Orientasi Waterpass (iOS Safari & Android)
// ---------------------------------------------------------------------
function setupIosOrientationSensor() {
  // Jika di iPhone (iOS 13+), butuh izin DeviceOrientationEvent
  if (typeof DeviceOrientationEvent !== 'undefined' && typeof DeviceOrientationEvent.requestPermission === 'function') {
    document.body.addEventListener('click', async () => {
      try {
        const resp = await DeviceOrientationEvent.requestPermission();
        if (resp === 'granted') {
          window.addEventListener('deviceorientation', handleOrientation);
        }
      } catch (_) {}
    }, { once: true });
  } else if ('ondeviceorientation' in window) {
    window.addEventListener('deviceorientation', handleOrientation);
  }
}

function handleOrientation(e) {
  if (e.beta !== null && e.gamma !== null) {
    surveyState.pitch = e.beta;  // Depan-belakang (-180 s/d 180)
    surveyState.roll = e.gamma;  // Kiri-kanan (-90 s/d 90)
    surveyState.tiltAngle = Math.sqrt(surveyState.pitch * surveyState.pitch + surveyState.roll * surveyState.roll);
    surveyState.isPlumb = surveyState.tiltAngle <= 2.0;
  }
}

// ---------------------------------------------------------------------
// 3. Rekam Titik Survei
// ---------------------------------------------------------------------
function recordSurveyPoint() {
  if (!surveyState.isPlumb) {
    alert(`PERINGATAN SURVEYOR: Jalon survei miring (${surveyState.tiltAngle.toFixed(1)}°)! Tegakkan waterpass di bawah 2.0° sebelum merekam.`);
    return;
  }

  const ptId = `PT-${String(surveyState.pointCounter).padStart(3, '0')}`;
  const groundZ = surveyState.rover.z - surveyState.poleHeight;

  surveyState.points.push({
    id: ptId,
    code: surveyState.activeCode,
    x: surveyState.rover.x,
    y: surveyState.rover.y,
    z: groundZ,
    rmse: surveyState.rmse,
  });

  surveyState.pointCounter++;
  document.getElementById('btn-label').textContent = `REKAM TITIK SURVEI [PT-${String(surveyState.pointCounter).padStart(3, '0')}]`;

  recomputeSurface();
  updateHud();

  if (navigator.vibrate) navigator.vibrate(50);
}

// ---------------------------------------------------------------------
// 4. Delaunay Triangulation & Marching Triangles Contours
// ---------------------------------------------------------------------
function recomputeSurface() {
  if (surveyState.points.length < 3) return;

  const pts = surveyState.points.map(p => ({ x: p.x, y: p.y, z: p.z }));
  surveyState.tinTriangles = triangulateDelaunay(pts);
  surveyState.contourSegments = generateContours(surveyState.tinTriangles, surveyState.contourInterval);

  // Update statistics
  const minZ = Math.min(...surveyState.points.map(p => p.z));
  const maxZ = Math.max(...surveyState.points.map(p => p.z));
  const relief = maxZ - minZ;

  document.getElementById('stat-points').textContent = surveyState.points.length;
  document.getElementById('stat-triangles').textContent = surveyState.tinTriangles.length;
  document.getElementById('stat-relief').textContent = `${relief.toFixed(2)}m`;
  document.getElementById('legend-min').textContent = `${minZ.toFixed(1)}m`;
  document.getElementById('legend-max').textContent = `${maxZ.toFixed(1)}m`;
}

function triangulateDelaunay(points) {
  // Bowyer-Watson sederhana untuk survei topografi
  let minX = points[0].x, maxX = points[0].x;
  let minY = points[0].y, maxY = points[0].y;
  for (let p of points) {
    minX = Math.min(minX, p.x); maxX = Math.max(maxX, p.x);
    minY = Math.min(minY, p.y); maxY = Math.max(maxY, p.y);
  }
  const delta = Math.max(maxX - minX, maxY - minY) * 3 || 30;
  const midX = (minX + maxX) / 2;
  const midY = (minY + maxY) / 2;

  const stA = { x: midX - 2 * delta, y: midY - delta, z: 100 };
  const stB = { x: midX, y: midY + 2 * delta, z: 100 };
  const stC = { x: midX + 2 * delta, y: midY - delta, z: 100 };

  let triangles = [{ a: stA, b: stB, c: stC }];

  for (let point of points) {
    let badTriangles = [];
    let edges = [];

    for (let t of triangles) {
      if (inCircumcircle(point, t.a, t.b, t.c)) {
        badTriangles.push(t);
        edges.push({ u: t.a, v: t.b }, { u: t.b, v: t.c }, { u: t.c, v: t.a });
      }
    }

    triangles = triangles.filter(t => !badTriangles.includes(t));

    // Ambil edge unik
    let uniqueEdges = [];
    for (let i = 0; i < edges.length; i++) {
      let isShared = false;
      for (let j = 0; j < edges.length; j++) {
        if (i !== j && isSameEdge(edges[i], edges[j])) {
          isShared = true; break;
        }
      }
      if (!isShared) uniqueEdges.push(edges[i]);
    }

    for (let edge of uniqueEdges) {
      triangles.push({ a: edge.u, b: edge.v, c: point });
    }
  }

  // Hapus segitiga yang bersinggungan dengan super-triangle
  return triangles.filter(t =>
    t.a !== stA && t.a !== stB && t.a !== stC &&
    t.b !== stA && t.b !== stB && t.b !== stC &&
    t.c !== stA && t.c !== stB && t.c !== stC
  );
}

function inCircumcircle(p, a, b, c) {
  const ax = a.x - p.x, ay = a.y - p.y;
  const bx = b.x - p.x, by = b.y - p.y;
  const cx = c.x - p.x, cy = c.y - p.y;

  const det = (ax*ax + ay*ay)*(bx*cy - cx*by) -
              (bx*bx + by*by)*(ax*cy - cx*ay) +
              (cx*cx + cy*cy)*(ax*by - bx*ay);

  const orient = (b.x - a.x)*(c.y - a.y) - (b.y - a.y)*(c.x - a.x);
  return orient < 0 ? det < 0 : det > 0;
}

function isSameEdge(e1, e2) {
  return (e1.u === e2.u && e1.v === e2.v) || (e1.u === e2.v && e1.v === e2.u);
}

function generateContours(triangles, interval) {
  if (!triangles.length) return [];
  let minZ = Infinity, maxZ = -Infinity;
  for (let t of triangles) {
    minZ = Math.min(minZ, t.a.z, t.b.z, t.c.z);
    maxZ = Math.max(maxZ, t.a.z, t.b.z, t.c.z);
  }

  const segments = [];
  const startLevel = Math.ceil(minZ / interval) * interval;

  for (let level = startLevel; level <= maxZ; level += interval) {
    const isIndex = Math.abs(level % (interval * 5)) < 1e-5;
    for (let tri of triangles) {
      const seg = interpolateTriangle(tri, level, isIndex);
      if (seg) segments.push(seg);
    }
  }
  return segments;
}

function interpolateTriangle(tri, z, isIndex) {
  const pts = [];
  checkEdge(tri.a, tri.b, z, pts);
  checkEdge(tri.b, tri.c, z, pts);
  checkEdge(tri.c, tri.a, z, pts);

  if (pts.length === 2) {
    return { start: pts[0], end: pts[1], elevation: z, isIndex };
  }
  return null;
}

function checkEdge(p1, p2, z, pts) {
  if ((p1.z <= z && p2.z >= z) || (p1.z >= z && p2.z <= z)) {
    const dz = p2.z - p1.z;
    if (Math.abs(dz) > 1e-6) {
      const t = (z - p1.z) / dz;
      pts.push({
        x: p1.x + t * (p2.x - p1.x),
        y: p1.y + t * (p2.y - p1.y),
        z: z
      });
    }
  }
}

// ---------------------------------------------------------------------
// 5. Render Loop & Canvas Visualizations
// ---------------------------------------------------------------------
function renderLoop() {
  renderBubbleLevel();
  renderMeshRadar();
  renderTopoMap();
  requestAnimationFrame(renderLoop);
}

function renderBubbleLevel() {
  const canvas = document.getElementById('bubbleCanvas');
  const ctx = canvas.getContext('2d');
  const w = canvas.width, h = canvas.height;
  const center = { x: w / 2, y: h / 2 };

  ctx.clearRect(0, 0, w, h);

  // Garis silang
  ctx.strokeStyle = '#30363D';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(0, center.y); ctx.lineTo(w, center.y);
  ctx.moveTo(center.x, 0); ctx.lineTo(center.x, h);
  ctx.stroke();

  // Lingkaran batas toleransi 2 derajat
  ctx.strokeStyle = surveyState.isPlumb ? '#00E676' : '#FF4D4F';
  ctx.lineWidth = 1.5;
  ctx.beginPath();
  ctx.arc(center.x, center.y, 14, 0, Math.PI * 2);
  ctx.stroke();

  // Gelembung udara
  const maxR = (w - 24) / 2;
  const dx = Math.min(Math.max(surveyState.roll / 8.0, -1), 1) * maxR;
  const dy = Math.min(Math.max(surveyState.pitch / 8.0, -1), 1) * maxR;

  ctx.fillStyle = surveyState.isPlumb ? '#00E676' : '#FF9F1C';
  ctx.beginPath();
  ctx.arc(center.x + dx, center.y + dy, 7, 0, Math.PI * 2);
  ctx.fill();

  // Update label
  const label = document.getElementById('tilt-angle-label');
  label.textContent = `${surveyState.tiltAngle.toFixed(1)}°`;
  label.className = `tilt-badge mono ${surveyState.isPlumb ? 'text-green' : 'text-amber'}`;

  const statusText = document.getElementById('level-status-text');
  statusText.textContent = surveyState.isPlumb ? '● JALON TEGAK (PLUMB)' : '▲ JALON MIRING';
  statusText.style.color = surveyState.isPlumb ? '#00E676' : '#FF4D4F';
}

function renderMeshRadar() {
  const canvas = document.getElementById('radarCanvas');
  const ctx = canvas.getContext('2d');
  const w = canvas.width, h = canvas.height;
  const center = { x: w / 2, y: h / 2 };
  const scale = 3.6; // piksel per meter

  ctx.clearRect(0, 0, w, h);

  // Lingkaran konsentris
  ctx.strokeStyle = '#21262D';
  ctx.lineWidth = 1;
  for (let r of [10, 20, 30]) {
    ctx.beginPath();
    ctx.arc(center.x, center.y, r * scale, 0, Math.PI * 2);
    ctx.stroke();
  }

  // Sinar multilaterasi ke Rover
  const rx = center.x + surveyState.rover.x * scale;
  const ry = center.y - surveyState.rover.y * scale;

  ctx.strokeStyle = 'rgba(0, 240, 255, 0.4)';
  ctx.lineWidth = 1.2;

  for (let a of surveyState.anchors) {
    const ax = center.x + a.x * scale;
    const ay = center.y - a.y * scale;

    ctx.beginPath();
    ctx.moveTo(ax, ay);
    ctx.lineTo(rx, ry);
    ctx.stroke();

    // Node Anchor
    ctx.fillStyle = a.id === 'ANC_A' ? '#00E676' : '#38BDF8';
    ctx.beginPath();
    ctx.arc(ax, ay, 5, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = '#F0F6FC';
    ctx.font = '8px monospace';
    ctx.fillText(`${a.id} (${a.dist.toFixed(1)}m)`, ax + 6, ay - 4);
  }

  // Rover Node
  ctx.fillStyle = '#FF9F1C';
  ctx.beginPath();
  ctx.arc(rx, ry, 6, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillText('ROVER', rx + 8, ry + 4);
}

function renderTopoMap() {
  const canvas = document.getElementById('topoCanvas');
  const ctx = canvas.getContext('2d');
  const w = canvas.width, h = canvas.height;
  const center = { x: w / 2, y: h / 2 };
  const scale = 11.0;

  ctx.clearRect(0, 0, w, h);

  // Grid
  ctx.strokeStyle = 'rgba(48, 54, 61, 0.4)';
  ctx.lineWidth = 0.8;
  for (let x = 0; x < w; x += 25) {
    ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, h); ctx.stroke();
  }
  for (let y = 0; y < h; y += 25) {
    ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke();
  }

  const minZ = Math.min(...surveyState.points.map(p => p.z), 100);
  const maxZ = Math.max(...surveyState.points.map(p => p.z), 102);

  // TIN Mesh
  if (surveyState.showTin) {
    ctx.strokeStyle = '#21262D';
    ctx.lineWidth = 0.8;
    for (let t of surveyState.tinTriangles) {
      const p1 = { x: center.x + t.a.x * scale, y: center.y - t.a.y * scale };
      const p2 = { x: center.x + t.b.x * scale, y: center.y - t.b.y * scale };
      const p3 = { x: center.x + t.c.x * scale, y: center.y - t.c.y * scale };

      ctx.beginPath();
      ctx.moveTo(p1.x, p1.y); ctx.lineTo(p2.x, p2.y); ctx.lineTo(p3.x, p3.y); ctx.closePath();

      const avgZ = (t.a.z + t.b.z + t.c.z) / 3;
      ctx.fillStyle = getElevationColorRgba(avgZ, minZ, maxZ, 0.2);
      ctx.fill();
      ctx.stroke();
    }
  }

  // Contours
  if (surveyState.showContours) {
    for (let c of surveyState.contourSegments) {
      ctx.strokeStyle = c.isIndex ? '#EA580C' : '#FBBF24';
      ctx.lineWidth = c.isIndex ? 2.0 : 1.0;
      ctx.beginPath();
      ctx.moveTo(center.x + c.start.x * scale, center.y - c.start.y * scale);
      ctx.lineTo(center.x + c.end.x * scale, center.y - c.end.y * scale);
      ctx.stroke();
    }
  }

  // Titik Survei
  for (let p of surveyState.points) {
    const px = center.x + p.x * scale;
    const py = center.y - p.y * scale;

    ctx.fillStyle = getElevationColorRgba(p.z, minZ, maxZ, 1.0);
    ctx.beginPath();
    ctx.arc(px, py, 4, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = '#F0F6FC';
    ctx.font = '8px monospace';
    ctx.fillText(`${p.id} (${p.z.toFixed(2)}m)`, px + 6, py - 4);
  }

  // Posisi Rover
  const rx = center.x + surveyState.rover.x * scale;
  const ry = center.y - surveyState.rover.y * scale;
  ctx.fillStyle = '#FF9F1C';
  ctx.beginPath();
  ctx.arc(rx, ry, 6, 0, Math.PI * 2);
  ctx.fill();
}

function getElevationColorRgba(z, minZ, maxZ, alpha) {
  const t = Math.max(0, Math.min(1, (z - minZ) / (maxZ - minZ || 1)));
  if (t < 0.3) return `rgba(16, 185, 129, ${alpha})`;
  if (t < 0.6) return `rgba(251, 191, 36, ${alpha})`;
  return `rgba(234, 88, 12, ${alpha})`;
}

function updateHud() {
  const groundElevation = surveyState.rover.z - surveyState.poleHeight;
  const deltaZ = groundElevation - surveyState.baseElevation;

  document.getElementById('elevation-value').textContent = groundElevation.toFixed(3);
  document.getElementById('delta-value').textContent = `${deltaZ >= 0 ? '+' : ''}${deltaZ.toFixed(3)} m`;
  document.getElementById('local-x').textContent = `${surveyState.rover.x.toFixed(2)} m`;
  document.getElementById('local-y').textContent = `${surveyState.rover.y.toFixed(2)} m`;
  document.getElementById('rmse-val').textContent = `±${surveyState.rmse.toFixed(2)} m`;
  document.getElementById('gdop-val').textContent = surveyState.gdop.toFixed(1);
}

// ---------------------------------------------------------------------
// 6. Simulasi Ticker Gerakan Rover & Fluktuasi BLE
// ---------------------------------------------------------------------
function startSimulationTicker() {
  let tick = 0;
  setInterval(() => {
    tick += 0.05;
    // Sedikit goyangan jalon waterpass saat dipegang
    if (!('ondeviceorientation' in window)) {
      surveyState.pitch = 0.5 + Math.sin(tick) * 0.4;
      surveyState.roll = 0.6 + Math.cos(tick) * 0.3;
      surveyState.tiltAngle = Math.sqrt(surveyState.pitch * surveyState.pitch + surveyState.roll * surveyState.roll);
      surveyState.isPlumb = surveyState.tiltAngle <= 2.0;
    }

    // Hitung jarak ke 3 anchor
    for (let a of surveyState.anchors) {
      a.dist = Math.sqrt(
        Math.pow(surveyState.rover.x - a.x, 2) +
        Math.pow(surveyState.rover.y - a.y, 2) +
        Math.pow(surveyState.rover.z - a.z, 2)
      );
    }
  }, 100);
}

// ---------------------------------------------------------------------
// 7. Ekspor CSV, GeoJSON, DXF
// ---------------------------------------------------------------------
function exportCsv() {
  let csv = 'Point_ID,Northing_Y_m,Easting_X_m,Elevation_Z_m,Code,Local_X,Local_Y,RMSE_m\n';
  for (let p of surveyState.points) {
    csv += `${p.id},${(9245100 + p.y).toFixed(3)},${(684200 + p.x).toFixed(3)},${p.z.toFixed(3)},${p.code},${p.x.toFixed(3)},${p.y.toFixed(3)},${p.rmse.toFixed(2)}\n`;
  }
  downloadFile(csv, 'survey_topografi_points.csv', 'text/csv');
}

function exportGeoJson() {
  const features = surveyState.points.map(p => ({
    type: 'Feature',
    geometry: { type: 'Point', coordinates: [107.618 + p.x*0.00001, -6.824 + p.y*0.00001, p.z] },
    properties: { id: p.id, code: p.code, elevation: p.z, rmse: p.rmse }
  }));
  const geojson = JSON.stringify({ type: 'FeatureCollection', features }, null, 2);
  downloadFile(geojson, 'survey_topografi.geojson', 'application/json');
}

function exportDxf() {
  let dxf = '0\nSECTION\n2\nENTITIES\n';
  for (let p of surveyState.points) {
    dxf += `0\nPOINT\n8\nSURVEY_POINTS\n10\n${p.x.toFixed(3)}\n20\n${p.y.toFixed(3)}\n30\n${p.z.toFixed(3)}\n`;
  }
  for (let c of surveyState.contourSegments) {
    dxf += `0\nLINE\n8\nCONTOURS\n10\n${c.start.x.toFixed(3)}\n20\n${c.start.y.toFixed(3)}\n30\n${c.elevation.toFixed(3)}\n11\n${c.end.x.toFixed(3)}\n21\n${c.end.y.toFixed(3)}\n31\n${c.elevation.toFixed(3)}\n`;
  }
  dxf += '0\nENDSEC\n0\nEOF\n';
  downloadFile(dxf, 'survey_topografi_3d.dxf', 'application/dxf');
}

function downloadFile(content, fileName, mimeType) {
  const blob = new Blob([content], { type: mimeType });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = fileName;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
}

