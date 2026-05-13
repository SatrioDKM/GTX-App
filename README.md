# GTX-App (Go Touring Xperience) 🏍️📡

**GTX-App** adalah aplikasi koordinasi touring motor cerdas yang dirancang untuk mengatasi tantangan komunikasi dan navigasi di jalur yang sulit. Dengan fokus pada *resilience* (ketangguhan) dan pengalaman pengguna yang intuitif, GTX-App menggabungkan sistem navigasi real-time, voice chat, dan fitur sosial yang mulus.

---

## 🌟 Fitur Utama

### 🗺️ Smart Navigation & Coordination
* **Real-time Member Tracking:** Lihat posisi semua anggota rombongan di peta secara langsung.
* **Navigation Sensor Fusion:** Sinkronisasi arah hadap menggunakan gabungan sensor Magnetometer dan GPS Course untuk pergerakan panah navigasi yang sangat halus (60 FPS).
* **Shared Route:** (Phase 7) Host dapat menentukan rute dan semua member akan mendapatkan navigasi yang sama.

### 🎙️ Advanced Communication (Software Intercom)
* **Low Latency Voice Chat:** Menggunakan teknologi LiveKit untuk komunikasi suara yang jernih dengan penggunaan kuota yang efisien.
* **Foreground Service:** Audio dan Mic tetap aktif meskipun aplikasi berada di background atau layar terkunci.

### 🎶 Music Sharing (Shared DJ)
* **In-App Music Search:** Cari lagu langsung dari aplikasi menggunakan integrasi data YouTube.
* **Shared Playback:** Semua member mendengarkan lagu yang sama secara sinkron (Local Sync via Firestore).
* **Independent Volume Control:** Member dapat mengatur volume musik sendiri tanpa mempengaruhi volume intercom atau volume musik anggota lain.

### 🛡️ Resilience & Persistence
* **Auto-Reconnect:** Sistem otomatis menghubungkan kembali Host atau Member ke room terakhir jika aplikasi tertutup.
* **Cloud & Local Sync:** Menggunakan Firestore untuk sinkronisasi state yang cepat dan handal.

---

## 🎨 UI/UX Design
Aplikasi mengusung tema **Royal Blue** dengan pendekatan desain bersih dan modern:
* **Mirror Search Bars:** Ikon pencarian musik (kiri) dan lokasi (kanan) yang memanjang secara simetris.
* **Now Playing HUD:** Overlay informasi lagu yang melayang secara elegan di bagian atas layar touring.
* **Glassmorphism Effects:** UI yang semi-transparan untuk menjaga fokus pada peta navigasi.

---

## 🛠️ Tech Stack
* **Frontend:** Flutter (Laravel & Tailwind CSS untuk penunjang ekosistem).
* **Backend & Database:** Firebase (Firestore, Authentication, Storage).
* **Voice/Audio Engine:** LiveKit, Just Audio.
* **State Management:** Flutter Cubit/Bloc.
* **Local Persistence:** SharedPreferences.

---

## 🏗️ Arsitektur Proyek
Aplikasi ini menggunakan pola arsitektur modular untuk memastikan efisiensi token AI dan kemudahan maintenance:
* `services/`: Logika berat seperti sensor, musik, dan LiveKit.
* `widgets/`: Komponen UI yang dapat digunakan kembali (TouringSidebar, NavigationMarker, dll).
* `pages/`: Kontroler tata letak utama.

---

## 🚀 Roadmap Pengembangan
- [x] Phase 1-5: Core Navigation & Authentication
- [x] Phase 6: Massive Refactoring & State Persistence
- [ ] Phase 7: Music Sharing Implementation (In-Progress)
- [ ] Phase 8: Hybrid Mesh Networking (Emergency Fallback)

---

**Developed by Satrio Dkm**
