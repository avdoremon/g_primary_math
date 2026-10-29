#!/usr/bin/env bash
# Toan Van Dong - dung project Android tu ma nguon (macOS / Linux).
# Chay trong thu muc goc cua repo:  bash setup.sh
# Chay lai nhieu lan khong sao (idempotent).
set -euo pipefail
cd "$(dirname "$0")"

MEDIAPIPE_VERSION="0.10.26"   # >= 0.10.26 de ho tro trang bo nho 16 KB (yeu cau Google Play)
CAMERAX_VERSION="1.4.1"

command -v flutter >/dev/null || { echo "Chua tim thay lenh 'flutter'. Cai Flutter SDK truoc."; exit 1; }

# 1. Tao khung project Android neu chua co
if [ ! -d android ]; then
  echo ">> Tao khung project Android bang flutter create..."
  rm -rf _gen
  flutter create --platforms=android --org vn.toanvandong --project-name g_primary_math _gen
  cp -R _gen/android ./android
  [ -f .metadata ] || cp _gen/.metadata .
  rm -rf _gen
  # MainActivity mac dinh se duoc thay bang ban trong android_overlay
  find android/app/src/main -name 'MainActivity.*' -not -path '*g_primary_math/MainActivity.kt' -delete
fi

# 2. Chep cac file native
echo ">> Chep lop nhan dien native..."
cp -R android_overlay/. android/

# 3. Them thu vien va dat minSdk = 28
KTS=android/app/build.gradle.kts
GROOVY=android/app/build.gradle
if [ -f "$KTS" ]; then
  if ! grep -q "tasks-vision" "$KTS"; then
    perl -pi -e 's/minSdk\s*=\s*flutter\.minSdkVersion/minSdk = 28/' "$KTS"
    cat >> "$KTS" <<EOF

// --- Toan Van Dong ---
android {
    androidResources {
        noCompress.add("task")
    }
}

dependencies {
    implementation("com.google.mediapipe:tasks-vision:${MEDIAPIPE_VERSION}")
    implementation("androidx.camera:camera-core:${CAMERAX_VERSION}")
    implementation("androidx.camera:camera-camera2:${CAMERAX_VERSION}")
    implementation("androidx.camera:camera-lifecycle:${CAMERAX_VERSION}")
}
EOF
    echo ">> Da cap nhat $KTS"
  fi
elif [ -f "$GROOVY" ]; then
  if ! grep -q "tasks-vision" "$GROOVY"; then
    perl -pi -e 's/minSdkVersion\s+flutter\.minSdkVersion/minSdkVersion 28/; s/minSdk\s*=\s*flutter\.minSdkVersion/minSdk = 28/' "$GROOVY"
    cat >> "$GROOVY" <<EOF

// --- Toan Van Dong ---
android {
    androidResources {
        noCompress 'task'
    }
}

dependencies {
    implementation 'com.google.mediapipe:tasks-vision:${MEDIAPIPE_VERSION}'
    implementation 'androidx.camera:camera-core:${CAMERAX_VERSION}'
    implementation 'androidx.camera:camera-camera2:${CAMERAX_VERSION}'
    implementation 'androidx.camera:camera-lifecycle:${CAMERAX_VERSION}'
}
EOF
    echo ">> Da cap nhat $GROOVY"
  fi
else
  echo "Khong tim thay android/app/build.gradle(.kts)"; exit 1
fi

# 3b. Giu lop MediaPipe khi build release (R8), them mot lan
if [ -f "$KTS" ] && ! grep -q "proguard-rules.pro" "$KTS"; then
  cat >> "$KTS" <<'EOF2'

// --- Toan Van Dong: giu lop MediaPipe khi build release ---
android {
    buildTypes {
        getByName("release") {
            proguardFiles("proguard-rules.pro")
        }
    }
}
EOF2
  echo ">> Da them proguard-rules.pro vao $KTS"
elif [ -f "$GROOVY" ] && ! grep -q "proguard-rules.pro" "$GROOVY"; then
  cat >> "$GROOVY" <<'EOF2'

// --- Toan Van Dong: giu lop MediaPipe khi build release ---
android {
    buildTypes {
        release {
            proguardFiles 'proguard-rules.pro'
        }
    }
}
EOF2
  echo ">> Da them proguard-rules.pro vao $GROOVY"
fi

# 3c. Ky ban release bang khoa co dinh neu co android/key.properties (de cai de ban cap nhat len ban cu)
if [ -f "$KTS" ] && ! grep -q "tvdKeyProps" "$KTS"; then
  cat >> "$KTS" <<'EOF2'

// --- Toan Van Dong: ky ban release bang khoa co dinh (android/key.properties), thieu thi dung khoa debug ---
val tvdKeyProps = java.util.Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
android {
    signingConfigs {
        if (tvdKeyProps.getProperty("storeFile") != null) {
            create("tvdRelease") {
                storeFile = file(tvdKeyProps.getProperty("storeFile"))
                storePassword = tvdKeyProps.getProperty("storePassword")
                keyAlias = tvdKeyProps.getProperty("keyAlias")
                keyPassword = tvdKeyProps.getProperty("keyPassword")
            }
        }
    }
    buildTypes {
        getByName("release") {
            if (tvdKeyProps.getProperty("storeFile") != null) {
                signingConfig = signingConfigs.getByName("tvdRelease")
            }
        }
    }
}
EOF2
  echo ">> Da them cau hinh khoa ky vao $KTS"
elif [ -f "$GROOVY" ] && ! grep -q "tvdKeyProps" "$GROOVY"; then
  cat >> "$GROOVY" <<'EOF2'

// --- Toan Van Dong: ky ban release bang khoa co dinh (android/key.properties), thieu thi dung khoa debug ---
def tvdKeyProps = new Properties()
def tvdKeyFile = rootProject.file('key.properties')
if (tvdKeyFile.exists()) { tvdKeyFile.withInputStream { tvdKeyProps.load(it) } }
android {
    signingConfigs {
        if (tvdKeyProps['storeFile'] != null) {
            tvdRelease {
                storeFile file(tvdKeyProps['storeFile'])
                storePassword tvdKeyProps['storePassword']
                keyAlias tvdKeyProps['keyAlias']
                keyPassword tvdKeyProps['keyPassword']
            }
        }
    }
    buildTypes {
        release {
            if (tvdKeyProps['storeFile'] != null) { signingConfig signingConfigs.tvdRelease }
        }
    }
}
EOF2
  echo ">> Da them cau hinh khoa ky vao $GROOVY"
fi

# 4. Tai mo hinh MediaPipe Pose
ASSETS=android/app/src/main/assets
mkdir -p "$ASSETS"
for m in lite full; do
  f="$ASSETS/pose_landmarker_${m}.task"
  if [ ! -f "$f" ]; then
    echo ">> Tai mo hinh $m ..."
    curl -fL -o "$f" "https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_${m}/float16/latest/pose_landmarker_${m}.task"
  fi
done

# 5. Lay package Dart
flutter pub get

echo ""
echo "Xong. Cam dien thoai (bat USB debugging) roi chay:"
echo "   flutter run --release"
