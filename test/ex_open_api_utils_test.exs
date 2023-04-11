defmodule ExOpenApiUtilsTest do
  use ExUnit.Case
  doctest ExOpenApiUtils

  test "greets the world" do
    assert ExOpenApiUtils.hello() == :world
  end
end
