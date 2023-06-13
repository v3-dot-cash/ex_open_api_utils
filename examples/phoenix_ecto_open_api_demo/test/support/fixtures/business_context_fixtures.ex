defmodule PhoenixEctoOpenApiDemo.BusinessContextFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `PhoenixEctoOpenApiDemo.BusinessContext` context.
  """

  @doc """
  Generate a business.
  """
  def business_fixture(attrs \\ %{}) do
    {:ok, business} =
      attrs
      |> Enum.into(%{
        name: "some name"
      })
      |> PhoenixEctoOpenApiDemo.BusinessContext.create_business()

    business
  end
end
