using BitFlags
import .Sys # explicitly imported to allow docs generation to override

@bitflag MmapProtection::Cuint begin
    PROT_NONE  = 0x00
    PROT_READ  = 0x01
    PROT_WRITE = 0x02
    PROT_EXEC  = 0x04
end

@bitflag SyncFlags::Cuint begin
    MS_ASYNC      = 0x1
    MS_INVALIDATE = 0x2
    MS_SYNC       = 0x4
end

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

# documentation requires the types to be defined first, so do after the fact
let _flag_docs
    function _flag_docs(T)
        buf = IOBuffer()
        for c in instances(T)
            println(buf, c)
        end
        return rstrip(String(take!(buf)))
    end

    @doc """
        @bitflag UnixMmap.MmapProtection

    Set of bit flags which control the memory protections applied to the memory mapped
    region. The flag should be either `PROT_NONE` or some bitwise-or combination of
    the remaining flags.

    The flags available on $(Sys.KERNEL) are:
    ```julia
    $(_flag_docs(MmapProtection))
    ```
    """ MmapProtection

    @doc """
        @bitflag UnixMmap.SyncFlags

    Set of bit flags which control the memory synchronization behavior.

    The flags available on $(Sys.KERNEL) are:
    ```julia
    $(_flag_docs(SyncFlags))
    ```
    """ SyncFlags


    @doc """
        @bitflag UnixMmap.MmapFlags

    Set of bit flags which control the handling of the memory mapped region. The flag
    should be a bitwise-or combination of flags.

    The flags available on $(Sys.KERNEL) are:
    ```julia
    $(_flag_docs(MmapFlags))
    ```
    """ MmapFlags

    @doc """
        @enum UnixMmap.AdviseFlags

    Set of flags which advise the kernel on handling of the memory mapped region.

    The flags available on $(Sys.KERNEL) are:
    ```julia
    $(_flag_docs(AdviseFlags))
    ```
    """ AdviseFlags
end
