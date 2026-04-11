defmodule PhoenixEctoOpenApiDemoWeb.BusinessJSON do
  @moduledoc """
  JSON renderer for businesses. Uses `ExOpenApiUtils.Mapper.to_map/1`
  for consistency with the notification, tenant, and user JSON views —
  the mapper walks the `use ExOpenApiUtils` property list and emits
  only the schema-declared fields in the right shape without needing
  to hand-roll a `%{id: ..., name: ...}` map per field.
  """

  def index(%{businesses: businesses}) do
    Enum.map(businesses, &ExOpenApiUtils.Mapper.to_map/1)
  end

  def show(%{business: business}) do
    ExOpenApiUtils.Mapper.to_map(business)
  end
end
