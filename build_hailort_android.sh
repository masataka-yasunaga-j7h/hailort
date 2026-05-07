#!/bin/bash
# HailoRT Android (arm64-v8a) ビルドスクリプト
# 対象: android-16.0.0_r4 + AAOS
#
# 前提条件:
#   - ~/hailort/ に HailoRT ソースが存在すること
#   - android-sdk/ndk-bundle が存在すること

set -e

# ==============================
# 設定
# ==============================
NDK=/home/mstk83long/android-sdk/ndk-bundle
AAOS_ROOT=/home/mstk83long/aaos
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build_android"

# cmake (AAOS プリビルド) を PATH に追加
export PATH="${AAOS_ROOT}/prebuilts/cmake/linux-x86/bin:${PATH}"

# Android API level (Android 8.0 以上であれば動作)
ANDROID_PLATFORM=android-26
ANDROID_ABI=arm64-v8a

# ==============================
# ツールチェーン確認
# ==============================
if [ ! -f "${NDK}/build/cmake/android.toolchain.cmake" ]; then
    echo "[ERROR] NDK toolchain が見つかりません: ${NDK}/build/cmake/android.toolchain.cmake"
    echo "[ERROR] NDK_PATH を確認してください"
    exit 1
fi

# ==============================
# ビルド
# ==============================
build() {
    echo "======================================================"
    echo " HailoRT Android ビルド"
    echo " NDK    : ${NDK}"
    echo " ABI    : ${ANDROID_ABI}"
    echo " PLATFORM: ${ANDROID_PLATFORM}"
    echo " 出力先  : ${BUILD_DIR}/"
    echo "======================================================"

    cmake -S "${SCRIPT_DIR}" -B "${BUILD_DIR}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_TOOLCHAIN_FILE="${NDK}/build/cmake/android.toolchain.cmake" \
        -DANDROID_NDK="${NDK}" \
        -DANDROID_ABI="${ANDROID_ABI}" \
        -DANDROID_PLATFORM="${ANDROID_PLATFORM}" \
        -DCMAKE_ANDROID_ARCH_ABI="${ANDROID_ABI}"

    cmake --build "${BUILD_DIR}" --config Release -- -j$(nproc)

    echo ""
    echo "[SUCCESS] ビルド完了!"
    echo ""
    find "${BUILD_DIR}" -name "libhailort.so" -o -name "hailortcli" 2>/dev/null | sort
    echo ""
    echo "======================================================"
    echo " 次のステップ: デバイスへの展開"
    echo "======================================================"
    LIB=$(find "${BUILD_DIR}" -name "libhailort.so" 2>/dev/null | head -1)
    CLI=$(find "${BUILD_DIR}" -name "hailortcli" 2>/dev/null | head -1)
    echo " adb root && adb remount"
    [ -n "${LIB}" ] && echo " adb push ${LIB} /vendor/lib64/"
    [ -n "${CLI}" ] && echo " adb push ${CLI} /vendor/bin/"
    echo "======================================================"
    echo " ※ './build_hailort_android.sh deploy' で上記を自動実行できます"
    echo "======================================================"
}

# ==============================
# クリーン
# ==============================
clean() {
    echo "[INFO] ${BUILD_DIR} を削除中..."
    rm -rf "${BUILD_DIR}"
    echo "[INFO] 完了"
}

# ==============================
# デプロイ (adb)
# ==============================
deploy() {
    local lib
    local cli
    lib=$(find "${BUILD_DIR}" -name "libhailort.so" 2>/dev/null | head -1)
    cli=$(find "${BUILD_DIR}" -name "hailortcli" 2>/dev/null | head -1)

    if [ -z "${lib}" ] && [ -z "${cli}" ]; then
        echo "[ERROR] ビルド成果物が見つかりません。先に './build_hailort_android.sh build' を実行してください"
        exit 1
    fi

    echo "[INFO] adb root && adb remount ..."
    adb root
    adb remount

    if [ -n "${lib}" ]; then
        echo "[INFO] libhailort.so をプッシュ中..."
        adb push "${lib}" /vendor/lib64/
    fi
    if [ -n "${cli}" ]; then
        echo "[INFO] hailortcli をプッシュ中..."
        adb shell "mkdir -p /vendor/bin"
        adb push "${cli}" /vendor/bin/
    fi

    echo ""
    echo "[SUCCESS] デプロイ完了!"
}

# ==============================
# メイン
# ==============================
case "${1:-build}" in
    build)
        build
        ;;
    clean)
        clean
        ;;
    deploy)
        deploy
        ;;
    *)
        echo "使い方: $0 [build|clean|deploy]"
        echo "  build  : HailoRT を Android arm64 向けにビルド (デフォルト)"
        echo "  clean  : ビルド成果物を削除"
        echo "  deploy : adb でデバイスに展開"
        exit 1
        ;;
esac
