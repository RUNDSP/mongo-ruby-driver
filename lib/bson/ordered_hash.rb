# Copyright (C) 2009-2013 MongoDB, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# A hash in which the order of keys are preserved.
#
# Under Ruby 1.9 and greater, this class has no added methods because Ruby's
# Hash already keeps its keys ordered by order of insertion.

module RUN_BSON
  class OrderedHash < Hash

    def ==(other)
      begin
        case other
        when RUN_BSON::OrderedHash
           keys == other.keys && values == other.values
        else
          super
        end
      rescue
        false
      end
    end

    # Allows activesupport Array#extract_options! to extract options
    # when they are instance of RUN_BSON::OrderedHash
    #
    # @return [true, false] true if options can be extracted
    def extractable_options?
      instance_of?(RUN_BSON::OrderedHash)
    end

    def reject
      return to_enum(:reject) unless block_given?
      dup.tap {|hash| hash.reject!{|k, v| yield k, v}}
    end

    def select
      return to_enum(:select) unless block_given?
      dup.tap {|hash| hash.reject!{|k, v| ! yield k, v}}
    end

    # We only need the body of this class if the RUBY_VERSION is before 1.9
    if RUBY_VERSION < '1.9'
      attr_accessor :ordered_keys

      def self.[] *args
        oh = RUN_BSON::OrderedHash.new
        if Hash === args[0]
          oh.merge! args[0]
        elsif (args.size % 2) != 0
          raise ArgumentError, "odd number of elements for Hash"
        else
          0.step(args.size - 1, 2) do |key|
            value = key + 1
            oh[args[key]] = args[value]
          end
        end
        oh
      end

      def initialize(*a, &b)
        @ordered_keys = []
        super
      end

      def yaml_initialize(tag, val)
        @ordered_keys = []
        super
      end

      def keys
        @ordered_keys.dup
      end

      def []=(key, value)
        unless has_key?(key)
          @ordered_keys << key
        end
        super(key, value)
      end

      def each
        @ordered_keys.each { |k| yield k, self[k] }
        self
      end
      alias :each_pair :each

      def to_a
        @ordered_keys.map { |k| [k, self[k]] }
      end

      def values
        collect { |k, v| v }
      end

      def replace(other)
        @ordered_keys.replace(other.keys)
        super
      end

      def merge(other)
        oh = self.dup
        oh.merge!(other)
        oh
      end

      def merge!(other)
        @ordered_keys += other.keys # unordered if not an RUN_BSON::OrderedHash
        @ordered_keys.uniq!
        super(other)
      end

      alias :update :merge!

      def dup
        result = OrderedHash.new
        @ordered_keys.each do |key|
          result[key] = self[key]
        end
        result
      end

      def inspect
        str = "#<RUN_BSON::OrderedHash:0x#{self.object_id.to_s(16)} {"
        str << (@ordered_keys || []).collect { |k| "\"#{k}\"=>#{self.[](k).inspect}" }.join(", ")
        str << '}>'
      end

      def delete(key, &block)
        @ordered_keys.delete(key) if @ordered_keys
        super
      end

      def delete_if(&block)
        keys.each do |key|
          if yield key, self[key]
            delete(key)
          end
        end
        self
      end

      def reject!
        return to_enum(:reject!) unless block_given?
        raise "can't modify frozen RUN_BSON::OrderedHash" if frozen?
        keys = @ordered_keys.dup
        @ordered_keys.each do |k|
          if yield k, self[k]
            keys.delete(k)
          end
        end
        keys == @ordered_keys ? nil : @ordered_keys = keys
      end

      def clear
        super
        @ordered_keys = []
      end

      def initialize_copy(original)
        super
        @ordered_keys = original.ordered_keys.dup
      end

      if RUBY_VERSION =~ /1.8.6/
        def hash
          code = 17
          each_pair do |key, value|
            code = 37 * code + key.hash
            code = 37 * code + value.hash
          end
          code & 0x7fffffff
        end

        def eql?(o)
          if o.instance_of? RUN_BSON::OrderedHash
            self.hash == o.hash
          else
            false
          end
        end
      end
    end
  end
end
