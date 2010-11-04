#!/usr/bin/ruby
=begin
parser/ruby.rb - parser for ruby script

Copyright (C) 2009       Bert Goethals
Copyright (C) 2003-2005  Masao Mutoh
Copyright (C) 2005       speakillof
Copyright (C) 2001,2002  Yasushi Shoji, Masao Mutoh

You may redistribute it and/or modify it under the same
license terms as Ruby.

$Id: ruby.rb,v 1.12 2008/08/06 17:35:52 mutoh Exp $
=end

require 'irb/ruby-lex.rb'
require 'stringio'

class RubyLexX < RubyLex  # :nodoc: all
  # Parser#parse resemlbes RubyLex#lex
  def parse
    until (  (tk = token).kind_of?(RubyToken::TkEND_OF_SCRIPT) && !@continue or tk.nil?  )
      s = get_readed
      if RubyToken::TkDSTRING === tk
        def tk.value
          @value
        end

        def tk.value=(s)
          @value = s
        end

        s = s.sub(/\A\s['"]/, '').sub(/['"]\Z/, '').scan(/\#\{(.*)\}/)

        tk.value = s
      end

      if RubyToken::TkSTRING === tk
        def tk.value
          @value
        end

        def tk.value=(s)
          @value = s
        end

        if @here_header
          s = s.sub(/\A.*?\n/, '').sub(/^.*\n\Z/, '')
        else
          begin
            s = eval(s)
          rescue Exception
            # Do nothing.
          end
        end

        tk.value = s
      end

      if $DEBUG
        if tk.is_a? TkSTRING
          $stderr.puts("#{tk}: #{tk.value}")
        elsif tk.is_a? TkIDENTIFIER
          $stderr.puts("#{tk}: #{tk.name}")
        else
          $stderr.puts(tk)
        end
      end

      yield tk
    end
    return nil
  end

end

module Extracters
  module RubyParser
    ID = ['t', 'translate']

    module_function
    def parse(file)  # :nodoc:
      lines = IO.readlines(file)
      parse_lines(file, lines)
    end

    def parse_lines(file_name, lines, line_no_base = 0)  # :nodoc:
      file = StringIO.new(lines.join("\n") + "\n")
      rl = RubyLexX.new
      rl.set_input(file)
      rl.skip_space = true

      targets = {}
      stack = []

      in_translation = false
      parenthesis_level = nil
      current_key = nil
      detecting_symbol = false
      variables = []

      v_cache = nil


      line_no = nil
      tk = nil
      begin
        rl.parse do |tk|
          line_no = tk.line_no + line_no_base
          unless in_translation
            # not inside translation string, so detect them
            case tk
            when RubyToken::TkIDENTIFIER, RubyToken::TkCONSTANT
              if ID.include?(tk.name)
                in_translation = true
              end
            end
          else
            # in a translation string

            # are we detecting variables? (aka, was previous token a symbol)
            if detecting_symbol
              case tk
              when RubyToken::TkIDENTIFIER
                v_cache = tk.name
              end
              detecting_symbol = false
            elsif v_cache # we have a potential variable, but we need to know if it's assigning something
              case tk
              when RubyToken::TkASSIGN
                # ok, do not clear
              when RubyToken::TkGT
                targets[current_key][:variables] << v_cache
                targets[current_key][:variables].uniq!
                v_cache = nil
              else
                v_cache = nil
              end
            end

            case tk
            when RubyToken::TkSYMBEG
              # is there is a current_key, a symbol might be a variable
              detecting_symbol = current_key
            when RubyToken::TkLPAREN
              parenthesis_level ||= 0
              parenthesis_level += 1
            when RubyToken::TkRPAREN
              parenthesis_level -= 1
            when RubyToken::TkSTRING
              current_key ||= tk.value
              targets[current_key] ||= {:lines => [], :variables => []}
              targets[current_key][:lines] << line_no.to_i
              targets[current_key][:lines].uniq!
            when RubyToken::TkDSTRING
              dstring_targets = parse_lines(file_name, tk.value, line_no)
              targets.merge!(dstring_targets)
            when RubyToken::TkIDENTIFIER, RubyToken::TkCONSTANT
              # this could be a translation call, inside a translation call!
              if ID.include?(tk.name)
                # it is, stack everything away, and start over
                stack << [current_key, in_translation, parenthesis_level, detecting_symbol, variables]
                current_key = nil
                in_translation = true
                parenthesis_level = nil
                detecting_symbol = false
                variables = []
              end
            else
              if (tk.is_a?(RubyToken::TkNL) && parenthesis_level.nil?) || (!(parenthesis_level.nil?) && parenthesis_level.zero?) # if it is nil, the method is stil open
                # translation method ended
                # do we have something on the stack?
                if stack.empty?
                  # all clear, not longer in translation
                  current_key = nil
                  in_translation = false
                  parenthesis_level = nil
                  detecting_symbol = false
                  variables = []
                else
                  # continue where we left off
                  situation         = stack.pop
                  current_key       = situation[0]
                  in_translation    = situation[1]
                  parenthesis_level = situation[2]
                  detecting_symbol  = situation[3]
                  variables         = situation[4]
                end
              end
            end
          end
        end
        return targets
      rescue
        $stderr.print "\n\nError: #{$!.inspect} "
        $stderr.print " in #{file_name}:#{tk.line_no}\n\t #{lines[tk.line_no - 1]}" if tk
        $stderr.print "\n"
        exit
      end
      return targets
    end

    def target?(file)  # :nodoc:
      true # always true, as default parser.
    end

  end
end