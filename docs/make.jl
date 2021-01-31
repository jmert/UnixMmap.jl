using Documenter, UnixMmap
include(joinpath(@__DIR__, "sys_override.jl"))

doctest = "--fix"  in ARGS ? :fix :
          "--test" in ARGS ? true : false

DocMeta.setdocmeta!(UnixMmap, :DocTestSetup, :(using UnixMmap); recursive=true)

makedocs(
    sitename = "UnixMmap.jl",
    authors  = "Justin Willmert",
    doctest  = doctest,
    doctestfilters = Regex[
        r"Ptr{0x[0-9a-f]+}",
        r"[0-9\.]+ seconds \(.*\)"
    ],
    format   = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical  = "https://jmert.github.io/UnixMmap.jl",
        assets     = String[],
        mathengine = Documenter.MathJax3(),
    ),
    pages = [
        "Home" => "index.md",
        "API Reference" => [
            "Public" => "lib/public.md",
        ]
    ],
    repo = "https://github.com/jmert/UnixMmap.jl/blob/{commit}{path}#L{line}",
)

deploydocs(
    repo = "github.com/jmert/UnixMmap.jl",
    push_preview = true,
)
