# Compile support files before running tests
Code.require_file("support/test_schema.ex", __DIR__)
Code.require_file("support/nullable_schema_test.ex", __DIR__)

ExUnit.start()
