compare(a, b) = a == b

compare(a::Vector, b::JSON3.Array) = length(a) == length(b) &&
                                       all(x -> compare(x...), zip(a, b))

compare(a::Dict, b::JSON3.Object) = length(a) == length(b) &&
                                      all(b) do (k, v)
                                        compare(a[String(k)], v)
                                      end

function verify(db, js)

  for j ∈ js

    ipm, data = only(j)

    ip, m = split(String(ipm), '/')

    m = parse(Int, m)

    d, p = MM.lookup(db, ip)

    @test p == m

    @test compare(d, data)
  end

end

path = only(readdir(artifact"testdb", join=true))

sdata, tdata = joinpath.(path, ("source", "test") .* "-data")

@testset "GeoIP2" begin

  files1 = "GeoIP2-" .* ["Anonymous-IP",
                         "City",
                         "Connection-Type",
                         "Country",
                         "DensityIncome",
                         "Domain",
                         "Enterprise",
                         "IP-Risk"]
                         #"ISP",
                         #"Precision-Enterprise",
                         #"Static-IP-Score",
                         #"User-Count"]

  files2 = "GeoLite2-" .* [ #"ASN",
                           "City",
                           "Country"]



  for f ∈ Iterators.flatten((files1, files2))

    db = MM.loaddb(joinpath(tdata, f * "-Test.mmdb"), true)
    js = JSON3.read(joinpath(sdata, f * "-Test.json"))

    verify(db, js)
  end
end



alltypes = Dict("array"       => UInt32[1, 2, 3],
                "bytes"       => [0x00, 0x00, 0x00, 0x2a],
                "boolean"     => true,
                "double"      => 42.123456,
                "float"       => 1.1f0,
                "int32"       => -Int32(2)^28,
                "map"         => Dict("mapX" =>
                                      Dict("utf8_stringX" => "hello",
                                            "arrayX"       => UInt32[7, 8, 9])),
                "uint16"      => UInt16(100),
                "uint32"      => UInt32(2)^28,
                "uint64"      => one(UInt64) << 60,
                "uint128"     => one(UInt128) << 120,
                "utf8_string" => "unicode! ☯ - ♫")

zerovals = Dict("array"       => [],
                "bytes"       => UInt8[],
                "boolean"     => zero(Bool),
                "double"      => zero(Float64),
                "float"       => zero(Float32),
                "int32"       => zero(Int32),
                "map"         => Dict(),
                "uint16"      => zero(UInt16),
                "uint32"      => zero(UInt32),
                "uint64"      => zero(UInt64),
                "uint128"     => zero(UInt128),
                "utf8_string" => "")

maxvals = Dict("double"      => typemax(Float64),
               "float"       => typemax(Float32),
               "int32"       => typemax(Int32),
               "uint16"      => typemax(UInt16),
               "uint32"      => typemax(UInt32),
               "uint64"      => typemax(UInt64),
               "uint128"     => typemax(UInt128))

cmpeq(a::Dict, b::Dict) = typeof(a) == typeof(b) && length(a) == length(b) &&
                            all(b) do (k, v)
                                     cmpeq(a[k], v)
                                   end

cmpeq(a::Vector, b::Vector) = typeof(a) == typeof(b) && length(a) == length(b) &&
                                all(pairs(b)) do (i, v)
                                  cmpeq(a[i], v)
                                end

cmpeq(a, b) = a === b

@testset "MaxMind DB decoder" begin

  db = MM.loaddb(joinpath(tdata, "MaxMind-DB-test-decoder.mmdb"), true)

  d, p = MM.lookup(db, "::1.1.0.0")

  @test isnothing(d)

  d, p = MM.lookup(db, "::1.1.1.0")

  @test p == 120
  @test cmpeq(d, alltypes)

  d, p = MM.lookup(db, "::0.0.0.0")
  @test p == 128
  @test cmpeq(d, zerovals)

  d, p = MM.lookup(db, "::255.255.255.255")
  @test p == 128
  @test cmpeq(d, maxvals)
end


jstxt = """
{ "ipv4" : [ { "1.1.1.1/32"  : { "ip" : "1.1.1.1"  } },
             { "1.1.1.2/31"  : { "ip" : "1.1.1.2"  } },
             { "1.1.1.4/30"  : { "ip" : "1.1.1.4"  } },
             { "1.1.1.8/29"  : { "ip" : "1.1.1.8"  } },
             { "1.1.1.16/28" : { "ip" : "1.1.1.16" } },
             { "1.1.1.32/32" : { "ip" : "1.1.1.32" } } ],

  "ipv6" : [ { "::1:ffff:ffff/128" : { "ip" : "::1:ffff:ffff" } },
             { "::2:0:0/122"       : { "ip" : "::2:0:0"  } },
             { "::2:0:40/124"      : { "ip" : "::2:0:40" } },
             { "::2:0:50/125"      : { "ip" : "::2:0:50" } },
             { "::2:0:58/127"      : { "ip" : "::2:0:58" } } ],

  "mixed" : [ { "1.1.1.1/32"        : { "ip" : "::1.1.1.1"  } },
              { "1.1.1.2/31"        : { "ip" : "::1.1.1.2"  } },
              { "1.1.1.4/30"        : { "ip" : "::1.1.1.4"  } },
              { "1.1.1.8/29"        : { "ip" : "::1.1.1.8"  } },
              { "1.1.1.16/28"       : { "ip" : "::1.1.1.16" } },
              { "1.1.1.32/32"       : { "ip" : "::1.1.1.32" } },
              { "::1:ffff:ffff/128" : { "ip" : "::1:ffff:ffff" } },
              { "::2:0:0/122"       : { "ip" : "::2:0:0"    } },
              { "::2:0:40/124"      : { "ip" : "::2:0:40"   } },
              { "::2:0:50/125"      : { "ip" : "::2:0:50"   } },
              { "::2:0:58/127"      : { "ip" : "::2:0:58"   } } ]}
"""


@testset "MaxMind DB" begin

  js = JSON3.read(jstxt)

  for ip ∈ ("ipv4", "ipv6", "mixed"), rs ∈ UInt16.((24, 28, 32))

    db = MM.loaddb(joinpath(tdata, "MaxMind-DB-test-$(ip)-$(rs).mmdb"), true)

    @test typeof(db) === MM.DB{rs}

    @test db.ip == (ip == "ipv4" ? 4 : 6)

    verify(db, js[ip])
  end
end
