# frozen_string_literal: true

require_relative 'game_error'
require_relative 'route'

module Engine
  class AutoRouter
    def initialize(game)
      @game = game
    end

    def compute(corporation, **opts)
      static = opts[:routes] || []
      path_timeout = opts[:path_timeout] || 10
      route_timeout = opts[:route_timeout] || 10
      route_limit = opts[:route_limit] || 60_000

      connections = {}

      nodes = @game.graph.connected_nodes(corporation).keys.sort_by do |node|
        revenue = corporation
          .trains
          .map { |train| node.route_revenue(@game.phase, train) }
          .max
        [
          node.tokened_by?(corporation) ? 0 : 1,
          node.offboard? ? 0 : 1,
          -revenue,
        ]
      end

      stops = static.flat_map(&:stops)
      nodes -= stops
      visited = stops.map { |node| [node, true] }.to_h

      now = Time.now

      nodes.each do |node|
        if Time.now - now > path_timeout
          puts 'Path timeout reached'
          break
        else
          puts "Path search: #{nodes.index(node)} / #{nodes.size}"
        end

        node.walk(corporation: corporation, visited: visited.dup) do |_, vp|
          paths = vp.keys

          chains = []
          chain = []
          left = nil
          right = nil

          complete = lambda do
            chains << { nodes: [left, right], paths: chain }
            left, right = nil
            chain = []
          end

          assign = lambda do |n|
            if !left
              left = n
            elsif !right
              right = n
              complete.call
            end
          end

          paths.each do |path|
            chain << path
            a, b = path.nodes

            assign.call(a) if a
            assign.call(b) if b
          end

          next if chains.empty?

          id = chains.flat_map { |c| c[:paths] }.sort!
          next if connections[id]

          connections[id] = chains.map do |c|
            { left: c[:nodes][0], right: c[:nodes][1], chain: c }
          end
        end
      end

      puts "Found #{connections.size} paths in: #{Time.now - now}"

      connections = connections.values

      train_routes = Hash.new { |h, k| h[k] = [] }

      puts 'Pruning paths to legal routes'
      now = Time.now
      connections.each do |connection|
        corporation.trains.each do |train|
          route = Engine::Route.new(
            @game,
            @game.phase,
            train,
            connection_data: connection,
          )
          route.revenue
          train_routes[train] << route
        rescue GameError # rubocop:disable Lint/SuppressedException
        end
      end
      puts "Pruned paths to #{train_routes.map { |k, v| k.name + ':' + v.size.to_s }.join(', ')} in: #{Time.now - now}"

      static.each { |route| train_routes[route.train] = [route] }

      limit = (1..train_routes.values.map(&:size).max).bsearch do |x|
        (x**train_routes.size) >= route_limit
      end || route_limit

      train_routes.each do |train, routes|
        train_routes[train] = routes.sort_by(&:revenue).reverse.take(limit)
      end

      train_routes = train_routes.values.sort_by { |routes| -routes[0].paths.size }

      combos = [[]]
      possibilities = []

      puts "Finding route combos with depth #{limit}"
      counter = 0
      now = Time.now

      train_routes.each do |routes|
        combos = routes.flat_map do |route|
          combos.map do |combo|
            combo += [route]
            route.routes = combo
            route.clear_cache!(only_routes: true)
            counter += 1
            if (counter % 1000).zero?
              puts "#{counter} / #{limit**train_routes.size}"
              raise if Time.now - now > route_timeout
            end
            route.revenue
            possibilities << combo
            combo
          rescue GameError # rubocop:disable Lint/SuppressedException
          end
        end

        combos.compact!
      rescue RuntimeError
        puts 'Route timeout reach'
        break
      end

      puts "Found #{possibilities.size} possible routes in: #{Time.now - now}"

      possibilities.max_by do |routes|
        routes.each { |route| route.routes = routes }
        @game.routes_revenue(routes)
      end || []
    end
  end
end
