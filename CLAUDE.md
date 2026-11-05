# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A C++20 library that parses NASDAQ TotalView-ITCH 5.0 binary market-data messages. The end goal (per the README architecture diagram) is to reconstruct per-instrument order books, expose them to Python via pybind11, and feed a Polars/Pandas research layer. **Only the ITCH parser and the file-reading engine are implemented today.** The order book, pybind11 bindings, and Python layer do not exist yet — `lib/include/LimitOrderBook.hpp` is an empty stub, and the Python side is aspirational.

## Build & test

Dependencies are managed by Conan and the build by CMake; `bin/setup.sh` wraps both. One-time setup requires `conan profile detect --force`.

```sh
./bin/setup.sh install   # conan install + cmake configure (conan-release preset)
./bin/setup.sh build     # cmake --build, outputs to build/Release/bin
./bin/setup.sh clean
./bin/setup.sh tests      # runs both test executables
```

Two test executables land in `build/Release/bin`:

- `ParserTests` — GoogleTest suite over the ITCH parser. Run a single test with a gtest filter: `./build/Release/bin/ParserTests --gtest_filter=ItchParser.ParseSystemEventMessage`.
- `RunEngine` — a plain `main()` (not gtest) that takes a config JSON path and runs the full engine: `./build/Release/bin/RunEngine examples/simple-example.json`.

Sample ITCH files and a sample config live in `examples/`.

## Architecture

Data flows: **config JSON → `ConfigParser` → `Engine` reads the ITCH file in 64 KB chunks → `Itch::parse` decodes each message → a handler functor consumes it.**

- **`Engine` (`lib/src/Engine.cpp`)** — reads the binary file into a fixed `BUFFER_SIZE` (64 KB) buffer. ITCH frames each message with a 2-byte big-endian length prefix (`LENGTH_FIELD_SIZE`). `processMessages` walks the buffer message-by-message; when a message straddles the end of a chunk it `memmove`s the leftover bytes to the front and returns the leftover count, which the next `read` fills in behind. This is the core correctness-sensitive loop — mind the offset arithmetic around partial messages.

- **`Itch::parse` (`lib/include/ItchParser.hpp`)** — header-only. Switches on the first byte (message type) and dispatches to `parseAs<MsgType>`, which `reinterpret_cast`s the buffer directly onto a packed struct (zero-copy), byte-swaps it, and invokes the handler. Unknown types return `ParseStatus::UnknownMessageType` and consume `length` bytes. **Adding a new ITCH message type means touching four places:** a struct in `ItchMessages.hpp`, an enum in `ItchEnums.hpp`, a `networkToHost` specialization in `Byteswap.hpp`, and a `case` in `parse`.

- **Handler functor pattern** — `parse` is templated on `Handler`; the handler is any struct with an `operator()` overload per message type. Two exist: `Printer` (`lib/include/Printer.hpp`, prints each message, used by the live `Engine`) and `CaptureMessage` (`lib/include/CaptureMessage.hpp`, stores the last message of each type, used by tests to assert decoded fields). New consumers (e.g. an order-book builder) should be new functors of this shape rather than changes to `parse`.

- **Endianness (`lib/include/Byteswap.hpp`)** — ITCH is big-endian; `networkToHost<T>` specializations swap each field in place via `__builtin_bswap*`. The primary template is `= delete`, so every parsed message type *must* have a specialization or it won't compile. 6-byte timestamps are decoded on demand with `parseTimestamp`, not stored swapped.

- **Message structs (`lib/include/ItchMessages.hpp`)** — wrapped in `#pragma pack(push, 1)` so their layout matches the wire format exactly for the `reinterpret_cast`. Do not add padding or reorder fields against the ITCH 5.0 spec.

- **`ConfigParser` (`lib/src/ConfigParser.cpp`)** — parses the JSON config (nlohmann_json) into a `Config` (`replay_speed`, `nasdaq_historical_file_path`, and per-instrument `id`/`symbol`/`depth`/`enabled`). See `examples/simple-example.json` for the schema.

## Reference

- ITCH 5.0 spec: NASDAQ TotalView-ITCH 5.0 (linked in README). Field layouts, enum codes, and message lengths must match it exactly.
- Untracked scratch files in the repo root (`actual`, `expected`, `extract*`, `res`, `template*`) are working notes, not part of the build.
