# Guía de Publicación - Padron Vista

## 🚀 Codemagic (CI/CD Recomendado)

### Configuración inicial en Codemagic

1. Ve a [codemagic.io](https://codemagic.io) y conecta tu repositorio
2. El archivo `codemagic.yaml` ya está configurado en el proyecto

### Para iOS (App Store):

1. **En Codemagic > Settings > Integrations:**
   - Conecta tu cuenta de App Store Connect
   - Agrega los certificados de distribución de Apple
   
2. **En Codemagic > Settings > Code signing > iOS:**
   - Sube tu certificado de distribución (.p12)
   - Sube tu provisioning profile
   - O usa "Automatic code signing" si tienes App Store Connect API Key

3. **Configurar App Store Connect API Key:**
   - En App Store Connect > Users > Keys > Generar nueva key
   - Descarga el archivo .p8
   - En Codemagic, agrega la integración con el Key ID, Issuer ID y el archivo .p8

### Para Android (Google Play):

1. **En Codemagic > Settings > Code signing > Android:**
   - Sube tu keystore (padrontag-release.keystore)
   - Configura el alias y contraseñas
   - Nombra la referencia como: `padrontag_keystore`

2. **Credenciales de Google Play:**
   - En Google Play Console > Setup > API access
   - Crea una cuenta de servicio
   - Descarga el JSON de credenciales
   - En Codemagic > Environment variables:
     - Nombre: `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS`
     - Valor: contenido del JSON
     - Grupo: `google_play`

### Ejecutar build:

1. En Codemagic, selecciona tu app
2. Elige el workflow: `ios-workflow` o `android-workflow`
3. Click en "Start new build"

---

## 📱 Google Play Store (Android)

### 1. Crear Keystore (solo una vez)
```bash
keytool -genkey -v -keystore padrontag-release.keystore -alias padrontag -keyalg RSA -keysize 2048 -validity 10000
```
- Guarda el archivo `padrontag-release.keystore` en un lugar seguro
- **NUNCA** subas el keystore a git
- Anota la contraseña que uses

### 2. Crear archivo key.properties
Crea el archivo `android/key.properties` con:
```properties
storePassword=TU_CONTRASEÑA
keyPassword=TU_CONTRASEÑA
keyAlias=padrontag
storeFile=C:/ruta/a/padrontag-release.keystore
```
⚠️ **IMPORTANTE**: Agrega `key.properties` a `.gitignore`

### 3. Generar APK o Bundle
```bash
# Para App Bundle (recomendado para Play Store)
flutter build appbundle --release

# Para APK
flutter build apk --release
```

Los archivos se generan en:
- Bundle: `build/app/outputs/bundle/release/app-release.aab`
- APK: `build/app/outputs/flutter-apk/app-release.apk`

### 4. Subir a Google Play Console
1. Ve a [Google Play Console](https://play.google.com/console)
2. Crea una nueva aplicación
3. Completa la información de la app:
   - Nombre: Padron Vista
   - Descripción corta: Gestión de tags y patentes para barrios privados
   - Categoría: Herramientas
4. Sube el .aab en Producción > Crear nueva versión
5. Completa las políticas de privacidad y clasificación de contenido

---

## 🍎 App Store (iOS) - Manual

> ⚠️ **Recomendado:** Usa Codemagic (ver arriba) para no necesitar una Mac

### 1. Requisitos (si no usas Codemagic)
- Mac con Xcode instalado
- Cuenta de Apple Developer ($99/año)
- Certificados de distribución configurados

### 2. Configurar en Xcode
1. Abre `ios/Runner.xcworkspace` en Xcode
2. Ve a Runner > Signing & Capabilities
3. Selecciona tu Team de desarrollo
4. Asegúrate que el Bundle Identifier sea único (ej: `com.tuempresa.padronvista`)

### 3. Generar Archive
```bash
flutter build ipa --release
```

O desde Xcode:
1. Product > Archive
2. Distribute App > App Store Connect

### 4. Subir a App Store Connect
1. Ve a [App Store Connect](https://appstoreconnect.apple.com)
2. Crea una nueva app
3. Completa la información:
   - Nombre: Padron Vista
   - Categoría: Utilidades
   - Descripción y capturas de pantalla
4. Sube el build desde Xcode o Transporter
5. Envía para revisión

---

## 📋 Checklist antes de publicar

### General
- [ ] Probar en dispositivo real Android
- [ ] Probar en dispositivo real iOS
- [ ] Verificar permisos de cámara funcionan
- [ ] Verificar que el scanner de tags funciona
- [ ] Verificar que el OCR de patentes funciona
- [ ] Verificar que compartir por WhatsApp funciona
- [ ] Crear íconos de la app (ver sección abajo)
- [ ] Crear capturas de pantalla para las tiendas

### Google Play
- [ ] Keystore creado y guardado de forma segura
- [ ] key.properties configurado
- [ ] Política de privacidad URL
- [ ] Capturas de pantalla (mínimo 2)
- [ ] Ícono 512x512 px
- [ ] Feature graphic 1024x500 px

### App Store
- [ ] Certificados de distribución configurados
- [ ] Capturas de pantalla para iPhone y iPad
- [ ] Ícono 1024x1024 px
- [ ] Política de privacidad URL
- [ ] Descripción de uso de cámara

---

## 🎨 Íconos de la App

Para generar íconos automáticamente, puedes usar:
1. Crea una imagen de 1024x1024 px con el logo
2. Usa [flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons)

```yaml
# Agrega a pubspec.yaml
dev_dependencies:
  flutter_launcher_icons: ^0.13.1

flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/app_icon.png"
```

Luego ejecuta:
```bash
flutter pub get
dart run flutter_launcher_icons
```

---

## 🔒 Seguridad

**NUNCA** subas a git:
- `android/key.properties`
- `*.keystore`
- `*.jks`
- Certificados de Apple

Agrega a `.gitignore`:
```
# Release keys
android/key.properties
*.keystore
*.jks
```
