module Pacer
  module Routes
    module RouteOperations
      def sort_section(section_name = nil, &block)
        chain_route transform: :sort_section, block: block, section_name: section_name
      end
    end
  end

  module Transform
    module SortSection
      class SortSectionPipe < Pacer::Pipes::RubyPipe
        def initialize(section, block)
          super()
          @to_emit = []
          @section = section
          @block = block
          if section
            section.on_start &method(:on_start)
            section.on_end &method(:on_end)
          else
            on_start nil, 0
          end
        end

        def processNextStart
          while @to_emit.empty?
            element = @starts.next
            @to_sort << element
          end
          element, sort_value = @to_emit.shift
          element
        rescue NativeException => e
          if e.cause.getClass == Pacer::NoSuchElementException.getClass
            if @to_emit.empty?
              raise e.cause
            else
              on_end(nil, 0)
              retry
            end
          else
            raise e
          end
        end

        def on_start(element, count)
          @section_element = element
          @section_number = count
          @to_sort = []
        end

        def on_end(section_element, count)
          if @to_sort.any?
            if @block
              sorted = @to_sort.sort_by do |element|
                @block.call element, section_element, count
              end
              @to_emit.concat sorted 
            else
              @to_emit.concat @to_sort.sort
            end
          end
        end
      end

      attr_accessor :block
      attr_reader :section_name

      def section_name=(name)
        @section_name = name
        @section_route = @back.get_section_route(name)
      end

      protected

      def attach_pipe(end_pipe)
        pipe = SortSectionPipe.new(@section_route.section_events, block)
        pipe.setStarts end_pipe if end_pipe
        pipe
      end
    end
  end
end