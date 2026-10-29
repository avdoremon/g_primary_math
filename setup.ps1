# Toan Van Dong - dung project Android tu ma nguon (Windows PowerShell).
# Chay trong thu muc goc cua repo:
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1
# Chay lai nhieu lan khong sao (idempotent).

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$MediaPipeVersion = "0.10.26"   # >= 0.10.26 de ho tro trang bo nho 16 KB (yeu cau Google Play)
$CameraXVersion = "1.4.1"

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText((Resolve-Path $Path), $Text, (New-Object System.Text.UTF8Encoding $false))
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "Chua tim thay lenh 'flutter'. Cai Flutter SDK va them vao PATH truoc."
}

# 1. Tao khung project Android neu chua co
if (-not (Test-Path "android")) {
    Write-Host ">> Tao khung project Android bang flutter create..."
    if (Test-Path "_gen") { Remove-Item -Recurse -Force "_gen" }
    flutter create --platforms=android --org vn.toanvandong --project-name g_primary_math _gen
    if ($LASTEXITCODE -ne 0) { throw "flutter create that bai" }
    Copy-Item -Recurse "_gen/android" "./android"
    if (-not (Test-Path ".metadata")) { Copy-Item "_gen/.metadata" "." }
    Remove-Item -Recurse -Force "_gen"
    # MainActivity mac dinh do flutter create sinh ra se duoc thay bang ban trong android_overlay
    Get-ChildItem -Path "android/app/src/main" -Recurse -Filter "MainActivity.*" |
        Where-Object { $_.FullName -notmatch "g_primary_math[\\/]+MainActivity" } |
        Remove-Item -Force
}

# 2. Chep lop nhan dien native (Kotlin, Manifest) de len khung
Write-Host ">> Chep lop nhan dien native..."
$overlay = (Resolve-Path "android_overlay").Path
Get-ChildItem -Path $overlay -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Substring($overlay.Length).TrimStart('\', '/')
    $dest = Join-Path "android" $rel
    New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
    Copy-Item $_.FullName $dest -Force
}

# 3. Them thu vien MediaPipe + CameraX va dat minSdk = 28
$kts = "android/app/build.gradle.kts"
$groovy = "android/app/build.gradle"
if (Test-Path $kts) {
    $c = Get-Content $kts -Raw
    if ($c -notmatch "tasks-vision") {
        $c = $c -replace "minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 28"
        $c += @"

// --- Toan Van Dong ---
android {
    androidResources {
        noCompress.add("task")
    }
}

dependencies {
    implementation("com.google.mediapipe:tasks-vision:$MediaPipeVersion")
    implementation("androidx.camera:camera-core:$CameraXVersion")
    implementation("androidx.camera:camera-camera2:$CameraXVersion")
    implementation("androidx.camera:camera-lifecycle:$CameraXVersion")
}
"@
        Write-Utf8NoBom $kts $c
        Write-Host ">> Da cap nhat $kts"
    }
} elseif (Test-Path $groovy) {
    $c = Get-Content $groovy -Raw
    if ($c -notmatch "tasks-vision") {
        $c = $c -replace "minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 28"
        $c = $c -replace "minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 28"
        $c += @"

// --- Toan Van Dong ---
android {
    androidResources {
        noCompress 'task'
    }
}

dependencies {
    implementation 'com.google.mediapipe:tasks-vision:$MediaPipeVersion'
    implementation 'androidx.camera:camera-core:$CameraXVersion'
    implementation 'androidx.camera:camera-camera2:$CameraXVersion'
    implementation 'androidx.camera:camera-lifecycle:$CameraXVersion'
}
"@
        Write-Utf8NoBom $groovy $c
        Write-Host ">> Da cap nhat $groovy"
    }
} else {
    throw "Khong tim thay android/app/build.gradle(.kts)"
}

# 3b. Giu lop MediaPipe khi build release (R8), them mot lan
if (Test-Path $kts) {
    $c = Get-Content $kts -Raw
    if ($c -notmatch "proguard-rules\.pro") {
        $c += @"

// --- Toan Van Dong: giu lop MediaPipe khi build release ---
android {
    buildTypes {
        getByName("release") {
            proguardFiles("proguard-rules.pro")
        }
    }
}
"@
        Write-Utf8NoBom $kts $c
        Write-Host ">> Da them proguard-rules.pro vao $kts"
    }
} elseif (Test-Path $groovy) {
    $c = Get-Content $groovy -Raw
    if ($c -notmatch "proguard-rules\.pro") {
        $c += @"

// --- Toan Van Dong: giu lop MediaPipe khi build release ---
android {
    buildTypes {
        release {
            proguardFiles 'proguard-rules.pro'
        }
    }
}
"@
        Write-Utf8NoBom $groovy $c
        Write-Host ">> Da them proguard-rules.pro vao $groovy"
    }
}

# 3c. Ky ban release bang khoa co dinh neu co android/key.properties
if (Test-Path $kts) {
    $c = Get-Content $kts -Raw
    if ($c -notmatch "tvdKeyProps") {
        $c += @'

// --- Toan Van Dong: ky ban release bang khoa co dinh (android/key.properties), thieu thi dung khoa debug ---
// (Khong dung java.util.Properties: trong khoi android, "java" bi hieu la extension cua Gradle.)
val tvdKeyProps: Map<String, String> = rootProject.file("key.properties").let { f ->
    if (!f.exists()) emptyMap() else f.readLines()
        .mapNotNull { line -> line.split("=", limit = 2).takeIf { it.size == 2 }?.let { it[0].trim() to it[1].trim() } }
        .toMap()
}
android {
    signingConfigs {
        if (tvdKeyProps["storeFile"] != null) {
            create("tvdRelease") {
                storeFile = file(tvdKeyProps.getValue("storeFile"))
                storePassword = tvdKeyProps["storePassword"]
                keyAlias = tvdKeyProps["keyAlias"]
                keyPassword = tvdKeyProps["keyPassword"]
            }
        }
    }
    buildTypes {
        getByName("release") {
            if (tvdKeyProps["storeFile"] != null) {
                signingConfig = signingConfigs.getByName("tvdRelease")
            }
        }
    }
}
'@
        Write-Utf8NoBom $kts $c
        Write-Host ">> Da them cau hinh khoa ky vao $kts"
    }
}

# 3d. Tat thu gon ma (R8) cho ban release: MediaPipe can giu nguyen lop Java
if (Test-Path $kts) {
    $c = Get-Content $kts -Raw
    if ($c -notmatch "tvdNoShrink") {
        $c += @'

// --- Toan Van Dong (tvdNoShrink): khong thu gon ma ban release ---
// R8 cat bo lop Java cua MediaPipe (goi tu ma native qua JNI) gay NoClassDefFoundError khi bat nhan dien.
android {
    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}
'@
        Write-Utf8NoBom $kts $c
        Write-Host ">> Da tat R8 cho ban release ($kts)"
    }
}

# 4. Tai mo hinh MediaPipe Pose (lite + full)
$assets = "android/app/src/main/assets"
New-Item -ItemType Directory -Force -Path $assets | Out-Null
foreach ($m in @("lite", "full")) {
    $file = "$assets/pose_landmarker_$m.task"
    if (-not (Test-Path $file)) {
        $url = "https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_$m/float16/latest/pose_landmarker_$m.task"
        Write-Host ">> Tai mo hinh $m ..."
        Invoke-WebRequest -Uri $url -OutFile $file
    }
}

# 5. Lay package Dart
flutter pub get
if ($LASTEXITCODE -ne 0) { throw "flutter pub get that bai" }

Write-Host ""
Write-Host "Xong. Cam dien thoai (bat USB debugging) roi chay:"
Write-Host "   flutter run --release"
