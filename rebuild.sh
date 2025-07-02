#!/bin/bash

set -e # exit on error

echo "[*] Cleaning build..."
rm -rf build

echo "[*] Creating build directory..."
mkdir -p build
cd build

echo "[*] Configuring with CMake..."
CC=clang CXX=clang++ cmake -G Ninja ..

echo "[*] Building..."
ninja

echo "[✓] Build complete!"
