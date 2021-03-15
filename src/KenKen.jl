Tp, Tm, Ts, Td = typeof(+), typeof(*), typeof(-), typeof(÷)

struct CageConstraint{T} <: Constraint where T <: Union{Tp, Tm, Ts, Td}
    total::Int
    coords::Array{Tuple{Int, Int}}
    op::T
end

"""
Creates a KenKen board given constraints. It inserts values for any `CellConstraints`
and discards them. It also creates row an column constraints, so those don't need
to be part of the input. As per the traditional formulation of constraint
satisfaction problems, each instance contains `domains` (valid remaining values for
each square), `variables` (values that have been completely determined), and
`constraints`.
"""
function KenKen(constraints, k::Int)
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
    return GridCSP(variables, vcat(clean_constraints, row_constraints, col_constraints), domains)
end

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
function eliminate!(constr::CageConstraint{Tp}, csp::GridCSP)
    acc, undetermined = _constraint_value_and_undetermined(constr, csp.variables)
    if length(undetermined) == 0
        return
    end
    k = size(csp)
    # if there is one cell left, anything not equal to the total - acc is invalid.
    # if there more than one undetermined, any single cell ≥ to the total - acc
    # is invalid
    comp = length(undetermined) == 1 ? (≠) : (≥)
    for (i, j) ∈ undetermined
        for cand ∈ 1:k
            if comp(cand, constr.total - acc)
                csp.domains[i, j][cand] = 0
            end
        end
    end
end

"""
Eliminates candidate values for a multiplication cage constraint.
"""
function eliminate!(constr::CageConstraint{Tm}, csp::GridCSP)
    acc, undetermined = _constraint_value_and_undetermined(constr, csp.variables)
    if length(undetermined) == 0
        return
    end
    k = size(csp)
    for (i, j) ∈ undetermined
        for cand ∈ 1:k
            # to remain valid, candidates must divide the remaining amount
            if (constr.total ÷ acc) % cand != 0
                csp.domains[i, j][cand] = 0
            end
        end
    end
end

"""
Eliminates candidate values for a subtraction cage constraint.
"""
function eliminate!(constr::CageConstraint{Ts}, csp::GridCSP)
    # We can assume there are only two cells in this cage.
    (i1, j1), (i2, j2) = constr.coords
    n1, n2 = csp.variables[i1, j1], csp.variables[i2, j2]
    if (n1 > 0 && n2 > 0) || (n1 < 0 && n2 < 0)
        return
    end
    k = size(csp)
    i, j = n1 > 0 ? (i2, j2) : (i1, j1)
    n = n1 > 0 ? n1 : n2
    csp.domains[i, j] .= 0
    # because the difference between n and the undetermined value must be
    # constr.total, once n has been set, the only other valid values are
    # n + constr.total (provided that it's ≤ k) and n - constr.total
    # (provided that it's ≥ 1)
    if n + constr.total ≤ k
        csp.domains[i, j][n + constr.total] = 1
    end
    if n - constr.total ≥ 1
        csp.domains[i, j][n - constr.total] = 1
    end
end

"""
Eliminates candidate values for a division cage constraint.
"""
function eliminate!(constr::CageConstraint{Td}, csp::GridCSP)
    # We can assume that there are only two cells in this cage.
    (i1, j1), (i2, j2) = constr.coords
    n1, n2 = csp.variables[i1, j1], csp.variables[i2, j2]
    if (n1 > 0 && n2 > 0) || (n1 < 0 && n2 < 0)
        return
    end
    # We can now assume that exactly one value has been set
    k = size(csp)
    i, j = n1 > 0 ? (i2, j2) : (i1, j1)
    n = n1 > 0 ? n1 : n2
    csp.domains[i, j] .= 0
    # Similar logic as the subtraction case
    if n * constr.total ≤ k
        csp.domains[i, j][n * constr.total] = 1
    end
    if n ÷ constr.total ≥ 1
        csp.domains[i, j][n ÷ constr.total] = 1
    end
end
