using MacroTools: flatten, isexpr, prewalk, postwalk

"""
    @staticexpand @a_macro begin
        # some code...
        @static if condition
            # conditional code
        end
        # more code...
    end

Pre-processes a macro expression, evaluating any `@static if condition` block and retaining
or dropping the inner expression based on the result. The inner expression must be valid
code given the surrounding context, as if the `@static` conditional statement did not
exist.
"""
macro staticexpand(expr::Expr)
    sentinel = gensym("sentinel")
    isexpr(expr, :macrocall) || error("Expected a macro to expand")
    # Evaluate the static statements
    expr′ = prewalk(expr) do ex
        # Search for @static macro
        isexpr(ex, :macrocall) || return ex
        ex = ex::Expr
        ex.args[1] === Symbol("@static") || return ex
        # Found it --- just let @static run and do its thing
        ret = Base.macroexpand(__module__, ex)
        # Replace a `nothing` result with a private sentinel so that we can accurately
        # filter it back out.
        return ret === nothing ? sentinel : ret
    end
    # Remove any instances of our sentinel result
    expr′ = postwalk(expr′) do ex
        isexpr(ex, :block) || return ex
        ex = ex::Expr
        filter!(x -> x !== sentinel, ex.args)
        return ex
    end
    # Then merge the true branches' blocks with the surrounding conditionals
    expr′ = postwalk(flatten, expr′)
    return esc(expr′)
end
