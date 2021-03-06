# A versatile graph type
#
# It implements edge_list, adjacency_list and incidence_list
#

type GenericGraph{V,E,VList,EList,IncList} <: AbstractGraph{V,E}
    is_directed::Bool
    vertices::VList     # an indexable container of vertices
    edges::EList        # an indexable container of edges
    finclist::IncList   # forward incidence list
    binclist::IncList   # backward incidence list 
end

@graph_implements GenericGraph vertex_list edge_list vertex_map edge_map 
@graph_implements GenericGraph bidirectional_adjacency_list bidirectional_incidence_list

# SimpleGraph:
#   V:          Int
#   E:          IEdge
#   VList:      Range1{Int}
#   EList:      Vector{IEdge}
#   AdjList:    Vector{Vector{Int}}
#   IncList:    Vector{Vector{IEdge}}
#
typealias SimpleGraph GenericGraph{Int,IEdge,Range1{Int},Vector{IEdge},Vector{Vector{IEdge}}}

typealias Graph{V,E} GenericGraph{V,E,Vector{V},Vector{E},Vector{Vector{E}}}

# construction

simple_graph(n::Integer; is_directed::Bool=true) = 
    SimpleGraph(is_directed,  
                1:int(n),  # vertices
                IEdge[],   # edges 
                multivecs(IEdge, n), # finclist
                multivecs(IEdge, n)) # binclist

function graph{V,E}(vs::Vector{V}, es::Vector{E}; is_directed::Bool=true)
    n = length(vs)
    g = Graph{V,E}(is_directed, vs, E[], multivecs(E, n), multivecs(E, n))
    for e in es
        add_edge!(g, e)
    end
    return g
end


# required interfaces

is_directed(g::GenericGraph) = g.is_directed

num_vertices(g::GenericGraph) = length(g.vertices)
vertices(g::GenericGraph) = g.vertices

num_edges(g::GenericGraph) = length(g.edges)
edges(g::GenericGraph) = g.edges

vertex_index{V}(v::V, g::GenericGraph{V}) = vertex_index(v)
edge_index{V,E}(e::E, g::GenericGraph{V,E}) = edge_index(e)

out_edges{V}(v::V, g::GenericGraph{V}) = g.finclist[vertex_index(v)]
out_degree{V}(v::V, g::GenericGraph{V}) = length(out_edges(v, g))
out_neighbors{V}(v::V, g::GenericGraph{V}) = TargetIterator(g, out_edges(v, g))

in_edges{V}(v::V, g::GenericGraph{V}) = g.binclist[vertex_index(v)]
in_degree{V}(v::V, g::GenericGraph{V}) = length(in_edges(v, g))
in_neighbors{V}(v::V, g::GenericGraph{V}) = SourceIterator(g, in_edges(v, g))


# mutation

function add_vertex!{V}(g::GenericGraph{V}, v::V)
    @assert vertex_index(v) == num_vertices(g) + 1
    push!(g.vertices, v)
    push!(g.finclist, Int[])
    push!(g.binclist, Int[])
    v
end
add_vertex!{V}(g::GenericGraph{V}, x) = add_vertex!(g, make_vertex(g, x))

function add_edge!{V,E}(g::GenericGraph{V,E}, u::V, v::V, e::E)
    # add an edge e between u and v
    @assert edge_index(e) == num_edges(g) + 1
    ui = vertex_index(u, g)::Int
    vi = vertex_index(v, g)::Int

    push!(g.edges, e)
    push!(g.finclist[ui], e)
    push!(g.binclist[vi], e)

    if !g.is_directed
        rev_e = revedge(e)
        push!(g.finclist[vi], rev_e)
        push!(g.binclist[ui], rev_e)
    end
    e
end

add_edge!{V,E}(g::GenericGraph{V,E}, e::E) = add_edge!(g, source(e, g), target(e, g), e)
add_edge!{V,E}(g::GenericGraph{V,E}, u::V, v::V) = add_edge!(g, u, v, make_edge(g, u, v))


# Ad-hoc vertex/edge removers below

# Naive general case
function remove_edge!{V,E}(g::GenericGraph{V,E}, u::V, v::V, e::E)
  @assert e in g.edges && source(e, g) == u && target(e, g) == v
  ei = edge_index(e, g)::Int
  ui = vertex_index(u, g)::Int
  vi = vertex_index(v, g)::Int

  for i = 1:length(g.finclist[ui])
    if g.finclist[ui][i] == e
      f_index = i
      break
    end # if
  end # for

  for j = 1:length(g.binclist[vi])
    if g.binclist[vi][j] == e
      b_index = j
      break
    end # if
  end # for

  splice!(g.edges, ei)
  splice!(g.finclist[ui], f_index)
  splice!(g.binclist[vi], b_index)

  if !g.is_directed
    rev_e = revedge(e)
    for i = 1:length(g.finclist[ui])
      if g.finclist[ui][i] == rev_e
        f_index = i
        break
      end # if
    end # for

    for j = 1:length(g.binclist[vi])
      if g.binclist[vi][j] == rev_e
        b_index = j
        break
      end # if
    end # for

    splice!(g.finclist[ui], f_index)
    splice!(g.binclist[vi], b_index)
  end # if
end


# Needed since edge indexing is not unique. That is, if e = edge(1, 2) is in graph g, then e != make_edge(g, 1, 2).
function remove_edge!{V,E}(g::GenericGraph{V,E}, u::V, v::V)
  for edge in g.edges
    if source(edge, g) == u && target(edge, g) == v
      uv_edge = edge
      break
    end # if
  end #for
  remove_edge!(g, u, v, uv_edge)
end


remove_edge!{V,E}(g::GenericGraph{V,E}, e::E) = remove_edge!(g, source(e, g), target(e, g))


function remove_vertex!{V,E}(g::GenericGraph{V,E}, v::V)
  @assert v in g.vertices
  vi = vertex_index(v, g)
  splice!(g.vertices, vi)

  for edge in g.edges
    if source(edge, g) == v || target(edge, g) == v
      remove_edge!(g, edge)
    end # if
  end #for
end
