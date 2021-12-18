# UnixMmap.jl Documentation

Installation and loading is as easy as:
```julia-repl
pkg> add UnixMmap

julia> using UnixMmap
```

A file can be memory mapped (read-only by default) by calling [`UnixMmap.mmap`](@ref)
with a filename and the `Array` type to be applied (and optionally with dimensions to give a
shape):
```julia-repl
julia> UnixMmap.mmap("arbitrary.dat", Array{Float64})
192-element Vector{Float64}:
 0.0
 0.0
 ⋮
 0.0
 0.0

julia> UnixMmap.mmap("arbitrary.dat", Array{Float64}, (64, 3))
64×3 Matrix{Float64}:
 0.0  0.0  0.0
 0.0  0.0  0.0
 ⋮
 0.0  0.0  0.0
 0.0  0.0  0.0
```
while an anonymous memory map can be created by instead specifying the `Array` type and
dimensions:
```julia-repl
julia> UnixMmap.mmap(Array{Float64}, (128, 3))
128×3 Matrix{Float64}:
 0.0  0.0  0.0
 0.0  0.0  0.0
 ⋮
 0.0  0.0  0.0
 0.0  0.0  0.0
```

The notable features that UnixMmap.jl provides over the standard library's Mmap module
is the ability to set Unix-specific flags during mapping.
For example, on Linux the `MAP_POPULATE` flag can be used to advise the kernel to
prefault all mapped pages into active memory.
```julia-repl
julia> UnixMmap.mmap("arbitrary.dat", Array{Float64}, (64, 3);
                     flags = UnixMmap.MAP_SHARED | UnixMmap.MAP_POPULATE)
64×3 Matrix{Float64}:
 0.0  0.0  0.0
 0.0  0.0  0.0
 ⋮
 0.0  0.0  0.0
 0.0  0.0  0.0
```

UnixMmap.jl provides OS-specific flags for several Unixes; see the
[Constants](@ref Constants-—-Linux) section for more details.

The package also exposes the [`UnixMmap.madvise!`](@ref), [`UnixMmap.msync!`](@ref), and
[`UnixMmap.mincore`](@ref) functions which correspond closely to the underlying system
calls.

## Library API Reference
```@contents
Pages = [
    "lib/public.md",
]
Depth = 1
```
