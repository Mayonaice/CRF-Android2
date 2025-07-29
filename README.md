# CRF Android

Aplikasi CRF (Cash Replenishment Form) untuk Android.

## Deskripsi

Aplikasi ini digunakan untuk mengelola proses replenishment dan return ATM, termasuk:
- Prepare Mode: Persiapan pengisian ATM
- Return Mode: Pengembalian cassette ATM
- Konsol Mode: Monitoring dan reporting

## Persyaratan Sistem

- Flutter 3.32.5 atau yang lebih baru
- JDK 17
- Android SDK 33
- Gradle 8.4
- Android Gradle Plugin 8.3.1
- Kotlin Plugin 1.9.22

## Cara Setup Proyek

1. Clone repository ini
2. Pastikan JDK 17 sudah terinstall dan diset sebagai JAVA_HOME
3. Jalankan `flutter pub get` untuk menginstall semua dependencies
4. Pastikan semua konfigurasi Android sudah benar

## Cara Build

### Menggunakan Script Build

Cara termudah untuk build aplikasi adalah menggunakan script BUILD.bat:

1. Buka Command Prompt atau PowerShell
2. Navigasi ke direktori proyek
3. Jalankan `BUILD.bat`
4. APK akan tersedia di `build\app\outputs\flutter-apk\app-debug.apk` dan juga di root folder sebagai `crf_android.apk`

### Build Manual

Jika ingin build secara manual:

1. Pastikan JDK 17 digunakan
2. Jalankan `flutter clean`
3. Jalankan `flutter pub get`
4. Jalankan `flutter build apk --debug --android-skip-build-dependency-validation`

## Troubleshooting

Jika mengalami masalah saat build:

1. **Error Java Heap Space**: Tingkatkan memory dengan mengedit `android/gradle.properties` dan set `org.gradle.jvmargs=-Xmx4096M`

2. **Error Gradle Plugin**: Pastikan menggunakan JDK 17 dan Android Gradle Plugin yang kompatibel

3. **Error Plugin Loader**: Pastikan `settings.gradle.kts` sudah berisi konfigurasi plugin loader yang benar

4. **Stuck di "Running Gradle task 'assembleDebug'"**: 
   - Matikan semua proses Java/Gradle dengan Task Manager
   - Hapus folder `.gradle` di direktori user
   - Coba build ulang

## Struktur Proyek

- `lib/models`: Model data untuk aplikasi
- `lib/screens`: Screen UI aplikasi
- `lib/services`: Service untuk API, autentikasi, dll
- `lib/utils`: Utility functions
- `lib/widgets`: Reusable widgets

## Kontak

Untuk pertanyaan atau bantuan, hubungi tim pengembang.

---

© 2024 Advantage. All rights reserved.
