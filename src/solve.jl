import Base: size, deepcopy

abstract type Constraint end

struct GridCSP
    variables::Array{Int, 2}
    constraints::Array{Constraint}
    domains::Array{BitArray, 2}
end

size(csp::GridCSP) = size(csp.domains, 1)
deepcopy(csp::GridCSP) = GridCSP(
    deepcopy(csp.variables),
    deepcopy(csp.constraints),
    deepcopy(csp.domains)
)

struct RowConstraint <: Constraint
    idx::Int
end

struct ColumnConstraint <: Constraint
    idx::Int
end

struct CellConstraint <: Constraint
    value::Int
    coord::Tuple{Int, Int}
end

function set_domain!(i, j, value, domains)
    domains[i, j] .= 0
    domains[i, j][value] = 1
end

function set_cell!(i, j, value, variables)
    variables[i, j] = value
end

"""
Fills in values that have been completely determined.
"""
function fill_in!(csp::GridCSP)
    k = size(csp)
    for i = 1:k
        for j = 1:k
            dom = csp.domains[i, j]
            if sum(dom) == 1 && csp.variables[i, j] < 0
                v = argmax(dom)
                csp.variables[i, j] = v
            end
        end
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
function eliminate!(constr::RowConstraint, csp::GridCSP)
    return _eliminate_rc!(csp.domains[constr.idx, :], csp.variables[constr.idx, :])
end

"""
Eliminates candidate values for a column constraint.
"""
function eliminate!(constr::ColumnConstraint, csp::GridCSP)
    return _eliminate_rc!(csp.domains[:, constr.idx], csp.variables[:, constr.idx])
end

"""
Eliminates values from the domains of the Kenken's cells based on the constraints.
"""
function eliminate!(csp::GridCSP)
    # To complete an elimination pass, we eliminate for each constraint and fill
    # in values that are completely determined by each step
    for constr ∈ csp.constraints
        eliminate!(constr, csp)
        fill_in!(csp)
    end
end

"""
A Kenken is consistent if there are no domains that have no more viable candidates.
"""
function consistent(csp::GridCSP)
    return all(sum.(csp.domains) .> 0)
end

"""
A Kenken is complete if there are no values that have not been completely determined.
"""
function complete(csp::GridCSP)
    return all(csp.variables .> 0)
end

"""
Find a cell whose value has not been determined which contains the minimum number of
viable candidates.
"""
function find_next_unset(csp::GridCSP)
    k = size(csp)
    min_cands = k
    imin, jmin = nothing, nothing
    for i = 1:k
        for j = 1:k
            s = sum(csp.domains[i, j])
            if csp.variables[i, j] < 0 && s ≤ min_cands
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
function backtrack(csp::GridCSP)
    eliminate!(csp)
    cons = consistent(csp)
    if !cons
        return
    end
    if complete(csp)
        if cons
            return csp
        else
            return
        end
    end
    k = size(csp)
    i, j = find_next_unset(csp)
    dom = csp.domains[i, j]
    cands = 1:k
    cands = cands[dom[cands] .== 1]
    for l = cands
        cspcpy = deepcopy(csp)
        set_domain!(i, j, l, cspcpy.domains)
        set_cell!(i, j, l, cspcpy.variables)
        res = backtrack(cspcpy)
        if !isnothing(res)
            return res
        end
    end
end
