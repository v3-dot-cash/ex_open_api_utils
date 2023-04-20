require ExOpenApiUtils

IO.inspect(OpenApiSpex.Schema.example(ExOpenApiUtils.OpenApiSchema.User))


IO.inspect(OpenApiSpex.Schema.example(ExOpenApiUtils.OpenApiSchema.Tenant))
IO.inspect(ExOpenApiUtils.OpenApiSchema.Business.schema.properties)
IO.inspect("-------------")
IO.inspect(ExOpenApiUtils.OpenApiSchema.Business.schema.properties.name)
IO.inspect("-------------")
IO.inspect(ExOpenApiUtils.OpenApiSchema.Business.schema)
IO.inspect(ExOpenApiUtils.OpenApiSchema.Business.Request.schema)


IO.inspect(
  ExOpenApiUtils.Json.to_json(%{
    a: "b",
    business: %ExOpenApiUtils.Example.Business{
      name: "Ame Corp",
      tenant: %ExOpenApiUtils.Example.Tenant{
        name: "tenant",
        users: [%ExOpenApiUtils.Example.User{name: "user"}]
      }
    }
  })
)

{:ok, tenant} = OpenApiSpex.cast_value(%{name: "ACME Corp 12345", to_be_removed_value: "removed"}, ExOpenApiUtils.OpenApiSchema.Tenant.schema)

IO.inspect(tenant)
