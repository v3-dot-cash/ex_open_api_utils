defmodule ExOpenApiUtils.Changeset do
  @moduledoc """
  Module to be called inside ecto schemas changeset function for seamless mapping to ecto
  """
  def cast(data, params, permitted, opts \\ []) do
    Ecto.Changeset.cast(data, ExOpenApiUtils.Mapper.to_map(params), permitted, opts)
  end

end
