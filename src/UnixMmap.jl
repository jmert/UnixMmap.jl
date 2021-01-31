module UnixMmap
@static if Sys.isunix()
    include("staticexpand.jl")
    include("consts.jl")
    include("mmap.jl")
end
end
