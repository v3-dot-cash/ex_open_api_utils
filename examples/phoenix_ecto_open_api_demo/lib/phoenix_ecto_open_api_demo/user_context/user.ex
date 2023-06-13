defmodule PhoenixEctoOpenApiDemo.UserContext.User do
  use ExOpenApiUtils
  use Ecto.Schema
  import Ecto.Changeset

  open_api_property(
    schema: %Schema{
      type: :string,
      description: "The id of the user",
      format: :uuid,
      example: "851b18d7-0c88-4095-9969-cbe385926420",
      readOnly: true
    },
    key: :id
  )

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    open_api_property(
      schema: %Schema{type: :string, description: "The name of the user", example: "himangshuj"},
      key: :name
    )

    field :name, :string
    field :tenant_id, :binary_id

    timestamps()
  end

  open_api_schema(
    required: [:name],
    title: "User",
    description: "The User",
    tags: ["User"],
    properties: [:name]
  )

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
