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

"""
Creates a Kenken board given constraints. It inserts values for any `CellConstraints`
and discards them. It also creates row an column constraints, so those don't need
to be part of the input. As per the traditional formulation of constraint
satisfaction problems, each instance contains `domains` (valid remaining values for
each square), `variables` (values that have been completely determined), and
`constraints`.
"""
function KenkenCSP(constraints, k::Int)
    variables = Array{Int, 2}(undef, k, k)
    domains = Array{BitArray, 2}(undef, k, k)
    for i = 1:k
        for j = 1:k
            domains[i, j] = BitArray{1}(undef, k) .+ 1
            variables[i, j] = -1
        end
    end
    clean_constraints = []
    for constr ∈ constraints
        # if it's a cell constraint, implement and discard. otherwise, keep
        if constr isa CellConstraint
            i, j = constr.coord
            v = constr.value
            set_cell!(i, j, v, variables)
            set_domain!(i, j, v, domains)
        else
            push!(clean_constraints, constr)
        end
    end
    row_constraints = [RowConstraint(i) for i = 1:k]
    col_constraints = [ColumnConstraint(i) for i = 1:k]
    return KenkenCSP(variables, vcat(clean_constraints, row_constraints, col_constraints), domains)
end

"""
Fills in values that have been completely determined.
"""
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

inverse(_::Tp) = -
inverse(_::Tm) = ÷

id(_::Tp) = 0
id(_::Tm) = 1

function _constraint_value_and_undetermined(constr::CageConstraint{T}, variables::Array{Int, 2}) where T <: Union{Tp, Tm}
    acc = id(constr.op)
    undetermined = []
    for (i, j) ∈ constr.coords
        v = variables[i, j]
        if v > 0
            acc = constr.op(acc, v)
        else
            push!(undetermined, (i, j))
        end
    end
    return acc, undetermined
end

"""
Eliminates candidate values for an addition cage constraint.
"""
function eliminate!(constr::CageConstraint{Tp}, kk::KenkenCSP)
    acc, undetermined = _constraint_value_and_undetermined(constr, kk.variables)
    if length(undetermined) == 0
        return
    end
    k = size(kk)
    # if there is one cell left, anything not equal to the total - acc is invalid.
    # if there more than one undetermined, any single cell ≥ to the total - acc
    # is invalid
    comp = length(undetermined) == 1 ? (≠) : (≥)
    for (i, j) ∈ undetermined
        for cand ∈ 1:k
            if comp(cand, constr.total - acc)
                kk.domains[i, j][cand] = 0
            end
        end
    end
end

"""
Eliminates candidate values for a multiplication cage constraint.
"""
function eliminate!(constr::CageConstraint{Tm}, kk::KenkenCSP)
    acc, undetermined = _constraint_value_and_undetermined(constr, kk.variables)
    if length(undetermined) == 0
        return
    end
    k = size(kk)
    for (i, j) ∈ undetermined
        for cand ∈ 1:k
            # to remain valid, candidates must divide the remaining amount
            if (constr.total ÷ acc) % cand != 0
                kk.domains[i, j][cand] = 0
            end
        end
    end
end

"""
Eliminates candidate values for a subtraction cage constraint.
"""
function eliminate!(constr::CageConstraint{Ts}, kk::KenkenCSP)
    # We can assume there are only two cells in this cage.
    (i1, j1), (i2, j2) = constr.coords
    n1, n2 = kk.variables[i1, j1], kk.variables[i2, j2]
    if (n1 > 0 && n2 > 0) || (n1 < 0 && n2 < 0)
        return
    end
    k = size(kk)
    i, j = n1 > 0 ? (i2, j2) : (i1, j1)
    n = n1 > 0 ? n1 : n2
    kk.domains[i, j] .= 0
    # because the difference between n and the undetermined value must be
    # constr.total, once n has been set, the only other valid values are
    # n + constr.total (provided that it's ≤ k) and n - constr.total
    # (provided that it's ≥ 1)
    if n + constr.total ≤ k
        kk.domains[i, j][n + constr.total] = 1
    end
    if n - constr.total ≥ 1
        kk.domains[i, j][n - constr.total] = 1
    end
end

"""
Eliminates candidate values for a division cage constraint.
"""
function eliminate!(constr::CageConstraint{Td}, kk::KenkenCSP)
    # We can assume that there are only two cells in this cage.
    (i1, j1), (i2, j2) = constr.coords
    n1, n2 = kk.variables[i1, j1], kk.variables[i2, j2]
    if (n1 > 0 && n2 > 0) || (n1 < 0 && n2 < 0)
        return
    end
    # We can now assume that exactly one value has been set
    k = size(kk)
    i, j = n1 > 0 ? (i2, j2) : (i1, j1)
    n = n1 > 0 ? n1 : n2
    kk.domains[i, j] .= 0
    # Similar logic as the subtraction case
    if n * constr.total ≤ k
        kk.domains[i, j][n * constr.total] = 1
    end
    if n ÷ constr.total ≥ 1
        kk.domains[i, j][n ÷ constr.total] = 1
    end
end

function _eliminate_rc!(doms::Array{BitArray}, vars::Array{Int})
    k = length(doms)
    # for each value in the row or column
    for (i, v) ∈ enumerate(vars)
        # if the value has been determined
        if v > 0
            for j = 1:k
                # remove the value as a candidate from every other cell in the
                # row/column
                if j ≠ i
                    doms[j][v] = 0
                end
            end
        end
    end
end

"""
Eliminates candidate values for a row constraint.
"""
function eliminate!(constr::RowConstraint, kk::KenkenCSP)
    return _eliminate_rc!(kk.domains[constr.idx, :], kk.variables[constr.idx, :])
end

"""
Eliminates candidate values for a column constraint.
"""
function eliminate!(constr::ColumnConstraint, kk::KenkenCSP)
    return _eliminate_rc!(kk.domains[:, constr.idx], kk.variables[:, constr.idx])
end

"""
Eliminates values from the domains of the Kenken's cells based on the constraints.
"""
function eliminate!(kk::KenkenCSP)
    # To complete an elimination pass, we eliminate for each constraint and fill
    # in values that are completely determined by each step
    for constr ∈ kk.constraints
        eliminate!(constr, kk)
        fill_in!(kk)
    end
end

"""
A Kenken is consistent if there are no domains that have no more viable candidates.
"""
function consistent(kk::KenkenCSP)
    return all(sum.(kk.domains) .> 0)
end

"""
A Kenken is complete if there are no values that have not been completely determined.
"""
function complete(kk::KenkenCSP)
    return all(kk.variables .> 0)
end

"""
Find a cell whose value has not been determined which contains the minimum number of
viable candidates.
"""
function find_next_unset(kk::KenkenCSP)
    k = size(kk)
    min_cands = k
    imin, jmin = nothing, nothing
    for i = 1:k
        for j = 1:k
            s = sum(kk.domains[i, j])
            if kk.variables[i, j] < 0 && s ≤ min_cands
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

"""
Find a solution for an arbitrary Kenken using backtracking search. At each
step, the algorithm makes an elimination pass, and then checks whether the resulting
board is a solution. If it is, we return it. If not, we find a cell whose value
has not been set, choose one of the remaining candidates for that cell, and then
recurse.
"""
function backtrack(kk::KenkenCSP)
    eliminate!(kk)
    cons = consistent(kk)
    if !cons
        return
    end
    if complete(kk)
        if cons
            return kk
        else
            return
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
end
