defmodule PhoenixEctoOpenApiDemoWeb.UserJSON do
  alias PhoenixEctoOpenApiDemo.UserContext.User

  @doc """
  Renders a list of users.
  """
  def index(%{users: users}) do
    for(user <- users, do: data(user))
  end

  @doc """
  Renders a single user.
  """
  def show(%{user: user}) do
    data(user)
  end

  defp data(%User{} = user) do
    ExOpenApiUtils.Mapper.to_map(user)
  end
end
