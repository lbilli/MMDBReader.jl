"""
    dump(db)

Print out the content of the data section.
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


function visitnode(db, node, path, prefix, res)

  if node ≥ db.nodeCount

    node > db.nodeCount && push!(res, (path << (8sizeof(path) - prefix), prefix, node + db.nodeCount))

    return
  end

  path <<= 1
  prefix += 0x01

  visitnode(db, nodeval(db, node, false), path, prefix, res)

  visitnode(db, nodeval(db, node, true), path | 0x01, prefix, res)
end


"""
    traversetree(db) -> [(ip, prefix, offset)]

Collect all the IP addresses from the binary tree section that point to an entry
in the data section.
"""
function traversetree(db)

  T = db.ip == 0x0006 ? UInt128 : UInt32

  path = zero(T)
  prefix = 0x00
  res = Tuple{T,UInt8,Int}[]
  node = zero(db.nodeCount)

  visitnode(db, node, path, prefix, res)

  res
end
