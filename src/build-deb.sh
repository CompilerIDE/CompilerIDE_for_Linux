#!/usr/bin/env bash
# ============================================
# Compiler IDE —— 一键生成 Debian 安装包
# ============================================
# 用法：
#   ./build-deb.sh
#   QT_DIR=/path/to/Qt/6.12.0/gcc_64 ./build-deb.sh
# 可选环境变量：
#   QT_DIR      指定 Qt 6 安装前缀（默认自动从 qmake6 / ~/Qt/*/gcc_64 中查找）
#   BUILD_DIR   指定构建目录（默认 <项目目录>/build-deb）
#
# 说明：脚本不再写死作者机器上的 /home/eric/CompilerIDE 路径，
# 因此把项目目录拷到任何位置都能直接打包。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
BUILD_DIR="${BUILD_DIR:-$PROJECT_DIR/build-deb}"
SETUP_DIR="$PROJECT_DIR/Setup"

if [ -z "${BUILD_DIR}" ] || [ "${BUILD_DIR}" = "/" ] || [ "${BUILD_DIR}" = "${PROJECT_DIR}" ]; then
    echo "错误：BUILD_DIR 不能为空、不能是 /，也不能等于项目目录。" >&2
    exit 1
fi

echo "=== 1/6 检测 Qt 6 ==="
QT_DIR="${QT_DIR:-}"
if [ -z "${QT_DIR}" ]; then
    for candidate in qmake6 qmake-qt6 qmake; do
        if command -v "${candidate}" >/dev/null 2>&1; then
            QT_DIR="$("${candidate}" -query QT_INSTALL_PREFIX 2>/dev/null || true)"
            if [ -n "${QT_DIR}" ]; then
                break
            fi
        fi
    done
fi
if [ -z "${QT_DIR}" ]; then
    # 常见安装位置：~/Qt/<版本>/gcc_64，取版本号最大的一个
    for candidate in "${HOME}"/Qt/*/gcc_64; do
        if [ -d "${candidate}/lib/cmake/Qt6" ]; then
            QT_DIR="${candidate}"
        fi
    done
fi
if [ -z "${QT_DIR}" ] || [ ! -d "${QT_DIR}/lib/cmake/Qt6" ]; then
    echo "错误：未找到 Qt 6（需要 6.11.2 或更新版本）。" >&2
    echo "      请先安装 Qt，或指定：QT_DIR=/path/to/Qt/6.12.0/gcc_64 ./build-deb.sh" >&2
    exit 1
fi
echo "使用 Qt：${QT_DIR}"

echo ""
echo "=== 2/6 清理构建目录 ==="
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

echo ""
echo "=== 3/6 清理旧的安装包 ==="
mkdir -p "${SETUP_DIR}"
rm -f "${SETUP_DIR}"/compileride_*.deb
rm -f "${SETUP_DIR}"/*.deb.sha256

echo ""
echo "=== 4/6 配置 CMake ==="
cmake -S "${PROJECT_DIR}" -B "${BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_PREFIX_PATH="${QT_DIR}" \
    -DCOMPILERIDE_QT_DIR="${QT_DIR}"

echo ""
echo "=== 5/6 编译 ==="
cmake --build "${BUILD_DIR}" -j"$(nproc)"

echo ""
echo "=== 6/6 打包 ==="
(
    cd "${BUILD_DIR}"
    cpack -G DEB
)

echo ""
echo "=== 生成 SHA-256 校验文件 ==="
cd "${SETUP_DIR}"
DEB_FILE="$(ls -1t compileride_*.deb | head -n 1)"
sha256sum "${DEB_FILE}" > "${DEB_FILE}.sha256"

echo ""
echo "======================================"
echo " 完成！安装包已生成到："
echo "   ${SETUP_DIR}"
echo "======================================"
ls -lh "${SETUP_DIR}"/compileride_*.deb
echo ""
cat "${DEB_FILE}.sha256"
echo ""
echo "安装命令（会自动补全依赖）："
echo "   sudo apt install ${SETUP_DIR}/${DEB_FILE}"
