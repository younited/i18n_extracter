require 'yaml'
require 'ftools'

module Generaters

  class YamlGenerater < Base

    def initialize(locale, translator, file = nil)
      @locale = locale
      @translator = translator
      @file = file
    end

    def generate(translations)
      translations = keys_to_hash(translations)
      yaml = YamlWriter::YamlDocument.new(@locale, @file)
      each_value [], translations do |parents, value|
        node = parents.inject(yaml[@locale]) {|node, parent| node[parent]}
        if node.new_node?
          node.value = @translator.translate(node.key)
        end
        node.variables = value[:variables]
        node.confirm!
      end
      if @file
        write_yaml_file(yaml)
      end
      yaml
    end

    def write_yaml_file(yaml_string)
      puts "Writing yaml to #{@file}"
      File.open(@file, 'wb') do |dest|
        dest.write yaml_string
      end
    end

  end

  module YamlWriter

    SPECIAL_KEYS = ['true', 'false', 'yes', 'no']

    class Node
      attr_reader :document, :indent_level, :variables
      attr_accessor :line
      
      def initialize(parent, line_index, text, new_node = false)
        @document, @line, @text = parent.document, line_index, text.to_s
        @text =~ /(^\s*)/
        @indent_level = $1.nil? ? 0 : $1.size
        @yaml = YAML.load(@text.to_s + ' ')
        @new_node = new_node
        @confirmed = new_node
        extract_fuzzzyness
        extract_variables
        clear_unused
      rescue ArgumentError => e
        puts "Line: '#{@line}' in '#{@text}'"
        lines = []
        8.times do |i|
          lines << @document.to_s.split("\n")[@line - (i - 4)]
        end
        puts lines.join("\n")
        raise e
      end

      def parent
        @parent ||= document.parent_of self
      end

      def children
        @children ||= document.children_of(self)
      end
      alias :nodes :children

      def [](node_name)
        if node = nodes.detect {|n| n.key.to_s == node_name.to_s}
          node
        else
          if SPECIAL_KEYS.include?(node_name)
            nodes.add "#{' ' * (@indent_level + 2)}'#{node_name}': "
          else
            nodes.add "#{' ' * (@indent_level + 2)}#{node_name}: "
          end
          nodes.last
        end
      end

      def key
        @yaml.is_a?(Hash) ? @yaml.keys.first : nil
      end

      def confirm!
        @confirmed = true
      end

      def value
        @yaml.is_a?(Hash) ? @yaml.values.first : nil
      end

      def value=(val, force = false)
        if @yaml[self.key] != val && (force || new_node?)
          @yaml[self.key] = val
          @value_changed = true
          @fuzzzy = true
        end
      end

      def variables=(var)
        return if var.nil?
        raise ArgumentError unless var.is_a?(Array)
        var = var.collect{|v| v.to_s}.sort
        if var != @variables
          @variables = var
          @variables_changed = true
        end
      end

      def text(with_info = false)
        line = @text
        if value_changed?
          v = if self.value.is_a?(Array)
              "[#{self.value * ', '}]"
            else
              %Q["#{self.value}"]
            end
          if SPECIAL_KEYS.include?(self.key)
            line = "#{' ' * self.indent_level}'#{self.key}': #{v} # FUZZZY"
          else
            line = "#{' ' * self.indent_level}#{self.key}: #{v} # FUZZZY"
          end
        end
        line += variable_comment
        line += " # UNUSED" unless @confirmed || (self.children && self.children.size > 0)
        return line
      end
      alias :to_s :text

      def new_node?
        @new_node
      end

      def fuzzzy?
        @fuzzzy
      end

      def value_changed?
        @value_changed
      end

      def is_blank_or_comment?
        @text.sub(/#.*$/, '').gsub(/\s/, '').empty?
      end

      def path
        @path ||= "#{self.parent.path}/#{self.key}"
      end

      def descendant_nodes(&block)
        yield self if self.value
        self.children.each {|child| child.descendant_nodes(&block)} if self.children
      end

      def <=>(other)
        self.line <=> other.line
      end

    private

      def clear_unused
        @text.gsub!(' # UNUSED', '')
      end

      def extract_fuzzzyness
        @fuzzzy = if @text.include?(' # FUZZZY') then true else false end
      end

      def extract_variables
        @variables = @text.match(/ # VARIABLES\((.*)\)/)[1].split(', ')
      rescue
      ensure
        @text.gsub!(/ # VARIABLES\(.*\)/, '')
      end

      def variable_comment
        if @variables.blank? then '' else " # VARIABLES(#{@variables.join(', ')})" end
      end

    end

    class YamlDocument < Node
      attr_accessor :lines
      alias :nodes :lines

      def initialize(locale_name, yml_path = nil)
        @locale_name, @lines, @current_line, @indent_level = locale_name, Nodes.new(self), -1, -2
        if yml_path && File.exists?(yml_path)
          File.open(yml_path) do |file|
            file.each_with_index do |line_text, i|
              n = Node.new(self, i, line_text.chomp)
              if ((n.key == 'en-US') || (n.key == 'en')) && n.value.blank?
                @lines << Node.new(self, i, "#{locale_name}:") 
              else 
                @lines << n
              end
            end
            @lines.delete_at(-1) if @lines[-1].text.blank?
          end
        end
      end

      def next
        return false if @lines.size == 0
        @current_line += 1
        return false if @current_line >= @lines.size
        @lines[@current_line].is_blank_or_comment? ? self.next : @lines[@current_line]
      end

      def prev
        return false if @current_line == 0
        @current_line -= 1
        @lines[@current_line].is_blank_or_comment? ? self.prev : @lines[@current_line]
      end

      def parent_of(child)
        @current_line = child.line
        while n = self.prev
          return n if n.indent_level == child.indent_level - 2
        end
        self
      end

      def children_of(parent)
        nodes = Nodes.new(parent)
        @current_line = parent.line
        while n = self.next
          if n.indent_level < parent.indent_level + 2
            break
          elsif n.indent_level == parent.indent_level + 2
            nodes << n
          end
        end
        nodes
      end

      def document
        self
      end

      def path
        ''
      end

      def line
        @current_line
      end

      def to_s
        @lines.inject('') do |ret, n|
          ret << n.text + "\n"
        end
      end
    end

    class Nodes < Array
      def initialize(parent)
        super()
        @parent = parent
      end

      def [](index)
        if index.is_a?(String) || index.is_a?(Symbol)
          return self.detect {|node| node.key.to_s == index.to_s} || add(index.to_s)
        end
        super
      end

      def last_leaf
        c = @parent
        loop do
          return c if c.children.blank?
          c = c.children.last
        end
      end

      def add(node_name)
        target_line = self.last_leaf.line + 1
        @parent.document.nodes.each {|n| n.line += 1 if n.line >= target_line}
        node = Node.new(@parent, target_line, node_name, true)
        @parent.document.lines << node
        @parent.document.lines.sort!
        self << node unless @parent.is_a? YamlDocument
      end
    end

  end


end
