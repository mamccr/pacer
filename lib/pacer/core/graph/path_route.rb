module Pacer::Core::Graph
  module PathRoute
    def transpose
      collect { |arraylist| arraylist.to_a }.transpose
    end

    def subgraph(target_graph = nil, opts = {})
      raise "Can't create a subgraph within itself." if target_graph == graph
      target_graph ||= Pacer.tg
      target_graph.vertex_name ||= graph.vertex_name
      missing_edges = Set[]
      bulk_job(nil, target_graph) do |path|
        path.select { |e| e.is_a? Pacer::Vertex }.each do |vertex|
          vertex.clone_into target_graph
        end
        path.select { |e| e.is_a? Pacer::Edge }.each do |edge|
          unless edge.clone_into target_graph, ignore_missing_vertices: true
            missing_edges << edge
          end
        end
      end
      if missing_edges.any?
        missing_edges.to_route(graph: graph, element_type: :edge).bulk_job nil, target_graph do |edge|
          edge.clone_into target_graph,
            ignore_missing_vertices: opts[:ignore_missing_vertices],
            show_missing_vertices: opts[:show_missing_vertices]
        end
      end
      target_graph
    end

    def payloads
      map element_type: :path, route_name: 'payloads' do |path|
        path.map do |e|
          if e.is_a? Pacer::Payload::Element
            e.payload
          elsif e.is_a? Pacer::Wrappers::ElementWrapper
            e.element_payload
          end
        end
      end
    end

    def compact_paths
      map element_type: :path, route_name: 'compact' do |path|
        path.compact
      end
    end

    def heads(et = :vertex)
      map element_type: et, route_name: 'heads' do |path|
        path.first
      end
    end

    def tails(et = :vertex)
      map element_type: et, route_name: 'tails' do |path|
        path.last
      end
    end

    def pairs(head = 0, tail = -1)
      map element_type: :path, route_name: "pairs[#{ head },#{ tail }]" do |path|
        [path[head], path[tail]]
      end
    end

    def len(n)
      select do |path|
        n === path.length
      end
    end

    def hashify
      map(element_type: :hash, route_name: 'trees') do |path|
        path.to_a.reverse.reduce({}) do |tree, element|
          if element.element_type == :vertex
            tree.merge element.properties
          else
            { element.label => [tree] }
          end
        end
      end
    end
    protected

    def configure_iterator(iter)
      if respond_to? :graph
        pipe = Pacer::Pipes::PathWrappingPipe.new(graph)
        pipe.setStarts iter
        pipe
      else
        iter
      end
    end
  end
end
