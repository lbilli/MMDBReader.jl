"""
    dump(db)

Print out data section.
"""
function dump(db, quiet=false)

  seek(db.data, db.dataSeek)

  while position(db.data) < db.dataEnd

    print(position(db.data))

    t, s = datatype(db.data)

    payload = t == 0x01 ? nothing :
                          decoder[t](db.data, s)

    println(" $t $s ", quiet ? "" : payload)
  end

  position(db.data) == db.dataEnd || @warn "dump: not end of data"
end
