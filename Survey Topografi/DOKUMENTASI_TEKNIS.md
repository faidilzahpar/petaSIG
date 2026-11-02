# 📐 Dokumentasi Teknis & Fondasi Geodesi TopoMesh

Dokumen ini memuat formulasi matematika, algoritma reduksi kesalahan (*error correction*), dan prosedur kalibrasi lapangan untuk sistem survei topografi multi-handphone.

---

## 1. Permasalahan Akurasi GNSS Smartphone & Pendekatan Diferensial

Chipset GNSS smartphone komersial memiliki kesalahan posisi horizontal tipikal 3 s/d 10 meter dan kesalahan posisi vertikal ($Z$) mencapai 10 s/d 25 meter yang disebabkan oleh:
1. Perlambatan sinyal pada ionosfer dan troposfer.
2. Efek *multipath* pantulan sinyal pada permukaan tanah, gedung, atau tajuk pohon.
3. Keterbatasan antena pasif mini internal handphone (SNR rendah).

Untuk mengatasi kendala ini pada pemetaan topografi kontur mikro, sistem menggunakan kombinasi **Trilaterasi/Multilaterasi Sinyal Jarak Dekat (BLE)** dengan konstelasi minimal 3 handphone, serta **Altimetri Barometrik Diferensial**.

---

## 2. Model Jarak BLE & Reduksi Derau (Kalman Filter)

### 2.1 Model Propagasi *Log-Distance Path Loss*
Jarak estimasi ($d$) dari nilai kuat sinyal yang diterima (*Received Signal Strength Indicator* / $RSSI$) dihitung dengan formula:

$$RSSI(d) = A - 10 \cdot n \cdot \log_{10}(d) + X_\sigma$$

Di mana:
- $RSSI$: Kuat sinyal yang diterima dalam satuan dBm.
- $A$: Nilai RSSI referensi pada jarak 1 meter (tipikal $-58$ s/d $-64\text{ dBm}$ pada handphone).
- $n$: Eksponen atenuasi transmisi lingkungan ($n \approx 2.0$ untuk ruang terbuka ideal, $n \approx 2.4 - 2.8$ untuk area survei bervegetasi/lereng).
- $X_\sigma$: Variabel acak Gaussian akibat efek *shadowing* dan *multipath*.

Dari persamaan di atas, jarak fisik $d$ (meter) diperoleh melalui:

$$d = 10^{\frac{A - RSSI}{10 \cdot n}}$$

### 2.2 Filter Kalman 1-Dimensi untuk Meredam Fluktuasi RSSI
Fluktuasi RSSI mentah diperhalus dengan filter Kalman sekuensial:

**Fase Prediksi:**
$$x_{k|k-1} = x_{k-1}$$
$$P_{k|k-1} = P_{k-1} + Q$$

**Fase Pembaruan (Koreksi):**
$$K_k = \frac{P_{k|k-1}}{P_{k|k-1} + R}$$
$$x_k = x_{k|k-1} + K_k (z_k - x_{k|k-1})$$
$$P_k = (1 - K_k) P_{k|k-1}$$

Parameter default:
- $Q$ (*Process Noise Covariance*) = $0.05$ (mencerminkan dinamika kecepatan jalan surveyor).
- $R$ (*Measurement Noise Covariance*) = $2.50$ (mencerminkan variansi derau frekuensi radio 2.4 GHz).

---

## 3. Solver Multilaterasi Non-Linear 3D

Diberikan $N \ge 3$ titik acuan (Anchor) $A_i = (x_i, y_i, z_i)$ dan jarak terukur $r_i$ ke posisi Rover $P = (x, y, z)$. Persamaan jarak geometris adalah:

$$(x - x_i)^2 + (y - y_i)^2 + (z - z_i)^2 = r_i^2 \quad \text{untuk } i = 1, \dots, N$$

### 3.1 Inisialisasi Linear Least Squares
Dengan mengurangkan persamaan Anchor pertama ($i=1$) dari seluruh Anchor lainnya ($i=2 \dots N$), sistem non-linear diubah menjadi sistem persamaan linear matriks:

$$\mathbf{A} \mathbf{x} = \mathbf{b}$$

Di mana baris ke-$(i-1)$ dari matriks $\mathbf{A}$ dan vektor $\mathbf{b}$ adalah:

$$\mathbf{A}_{i-1} = 2 \begin{bmatrix} (x_i - x_1) & (y_i - y_1) & (z_i - z_1) \end{bmatrix}$$
$$b_{i-1} = r_1^2 - r_i^2 + (x_i^2 - x_1^2) + (y_i^2 - y_1^2) + (z_i^2 - z_1^2)$$

Solusi awal diperoleh menggunakan pseudo-invers:
$$\mathbf{x}_0 = (\mathbf{A}^T \mathbf{A})^{-1} \mathbf{A}^T \mathbf{b}$$

### 3.2 Optimasi Iteratif Gauss-Newton
Vektor posisi diperbaiki secara iteratif untuk meminimalkan jumlah kuadrat residu:

$$\min \sum_{i=1}^N \left( \|P - A_i\| - r_i \right)^2$$

Pada setiap iterasi $k$:
$$\Delta \mathbf{x} = (\mathbf{J}^T \mathbf{J} + \lambda \mathbf{I})^{-1} \mathbf{J}^T \mathbf{r}$$
$$\mathbf{x}_{k+1} = \mathbf{x}_k + \Delta \mathbf{x}$$

Dengan matriks Jacobian $\mathbf{J}$:
$$J_{i, j} = \frac{x_j - x_{i,j}}{\|P - A_i\|}$$

### 3.3 Indikator Kualitas Geodetik (GDOP & RMSE)
- **Root Mean Square Error (RMSE)**:
  $$RMSE = \sqrt{\frac{1}{N} \sum_{i=1}^N (\|P - A_i\| - r_i)^2}$$
- **Geometric Dilution of Precision (GDOP)**:
  $$GDOP = \sqrt{\text{trace}((\mathbf{G}^T \mathbf{G})^{-1})}$$
  Nilai $GDOP < 2.5$ menandakan geometri segitiga yang ideal; $GDOP > 6.0$ menandakan posisi Anchor hampir segaris (*collinear*).

---

## 4. Altimetri Barometrik Diferensial

Sensor barometer handphone (seperti Bosch BMP388 / ST LPS22HB / Apple CoreMotion) memiliki resolusi relatif sangat tinggi ($\pm 0.1\text{ hPa} \approx 0.8\text{ meter}$). Namun, nilai tekanan absolut berubah sepanjang hari akibat perubahan cuaca meteorologi (*diurnal pressure drift*).

### Solusi Diferensial Base-Rover:
Dengan menempatkan **HP-1 (Anchor A / Base Station)** pada patok acuan tetap, setiap perubahan tekanan di Base Station adalah murni perubahan cuaca $\Delta P_{\text{cuaca}}(t)$.

Ketinggian elevasi permukaan Rover $Z_{\text{rover}}(t)$ dihitung menggunakan formula hypsometrik diferensial:

$$Z_{\text{rover}}(t) = Z_{\text{base}} + \frac{R_{\text{udara}} \cdot T_{\text{kelvin}}}{g} \cdot \ln\left( \frac{P_{\text{base}}(t)}{P_{\text{rover}}(t)} \right)$$

Di mana:
- $R_{\text{udara}} = 287.058\text{ J/(kg}\cdot\text{K)}$ (Konstanta gas spesifik udara kering).
- $g = 9.80665\text{ m/s}^2$ (Percepatan gravitasi standar).
- $T_{\text{kelvin}} = 273.15 + T_{\text{Celsius}}$ (Suhu udara terukur).
- $Z_{\text{base}}$: Ketinggian Benchmark awal (misal $100.00\text{ m}$ dpl).

Karena $P_{\text{base}}(t)$ dan $P_{\text{rover}}(t)$ diukur secara serentak pada interval waktu yang sama, fluktuasi cuaca atmosfer saling meniadakan secara sempurna.

---

## 5. Pemodelan Permukaan: Delaunay TIN & Garis Kontur

1. **Delaunay Triangulation (Bowyer-Watson Algorithm)**:
   - Menjamin bahwa tidak ada simpul titik survei yang berada di dalam *circumcircle* (lingkaran luar) dari segitiga manapun dalam jaring TIN.
   - Menghasilkan jaring segitiga dengan sudut terkecil yang dimaksimalkan (*equiangular triangles*), mencegah segitiga gepeng/runcing.
2. **Marching Triangles Contour Generator**:
   - Untuk setiap segitiga TIN dengan simpul $(A, B, C)$ dan elevasi target $Z_{\text{kontur}}$:
   - Jika bidang $Z_{\text{kontur}}$ memotong dua sisi segitiga, titik potong $(x, y)$ diinterpolasi secara linear:
     $$x = x_1 + \frac{Z_{\text{kontur}} - z_1}{z_2 - z_1} (x_2 - x_1)$$
     $$y = y_1 + \frac{Z_{\text{kontur}} - z_1}{z_2 - z_1} (y_2 - y_1)$$
   - Segmen garis kontur dibedakan menjadi:
     - **Kontur Intermediet** (tipis, interval default $0.5\text{m}$).
     - **Kontur Indeks** (tebal, setiap kelipatan $5 \times$ interval, disertai label elevasi).

