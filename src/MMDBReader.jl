module MMDBReader

using Dates,
      Mmap,
      Sockets

include("db.jl")
include("decode.jl")

public loaddb,
       lookup,
       metadata

end # module
