@testset "Control Byte" begin

  function writebitstring(bs...)

    buf = IOBuffer()

    write(buf, parse.(UInt8, bs; base=2)...)

    seekstart(buf)
  end

  # From the spec
  @test MM.datatype(writebitstring("01000010")) === (0x02, 0x02)

  @test MM.datatype(writebitstring("01011100")) === (0x02, 0x1c)

  @test MM.datatype(writebitstring("11000001")) === (0x06, 0x01)

  @test MM.datatype(writebitstring("00000011", "00000011")) === (0x0a, 0x03)

  @test MM.datatype(writebitstring("01011101", "00110011")) === (0x02, UInt32(80))

  @test MM.datatype(writebitstring("01011110", "00110011", "00110011")) === (0x02, UInt32(13_392))

  @test MM.datatype(writebitstring("01011111", "00110011", "00110011", "00110011")) === (0x02, UInt32(3_421_264))

  @test MM.datatype(writebitstring("11111111", "11111111", "11111111", "11111111")) === (0x07, UInt32(16_843_036))

  # Pointers
  @test MM.datatype(writebitstring("00100010", "11100011")) === (0x01, 0x000002e3)

  @test MM.datatype(writebitstring("00101010", "11100011", "00110001")) === (0x01, 0x0002eb31)

  @test MM.datatype(writebitstring("00110010", "11100011", "00110001", "11111111")) === (0x01, 0x02eb39ff)

  @test MM.datatype(writebitstring("00111111", "11100011", "00110001", "11111111", "01010101")) === (0x01, 0xe331ff55)

  # Other
  buf = IOBuffer()
  write(buf, UInt8(29), UInt8(4), UInt8(11),
             0x28, 0x08, 0x82)

  @test MM.datatype(seekstart(buf)) === (0x0b, UInt32(40))

  @test MM.datatype(buf) === (0x01, 0x00001082)

  @test eof(buf)


  # UTF8 and EOF
  buf = seekend(writebitstring("01000100"))
  write(buf, "A∈")

  seekstart(buf)
  @test MM.datafield(buf) == "A∈"

  @test eof(buf)

end
