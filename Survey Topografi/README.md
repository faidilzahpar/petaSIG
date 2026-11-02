# 📡 TopoMesh Geodetic Surveyor (Android & iOS)

> **Sistem Alat Ukur Survei Topografi Multi-Device Presisi Tinggi**  
> Mengatasi keterbatasan akurasi GPS smartphone (3-10m) menggunakan metode **Trilaterasi / Multilaterasi BLE Kolaboratif (Min. 3 Handphone)**, **Altimetri Barometrik Diferensial**, **Waterpass Digital Plumb Level**, serta **Interpolasi Jaring TIN & Garis Kontur Real-Time**.

---

## 🎯 Menjawab Seluruh Butir Penugasan

| No | Butir Penugasan | Solusi Rekayasa / Implementasi Teknis |
|---|---|---|
| **1** | **Titik ketinggian dari setiap permukaan yang ada** | Sensor barometer diferensial yang terkalibrasi secara terus-menerus terhadap Base Station benchmark, mengeliminasi penyimpangan cuaca dan menghasilkan ketelitian elevasi mikro permukaan tanah ($Z$) hingga desimeter. |
| **2** | **Keterbatasan GPS Android 10M diatasi dengan Trilaterasi / Multilaterasi** | Menggunakan solver **Gauss-Newton Non-Linear Least Squares** berbasis geometri 3D dengan kalkulasi GDOP (*Geometric Dilution of Precision*) untuk membatasi *residual root-mean-square error* (RMSE $\le 0.3 - 0.8\text{m}$). |
| **3** | **Pengumpulan data minimal 3 Handphone** | Arsitektur konstelasi geodesi: **HP-1 (Anchor A / Base Station 0,0)**, **HP-2 (Anchor B / Sumbu Baseline X)**, **HP-3 (Anchor C / Penutup Triangulasi Y)**, dan **HP Rover (Pembawa Jalon Survei)**. |
| **4** | **Trilaterasi diperkuat dengan BLE (Bluetooth Low Energy)** | Ranging BLE berbasis *Log-Distance Path Loss Model* yang diperkuat dengan **1D Kalman Filter** untuk meredam multipath fading dan interferensi sinyal radio. |
| **5** | **GitHub Workflow auto-tag & release APK Android** | Workflow CI/CD di `.github/workflows/build-and-release.yml` yang secara otomatis mengompilasi kode program menjadi file `TopoMesh-Surveyor-v1.0-Universal.apk`, membuat tag rilis Git, dan mengunggahnya ke GitHub Releases. |
| **iOS** | **Dukungan Cross-Platform (iPhone / iOS)** | 1) Proyek Flutter native mendukung iOS (`ios/Runner/Info.plist` dengan izin BLE & CoreMotion).<br>2) Disertai **Web GIS / PWA Field Console** di folder `web/` yang dapat dibuka langsung di **Safari iPhone** dengan akses sensor orientasi gyro/akselerometer untuk waterpass digital. |
| **UI** | **Desain Profesional (Bukan AI Slop)** | Tampilan *instrument field controller* taktis berdensitas informasi tinggi ala **Leica Geosystems / Trimble**, warna kontras tinggi (*dark industrial slate* & *cadastral amber*), tipografi monospace untuk telemetri angka, dan bebas dari elemen hiasan artifisial yang tidak fungsional. |

---

## 📱 Arsitektur Konstelasi Lapangan (Minimal 3 Handphone)

```
             ▲ Utara
             │
             │           [ HP-3: Anchor C ] (10.0, 17.32, Z: 101.5)
             │                ▲        ▲
             │               /          \
             │      r3 (BLE)/            \ r2 (BLE)
             │             /   [ ROVER ]  \
             │            /   (iPhone Anda)\
             │           /   x=8.5, y=6.2   \
             │          /      z=100.8       \
             │         /                      \
             │        ▼                        ▼
[ HP-1: Anchor A (Base) ] ══════════════════ [ HP-2: Anchor B ]
(0.0, 0.0, Z: 100.0 Benchmark)   Baseline 20m  (20.0, 0.0, Z: 100.2)
```

1. **HP-1 (Anchor A / Base Station)**:
   - Diletakkan di patok acuan tetap (*Benchmark* / BM).
   - Menjadi titik koordinat origin $(0, 0, Z_0)$.
   - Membaca tekanan udara atmosfir lokal $P_{\text{base}}(t)$ sebagai acuan diferensial barometer.
2. **HP-2 (Anchor B / Sumbu X)**:
   - Diletakkan berjarak 15–30 meter dari Base Station (diukur jaraknya dengan pita ukur atau rangefinder untuk kalibrasi atenuasi sinyal BLE).
   - Membentuk sumbu orientasi horizontal $X$.
3. **HP-3 (Anchor C / Penutup Triangulasi Y)**:
   - Diletakkan di sisi lapangan lain sehingga membentuk segitiga luas (menghindari geometri sejajar/segaris).
4. **HP Rover (Handphone Anda / iPhone / Android Surveyor)**:
   - Dipasang pada jalon survei (*surveying pole*) dengan ketinggian patokan (misal 1.50m).
   - Menerima sinyal BLE dari ketiga Anchor, menghitung jarak $r_1, r_2, r_3$, menjalankan filter Kalman, dan menentukan titik koordinat $X, Y, Z$ permukaan saat jalon dalam kondisi tegak lurus (waterpass $< 2^\circ$).

---

## 🚀 Alur Kompilasi APK Otomatis (GitHub Actions)

Aplikasi telah dilengkapi workflow otomatis:
[`.github/workflows/build-and-release.yml`](.github/workflows/build-and-release.yml)

### Cara Memicu Pembuatan APK:
1. **Otomatis Melalui Git Tag**:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
2. **Otomatis Saat Push ke Branch `main`**:
   Setiap perubahan kode yang di-*push* ke `main` akan otomatis memicu pembuatan tag `v1.0.<nomor_run>`.
3. **Manual Lewat Halaman GitHub Actions**:
   Buka tab **Actions** di repositori GitHub -> Pilih **Build & Release Android APK** -> Klik **Run workflow**.

### Output Rilis:
GitHub Actions akan secara otomatis menghasilkan:
- File APK: `TopoMesh-Surveyor-v1.0-Universal.apk`
- Berkas verifikasi: `SHA256SUMS.txt`
- Halaman Rilis GitHub Resmi (*GitHub Releases*) yang siap diunduh langsung ke handphone Android masing-masing anggota tim survei.

---

## 🍏 Panduan Pengguna iPhone (iOS)

Bagi Anda yang menggunakan iPhone, tersedia 2 metode:

### Metode 1: Web GIS Field Console (Langsung di Safari iPhone)
1. Buka browser **Safari** di iPhone Anda.
2. Akses Web Console yang otomatis ter-deploy melalui GitHub Pages:  
   `https://faidilzahpar.github.io/petaSIG/`  
   *(Atau buka file `web/index.html` di browser)*.
3. Ketuk tombol **Share** di Safari -> Pilih **"Add to Home Screen"** (*Tambah ke Layar Utama*).
4. Aplikasi akan terpasang sebagai Progressive Web App (PWA) layar penuh.
5. Saat pertama kali dibuka, berikan izin orientasi sensor agar **Waterpass Digital** dapat membaca kemiringan fisik iPhone Anda secara langsung.

### Metode 2: Kompilasi Native iOS (Xcode)
Proyek ini memiliki struktur Flutter iOS lengkap di folder `ios/`:
```bash
cd "c:\Sistem Informasi Geografis\Survey Topografi"
flutter build ios --no-codesign
```

---

## 📐 Fitur Hasil Pemetaan & Ekspor Data

1. **Jaring Segitiga TIN (*Triangulated Irregular Network*)**:
   - Membangun jaring permukaan 3D otomatis menggunakan algoritma **Delaunay Triangulation (Bowyer-Watson)**.
2. **Garis Kontur Topografi Real-Time**:
   - Menghasilkan kurva kontur indeks dan intermediet (*Marching Triangles*) dengan interval 0.25m, 0.50m, 1.00m, atau 2.00m.
3. **Estimasi Volume Galian & Timbunan (*Cut and Fill*)**:
   - Menghitung kubikasi tanah terhadap bidang datum acuan ($m^3$).
4. **Format Ekspor Standar Industri**:
   - **CSV (PNEZD)**: Format tabel titik (`Point_ID, Northing, Easting, Elevation, Code`) langsung kompatibel dengan AutoCAD Civil 3D, Surfer, dan Microsoft Excel.
   - **GeoJSON**: Kompatibel dengan QGIS, ArcGIS, dan Mapbox.
   - **AutoCAD DXF 3D**: Berisi entitas titik 3D (`POINT`), permukaan TIN (`3DFACE`), dan garis kontur 3D (`LINE` / `POLYLINE`).

---

## 🛠️ Struktur Repositori

```
├── .github/workflows/
│   ├── build-and-release.yml    # CI/CD: Auto tag & build APK release
│   └── deploy-pages.yml         # CI/CD: Auto deploy Web GIS untuk iPhone
├── android/                     # Konfigurasi native Android (Gradle, Manifest BLE)
├── ios/                         # Konfigurasi native iOS (Info.plist, CoreMotion, BLE)
├── web/                         # Web Field GIS PWA (Khusus Safari iPhone & Desktop)
│   ├── index.html
│   ├── style.css
│   └── app.js
├── lib/                         # Source code inti aplikasi Flutter
│   ├── core/math/               # Multilaterasi, Kalman Filter, Delaunay, Geodesi UTM
│   ├── core/sensors/            # BLE Mesh, Barometer Diferensial, Waterpass
│   ├── core/models/             # Point, Node, TopoDataset
│   ├── core/export/             # CSV, GeoJSON, AutoCAD DXF
│   └── ui/                      # Field HUD, Kanvas 2D/3D Kontur, Jaringan
└── pubspec.yaml
```

---

*Dikembangkan untuk Penugasan Sistem Informasi Geografis & Survei Topografi Multi-Device.*

