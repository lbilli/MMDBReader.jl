const DATA_START_LENGTH = 16
const METADATA_START = b"\xab\xcd\xefMaxMind.com"
const METADATA_MAX = one(UInt32) << 17  # 128 KiB


"""
    DB{RS}

Database type parametrized by the record size `RS`.
"""
struct DB{RS}
  data::IOBuffer
  file::String
  version::VersionNumber
  build::DateTime
  nodeCount::UInt32
  ip::UInt16
  dataSeek::Int
  dataOffset::Int
  dataEnd::Int
  metaSeek::Int
  ipv4Start::UInt32
end


"""
    loaddb(file, inmemory)

Load a database from `file`.

If `inmemory=true` the file is loaded in memory, otherwise it is memory mapped.

Return a [`DB`](@ref) struct.
"""
function loaddb(file, inmemory)

  db = inmemory ? read(file) : mmap(file)

  offset = max(length(db) - METADATA_MAX, 0)

  midx =findlast(METADATA_START, offset > 0 ? @view(db[offset+1:end]) : db)

  isnothing(midx) && error("loaddb(): metadata not found")

  metaSeek = last(midx) + offset

  data = IOBuffer(db)

  meta = _metadata(data, metaSeek)

  ver = VersionNumber(meta["binary_format_major_version"],
                      meta["binary_format_minor_version"])

  ver.major == 2 || error("loaddb(): unsupported version $ver")

  build = unix2datetime(meta["build_epoch"])

  recordSize = meta["record_size"]
  recordSize & 0x03 == 0x00 || error("loaddb(): record size not a multiple of 4")

  ip = meta["ip_version"]

  ip ∈ (0x004, 0x006) || error("loaddb(): unsupported IP version $ip")

  nodeCount = meta["node_count"]

  searchTreeSize = nodeCount * recordSize >> 2 # = 1 / 4
  dataSeek = searchTreeSize + DATA_START_LENGTH
  dataOffset = searchTreeSize - nodeCount
  dataEnd = metaSeek - length(METADATA_START)

  # Verify data section start
  dataSeek ≤ dataEnd || error("loaddb(): data section overlaps metadata")

  seek(data, dataSeek - DATA_START_LENGTH)
  iszero(read(data, DATA_START_LENGTH)) || error("loaddb(): data section not found")

  # Abuse mark to hold section start
  mark(data) == dataSeek || error("loaddb(): wrong mark")

  # Find IPv4 node start
  ipv4Start = zero(nodeCount)

  if ip == 0x0006

    for _ ∈ 1:96
      ipv4Start < nodeCount || break

      ipv4Start = _nodeval(data, recordSize, ipv4Start, false)
    end

    # Check alternatives
    # i) ::ffff:0:0/96
    node = zero(nodeCount)

    for i ∈ 1:96
      node < nodeCount || break

      node = _nodeval(data, recordSize, node, i > 80)
    end

    # ii) 2002::/16
    node2 = zero(nodeCount)

    for i ∈ 1:16
      node2 < nodeCount || break

      node2 = _nodeval(data, recordSize, node2, i ∈ (3, 15))
    end

    ipv4Start == node == node2 < nodeCount || @warn "inconsistent ipv4Start" ipv4Start node node2 nodeCount

  end

  DB{recordSize}(data, file, ver, build, nodeCount, ip,
                 dataSeek, dataOffset, dataEnd, metaSeek, ipv4Start)
end


"""
    lookup(db, ip) -> (res, prefix)

Lookup an IP address `ip` in the database `db`.

The address can either be IPv4 or IPv6 and the
database is a [`DB`](@ref) instance returned by [`loaddb`](@ref).

Return a 2-tuple of the data stored in the database,
or `nothing` if no match is found,
and an integer representing the prefix length.
"""
lookup(db, ip) = lookup(db, parse(IPAddr, ip))

function lookup(db, ip::IPAddr)

  db.ip == 0x0006 || ip isa IPv4 ||
    error("lookup(): no IPv6 addresses in a IPv4 database")

  node = ip isa IPv4 ? db.ipv4Start : zero(db.ipv4Start)

  node, prefix = findintree(db, node, ip.host)

  if node > db.nodeCount

    offset = node + db.dataOffset

    offset < db.dataEnd ||
      error("lookup(): attempt to read past data section at offset $offset")

    return datafield(seek(db.data, offset)), prefix

  elseif node == db.nodeCount

    return nothing, prefix
  end

  error("lookup(): never here")
end


function findintree(db, node, ip)

  prefix = 0x00

  for i ∈ 8(sizeof(ip) - 1):-8:0

    u8 = (ip >> i) % UInt8

    for mask ∈ (0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x01)

      node < db.nodeCount || return node, prefix

      prefix += 0x01

      node = nodeval(db, node, !iszero(u8 & mask))
    end
  end

  node, prefix
end


function nodeval(db::DB{RS}, node, right) where RS

  _nodeval(db.data, RS, node, right)
end


function _nodeval(data, rs, node, right)

  if rs == 24

    seek(data, 3(2node + right)) |> next3

  elseif rs == 28

    res = seek(data, 7node + 3right) |> next4

    right ? res & 0x0fffffff :
            (res & 0xf0) << 20 | res >> 8

  elseif rs == 32

    seek(data, 4(2node + right)) |> next4

  else
    error("_nodeval(): record size not implemented $rs")
  end
end


function _metadata(data, metaSeek)

  oldm = ismarked(data) ? reset(data) : nothing

  seek(data, metaSeek) |> mark

  res = datafield(data)

  eof(data) || @warn "_metadata(): EOF not reached"

  isnothing(oldm) ? unmark(data) :
                    seek(data, oldm) |> mark

  res
end


"""
    metadata(db)

Return the database metadata, typically a key/value map of database parameters.
"""
metadata(db) = _metadata(db.data, db.metaSeek)
