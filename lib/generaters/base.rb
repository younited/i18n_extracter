
module Generaters

  class ConflictingKeyException < Exception; end

  class Base

    # iterate through all values
    def each_value(parents, src, &block)
      src.each do |k, v|
        if v.is_a?(ActiveSupport::OrderedHash)
          each_value parents + [k], v, &block
        else
          yield parents + [k], v
        end
      end
    end

    def keys_to_hash(key_based)
      returning ActiveSupport::OrderedHash.new do |oh|
        key_based.each do |key, value|
          if key.to_s.include? '.'
            key_prefix, key_suffix = key.to_s.split('.')[0...-1], key.to_s.split('.')[-1]
            target_key = key_prefix.inject(oh){ |h, k|
              if h[k].nil?
                h[k] = ActiveSupport::OrderedHash.new
              elsif !(h[k].is_a?(ActiveSupport::OrderedHash))
                raise ConflictingKeyException, "Expecting #{key_prefix.join('.')} (#{key}) to be a scope. But is used as value. \nSee:\n  #{((h[k][:lines] || []) + (value[:lines] || [])).join("\n  ")}"
              end
              h[k]
            }
            if target_key[key_suffix].is_a?(ActiveSupport::OrderedHash)
              raise ConflictingKeyException, "Expecting #{key_prefix.join('.')}.#{key_suffix} (#{key}) to be a value. But is used as scope. \nSee:\n  #{(key_based[key][:lines] + target_key[key_suffix].collect{|h| h[1][:lines]}.flatten).join("\n  ")}"
            else
              target_key[key_suffix] = value
            end
          else
            if oh[key].is_a?(ActiveSupport::OrderedHash)
              raise
            else
              oh[key] = value
            end
          end
        end
      end
    end

  end

end
