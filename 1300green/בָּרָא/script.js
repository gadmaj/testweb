const layers = [];
let selectedId = null;
let nextZ = 1;
let activeAction = null;

const canvasEl = document.getElementById('canvas-area');
const layerListEl = document.getElementById('layer-list');
const placeholderEl = document.getElementById('placeholder');
const fileInput = document.getElementById('file-input');

// ── Presets ──
async function loadPresets() {
    try {
        const res = await fetch('../textures/index.json');
        const files = await res.json();
        return files.map(name => ({ name, src: `../textures/${name}` }));
    } catch {
        return [];
    }
}

// ── Give ──
function triggerGive() { fileInput.value = ''; fileInput.click(); }
fileInput.addEventListener('change', () => {
    [...fileInput.files].forEach(f => addLayer(URL.createObjectURL(f), f.name));
});

// ── Add layer ──
function addLayer(src, name) {
    const id = 'l-' + Date.now() + '-' + Math.random().toString(36).slice(2);
    const z = nextZ++;

    const el = document.createElement('div');
    el.className = 'layer';
    el.dataset.id = id;
    el.style.zIndex = z;
    el.style.left = '20px';
    el.style.top = '20px';

    const inner = document.createElement('div');
    inner.className = 'layer-inner';

    const img = document.createElement('img');
    img.src = src;
    inner.appendChild(img);
    el.appendChild(inner);

    // corner scale handles
    ['tl', 'tr', 'bl', 'br'].forEach(c => {
        const h = document.createElement('div');
        h.className = `handle handle-${c}`;
        h.addEventListener('mousedown', e => startScale(e, id, c));
        inner.appendChild(h);
    });

    // rotation handle
    const rot = document.createElement('div');
    rot.className = 'handle handle-rot';
    rot.textContent = '↻';
    rot.addEventListener('mousedown', e => startRotate(e, id));
    inner.appendChild(rot);

    el.addEventListener('mousedown', e => {
        if (e.target.classList.contains('handle')) return;
        startDrag(e, id);
    });

    canvasEl.appendChild(el);

    const layer = {
        id, name: name || src.split('/').pop(),
        el, imgEl: img, x: 20, y: 20, z,
        w: 0, h: 0, scale: 1, rotation: 0
    };
    layers.push(layer);

    img.onload = () => {
        const maxW = 400, maxH = 300;
        let w = img.naturalWidth, h = img.naturalHeight;
        const ratio = Math.min(maxW / w, maxH / h, 1);
        w = Math.round(w * ratio);
        h = Math.round(h * ratio);
        img.style.width = w + 'px';
        img.style.height = h + 'px';
        layer.w = w; layer.h = h;
    };

    selectLayer(id);
    renderLayerList();
    placeholderEl.style.opacity = '0';
}

// ── Apply transform ──
function applyTransform(layer) {
    layer.el.style.left = layer.x + 'px';
    layer.el.style.top = layer.y + 'px';
    layer.el.style.transform = `rotate(${layer.rotation}deg) scale(${layer.scale})`;
}

// ── Drag ──
function startDrag(e, id) {
    selectLayer(id);
    const layer = getLayer(id);
    activeAction = {
        type: 'drag', id,
        startMouseX: e.clientX, startMouseY: e.clientY,
        startX: layer.x, startY: layer.y
    };
    e.preventDefault();
}

// ── Scale ──
function startScale(e, id, corner) {
    e.stopPropagation();
    selectLayer(id);
    const layer = getLayer(id);
    activeAction = {
        type: 'scale', id, corner,
        startMouseX: e.clientX, startMouseY: e.clientY,
        startScale: layer.scale
    };
    e.preventDefault();
}

// ── Rotate ──
function startRotate(e, id) {
    e.stopPropagation();
    selectLayer(id);
    const layer = getLayer(id);
    const rect = layer.el.getBoundingClientRect();
    const cx = rect.left + rect.width / 2;
    const cy = rect.top + rect.height / 2;
    activeAction = {
        type: 'rotate', id, cx, cy,
        startAngle: Math.atan2(e.clientY - cy, e.clientX - cx) * (180 / Math.PI),
        startRotation: layer.rotation
    };
    e.preventDefault();
}

// ── Global mousemove ──
document.addEventListener('mousemove', e => {
    if (!activeAction) return;
    const layer = getLayer(activeAction.id);
    if (!layer) return;

    if (activeAction.type === 'drag') {
        layer.x = activeAction.startX + (e.clientX - activeAction.startMouseX);
        layer.y = activeAction.startY + (e.clientY - activeAction.startMouseY);
        applyTransform(layer);

    } else if (activeAction.type === 'scale') {
        const dx = e.clientX - activeAction.startMouseX;
        const dy = e.clientY - activeAction.startMouseY;
        const signX = activeAction.corner.includes('r') ? 1 : -1;
        const signY = activeAction.corner.includes('b') ? 1 : -1;
        const delta = (dx * signX + dy * signY) / 2;
        const baseSize = Math.max(layer.w, layer.h, 1);
        layer.scale = Math.max(0.05, activeAction.startScale + delta / baseSize);
        applyTransform(layer);

    } else if (activeAction.type === 'rotate') {
        const angle = Math.atan2(e.clientY - activeAction.cy, e.clientX - activeAction.cx) * (180 / Math.PI);
        layer.rotation = activeAction.startRotation + (angle - activeAction.startAngle);
        applyTransform(layer);
    }
});

document.addEventListener('mouseup', () => { activeAction = null; });

// ── Select ──
function selectLayer(id) {
    selectedId = id;
    layers.forEach(l => l.el.classList.toggle('selected', l.id === id));
    renderLayerList();
}

canvasEl.addEventListener('mousedown', e => {
    if (e.target === canvasEl || e.target.id === 'placeholder') {
        selectedId = null;
        layers.forEach(l => l.el.classList.remove('selected'));
        renderLayerList();
    }
});

// ── Layer list ──
function renderLayerList() {
    layerListEl.innerHTML = '';
    [...layers].reverse().forEach(l => {
        const item = document.createElement('div');
        item.className = 'layer-item' + (l.id === selectedId ? ' active' : '');
        item.innerHTML = `<span title="${l.name}">${l.name}</span>
      <button title="Delete" onclick="removeLayer('${l.id}')">✕</button>`;
        item.addEventListener('click', e => {
            if (e.target.tagName !== 'BUTTON') selectLayer(l.id);
        });
        layerListEl.appendChild(item);
    });
}

function removeLayer(id) {
    const idx = layers.findIndex(l => l.id === id);
    if (idx === -1) return;
    layers[idx].el.remove();
    layers.splice(idx, 1);
    if (selectedId === id) selectedId = layers.length ? layers[layers.length - 1].id : null;
    if (!layers.length) placeholderEl.style.opacity = '1';
    renderLayerList();
}

function getLayer(id) { return layers.find(l => l.id === id); }

// ── z-order ──
function moveLayer(dir) {
    if (!selectedId) return;
    const idx = layers.findIndex(l => l.id === selectedId);
    const target = idx - dir;
    if (target < 0 || target >= layers.length) return;
    [layers[idx], layers[target]] = [layers[target], layers[idx]];
    layers.forEach((l, i) => { l.z = i + 1; l.el.style.zIndex = l.z; });
    renderLayerList();
}

// ── Delete key ──
document.addEventListener('keydown', e => {
    const tag = document.activeElement.tagName;
    if ((e.key === 'Delete' || e.key === 'Backspace') && selectedId) {
        if (tag !== 'INPUT' && tag !== 'TEXTAREA') removeLayer(selectedId);
    }
});

// ── Take: export ──
async function doTake() {
    if (!layers.length) { alert('you have nothing to offer; do not ask to take'); return; }

    const w = canvasEl.offsetWidth;
    const h = canvasEl.offsetHeight;
    const offscreen = document.createElement('canvas');
    offscreen.width = w; offscreen.height = h;
    const ctx = offscreen.getContext('2d');
    ctx.fillStyle = 'transparent';
    ctx.fillRect(0, 0, w, h);


    const sorted = [...layers].sort((a, b) => a.z - b.z);
    for (const layer of sorted) {
        img =   layer.imgEl;
        const iw = layer.w || img.naturalWidth;
        const ih = layer.h || img.naturalHeight;

        const cx = layer.x + iw / 2;
        const cy = layer.y + ih / 2;

        ctx.save();
        ctx.translate(cx, cy);
        ctx.rotate(layer.rotation * Math.PI / 180);
        ctx.scale(layer.scale, layer.scale);
        ctx.filter = 'grayscale(100%) brightness(1.3) contrast(1.1)';
        try { ctx.drawImage(img, -iw / 2, -ih / 2, iw, ih); }
        catch (err) { console.warn('CORS on layer:', layer.name); }
        ctx.filter = 'none';
        ctx.restore();
    }

    const link = document.createElement('a');
    link.download = 'curation.png';
    link.href = offscreen.toDataURL('image/png');
    link.click();
}

// ── Resources modal ──
async function openResources() {
    document.getElementById('resources-modal').classList.add('open');
    const list = document.getElementById('preset-list');
    list.innerHTML = '<div style="color:var(--muted);font-size:0.85rem;padding:8px;">Loading…</div>';
    const presets = await loadPresets();
    list.innerHTML = '';
    if (!presets.length) {
        list.innerHTML = '<div style="color:var(--muted);font-size:0.85rem;padding:8px;">No presets found in textures/index.json</div>';
        return;
    }
    presets.forEach(p => {
        const item = document.createElement('div');
        item.className = 'preset-item';
        item.textContent = p.name;
        item.onclick = () => { addLayer(p.src, p.name); closeResources(); };
        list.appendChild(item);
    });
}

function closeResources() {
    document.getElementById('resources-modal').classList.remove('open');
}

document.getElementById('resources-modal').addEventListener('click', e => {
    if (e.target === e.currentTarget) closeResources();
});