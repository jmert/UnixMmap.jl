using UnixMmap
using UnixMmap: mmap, PROT_READ, PROT_WRITE, MAP_PRIVATE, MAP_SHARED
using Test


# Julia normally translates SIGSEGV from trying to write to read-only memory into a
# ReadOnlyMemoryError. Due to a change in glibc, though, the "handle signal and resume"
# process does not work on all versions of Julia for certain glibc versions.
# (See issue JuliaLang/julia#62683 and fix JuliaLang/julia#62684.)
# Skip tests if we can reasonably expect the SIGSEGV is not handled as desired.
function readonly_will_segfault()
    # x86-64 Linux only
    !Sys.islinux() && return false
    Sys.ARCH !== :x86_64 && return false
    # Julia versions prior to v1.11 are unaffected
    VERSION <= v"1.11" && return false
    # Fix is backported to v1.12.8 and exists in all (released) versions of v1.13
    VERSION >= v"1.12.8" && return false

    # Now try to get the glibc version
    try
        gnu_ver = unsafe_string(ccall(:gnu_get_libc_version, Cstring, ()))
        ver = match(r"^(\d+\.\d+)", gnu_ver)
        return ver !== nothing && VersionNumber(ver.captures[1]) >= v"2.44"
    catch
        # must not be a glibc version, so unaffected
        return false
    end
end


@testset "Mapping files by name" begin
    data = [zeros(Float64, 100); ones(Float64, 256)]
    byteoff = 100 * sizeof(Float64)

    mktemp() do path, io
        write(io, zeros(Float64, 100))
        write(io, ones(Float64, 256))
        close(io)

        # Open and read
        A = mmap(path, Array{Float64}, 356)
        @test A == data

        # Open and read with offset
        A = mmap(path, Array{Float64}, 256; offset = byteoff)
        @test all(isone, A)

        # File exists → opened by default as read-only
        if readonly_will_segfault()
            @test_skip @test_throws ReadOnlyMemoryError A[1] = 0.0
        else
            @test_throws ReadOnlyMemoryError A[1] = 0.0
        end

        # Re-open with read-write permissions
        A = mmap(path, Array{Float64}, 256; offset = byteoff, prot = PROT_READ | PROT_WRITE)
        @test all(isone, A)
        A[1] = 2.0
        @test A[1] == 2.0
        A[1] = 1.0

        # Unspecified length defaults to openening remainder of file
        A = mmap(path, Array{Float64}; offset = byteoff)
        @test length(A) == 256
        @test all(isone, A)
        # again without an offset
        A = mmap(path, Array{Float64})
        @test length(A) == length(data)
        @test A == data

        # Unspecified array type defaults to UInt8
        A = mmap(path)
        @test A == reinterpret(UInt8, data)

        A = nothing; GC.gc()
    end
end

@testset "Mapping files by IO handle" begin
    data = [zeros(Float64, 100); ones(Float64, 256)]
    byteoff = 100 * sizeof(Float64)

    mktemp() do path, io
        write(io, zeros(Float64, 100))
        write(io, ones(Float64, 256))
        close(io)

        io = open(path, "r")
        # Open and read
        A = mmap(io, Array{Float64}, 356)
        @test A == data

        # Open and read with offset
        A = mmap(io, Array{Float64}, 256; offset = byteoff)
        @test all(isone, A)

        # File exists → opened by default as read-only
        if readonly_will_segfault()
            @test_skip @test_throws ReadOnlyMemoryError A[1] = 0.0
        else
            @test_throws ReadOnlyMemoryError A[1] = 0.0
        end

        # File handle opened read-only, but requesting read-write
        @test_throws SystemError mmap(io, Array{Float64}, 256; prot = PROT_READ | PROT_WRITE)

        # Reopen as read-write
        close(io)
        io = open(path, "r+")
        A = mmap(path, Array{Float64}, 256; offset = byteoff, prot = PROT_READ | PROT_WRITE)
        @test all(isone, A)
        A[1] = 2.0
        @test A[1] == 2.0
        A[1] = 1.0

        # Unspecified length defaults to openening remainder of file
        A = mmap(io, Array{Float64}; offset = byteoff)
        @test length(A) == 256
        @test all(isone, A)
        # again without an offset
        A = mmap(io, Array{Float64})
        @test length(A) == length(data)
        @test A == data

        # Unspecified array type defaults to UInt8
        A = mmap(io)
        @test A == reinterpret(UInt8, data)

        close(io)
        A = nothing; GC.gc()
    end
end

@testset "Growing mapped files" begin
    mktemp() do path, io
        close(io)
        @test filesize(path) == 0
        # Note! Require explicit write perms since the file `path` now exists
        A = mmap(path, Array{Float32}, 500; prot = PROT_READ | PROT_WRITE)
        @test filesize(path) == 2000
        @test all(iszero, A)
    end
    mktemp() do path, io
        close(io)
        @test filesize(path) == 0
        A = mmap(path, Array{Float32}, 500; offset = 400, prot = PROT_READ | PROT_WRITE)
        @test filesize(path) == 2400
        @test all(iszero, A)
    end
    mktemp() do path, io
        @test filesize(io) == 0
        # Here, `io` will have already been opened with write perms, so defaults OK
        A = mmap(io, Array{Float32}, 500)
        @test filesize(io) == 2000
        @test all(iszero, A)
    end
    mktemp() do path, io
        @test filesize(io) == 0
        A = mmap(io, Array{Float32}, 500; offset = 400)
        @test filesize(io) == 2400
        @test all(iszero, A)
    end

    # If grow is *false*, the memory map cannot be accessed without throwing a
    # SIGBUS signal, but we can at least check that the file has not changed size.
    mktemp() do path, io
        @test filesize(io) == 0
        A = mmap(io, Array{Float32}, 500; offset = 400, grow = false)
        @test filesize(io) == 0
        A = nothing
    end

    GC.gc()
end

@testset "Shared and private file maps" begin
    data = collect(range(-1.0, stop=1.0, length=10))

    # Default is shared mapping
    mktemp() do path, io
        write(io, data)
        flush(io)
        seek(io, 0)

        A = mmap(io, Array{Float64})
        B = mmap(io, Array{Float64})

        A[1] = 0.0
        @test B[1] == 0.0
    end

    # Check that private mapping request works
    mktemp() do path, io
        write(io, data)
        flush(io)
        seek(io, 0)

        A = mmap(io, Array{Float64}; flags = MAP_PRIVATE)
        B = mmap(io, Array{Float64}; flags = MAP_PRIVATE)

        A[1] = 0.0
        @test B[1] == -1.0
    end
end

@testset "Inferring return types" begin
    # N.B. also tests that any <:Array{T} works as the array type argument
    data = repeat(1.0:16.0, 1, 3)
    mktemp() do path, io
        write(io, data)
        flush(io)
        seek(io, 0)
        @testset "IO handle - $AT" for AT in (Array, Vector, Matrix)
            # dims isa Tuple{Int}, so V isa Vector no matter AT
            V = @inferred mmap(io, AT{Float64}, (16*3,))
            @test V isa Vector
            @test V == vec(data)
            # dims isa Tuple{Int,Int}, so M isa Matrix no matter AT
            M = @inferred mmap(io, AT{Float64}, (16, 3))
            @test M isa Matrix
            @test M == data
        end
        close(io)
        @testset "File name - $AT" for AT in (Array, Vector, Matrix)
            # dims isa Tuple{Int}, so V isa Vector no matter AT
            V = @inferred mmap(path, AT{Float64}, (16*3,))
            @test V isa Vector
            @test V == vec(data)
            # dims isa Tuple{Int,Int}, so M isa Matrix no matter AT
            M = @inferred mmap(path, AT{Float64}, (16, 3))
            @test M isa Matrix
            @test M == data
        end
        @testset "Anonymous - $AT" for AT in (Array, Vector, Matrix)
            # dims isa Tuple{Int}, so V isa Vector no matter AT
            V = @inferred mmap(AT{Float64}, (16*3,))
            @test V isa Vector
            @test all(iszero, V)
            # dims isa Tuple{Int,Int}, so M isa Matrix no matter AT
            M = @inferred mmap(AT{Float64}, (16, 3))
            @test M isa Matrix
            @test all(iszero, M)
        end
        GC.gc()
    end
end

@testset "Anonymous memory maps" begin
    A = mmap(Array{Int16}, 500)
    @test size(A) == (500,)

    A = mmap(Array{Int16}, (50, 10))
    @test size(A) == (50, 10)
end

@testset "In-core" begin
    A = mmap(Array{Int}, 5000)
    ic = UnixMmap.mincore(A)
    # Just checking that the function works
    @test ic isa Vector{Bool}

    # On linux and if the array not immediately mapped by default, take the opportunity
    # to test for non-standard flag: MAP_POPULATE will force fully mapping into RAM
    if Sys.islinux() && any(!, ic)
        B = mmap(Array{Int}, 5000; flags = MAP_SHARED | UnixMmap.MAP_POPULATE)
        @test all(UnixMmap.mincore(B))
    end
end

@testset "Giving advice" begin
    # It's hard to test behavior of the advise flags --- just check for not erroring
    A = mmap(Array{Int}, 500)
    @test A == UnixMmap.madvise!(A, UnixMmap.MADV_WILLNEED)
end

@testset "Synchronizing" begin
    # It's hard to test behavior of the sync flags --- just check for not erroring
    mktemp() do path, io
        A = mmap(io, Array{Int}, 500)
        @test A == UnixMmap.msync!(A, UnixMmap.MS_SYNC | UnixMmap.MS_INVALIDATE)
        A[:] .= 1.0
        @test A == UnixMmap.msync!(A, UnixMmap.MS_ASYNC)
    end
end

@testset "Julia Memory-backed arrays" begin
    # See JuliaLang/julia#54128 and JuliaLang/julia#54210
    mktempdir() do tdir
        cd(tdir) do
            # generate and store some random data in a file
            open("rand.dat", "w") do io
                write(io, rand(UInt8, 1024))
            end

            # read the contents of the file twice
            # 1st: read as a plain array
            plain = open("rand.dat", "r") do io
                read(io)
            end
            # 2nd: read via a memory mapped array, wrapped in an IOBuffer.
            #      The IOBuffer is important in order to lose the original Array wrapper of
            #      the underlying Memory on Julia 1.11+
            mapbuf = open("rand.dat", "r") do io
                IOBuffer(mmap(io, Vector{UInt8}))
            end

            # Force a garbage collection
            GC.gc(true)
            # Then check that the plain array matches what can be retrieved from the IOBuffer
            # If the underlying memory map has been freed, this should result in a segfault.
            @test plain == take!(mapbuf)
        end
    end
end

@testset "Other tests" begin
    @testset "primitive types with non-power-of-two sizes" begin
        # Use >12 bytes so that padding goes to 16 bytes on both 32bit and 64bit arch
        primitive type IrregularBitsType 13 * 8 end
        @test sizeof(IrregularBitsType) == 13
        @test Base.aligned_sizeof(IrregularBitsType) == 16

        data = IrregularBitsType[
            Core.Intrinsics.zext_int(IrregularBitsType, 0xcafef00d),
            Core.Intrinsics.zext_int(IrregularBitsType, 0xfeedface),
        ]
        # Prior to Julia v1.5, write(fh, data) incorrectly ignores the padding in the array;
        # construct the equivalent padded array directly and write that instead.
        padded = UInt128[0xcafef00d, 0xfeedface]

        mktemp() do path, fh
            wb = write(fh, padded)
            flush(fh)
            seek(fh, 0)
            @test UnixMmap.filedim(fh, IrregularBitsType, 0) == (2,)

            A = mmap(path, Vector{IrregularBitsType}; prot = UnixMmap.PROT_READ)
            @test length(A) == 2
            @test A == data
        end
    end

    if isdefined(Test, :detect_closure_boxes)
        @test length(Test.detect_closure_boxes(UnixMmap)) == 0
    end
end
