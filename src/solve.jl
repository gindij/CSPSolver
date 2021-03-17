import Base: size, deepcopy

abstract type Constraint end

struct GridCSP
    variables::Array{Int, 2}
    constraints::Array{Constraint}
    domains::Array{BitArray, 2}
end

function GridCSP(constraints::Array{Constraint, 1}, k::Int)
    vars = -ones(Int, k, k)
    domains = Array{BitArray, 2}(undef, k, k)
    for i = 1:k
        for j = 1:k
            domains[i, j] = BitArray(undef, k)
            domains[i, j] .+= 1
        end
    end
    return GridCSP(vars, constraints, domains)
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
Find solutions to arbitrary GridCSP by backtracking.
"""
function backtrack(csp::GridCSP, n_solutions::Int; randomize::Bool = false)
    solutions = GridCSP[]
    backtrack!(csp, solutions, n_solutions, randomize)
    return n_solutions == 1 ? solutions[1] : solutions
end

function backtrack!(csp::GridCSP, solutions::Array{GridCSP, 1}, n_solutions::Int, randomize::Bool)
    eliminate!(csp)
    cons = consistent(csp)
    if !cons
        return
    end
    if complete(csp) && cons
        push!(solutions, csp)
        return
    end
    k = size(csp)
    i, j = find_next_unset(csp)
    dom = csp.domains[i, j]
    cands = 1:k
    cands = cands[dom[cands] .== 1]
    if randomize
        cands = cands[randperm(length(cands))]
    end
    for l = cands
        cspcpy = deepcopy(csp)
        set_domain!(i, j, l, cspcpy.domains)
        set_cell!(i, j, l, cspcpy.variables)
        backtrack!(cspcpy, solutions, n_solutions, randomize)
        # if we have more solutions than we want, terminate
        if length(solutions) ≥ n_solutions
            break
        end
    end
    return solutions[1:min(length(solutions), n_solutions)]
end
