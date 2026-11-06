# 📄 ScanPro

**Escáner de documentos profesional para Android.**

Escanea, organiza y exporta documentos a PDF con OCR, 100% offline y sin publicidad.

---

## ✨ Características

### 🔍 Escaneo
- Detección automática de bordes con Google ML Kit
- Corrección de perspectiva automática
- Multi-página en un solo documento
- Importar desde galería
- Auto-crop + resize a A4 alta calidad

### 📁 Organización
- Carpetas ilimitadas
- Un documento en múltiples carpetas
- Búsqueda global (documentos + carpetas)
- Favoritos
- Ordenar por fecha, nombre, favoritos
- Selección múltiple para eliminar en masa

### ✏️ Edición
- Rotar páginas (↺ ↻)
- Recortar con uCrop
- Añadir / eliminar páginas
- Zoom hasta 6x nítido

### 📤 Exportación
- PDF profesional con OCR seleccionable
- PDF limpio (solo imagen)
- Exportar JPG / PNG
- Guardar en carpeta elegida (SAF)
- Compartir por WhatsApp, email, Drive
- Imprimir

### 🔤 OCR
- Extrae texto con Google ML Kit
- Compatible con 100+ idiomas
- Copiar texto al portapapeles
- PDF con texto buscable y copiable

### 🔒 Privacidad
- 100% offline
- Sin publicidad
- Sin trackers
- Sin cuenta obligatoria
- Sin compras integradas

---

## 🛠️ Stack técnico

| Tecnología | Uso |
|-----------|-----|
| **Flutter 3.24+** | Framework multiplataforma |
| **Riverpod** | Gestión de estado |
| **Isar Community** | Base de datos local (reemplazo del Isar abandonado) |
| **Google ML Kit** | Document Scanner + Text Recognition |
| **pdf** | Generación de PDF |
| **image** | Procesamiento de imágenes |
| **image_cropper** | Recorte con uCrop |
| **photo_view** | Visor con zoom |
| **file_picker** | SAF (Storage Access Framework) |
| **shared_preferences** | Persistencia de onboarding |
| **flutter_launcher_icons** | Generación de iconos adaptativos |
| **flutter_native_splash** | Splash screen nativo |

---

## 📱 Requisitos

- **Android 7.0 (API 24)** o superior
- **Flutter 3.24+** para desarrollo
- **JDK 17** para compilar
- **Android SDK 34+**

---

## 🚀 Instalación

### 1. Clonar el repositorio

```bash
git clone https://github.com/azzaz123/scanpro.git
cd scanpro
```

### 2. Instalar dependencias

```bash
flutter pub get
```

### 3. Generar código de Isar

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 4. Generar iconos y splash

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

### 5. Ejecutar

```bash
flutter run
```

---

## 🏗️ Estructura del proyecto

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── constants/
│   ├── theme/
│   ├── router/
│   └── utils/
├── data/
│   ├── models/
│   │   ├── document.dart
│   │   ├── page.dart
│   │   └── folder.dart
│   ├── repositories/
│   │   └── document_repository.dart
│   └── services/
│       ├── scanner_service.dart
│       ├── ocr_service.dart
│       ├── pdf_service.dart
│       ├── storage_service.dart
│       └── image_enhancer_service.dart
├── features/
│   ├── home/
│   ├── scanner/
│   ├── document_detail/
│   ├── folder/
│   ├── onboarding/
│   └── settings/
└── shared/
    └── widgets/
```

---

## 🔧 Configuración Android

### `android/app/build.gradle.kts`

```kotlin
android {
    namespace = "com.tuempresa.scanpro"
    compileSdk = 34
    
    defaultConfig {
        applicationId = "com.tuempresa.scanpro"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }
}
```

### `android/app/src/main/AndroidManifest.xml`

```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32"/>

<uses-feature android:name="android.hardware.camera" android:required="false"/>
```

---

## 🎨 Icono y splash

Los assets están configurados en `pubspec.yaml`:

```yaml
flutter_launcher_icons:
  android: "launcher_icon"
  image_path: "assets/icon/app_icon.png"
  adaptive_icon_background: "#1E6FFF"
  adaptive_icon_foreground: "assets/icon/app_icon.png"

flutter_native_splash:
  color: "#1E6FFF"
  color_dark: "#0D47A1"
  image: "assets/icon/app_icon.png"
```

---

## 🧪 Compilar para producción

### APK (para pruebas)

```bash
flutter build apk --release
```

### App Bundle (para Play Store)

```bash
flutter build appbundle --release
```

### Configurar firma

1. Generar keystore:

```bash
keytool -genkey -v -keystore ~/scanpro-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias scanpro
```

2. Crear `android/key.properties`:

```properties
storePassword=TU_PASSWORD
keyPassword=TU_PASSWORD
keyAlias=scanpro
storeFile=/home/tuusuario/scanpro-release.jks
```

3. Configurar en `android/app/build.gradle.kts`:

```kotlin
signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String
        keyPassword = keystoreProperties["keyPassword"] as String
        storeFile = file(keystoreProperties["storeFile"] as String)
        storePassword = keystoreProperties["storePassword"] as String
    }
}

buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
        isMinifyEnabled = true
        isShrinkResources = true
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
    }
}
```

---

## 📊 Rendimiento

| Aspecto | Valor |
|---------|-------|
| Tamaño APK release | ~25 MB |
| Tamaño por página escaneada | ~1.5-2.5 MB |
| Tiempo de escaneo | 1-3 s por página |
| Tiempo de OCR | 2-4 s por página |
| Tiempo de generación PDF | 1-5 s por documento |

---

## 🐛 Bugs conocidos

- **Multi-página**: ML Kit agrupa varias páginas en un solo documento (comportamiento nativo).
- **OCR en chino/japonés**: no incluido, solo latín (español, inglés, francés, etc.).

---

## 🗺️ Roadmap

### v1.0 (actual)
- [x] Escaneo con ML Kit
- [x] Carpetas
- [x] PDF con OCR seleccionable
- [x] Exportar JPG/PNG
- [x] OCR

### v1.1 (próximo)
- [ ] Filtros de imagen (blanco/negro, grises)
- [ ] Mover documentos a carpetas en masa
- [ ] Backup en Google Drive
- [ ] Imprimir desde la app

### v1.2
- [ ] Contraseña en PDF
- [ ] Widget de Android
- [ ] Modo escáner continuo
- [ ] Detección de documento automática

---

## 📄 Licencia

```
MIT License

Copyright (c) 2026 Aziz

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 🙏 Agradecimientos

- [Flutter](https://flutter.dev)
- [Google ML Kit](https://developers.google.com/ml-kit)
- [Isar Community](https://github.com/isar-community/isar)
- [Riverpod](https://riverpod.dev)
- [pdf package](https://pub.dev/packages/pdf)
- [uCrop](https://github.com/Yalantis/uCrop)

---

## 📧 Contacto

- **Autor**: Aziz
- **GitHub**: [@azzaz123](https://github.com/azzaz123)
- **Email**: tu@email.com

---

## ⭐ ¿Te gusta el proyecto?

Dale una **⭐** en GitHub y comparte la app. ¡Ayuda mucho!

---

**Hecho con ❤️ usando Flutter**