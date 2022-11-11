import Base: INVALID_OS_HANDLE
import Mmap

const PAGESIZE = Mmap.PAGESIZE

# Helpers to infer default parameters given a file handle/fd
import Mmap: Anonymous, gethandle, grow!

fileposition(::Anonymous) = Int64(0)
fileposition(io::IO) = Int64(position(io))

function filedim(io::IO, T::Type, offset::Union{Integer,Nothing} = nothing)
    offset = offset === nothing ? position(io) : offset
    return (div(filesize(io) - offset, sizeof(T)),)
end
function filedim(file::AbstractString, T::Type, offset::Union{Integer,Nothing} = nothing)
    offset = offset === nothing ? 0 : offset
    return (div(filesize(file) - offset, sizeof(T)),)
end

function filemode(fd::RawFD)
    F_GETFL = Cint(3)
    O_ACCMODE = Cint(3)
    O_RDONLY = 0
    O_WRONLY = 1
    O_RDWR   = 2
    fmode = ccall(:fcntl, Cint, (RawFD, Cint, Cint...), fd, F_GETFL)
    Base.systemerror("fcntl F_GETFL", fmode == -1)
    fmode &= O_ACCMODE
    return fmode == O_RDWR ? PROT_READ|PROT_WRITE :
           fmode == O_WRONLY ? PROT_WRITE : PROT_READ
end
filemode(io::IO) = filemode(gethandle(io))
filemode(::Anonymous) = PROT_READ | PROT_WRITE

fileflags(::Anonymous) = MAP_SHARED | MAP_ANONYMOUS
fileflags(::IO) = MAP_SHARED

###

# Raw call to mmap syscall
function _sys_mmap(ptr::Ptr{Cvoid}, len::Int,
                                   prot::MmapProtection, flags::MmapFlags,
                                   fd::RawFD, offset::Int64)

    len < typemax(Int) - PAGESIZE || throw(
            ArgumentError("requested size must be < $(typemax(Int)-PAGESIZE), got $len"))
    offset >= 0 || throw(ArgumentError("requested offset must be ≥ 0, got $offset"))

    # N.B. mmap may be a C header macro to another name, so use Julia's wrapper (just as
    #      Mmap.mmap does)
    ret = ccall(:jl_mmap, Ptr{Cvoid}, (Ptr{Cvoid}, Csize_t, Cint, Cint, RawFD, Int64),
                ptr, len, prot, flags, fd, offset)
    Base.systemerror("mmap", reinterpret(Int, ret) == -1)
    return ret
end

function _sys_unmap!(ptr::Ptr{Cvoid}, len::Int)
    ret = ccall(:munmap, Cint, (Ptr{Cvoid}, Csize_t), ptr, len)
    Base.systemerror("munmap", ret != 0)
    return
end

# Low-level form which mirrors a raw mmap, but constructs a Julia array of given
# dimension(s) at a specific offset within a file (includes accounting for page alignment
# requirement).
function _mmap(::Type{Array{T}}, dims::NTuple{N,Integer},
              prot::MmapProtection, flags::MmapFlags,
              fd::RawFD, offset::Integer) where {T, N}
    isbitstype(T) || throw(ArgumentError("unable to mmap type $T; must satisfy `isbitstype(T) == true`"))

    len = prod(dims) * sizeof(T)
    iszero(len) && return Array{T}(undef, ntuple(x->0, Val(N)))
    len > 0 || throw(ArgumentError("requested size must be ≥ 0, got $len"))
    len = Int(len)

    page_pad = rem(Int64(offset), PAGESIZE)
    mmaplen::Int = len + page_pad

    ptr = _sys_mmap(C_NULL, mmaplen, prot, flags, fd, Int64(offset) - page_pad)
    aptr = convert(Ptr{T}, ptr + page_pad)
    array = unsafe_wrap(Array{T,N}, aptr, dims)
    finalizer(_ -> _sys_unmap!(ptr, mmaplen), array)
    return array
end
function _mmap(::Type{Array{T}}, len::Int, prot::MmapProtection, flags::MmapFlags,
              fd::RawFD, offset::Int) where {T}
    return _mmap(Array{T}, (Int(len),), prot, flags, fd, offset)
end

# Higher-level interface which takes an IO object and sets default flag values.
function mmap(io::IO, ::Type{<:Array{T}}, dims::NTuple{N,Integer};
              offset::Union{Integer,Nothing} = nothing,
              prot::Union{MmapProtection,Nothing} = nothing,
              flags::Union{MmapFlags,Nothing} = nothing,
              grow::Bool = true
             ) where {T, N}
    isbitstype(T) || throw(ArgumentError("unable to mmap type $T; must satisfy `isbitstype(T) == true`"))
    isopen(io) || throw(ArgumentError("$io must be open to mmap"))

    len = prod(dims) * sizeof(T)
    iszero(len) && return Array{T}(undef, ntuple(x->0, Val(N)))
    len > 0 || throw(ArgumentError("requested size must be ≥ 0, got $len"))
    len = Int(len)

    offset = offset === nothing ? fileposition(io) : Int(offset)
    prot   = prot === nothing ? filemode(io) : prot
    flags  = flags === nothing ? fileflags(io) : flags

    grow && iswritable(io) && grow!(io, offset, len)

    return _mmap(Array{T}, dims, prot, flags, gethandle(io), offset)
end
function mmap(io::IO, ::Type{<:Array{T}}, len::Integer;
              offset::Union{Integer,Nothing} = nothing,
              prot::Union{MmapProtection,Nothing} = nothing,
              flags::Union{MmapFlags,Nothing} = nothing,
              grow::Bool = true
             ) where {T}
    return mmap(io, Array{T}, (len,);
                offset = offset, prot = prot, flags = flags, grow = grow)
end
function mmap(io::IO, ::Type{<:Array{T}} = Array{UInt8};
              offset::Union{Integer,Nothing} = nothing,
              prot::Union{MmapProtection,Nothing} = nothing,
              flags::Union{MmapFlags,Nothing} = nothing,
              grow::Bool = true
             ) where {T}
    return mmap(io, Array{T}, filedim(io, T, offset);
                offset = offset, prot = prot, flags = flags, grow = grow)
end

# Mapping of files
function mmap(file::AbstractString, ::Type{<:Array{T}}, dims::NTuple{N,Integer};
              offset::Union{Integer,Nothing} = nothing,
              prot::Union{MmapProtection,Nothing} = nothing,
              flags::Union{MmapFlags,Nothing} = nothing,
              grow::Bool = true
             ) where {T, N}
    if prot === nothing
        # Default to read-only if file exists, otherwise read/write/create
        openmode = isfile(file) ? "r" : "w+"
    else
        # If protection requested write...
        if (prot & PROT_WRITE) == PROT_WRITE
            # read/write if file exists, otherwise read/write/create
            openmode = isfile(file) ? "r+" : "w+"
        else
            # otherwise read-only
            openmode = "r"
        end
    end

    return open(file, openmode) do io
        mmap(io, Array{T}, dims;
             offset = offset, prot = prot, flags = flags, grow = grow)
    end
end
function mmap(file::AbstractString, ::Type{<:Array{T}}, len::Integer;
              offset::Union{Integer,Nothing} = nothing,
              prot::Union{MmapProtection,Nothing} = nothing,
              flags::Union{MmapFlags,Nothing} = nothing,
              grow::Bool = true
             ) where {T}
    return mmap(file, Array{T}, (len,);
                offset = offset, prot = prot, flags = flags, grow = grow)
end
# Default mapping of the [rest of] given file
function mmap(file::AbstractString, ::Type{<:Array{T}} = Array{UInt8};
              offset::Union{Integer,Nothing} = nothing,
              prot::Union{MmapProtection,Nothing} = nothing,
              flags::Union{MmapFlags,Nothing} = nothing,
              grow::Bool = true
             ) where {T}
    return mmap(file, Array{T}, filedim(file, T, offset);
                offset = offset, prot = prot, flags = flags, grow = grow)
end

# form to construct anonymous memory maps
function mmap(::Type{<:Array{T}}, dims::NTuple{N,Integer};
              prot::Union{MmapProtection,Nothing} = nothing,
              flags::Union{MmapFlags,Nothing} = nothing
             ) where {T, N}
    prot = prot === nothing ? PROT_READ | PROT_WRITE : prot
    flags = MAP_ANONYMOUS | (flags === nothing ? MAP_SHARED : flags)
    return mmap(Anonymous(), Array{T}, dims;
                offset = Int64(0), prot = prot, flags = flags, grow = false)
end
function mmap(::Type{<:Array{T}}, len::Integer;
              prot::Union{MmapProtection,Nothing} = nothing,
              flags::Union{MmapFlags,Nothing} = nothing
             ) where {T}
    return mmap(Array{T}, (len,);
                prot = prot, flags = flags)
end

"""
    mmap(file::Union{IO,AbstractString}[, ::Type{Array{T}}, dims]; kws...)
    mmap(::Type{Array{T}}, dims; kws...)

Memory maps an `Array` from a file `file` of size `dims` (either a scalar `Integer` or
a tuple of dimension lengths), or creates an anonymous mapping not backed by a file if
no file is given.

If not specified, the array type defaults to `Array{UInt8}`, and `dim` defaults to a
vector with length equal to the number of elements remaining in the file (accounting for
a non-zero position in the file stream `io`).

# Extended help

This function provides a relatively simple wrapper around the underlying `mmap` system
call. In particular, it is the user's responsibility to ensure the combination(s) of
stream state (e.g. read/write or read-only, file length), protection flags, and memory map
flags must form a valid `mmap` request, as they are not validated here.

See your system `mmap` man page for details on the behaviors of each flag.

## Keywords

The following keywords are available:

* `flags::MmapFlags` — any of the `MAP_*` system-specific constants. For files, this
  defaults to `MAP_SHARED`, and anonymous mappings default to `MAP_SHARED | MAP_ANONYMOUS`.

* `prot::MmapProtection` — any of the `PROT_*` flags. The default is `PROT_READ |
  PROT_WRITE` for all anonymous maps and memory maps of non-existent files (in which case
  the file will be created). If the file already exists, it is opened read-only and the
  default is `PROT_READ` only.

* `offset::Integer` — offset _in bytes_ from the beginning of the file, defaulting to the current
  stream position. This keyword is not valid for anonymous maps.

* `grow::Bool` — Whether to grow a file to accomodate the memory map, if the file is
  writable. Defaults to `true`. This keyword is not valid for anonymous maps.
"""
function mmap end

function pagepointer(array::Array)
    ptr = pointer(array)
    off = convert(UInt, ptr) % PAGESIZE
    ptr -= off
    len = off + sizeof(array)
    return (ptr, off, len)
end

"""
    mincore(array::Array)

Returns a boolean array (of length `fld1(sizeof(m), PAGESIZE)`) indicating whether the
pages of the memory-mapped `array` are resident in RAM. Pages corresponding to `false`
values will cause a fault if referenced.

!!! note
    Memory maps are always page-aligned, so an offset which is not a multiple of `PAGESIZE`
    will result in a return array where the first element does _not_ correspond to the
    first `PAGESIZE ÷ sizeof(eltype(array))` elements of `array` — i.e. the first page
    may cover memory addresses before the first element of `array`.
"""
function mincore(array::Array)
    ptr, _, len = pagepointer(array)
    sz = fld1(len, PAGESIZE)
    mask = Vector{Bool}(undef, sz)
    GC.@preserve array begin
        Base.systemerror("mincore",
                ccall(:mincore, Cint, (Ptr{Cvoid}, Csize_t, Ptr{UInt8}),
                      ptr, len, mask) != 0)
    end
    return mask
end

"""
    madvise!(array, flag::AdviseFlags = MADV_NORMAL)

Advises the kernel on the intended usage of the memory-mapped `array`, with the intent
`flag` being one of the available `MADV_*` constants.
"""
function madvise!(array::Array, flag::AdviseFlags = MADV_NORMAL)
    GC.@preserve array begin
        ptr, off, len = pagepointer(array)
        Base.systemerror("madvise",
                ccall(:madvise, Cint, (Ptr{Cvoid}, Csize_t, Cint),
                      ptr, len, flag) != 0)
    end
    return array
end

"""
    msync!(array, flag::SyncFlags = MS_SYNC)

Synchronizes the memory-mapped `array` and its backing file on disk.
"""
function msync!(array::Array, flag::SyncFlags = MS_SYNC)
    GC.@preserve array begin
        ptr, off, len = pagepointer(array)
        Base.systemerror("msync",
                ccall(:msync, Cint, (Ptr{Cvoid}, Csize_t, Cint),
                      ptr, len, flag) != 0)
    end
    return array
end
