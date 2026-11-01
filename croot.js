import { 
    createMap, 
    addGeoJSON, 
    fitMap, 
    getGeoJSON, 
    onMapClick 
} from "https://cdn.jsdelivr.net/gh/crootjs/lib@0.0.16/map.js";

// 1. Inisialisasi peta
createMap("peta", {
    zoomControl: true,
    scrollZoom: true
});

const infoKoordinatEl = document.getElementById("info-koordinat");
const listGeoJSONEl = document.getElementById("list-geojson");

// Fungsi deteksi kategori
function deteksiKategori(feature) {
    const geomType = feature.geometry?.type;

    if (geomType === "Polygon" || geomType === "MultiPolygon") {
        return "Polygon Gedung";
    }
    if (geomType === "LineString" || geomType === "MultiLineString") {
        return "Polyline Jalan";
    }
    if (geomType === "Point" || geomType === "MultiPoint") {
        return "Point";
    }
    return "Lainnya";
}

// 2. Ambil data GeoJSON
getGeoJSON("./714240007_FaidilZahpar.geojson", (response) => {
    if (!response.data) {
        console.error("Gagal memuat data GeoJSON:", response.status);
        listGeoJSONEl.innerHTML = "<li>Gagal memuat data.</li>";
        return;
    }

    // Render data pada peta dengan popup
    addGeoJSON("peta", response.data, {
        popup: (feature) => {
            const props = feature.properties;
            const container = document.createElement("div");

            if (!props || Object.keys(props).length === 0) {
                container.textContent = `Fitur ${feature.geometry.type}`;
                return container;
            }

            container.innerHTML = Object.entries(props)
                .map(([kunci, nilai]) => `<strong>${kunci}:</strong> ${nilai}`)
                .join("<br>");

            return container;
        }
    });

    fitMap("peta", response.data);

    // 3. Kelompokkan dan tampilkan daftar lokasi berdasarkan kategori
    listGeoJSONEl.innerHTML = "";
    
    const kelompok = {
        "Polygon Gedung": [],
        "Polyline Jalan": [],
        "Point": [],
        "Lainnya": []
    };

    response.data.features.forEach((feature) => {
        const props = feature.properties || {};
        const namaLokasi = props.label || props.Gedung || props.Kampus || props.Jalan || props.nama || Object.values(props)[0];
        if (!namaLokasi) return;

        const katNama = deteksiKategori(feature);
        kelompok[katNama].push({
            nama: namaLokasi,
            type: feature.geometry.type
        });
    });

    // Tampilkan per header kategori dengan pembatas yang jelas
    let kategoriIndex = 0;
    Object.entries(kelompok).forEach(([namaKategori, daftarItem]) => {
        if (daftarItem.length === 0) return;

        // Berikan garis pemisah antar kategori (kecuali kategori pertama)
        if (kategoriIndex > 0) {
            const dividerLi = document.createElement("li");
            dividerLi.className = "kategori-divider";
            listGeoJSONEl.appendChild(dividerLi);
        }

        let borderClass = "";
        if (namaKategori.includes("Polygon")) borderClass = "border-polygon";
        else if (namaKategori.includes("Polyline")) borderClass = "border-polyline";
        else if (namaKategori.includes("Point")) borderClass = "border-point";

        const headerLi = document.createElement("li");
        headerLi.className = `kategori-title ${borderClass}`;
        headerLi.innerHTML = `<span>${namaKategori}</span> <span class="badge-count">${daftarItem.length}</span>`;
        listGeoJSONEl.appendChild(headerLi);

        daftarItem.forEach(item => {
            const li = document.createElement("li");
            li.className = "item-lokasi";
            li.innerHTML = `<strong>${item.nama}</strong> <small style="color:#64748b;">(${item.type})</small>`;
            listGeoJSONEl.appendChild(li);
        });

        kategoriIndex++;
    });
});

// 4. Ambil koordinat saat klik peta
let hapusPenandaTitik = () => {};

onMapClick("peta", (position, feature) => {
    const [lng, lat] = position;

    const props = feature?.properties || {};
    const namaObjek = props.label || props.Gedung || props.nama || (Object.keys(props).length ? Object.values(props)[0] : null);

    infoKoordinatEl.innerHTML = `
        <strong>Longitude:</strong> ${lng}<br>
        <strong>Latitude:</strong> ${lat}
        ${namaObjek ? `<br><strong>Objek Diklik:</strong> ${namaObjek}` : ''}
    `;

    if (feature) return;

    hapusPenandaTitik();
    hapusPenandaTitik = addGeoJSON("peta", {
        type: "Point",
        coordinates: position
    }, {
        style: { fill: "#ef4444", stroke: "#ffffff", radius: 8 },
        popup: () => {
            const el = document.createElement("div");
            el.innerHTML = `<strong>Lng:</strong> ${lng}<br><strong>Lat:</strong> ${lat}`;
            return el;
        }
    });
});
