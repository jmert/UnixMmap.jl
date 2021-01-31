import UnixMmap
using Markdown
srcdir = dirname(pathof(UnixMmap))

# Same names as Sys.KERNEL
bsds = (:Apple, :DragonFly, :FreeBSD, :NetBSD, :OpenBSD)
for sys in (:Linux, bsds...)
    @eval module $(Symbol(sys, "Mmap"))
        module UnixMmap
            module Sys
                const KERNEL = $(Expr(:quote, sys))
                islinux() = $(sys === :Linux)
                isapple() = $(sys === :Apple)
                isbsd()   = $(sys in bsds)
                isdragonfly() = $(sys === :DragonFly)
                isfreebsd()   = $(sys === :FreeBSD)
                isnetbsd()    = $(sys === :NetBSD)
                isopenbsd()   = $(sys === :OpenBSD)
            end
            import Main.UnixMmap: @staticexpand
            include($(joinpath(srcdir, "consts.jl")))
        end
    end
end

function _flag_docs(T)
    buf = IOBuffer()
    for c in instances(T)
        println(buf, c)
    end
    return Markdown.parse("```julia\n" * String(take!(buf)) * "```\n")
end
