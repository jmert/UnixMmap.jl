using BitFlags

import Base: INVALID_OS_HANDLE
import Mmap
const PAGESIZE = Mmap.PAGESIZE

### Flags

@bitflag MmapProtection::Cuint begin
    PROT_NONE  = 0x00
    PROT_READ  = 0x01
    PROT_WRITE = 0x02
    PROT_EXEC  = 0x04
end
Base.cconvert(::Type{T}, pf::MmapProtection) where {T <: Integer} = T(pf)

@staticexpand @bitflag MmapFlags::Cuint begin
    MAP_FILE      = 0x00
    MAP_SHARED    = 0x01
    MAP_PRIVATE   = 0x02
    MAP_FIXED     = 0x0010
    MAP_ANONYMOUS = @static Sys.isbsd() ? 0x1000 : 0x0020
    @static if Sys.islinux()
        MAP_32BIT      =   0x0040
        MAP_GROWSDOWN  =   0x0100
        MAP_DENYWRITE  =   0x0800
        MAP_EXECUTABLE =   0x1000
        MAP_LOCKED     =   0x2000
        MAP_NORESERVE  =   0x4000
        MAP_POPULATE   =   0x8000
        MAP_NONBLOCK   = 0x1_0000
        MAP_STACK      = 0x2_0000
        MAP_HUGETLB    = 0x4_0000
        MAP_SYNC       = 0x8_0000
        MAP_FIXED_NOREPLACE = 0x10_0000
    end
    @static if Sys.isapple() || (VERSION >= v"1.1" && (Sys.isnetbsd() || Sys.isdragonfly()))
        MAP_RENAME       = 0x0020
        MAP_NORESERVE    = 0x0040
        MAP_INHERIT      = 0x0080
        MAP_NOEXTEND     = 0x0100
        MAP_HASSEMAPHORE = 0x0200
    end
    @static if VERSION >= v"1.1" && Sys.isfreebsd()
        MAP_STACK   =   0x0400
        MAP_NOSYNC  =   0x0800
        MAP_GUARD   =   0x2000
        MAP_EXCL    =   0x4000
        MAP_NOCORE  = 0x4_0000
        MAP_32BIT   = 0x8_0000
    elseif VERSION >= v"1.1" && Sys.isdragonfly()
        MAP_STACK      =   0x0400
        MAP_NOSYNC     =   0x0800
        MAP_VPAGETABLE =   0x2000
        MAP_TRYFIXED   = 0x1_0000
        MAP_NOCORE     = 0x2_0000
        MAP_SIZEALIGN  = 0x4_0000
    elseif VERSION >= v"1.1" && Sys.isopenbsd()
        MAP_STACK   = 0x4000
        MAP_CONCEAL = 0x8000
    elseif VERSION >= v"1.1" && Sys.isnetbsd()
        MAP_REMAPDUP = 0x0004
        MAP_TRYFIXED = 0x0400
        MAP_WIRED    = 0x0800
        MAP_STACK    = 0x2000
    end
end
Base.cconvert(::Type{T}, mf::MmapFlags) where {T <: Integer} = T(mf)

# Provide this weird mode?
#@static if Sys.islinux()
#const MAP_SHARED_VALIDATE = MmapFlags(0x03)
#end

@staticexpand @enum AdviseFlags::Cint begin
    MADV_NORMAL = 0
    MADV_RANDOM = 1
    MADV_SEQUENTIAL = 2
    MADV_WILLNEED = 3
    MADV_DONTNEED = 4
    @static if Sys.islinux()
        MADV_FREE = 8
        MADV_REMOVE = 9
        MADV_DONTFORK = 10
        MADV_DOFORK = 11
        MADV_MERGEABLE = 12
        MADV_UNMERGEABLE = 13
        MADV_HUGEPAGE = 14
        MADV_NOHUGEPAGE = 15
        MADV_DONTDUMP = 16
        MADV_DODUMP = 17
        MADV_WIPEONFORK = 18
        MADV_KEEPONFORK = 19
        MADV_COLD = 20
        MADV_PAGEOUT = 21
        MADV_HWPOISON = 100
        MADV_SOFT_OFFLINE = 101
    elseif Sys.isapple()
        MADV_FREE = 5
    elseif VERSION >= v"1.1" && (Sys.isfreebsd() || Sys.isdragonfly())
        MADV_FREE = 5
        MADV_NOSYNC = 6
        MADV_AUTOSYNC = 7
        MADV_NOCORE = 8
        MADV_CORE = 9
        @static if Sys.isfreebsd()
            MADV_PROTECT = 10
        else
            MADV_INVAL = 10
            MADV_SETMAP = 11
        end
    elseif VERSION >= v"1.1" && (Sys.isopenbsd() || Sys.isnetbsd())
        MADV_SPACEAVAIL = 5
        MADV_FREE = 6
    end
end
Base.cconvert(::Type{T}, af::AdviseFlags) where {T <: Integer} = T(af)

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
function _mmap(ptr::Ptr{Cvoid}, len::Int,
                                   prot::MmapProtection, flags::MmapFlags,
                                   fd::RawFD, offset::Int64)

    len < typemax(Int) - PAGESIZE || throw(
            ArgumentError("requested size must be < $(typemax(Int)-PAGESIZE), got $len"))
    offset >= 0 || throw(ArgumentError("requested offset must be ≥ 0, got $offset"))

    ret = ccall(:jl_mmap, Ptr{Cvoid}, (Ptr{Cvoid}, Csize_t, Cint, Cint, RawFD, Int64),
                ptr, len, prot, flags, fd, offset)
    Base.systemerror("mmap", reinterpret(Int, ret) == -1)
    return ret
end

function _unmap!(ptr::Ptr{Cvoid}, len::Int)
    ret = ccall(:munmap, Cint, (Ptr{Cvoid}, Csize_t), ptr, len)
    Base.systemerror("munmap", ret != 0)
    return
end

# Low-level form which mirrors a raw mmap, but constructs a Julia array of given
# dimension(s) at a specific offset within a file (includes accounting for page alignment
# requirement).
function mmap(::Type{Array{T}}, dims::NTuple{N,Integer},
              prot::MmapProtection, flags::MmapFlags,
              fd::RawFD, offset::Integer) where {T, N}
    isbitstype(T) || throw(ArgumentError("unable to mmap type $T; must satisfy `isbitstype(T) == true`"))

    len = prod(dims) * sizeof(T)
    iszero(len) && return Array{T}(undef, ntuple(x->0, Val(N)))
    len > 0 || throw(ArgumentError("requested size must be ≥ 0, got $len"))
    len = Int(len)

    page_pad = rem(Int64(offset), PAGESIZE)
    mmaplen::Int = len + page_pad

    ptr = _mmap(C_NULL, mmaplen, prot, flags, fd, Int64(offset) - page_pad)
    aptr = convert(Ptr{T}, ptr + page_pad)
    array = unsafe_wrap(Array{T,N}, aptr, dims)
    finalizer(_ -> _unmap!(ptr, mmaplen), array)
    return array
end
function mmap(::Type{Array{T}}, len::Int, prot::MmapProtection, flags::MmapFlags,
              fd::RawFD, offset::Int) where {T}
    return mmap(Array{T}, (Int(len),), prot, flags, fd, offset)
end

# Higher-level interface which takes an IO object and sets default flag values.
function mmap(io::IO, ::Type{Array{T}}, dims::NTuple{N,Integer};
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

    return mmap(Array{T}, dims, prot, flags, gethandle(io), offset)
end
function mmap(io::IO, ::Type{Array{T}}, len::Integer;
              offset::Union{Integer,Nothing} = nothing,
              prot::Union{MmapProtection,Nothing} = nothing,
              flags::Union{MmapFlags,Nothing} = nothing,
              grow::Bool = true
             ) where {T}
    return mmap(io, Array{T}, (len,);
                offset = offset, prot = prot, flags = flags, grow = grow)
end
function mmap(io::IO, ::Type{Array{T}} = Array{UInt8};
              offset::Union{Integer,Nothing} = nothing,
              prot::Union{MmapProtection,Nothing} = nothing,
              flags::Union{MmapFlags,Nothing} = nothing,
              grow::Bool = true
             ) where {T}
    return mmap(io, Array{T}, filedim(io, T, offset);
                offset = offset, prot = prot, flags = flags, grow = grow)
end

# Mapping of files
function mmap(file::AbstractString, ::Type{Array{T}}, dims::NTuple{N,Integer};
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
function mmap(file::AbstractString, ::Type{Array{T}}, len::Integer;
              offset::Union{Integer,Nothing} = nothing,
              prot::Union{MmapProtection,Nothing} = nothing,
              flags::Union{MmapFlags,Nothing} = nothing,
              grow::Bool = true
             ) where {T}
    return mmap(file, Array{T}, (len,);
                offset = offset, prot = prot, flags = flags, grow = grow)
end
# Default mapping of the [rest of] given file
function mmap(file::AbstractString, ::Type{Array{T}} = Array{UInt8};
              offset::Union{Integer,Nothing} = nothing,
              prot::Union{MmapProtection,Nothing} = nothing,
              flags::Union{MmapFlags,Nothing} = nothing,
              grow::Bool = true
             ) where {T}
    return mmap(file, Array{T}, filedim(file, T, offset);
                offset = offset, prot = prot, flags = flags, grow = grow)
end

# form to construct anonymous memory maps
function mmap(::Type{Array{T}}, dims::NTuple{N,Integer};
              prot::Union{MmapProtection,Nothing} = nothing,
              flags::Union{MmapFlags,Nothing} = nothing
             ) where {T, N}
    prot = prot === nothing ? PROT_READ | PROT_WRITE : prot
    flags = MAP_ANONYMOUS | (flags === nothing ? MAP_SHARED : flags)
    return mmap(Anonymous(), Array{T}, dims;
                offset = Int64(0), prot = prot, flags = flags, grow = false)
end
function mmap(::Type{Array{T}}, len::Integer;
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
