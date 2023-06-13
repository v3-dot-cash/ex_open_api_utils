defmodule PhoenixEctoOpenApiDemoWeb.BusinessJSON do
  alias PhoenixEctoOpenApiDemo.BusinessContext.Business

  @doc """
  Renders a list of businesses.
  """
  def index(%{businesses: businesses}) do
    for(business <- businesses, do: data(business))
  end

  @doc """
  Renders a single business.
  """
  def show(%{business: business}) do
    data(business)
  end

  defp data(%Business{} = business) do
    %{
      id: business.id,
      name: business.name
    }
  end
end
