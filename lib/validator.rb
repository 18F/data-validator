require 'safe_yaml'

module Validator

  # Raised when the validation schema itself is invalid.
  class SchemaException < ::Exception
  end

  # Raised for validation exceptions.
  class Exception < ::Exception
  end

  # Collects schema violations and produces a string representation of them.
  class Violations
    attr_writer :introduction
    attr_reader :violations

    def initialize
      @introduction = ''
      @violations = []
    end

    def add(violation)
      @violations.push violation
    end

    # Concatenates the messages from another Violations objects to this
    # object. Will nest the concatenated violations by two spaces.
    # +introduction+:: summary of the concatenated set of violations
    # +incoming+:: another Violations object instance
    def concat(introduction, incoming)
      add introduction
      @violations.concat incoming.violations.map {|i| '  ' + i}
    end

    def has_violations?
      !@violations.empty?
    end

    # Produces a string of all of the collected violations.
    def to_s()
      if @introduction.empty?
        @violations.join("\n")
      else
        @introduction + "\n  " + @violations.join("\n  ")
      end
    end
  end

  # Validates data hashes against a schema.
  #
  # The filename of the schema should be of the form "object_schema.yml",
  # where "object.yml" contains the collection of objects being described by
  # the schema.
  #
  # The format of the schema is:
  #
  # description: Description of the object defined by the schema
  # used_by:
  #   - list of 18F/project repos using the data
  #   - ...
  # primary_key: (optional) property used by other object collections to
  #   reference objects in this collection
  # properties:
  #   [property name]:
  #     type: String, Fixnum, or Array
  #     description: (optional) explanation of the object property
  #     key_into: (optional) object collection into which this element is a
  #       reference, relative to the current directory or a GitHub repo
  class Validator
    attr_reader :schema

    REQUIRED_SCHEMA_FIELDS = {
      'description' => ::String,
      'used_by' => ::Array,
      }

    OPTIONAL_SCHEMA_FIELDS = {
      'primary_key' => ::String,
    }

    REQUIRED_PROPERTY_FIELDS = {
      'type' => ::String,
    }

    OPTIONAL_PROPERTY_FIELDS = {
      'description' => ::String,
      'key_into' => ::String,
    }

    # Sets the schema used to validate incoming data. Raises SchemaException
    # when the schema itself is malformed.
    # +schema+:: YAML representation of the schema used for validation
    def initialize(schema)
      @schema = SafeYAML.load(schema, :safe => true)

      unless @schema
        raise SchemaException.new "Schema failed to parse"
      end

      violations = validate_schema

      if violations.has_violations?
        violations.introduction = "Invalid schema:"
        raise SchemaException.new violations
      end

      @schema['properties'].each do |unused_name, criteria|
        type_string = criteria['type']
        if type_string == 'Boolean'
          criteria['type'] = ::TrueClass
        else
          criteria['type'] = Object.const_get(type_string)
        end
      end
    end

    # Validates a collection of objects based on the schema.
    # +collection+:: YAML representation of the object collection
    def validate(collection)
      parsed = SafeYAML.load(collection, :safe => true)

      unless parsed
        raise Exception.new "Object collection failed to parse"
      end

      unless parsed.instance_of? ::Array
        raise Exception.new "Collection is not an Array of objects"
      end

      primary_key = @schema['primary_key']
      violations = Violations.new

      parsed.each do |element|
        element_violations = Violations.new

        if primary_key and !element.member? primary_key
          element_violations.add "missing primary key field #{primary_key}:"
        end

        @schema['properties'].each do |name, criteria|
          next unless element.member? name
          value = element[name]
          expected_type = criteria['type']
          if expected_type == ::TrueClass
            unless value == true or value == false
              element_violations.add("#{name}: should be boolean, " +
                "but is of type #{value.class}")
            end
          elsif !value.instance_of? expected_type
            element_violations.add("#{name}: should be of type " +
              "#{expected_type}, but is of type #{value.class}")
          end
        end

        element.keys.each do |key|
          unless @schema['properties'].member? key
            element_violations.add "unknown field #{key}:"
          end
        end

        if element_violations.has_violations?
          violations.concat("Malformed object:\n#{element.to_yaml}",
            element_violations)
        end
      end

      if violations.has_violations?
        raise Exception.new violations
      end
    end

    private

    # Validates that the schema contains all the required fields, all of the
    # correct type. Returns a Violations object; if empty, the validation
    # succeeded.
    def validate_schema
      violations = validate_fields(@schema, REQUIRED_SCHEMA_FIELDS,
        OPTIONAL_SCHEMA_FIELDS)

      primary_key = @schema['primary_key']
      properties = @schema['properties']

      if !properties
        violations.add "no properties defined"
      else
        if primary_key and !properties.member? primary_key
          violations.add "missing primary_key: property"
        end

        properties.each do |name, criteria|
          property_violations = validate_fields(criteria,
            REQUIRED_PROPERTY_FIELDS, OPTIONAL_PROPERTY_FIELDS)
          if property_violations.has_violations?
            violations.concat("malformed property #{name}:",
              property_violations)
          end
        end
      end

      violations
    end

    def validate_fields(entity, required_fields, optional_fields)
      violations = Violations.new
      required_fields.each do |field, type|
        if entity.member? field
          validate_type(entity, field, type, violations)
        else
          violations.add "missing #{field}:"
        end
      end

      optional_fields.each do |field, type|
        validate_type(entity, field, type, violations) if entity.member? field
      end

      violations
    end

    def validate_type(entity, field, type, violations)
      unless entity[field].instance_of? type
        violations.add ("#{field}: should be of type #{type}, " +
         "but is of type #{entity[field].class}")
      end
    end
  end
end
