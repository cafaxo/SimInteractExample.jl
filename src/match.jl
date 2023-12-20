macro match(enum_ex, block_ex)
    if enum_ex.head !== :(::)
        throw(ArgumentError("@match requires an explicit type annotation."))
    end

    enum_type = getfield(__module__, enum_ex.args[2])

    pairs = block_ex.args
    filter!(x -> !(x isa LineNumberNode), pairs)

    for pair in pairs
        if pair.args[1] !== :(=>)
            throw(ArgumentError("@match arms must be specified using the => syntax"))
        end
    end

    used_symbols = [pair.args[2] for pair in pairs]
    enum_symbols = collect(values(Base.Enums.namemap(enum_type)))

    if !(enum_symbols ⊆ used_symbols)
        throw(ArgumentError("Patterns must be exhaustive."))
    end

    if !(used_symbols ⊆ enum_symbols)
        throw(ArgumentError("Pattern must be an enum name."))
    end

    if length(used_symbols) > length(enum_symbols)
        throw(ArgumentError("Duplicate pattern detected."))
    end

    enum_var = gensym()

    result = Expr(:if, Expr(:call, :(===), enum_var, pairs[1].args[2]), pairs[1].args[3])
    ex = result

    for i in 2:length(pairs)
        pair = pairs[i]
        inner_ex = Expr(:elseif, Expr(:call, :(===), enum_var, pair.args[2]), pair.args[3])
        push!(ex.args, inner_ex)
        ex = inner_ex
    end

    return esc(Expr(:let, Expr(:(=), enum_var, enum_ex.args[1]), result))
end
