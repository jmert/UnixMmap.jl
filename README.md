# UnixMmap

| **Documentation**                                                         | **Build Status**      | **DOI**                 |
|:-------------------------------------------------------------------------:|:---------------------:|:-----------------------:|
| [![][docs-stable-img]][docs-stable-url] [![][docs-dev-img]][docs-dev-url] | [![][ci-img]][ci-url] | [![][doi-img]][doi-url] |

`UnixMmap` is an alternative to the Julia standard library's `Mmap`, with the purpose of
exposing the Unix memory-mapping interface.

### Installation and usage

Installation and loading is as easy as:
```julia
pkg> add UnixMmap

julia> using UnixMmap
```

A file can be memory mapped (read-only by default) by giving the filename and the `Array`
type (optionally with dimensions to give a shape):
```julia
julia> UnixMmap.mmap("arbitrary.dat", Vector{Float64})
192-element Vector{Float64}:
 0.0
 0.0
 ⋮
 0.0
 0.0

julia> UnixMmap.mmap("arbitrary.dat", Matrix{Float64}, (64, 3))
64×3 Matrix{Float64}:
 0.0  0.0  0.0
 0.0  0.0  0.0
 ⋮
 0.0  0.0  0.0
 0.0  0.0  0.0
```
while an anonymous memory map can be created by instead specifying the `Array` type and
dimensions:
```julia
julia> UnixMmap.mmap(Matrix{Float64}, (128, 3))
128×3 Matrix{Float64}:
 0.0  0.0  0.0
 0.0  0.0  0.0
 ⋮
 0.0  0.0  0.0
 0.0  0.0  0.0
```

[docs-stable-img]: https://img.shields.io/badge/docs-stable-blue.svg
[docs-stable-url]: https://jmert.github.io/UnixMmap.jl/stable
[docs-dev-img]: https://img.shields.io/badge/docs-dev-blue.svg
[docs-dev-url]: https://jmert.github.io/UnixMmap.jl/dev

[ci-img]: https://github.com/jmert/UnixMmap.jl/workflows/CI/badge.svg
[ci-url]: https://github.com/jmert/UnixMmap.jl/actions

[doi-img]: https://zenodo.org/badge/295815969.svg
[doi-url]: https://zenodo.org/badge/latestdoi/295815969

[codecov-img]: https://codecov.io/gh/jmert/UnixMmap.jl/branch/master/graph/badge.svg
[codecov-url]: https://codecov.io/gh/jmert/UnixMmap.jl

[General.jl]: https://github.com/JuliaRegistries/General
[Registry.jl]: https://github.com/jmert/Registry.jl
