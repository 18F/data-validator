require_relative "../lib/validator"
require "minitest/autorun"

module Validator
  class SchemaValidationTest < ::Minitest::Test
    def test_empty_schema
      actual_exception = assert_raises(SchemaException) do
        validator = Validator.new ''
      end

      assert_equal("Schema failed to parse", actual_exception.to_s)
    end

    def test_well_formed_schema
      schema = [
        "description: Test schema object",
        "used_by:",
        "  - 18F/data-validator",
        "primary_key: name",
        "properties:",
        "  name:",
        "    type: String",
        "    description: A sample object's name",
        "  projects:",
        "    type: Array",
        "    description: A sample object's references to project objects",
        "    key_into: projects",
        "  18f:",
        "    type: Boolean",
        "    description: Determines whether a member is full-time 18F",
        ].join("\n")

      expected = {
        "description" => "Test schema object",
        "used_by" => ["18F/data-validator"],
        "primary_key" => "name",
        "properties" => {
          "name" => {
            "type" => ::String,
            "description" => "A sample object's name"
          },
          "projects" => {
            "type" => ::Array,
            "description" =>
              "A sample object's references to project objects",
            "key_into" => "projects"
          },
          "18f" => {
            "type" => ::TrueClass,
            "description" => "Determines whether a member is full-time 18F"
          }
        }
      }

      validator = Validator.new schema
      assert_equal expected, validator.schema
    end

    def test_well_formed_schema_without_optional_fields
      schema = [
        "description: Test schema object",
        "used_by:",
        "  - 18F/data-validator",
        "properties:",
        "  schema_element:",
        "    type: String",
        ].join("\n")

      expected = {
        "description" => "Test schema object",
        "used_by" => ["18F/data-validator"],
        "properties" => {
          "schema_element" => {"type" => ::String},
        }
      }

      validator = Validator.new schema
      assert_equal expected, validator.schema
    end

    def test_schema_missing_properties
      schema = [
        "used_by: 18F/data-validator",
        ].join("\n")

      expected = [
        "Invalid schema:",
        "  missing description:",
        "  used_by: should be of type Array, but is of type String",
        "  no properties defined",
        ].join("\n")

      actual_exception = assert_raises(SchemaException) do
        validator = Validator.new schema
      end

      assert_equal(expected, actual_exception.to_s)
    end

    def test_schema_missing_primary_key
      schema = [
        "description: Test schema object",
        "used_by:",
        "  - 18F/data-validator",
        "primary_key: missing_property",
        "properties:",
        "  schema_element:",
        "    type: String",
        ].join("\n")

      expected = [
        "Invalid schema:",
        "  missing primary_key: property",
        ].join("\n")

      actual_exception = assert_raises(SchemaException) do
        validator = Validator.new schema
      end

      assert_equal(expected, actual_exception.to_s)
    end

    def test_schema_with_malformed_properties
      schema = [
        "description: Test schema object",
        "used_by:",
        "  - 18F/data-validator",
        "primary_key: name",
        "properties:",
        "  name:",
        "    type: 27",
        "    description:",
        "      - A sample object's name",
        "  projects:",
        "    type: Array",
        "    description: A sample object's references to project objects",
        "    key_into: 27",
        ].join("\n")

      expected = [
        "Invalid schema:",
        "  malformed property name:",
        "    type: should be of type String, but is of type Fixnum",
        "    description: should be of type String, but is of type Array",
        "  malformed property projects:",
        "    key_into: should be of type String, but is of type Fixnum",
        ].join("\n")

      actual_exception = assert_raises(SchemaException) do
        validator = Validator.new schema
      end

      assert_equal(expected, actual_exception.to_s)
    end
  end

  class ObjectValidationTest < ::Minitest::Test
    def setup
      schema = [
        "description: Test schema object",
        "used_by:",
        "  - 18F/data-validator",
        "primary_key: name",
        "properties:",
        "  name:",
        "    type: String",
        "    description: A sample object's name",
        "  projects:",
        "    type: Array",
        "    description: A sample object's references to project objects",
        "    key_into: projects",
        "  pif-round:",
        "    type: Fixnum",
        "    description: PIF class, if applicable",
        "  18f:",
        "    type: Boolean",
        "    description: Determines whether a member is full-time 18F",
      ].join("\n")
      @validator = Validator.new schema
    end

    def test_empty_collection
      actual_exception = assert_raises(Exception) do
        @validator.validate ''
      end

      assert_equal("Object collection failed to parse", actual_exception.to_s)
    end

    def test_element
      collection = [
        "- name: mbland",
        "  projects:",
        "    - hub",
        "  18f: true",
        ].join("\n")

      @validator.validate collection
    end

    def test_multiple_elements
      collection = [
        "- name: mbland",
        "  projects:",
        "    - hub",
        "  18f: true",
        "",
        "- name: gboone",
        "  projects:",
        "    - dashboard",
        "  18f: true",
        ].join("\n")

      @validator.validate collection
    end

    def test_malformed_element
      collection = [
        "- name: 27",
        "  projects: hub",
        "  18f:",
        "  - true",
        ].join("\n")

      expected = [
        "Malformed object:",
        "---",
        "name: 27",
        "projects: hub",
        "18f:",
        "- true",
        "",
        "  name: should be of type String, but is of type Fixnum",
        "  projects: should be of type Array, but is of type String",
        "  18f: should be boolean, but is of type Array",
        ].join("\n")

      actual_exception = assert_raises(Exception) do
        @validator.validate collection
      end

      assert_equal(expected, actual_exception.to_s)
    end

    def test_missing_primary_key
      collection = [
        "- projects:",
        "    - hub",
        "  18f: false",
        ].join("\n")

      expected = [
        "Malformed object:",
        "---",
        "projects:",
        "- hub",
        "18f: false",
        "",
        "  missing primary key field name:",
        ].join("\n")

      actual_exception = assert_raises(Exception) do
        @validator.validate collection
      end

      assert_equal(expected, actual_exception.to_s)
    end

    def test_unknown_property
      collection = [
        "- name: mbland",
        "  projects:",
        "    - hub",
        "  18f: true",
        "  location: DCA",
        ].join("\n")

      expected = [
        "Malformed object:",
        "---",
        "name: mbland",
        "projects:",
        "- hub",
        "18f: true",
        "location: DCA",
        "",
        "  unknown field location:",
        ].join("\n")

      actual_exception = assert_raises(Exception) do
        @validator.validate collection
      end

      assert_equal(expected, actual_exception.to_s)
    end

    def test_not_a_collection
      collection = [
        "name: mbland",
        "projects:",
        "  - hub",
        "18f: true",
        ].join("\n")

      actual_exception = assert_raises(Exception) do
        @validator.validate collection
      end

      assert_equal("Collection is not an Array of objects",
        actual_exception.to_s)
    end
  end
end
