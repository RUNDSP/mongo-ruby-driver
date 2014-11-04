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

module Mongo #:nodoc:

  # Utility module to include when needing to convert certain types of
  # objects to mongo-friendly parameters.
  module Conversions

    ASCENDING_CONVERSION  = ["ascending", "asc", "1"]
    DESCENDING_CONVERSION = ["descending", "desc", "-1"]

    # Allows sort parameters to be defined as a Hash.
    # Does not allow usage of un-ordered hashes, therefore
    # Ruby 1.8.x users must use RUN_BSON::OrderedHash.
    #
    # Example:
    #
    # <tt>hash_as_sort_parameters({:field1 => :asc, "field2" => :desc})</tt> =>
    # <tt>{ "field1" => 1, "field2" => -1}</tt>
    def hash_as_sort_parameters(value)
      if RUBY_VERSION < '1.9' && !value.is_a?(RUN_BSON::OrderedHash)
        raise InvalidSortValueError.new(
          "Hashes used to supply sort order must maintain ordering." +
          "Use RUN_BSON::OrderedHash."
        )
      else
        order_by = value.inject({}) do |memo, (key, direction)|
          memo[key.to_s] = sort_value(direction)
          memo
        end
      end
      order_by
    end

    # Converts the supplied +Array+ to a +Hash+ to pass to mongo as
    # sorting parameters. The returned +Hash+ will vary depending
    # on whether the passed +Array+ is one or two dimensional.
    #
    # Example:
    #
    # <tt>array_as_sort_parameters([["field1", :asc], ["field2", :desc]])</tt> =>
    # <tt>{ "field1" => 1, "field2" => -1}</tt>
    def array_as_sort_parameters(value)
      order_by = RUN_BSON::OrderedHash.new
      if value.first.is_a? Array
        value.each do |param|
          if (param.class.name == "String")
            order_by[param] = 1
          else
            order_by[param[0]] = sort_value(param[1]) unless param[1].nil?
          end
        end
      elsif !value.empty?
        if order_by.size == 1
          order_by[value.first] = 1
        else
          order_by[value.first] = sort_value(value[1])
        end
      end
      order_by
    end

    # Converts the supplied +String+ or +Symbol+ to a +Hash+ to pass to mongo as
    # a sorting parameter with ascending order. If the +String+
    # is empty then an empty +Hash+ will be returned.
    #
    # Example:
    #
    # *DEPRECATED
    #
    # <tt>string_as_sort_parameters("field")</tt> => <tt>{ "field" => 1 }</tt>
    # <tt>string_as_sort_parameters("")</tt> => <tt>{}</tt>
    def string_as_sort_parameters(value)
      return {} if (str = value.to_s).empty?
      { str => 1 }
    end

    # Converts the +String+, +Symbol+, or +Integer+ to the
    # corresponding sort value in MongoDB.
    #
    # Valid conversions (case-insensitive):
    #
    # <tt>ascending, asc, :ascending, :asc, 1</tt> => <tt>1</tt>
    # <tt>descending, desc, :descending, :desc, -1</tt> => <tt>-1</tt>
    #
    # If the value is invalid then an error will be raised.
    def sort_value(value)
      return value if value.is_a?(Hash)
      val = value.to_s.downcase
      return 1 if ASCENDING_CONVERSION.include?(val)
      return -1 if DESCENDING_CONVERSION.include?(val)
      raise InvalidSortValueError.new(
        "#{self} was supplied as a sort direction when acceptable values are: " +
        "Mongo::ASCENDING, 'ascending', 'asc', :ascending, :asc, 1, Mongo::DESCENDING, " +
        "'descending', 'desc', :descending, :desc, -1.")
    end
  end
end
