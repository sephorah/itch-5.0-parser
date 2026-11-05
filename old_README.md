# ITCH Market Data Engine

The goal is to create a C++20 library, exposed to Python through pybind11, that parses NASDAQ TotalView-ITCH 5.0 messages and reconstructs per-instrument order books for market microstructure analysis.

## Current status

### ITCH parser

- Reads binary ITCH file sequentially.
- Handles endianness (from big-endian to little-endian).
- Reads the file in fixed-size chunks and handles split messages between two chunks.

### Supported ITCH 5.0 Messages

#### Stock related messages

| Type | Message | Description |
|------|---------|-------------|
| `S` | `SystemEvent` | Used to signal a market or data feed handler event. |
| `R` | `StockDirectory` | Sent at the start of each trading day for all active symbols. |
| `H` | `StockTradingAction` | Indicate the current trading status of a security: halted (H), paused (P), quote-only (Q), or trading (T). |

#### Order related messages

| Type | Message | Description |
|------|---------|-------------|
| `A` | `AddOrder` | A new order has been accepted and was added to the order book (no MPID attribution). |
| `F` | `AddOrderMPID` | A new order has been accepted and was added to the order book (MPID attribution). |
| `E` | `OrderExecuted` | An order on the book was executed in whole or in part at its display price. |
| `C` | `OrderExecutedWithPrice` | An order on the book was executed in whole or in part at a price different from the initial display price. |
| `X` | `OrderCancel` | An order on the book was partially canceled, which reduces shares on an existing order. |
| `D` | `OrderDelete` | An order on the book was cancelled entirely and must be removed from the book. |
| `U` | `OrderReplace` | An order on the book was cancelled and replaced with a new order. |

## Architecture diagram

```mermaid
flowchart TD

    config_file["Configuration file with instruments details (ID, symbol, order book depth)"]
    
    nasdaq_itch_file[NASDAQ TotalView-ITCH 5.0 historical file<br/>• Replayed as a continuous event stream, providing level 3 market data]

    subgraph cpp_server[C++ library]

        itch_parser["ITCH Parser<br/>• Decodes ITCH messages and emits normalized order events"]

        order_book_manager[Order book manager<br/>• Applies events to maintain order book state<br/>• Manages order books for all instruments]
        
        order_book[Order book<br/>• Lists bids and asks for an instrument]

        pybind11_interface[Pybind11 bindings<br/>• Exposes C++ API to Python<br/>• Zero-copy data transfer via NumPy arrays]
    end

    subgraph python_layer[Python Research layer]

        update_buffers[Update buffers per instrument<br/>• Maintains separate buffer per instrument<br/>• Collects updates up to 1000 per instrument]

        polars_processing[Polars processing<br/>• Processes each instrument independently<br/>• Triggers when instrument reaches 1000 updates<br/>• Extracts features and saves to Parquet]
    end

    parquet_files[Parquet files]
    
    pandas_analysis[Pandas analysis<br/>• Jupyter notebooks<br/>• Loads Parquet files for statistical analysis and visualizations]


    config_file -->|Specifies instruments to observe| order_book_manager
    order_book_manager --> order_book
    nasdaq_itch_file --> itch_parser
    itch_parser --> order_book_manager
    order_book_manager --> pybind11_interface
    pybind11_interface --> update_buffers
    update_buffers --> polars_processing
    polars_processing --> parquet_files
    parquet_files --> pandas_analysis
```

## Stack used

- Build system: [CMake](https://cmake.org/), a cross-platform build system generator.
- Package manager: [Conan](https://conan.io/), a C/C++ dependency manager widely used in production environments.

## Getting started

### Requirements

The project requires the following to run:

- [CMake](https://cmake.org/): if not installed, refer to the [installation guide](https://cmake.org/download/).
- [Conan](https://conan.io/): if not installed, refer to the [installtion guide](https://docs.conan.io/2/installation.html).

Run the following command:
```sh
conan profile detect --force
```

### Dataset

Download raw ITCH 5.0 data `01302020.NASDAQ_ITCH50.gz` from `https://emi.nasdaq.com/ITCH/Nasdaq%20ITCH/`.

Samples are available in `examples/` folder.

The data format is defined by the document [Nasdaq TotalView-ITCH 5.0](https://www.nasdaqtrader.com/content/technicalsupport/specifications/dataproducts/NQTVITCHspecification.pdf).

### Installation

1. Clone the git repository.
```sh
git clone git@github.com:sephorah/ITCH-market-data-engine.git
cd ITCH-market-data-engine
```

2. Install dependencies.
```sh
./bin/setup.sh install
```

3. Build the project.
```sh
./bin/setup.sh build
```

4. Run tests.
```sh
./bin/setup.sh tests
```
