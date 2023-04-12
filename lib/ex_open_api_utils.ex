defmodule ExOpenApiUtils do
  @moduledoc """
  Documentation for `ExOpenApiUtils`.
  """

  defmacro __using__(_opts) do
    quote do
      Module.register_attribute __MODULE__, :open_api_param, accumulate: true
    end
  end

  def get_open_api_properties(module) do
    Module.get_attribute(module, :open_api_param)
  end


  def get_open_api_example(module) do
    Module.get_attribute(module, :open_api_param)
  end
end
