function datafield(data)

  t, s = datatype(data)

  # Pointer
  if t == 0x01

    ismarked(data) || @error "datafield(): data not marked"

    pos = position(data)

    seek(data, data.mark + s)

    tt, ss = datatype(data)

    tt == 0x01 && @error "datafield(): pointer to pointer"

    res = decoder[tt](data, ss)

    seek(data, pos)

    return res
  end

  decoder[t](data, s)
end


controlbyte(b) = b >> 5, b & 0x1f


function datatype(data)

  t, s = controlbyte(next(data))

  # Pointer
  if t == 0x01

    ss = s >> 3

    p = UInt32(s & 0x07)

    if ss == 0x00
      p = p << 8 | next(data)

    elseif ss == 0x01
      p = UInt32(2048) + (p << 16 | next2(data))

    elseif ss == 0x02
      p = UInt32(526336) + (p << 24 | next3(data))

    else
      p = next4(data)
    end

    return t, p
  end

  # Extended type
  if t == 0x00
    t = next(data) + 0x07
  end

  # Size
  if s == 0x1d     # 29

    s = UInt32(29) + next(data)

  elseif s == 0x1e # 30

    s = UInt32(285) + next2(data)

  elseif s == 0x1f # 31

    s = UInt32(65821) + next3(data)
  end

  t, s
end


next(data)  = read(data, UInt8)
next2(data) = read(data, UInt16) |> ntoh
next3(data) = UInt32(next2(data)) << 8 | next(data)
next4(data) = read(data, UInt32) |> ntoh


decodeutf8(data, s) = String(decodeu8(data, s))

decodeu8(data, s) = read!(data, Base.StringVector(s))

function decodefloat(T::Union{Type{Float32},Type{Float64}}, data, s)

  s == sizeof(T) || error("decodefloat(): wrong size $T $s")

  read(data, T) |> ntoh
end

decodef32(data, s) = decodefloat(Float32, data, s)
decodef64(data, s) = decodefloat(Float64, data, s)


function decodeuint(T::Union{Type{UInt16},Type{UInt32},Type{UInt64},Type{UInt128}}, data, s)

  s ≤ sizeof(T) || error("decodeuint(): wrong size $T $s")

  res = zero(T)

  for _ ∈ 0x01:s
    res = res << 8 | read(data, UInt8)
  end

  res
end

decodeu16(data, s) = decodeuint(UInt16, data, s)
decodeu32(data, s) = decodeuint(UInt32, data, s)
decodeu64(data, s) = decodeuint(UInt64, data, s)
decodeu128(data, s) = decodeuint(UInt128, data, s)

decodei32(data, s) = reinterpret(Int32, decodeu32(data, s))


function decodekv(data)

  k = datafield(data)

  k isa String || error("decodekv(): string expected")

  v = datafield(data)

  k => v
end

decodemap(data, n) = Dict(decodekv(data) for _ ∈ 1:n)

decodearray(data, n) = [ datafield(data) for _ ∈ 1:n ]

decodebool(data, s) = !iszero(s)


placeholder(i) = (data, s) -> @error "not implemented" i s

const decoder = (placeholder(1),
                 decodeutf8,   #  2 utf8
                 decodef64,    #  3 double
                 decodeu8,     #  4 bytes
                 decodeu16,    #  5 uint16
                 decodeu32,    #  6 uint32
                 decodemap,    #  7 map
                 decodei32,    #  8 int32
                 decodeu64,    #  9 uint64
                 decodeu128,   # 10 uint128
                 decodearray,  # 11 array
                 placeholder(12),
                 placeholder(13),
                 decodebool,   # 14 bool
                 decodef32)    # 15 float32
