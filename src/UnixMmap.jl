module UnixMmap
@static if Sys.isunix()
    include("staticexpand.jl")
    include("mmap.jl")
end
end
