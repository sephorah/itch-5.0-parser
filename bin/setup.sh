#!/usr/bin/env bash

install() {
    echo "Installing packages..."
    conan install . --build=missing
    cmake --preset conan-release
}

build() {
    echo "Building ITCH Market Data Engine with CMake..."
    cmake --build --preset conan-release
    make -C build/Release
}

clean() {
    echo "Cleaning ITCH Market Data Engine..."
    cmake --build --target clean --preset conan-release
    echo "Done."
}

tests() {
    echo -e "Run ITCH Market Data Engine tests...\n"
    echo -e "--------- Parser tests ---------"
    ./build/Release/bin/ParserTests
    echo -e "\n--------- Engine tests ---------"
    ./build/Release/bin/RunEngine examples/simple-example.json
}

case "$1" in
    install)
        install
        ;;
    build)
        build
        ;;
    clean)
        clean
        ;;
    tests)
        tests
        ;;
    *)
        echo "Usage: $0 {install|build|clean|tests}"
        exit 1
        ;;
esac