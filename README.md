# UnixMmap

| **Build Status**                                             |
|:------------------------------------------------------------:|
| [![][ci-img]][ci-url]                                        |

`UnixMmap` is an alternative to the Julia standard library's `Mmap`, with the purpose of
exposing the Unix memory-mapping interface.

### Installation and usage

This library is **not** registered in Julia's [General registry][General.jl],
so the package must be installed either by cloning it directly:

```
(@v1.6) pkg> add https://github.com/jmert/UnixMmap.jl
```

or by making use of my [personal registry][Registry.jl]:

```
(@v1.6) pkg> registry add https://github.com/jmert/Registry.jl
(@v1.6) pkg> add UnixMmap
```

After installing, just load like any other Julia package:

```
julia> using UnixMmap
```

[docs-stable-img]: https://img.shields.io/badge/docs-stable-blue.svg
[docs-stable-url]: https://jmert.github.io/UnixMmap.jl/stable
[docs-dev-img]: https://img.shields.io/badge/docs-dev-blue.svg
[docs-dev-url]: https://jmert.github.io/UnixMmap.jl/dev

[ci-img]: https://github.com/jmert/UnixMmap.jl/workflows/CI/badge.svg
[ci-url]: https://github.com/jmert/UnixMmap.jl/actions

[codecov-img]: https://codecov.io/gh/jmert/UnixMmap.jl/branch/master/graph/badge.svg
[codecov-url]: https://codecov.io/gh/jmert/UnixMmap.jl

[General.jl]: https://github.com/JuliaRegistries/General
[Registry.jl]: https://github.com/jmert/Registry.jl
