# typed: true
module Parlour
  # A generic superclass of all objects which form part of type definitions in,
  # specific formats, such as RbiObject and RbsObject.
  class TypedObject
    extend T::Sig
    extend T::Helpers
    abstract!

    sig { params(name: String).void }
    # Create a new typed object.
    def initialize(name)
      @name = name
      @comments = []
    end

    sig { returns(T.nilable(Plugin)) }
    # The {Plugin} which was controlling the {generator} when this object was
    # created.
    # @return [Plugin, nil]
    attr_reader :generated_by

    sig { returns(String).checked(:never) }
    # The name of this object.
    # @return [String]
    attr_reader :name

    sig { returns(T::Array[String]) }
    # An array of comments which will be placed above the object in the RBS
    # file.
    # @return [Array<String>]
    attr_reader :comments

    sig { params(comment: T.any(String, T::Array[String])).void }
    # Adds one or more comments to this RBS object. Comments always go above 
    # the definition for this object, not in the definition's body.
    #
    # @example Creating a module with a comment.
    #   namespace.create_module('M') do |m|
    #     m.add_comment('This is a module')
    #   end
    #
    # @example Creating a class with a multi-line comment.
    #   namespace.create_class('C') do |c|
    #     c.add_comment(['This is a multi-line comment!', 'It can be as long as you want!'])
    #   end
    #
    # @param comment [String, Array<String>] The new comment(s).
    # @return [void]
    def add_comment(comment)
      if comment.is_a?(String)
        comments << comment
      elsif comment.is_a?(Array)
        comments.concat(comment)
      end
    end

    alias_method :add_comments, :add_comment

    sig { returns(String) }
    # Returns a human-readable brief string description of this object. This
    # is displayed during manual conflict resolution with the +parlour+ CLI.
    #
    # @return [String]
    def describe
      if is_a?(RbiGenerator::RbiObject)
        type_system = 'RBI'
      elsif is_a?(RbsGenerator::RbsObject)
        type_system = 'RBS'
      else
        raise 'unknown type system'
      end

      attr_strings = describe_attrs.map do |a|
        case a
        when Symbol
          key = a
          value = send(a)

          case value
          when Array, Hash
            value = value.length
            next nil if value == 0
          when String
            value = value.inspect
          when Parlour::Types::Type
            value = value.describe
          when true
            next key
          when false
            next nil
          end
        when Hash
          raise 'describe_attrs Hash must have one key' unless a.length == 1

          key = a.keys[0]
          value = a.values[0]
        end

        "#{key}=#{value}"
      end.compact

      class_name = T.must(self.class.name).split('::').last
      if attr_strings.empty?
        "<#{type_system}:#{class_name}:#{name}>"
      else
        "<#{type_system}:#{class_name}:#{name} #{attr_strings.join(" ")}>"
      end
    end
    
    protected

    sig { abstract.returns(T::Array[T.any(Symbol, T::Hash[Symbol, String])]) }
    # The attributes for an instance of this object which should be included in
    # its string form generated by +#describe+.
    # For each element in the returned array:
    #   - If it is a symbol, this symbol will be called on +self+ and the
    #     returned object will be dynamically converted into a string.
    #   - If it is a hash, it must be of the format { Symbol => String }. The
    #     given string will be used instead of calling the symbol.
    #
    # @abstract
    # @return [<Symbol, String>]
    def describe_attrs; end

    sig do
      params(
        indent_level: Integer,
        options: Options
      ).returns(T::Array[String])
    end
    # Generates the RBS lines for this object's comments.
    #
    # @param indent_level [Integer] The indentation level to generate the lines at.
    # @param options [Options] The formatting options to use.
    # @return [Array<String>] The RBS lines for each comment, formatted as specified.
    def generate_comments(indent_level, options)
      comments.any? \
        ? comments.map { |c| options.indented(indent_level, "# #{c}") }
        : []
    end
  end
end
