# MMDBReader

*A MaxMind DB reader in Julia*

[MaxMind DB](https://maxmind.github.io/MaxMind-DB/) binary files store data
indexed by IB address subnets.

This package implements version 2 of the format and it can handle both
IPv4 or IPv6 databases with record sizes of 24, 28 or 32 bits.

## Installation
To install from GitHub:
```julia
] add https://github.com/lbilli/MMDBReader.jl
```

## Usage
To look up an IP address in a database:
```julia
using MMDBReader: MMDBReader as MM
using Sockets

filename = "/path/to/file.db"
ip = ip"x.x.x.x" or ip"x:x:x:x"

# Load a database file
db = MM.loaddb(filename)

# Look up an IP
res, prefix = MM.lookup(db, ip)

# Return the database metadata
meta = MM.metadata(db)
```
Results are typically kay/value maps, possibly nested,
and are presented here as Julia's `Dict{String,Any}`.

## Data mapping
Supported data types are mapped to Julia builtin types
according to the following table:

| MaxMind DB | Julia |
| ---: | ---: |
| UTF-8 string | `String` |
| double | `Float64` |
| bytes  | `UInt8[]` |
| unsigned 16-bit int | `UInt16` |
| unsigned 32-bit int | `UInt32` |
| signed 32-bit int   | `Int32` |
| unsigned 64-bit int | `UInt64` |
| unsigned 128-bit int | `UInt128` |
| map | `Dict{String,Any}`[^1] |
| array | `Vector{Any}`[^1]  |
| boolean | `Bool` |
| float | `Float32` |

[^1]: `eltype` can be stricter than `Any` if possible


