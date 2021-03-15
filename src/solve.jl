import Base: size, deepcopy

abstract type KenkenConstraint end

struct RowConstraint <: KenkenConstraint
    idx::Int
end

struct ColumnConstraint <: KenkenConstraint
    idx::Int
end

Tp, Tm, Ts, Td = typeof(+), typeof(*), typeof(-), typeof(÷)

struct CageConstraint{T} <: KenkenConstraint where T <: Union{Tp, Tm, Ts, Td}
    total::Int
    coords::Array{Tuple{Int, Int}}
    op::T
end

struct CellConstraint <: KenkenConstraint
    value::Int
    coord::Tuple{Int, Int}
end

complete(constr::RowConstraint, board::Array{Int, 2}) = all(board[constr.idx, :] .> 0)
complete(constr::ColumnConstraint, board::Array{Int, 2}) = all(board[:, constr.idx] .> 0)
complete(constr::CageConstraint, board::Array{Int, 2}) = all([board[i, j] > 0 for (i, j) in constr.coords])

struct KenkenCSP
    variables::Array{Int, 2}
    constraints::Array{KenkenConstraint}
    domains::Array{BitArray, 2}
end

function set_domain!(i, j, value, domains)
    domains[i, j] .= 0
    domains[i, j][value] = 1
end

function set_cell!(i, j, value, variables)
    variables[i, j] = value
end

function KenkenCSP(constraints, k::Int)
    variables = Array{Int, 2}(undef, k, k)
    domains = Array{BitArray, 2}(undef, k, k)
    for i = 1:k
        for j = 1:k
            domains[i, j] = BitArray{1}(undef, k) .+ 1
            variables[i, j] = -1
        end
    end
    row_constraints = [RowConstraint(i) for i = 1:k]
    col_constraints = [ColumnConstraint(i) for i = 1:k]
    clean_constraints = []
    for constr ∈ constraints
        if constr isa CellConstraint
            i, j = constr.coord
            v = constr.value
            set_cell!(i, j, v, variables)
            set_domain!(i, j, v, domains)
        else
            push!(clean_constraints, constr)
        end
    end
    return KenkenCSP(variables, vcat(clean_constraints, row_constraints, col_constraints), domains)
end

function fill_in!(kk::KenkenCSP)
    k = size(kk)
    for i = 1:k
        for j = 1:k
            dom = kk.domains[i, j]
            if sum(dom) == 1 && kk.variables[i, j] < 0
                v = argmax(dom)
                kk.variables[i, j] = v
            end
        end
    end
end

size(kk::KenkenCSP) = size(kk.domains, 1)
deepcopy(kk::KenkenCSP) = KenkenCSP(deepcopy(kk.variables), deepcopy(kk.constraints), deepcopy(kk.domains))

function eliminate!(constr::CageConstraint{Tp}, kk::KenkenCSP)
    acc = 0
    undetermined = []
    for (i, j) ∈ constr.coords
        v = kk.variables[i, j]
        if v > 0
            acc += v
        else
            push!(undetermined, (i, j))
        end
    end
    if length(undetermined) == 0
        return false
    end
    k = size(kk)
    comp = length(undetermined) == 1 ? (≠) : (≥)
    for (i, j) ∈ undetermined
        for cand ∈ 1:k
            if comp(cand, constr.total - acc)
                kk.domains[i, j][cand] = 0
            end
        end
    end
end

function eliminate!(constr::CageConstraint{Tm}, kk::KenkenCSP)
    acc = 1
    undetermined = []
    for (i, j) ∈ constr.coords
        v = kk.variables[i, j]
        if v > 0
            acc *= v
        else
            push!(undetermined, (i, j))
        end
    end
    k = size(kk)
    for (i, j) ∈ undetermined
        for cand ∈ 1:k
            if (constr.total ÷ acc) % cand != 0
                kk.domains[i, j][cand] = 0
            end
        end
    end
end

function eliminate!(constr::CageConstraint{Ts}, kk::KenkenCSP)
    (i1, j1), (i2, j2) = constr.coords
    n1, n2 = kk.variables[i1, j1], kk.variables[i2, j2]
    if (n1 > 0 && n2 > 0) || (n1 < 0 && n2 < 0)
        return
    end
    k = size(kk)
    i, j = n1 > 0 ? (i2, j2) : (i1, j1)
    n = n1 > 0 ? n1 : n2
    kk.domains[i, j] .= 0
    if n + constr.total ≤ k
        kk.domains[i, j][n + constr.total] = 1
    end
    if n - constr.total ≥ 1
        kk.domains[i, j][n - constr.total] = 1
    end
end

function eliminate!(constr::CageConstraint{Td}, kk::KenkenCSP)
    (i1, j1), (i2, j2) = constr.coords
    n1, n2 = kk.variables[i1, j1], kk.variables[i2, j2]
    if (n1 > 0 && n2 > 0) || (n1 < 0 && n2 < 0)
        return
    end
    k = size(kk)
    i, j = n1 > 0 ? (i2, j2) : (i1, j1)
    n = n1 > 0 ? n1 : n2
    kk.domains[i, j] .= 0
    if n * constr.total ≤ k
        kk.domains[i, j][n * constr.total] = 1
    end
    if n ÷ constr.total ≥ 1
        kk.domains[i, j][n ÷ constr.total] = 1
    end
end

function _eliminate_rc!(doms::Array{BitArray}, vars::Array{Int})
    k = length(doms)
    for (i, v) ∈ enumerate(vars)
        if v > 0
            for j = 1:k
                if j ≠ i
                    doms[j][v] = 0
                end
            end
        end
    end
end

function eliminate!(constr::RowConstraint, kk::KenkenCSP)
    return _eliminate_rc!(kk.domains[constr.idx, :], kk.variables[constr.idx, :])
end

function eliminate!(constr::ColumnConstraint, kk::KenkenCSP)
    return _eliminate_rc!(kk.domains[:, constr.idx], kk.variables[:, constr.idx])
end

function eliminate!(kk::KenkenCSP)
    for constr ∈ kk.constraints
        eliminate!(constr, kk)
        fill_in!(kk)
    end
end

function consistent(kk::KenkenCSP)
    return all(dom -> sum(dom) > 0, kk.domains)
end

function complete(kk::KenkenCSP)
    return all(constr -> complete(constr, kk.variables), kk.constraints)
end

function find_next_unset(kk::KenkenCSP)
    k = size(kk)
    min_cands = k
    imin, jmin = nothing, nothing
    for i = 1:k
        for j = 1:k
            s = sum(kk.domains[i, j])
            if kk.variables[i, j] < 0 && s < min_cands
                min_cands = s
                imin, jmin = i, j
                if s == 2
                    return imin, jmin
                end
            end
        end
    end
    return imin, jmin
end

function backtrack(kk::KenkenCSP)
    eliminate!(kk)
    cons = consistent(kk)
    if !cons
        return nothing
    end
    if all(kk.variables .> 0)
        if cons
            return kk
        else
            return nothing
        end
    end
    k = size(kk)
    i, j = find_next_unset(kk)
    dom = kk.domains[i, j]
    cands = 1:k
    cands = cands[dom[cands] .== 1]
    for l = cands
        kkcpy = deepcopy(kk)
        set_domain!(i, j, l, kkcpy.domains)
        set_cell!(i, j, l, kkcpy.variables)
        res = backtrack(kkcpy)
        if !isnothing(res)
            return res
        end
    end
    return nothing
end
