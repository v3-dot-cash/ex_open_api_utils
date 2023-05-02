require ExOpenApiUtils

IO.inspect(OpenApiSpex.Schema.example(ExOpenApiUtils.OpenApiSchema.UserRequest))
IO.inspect(OpenApiSpex.Schema.example(ExOpenApiUtils.OpenApiSchema.UserResponse))


IO.inspect(OpenApiSpex.Schema.example(ExOpenApiUtils.OpenApiSchema.TenantRequest))
IO.inspect(OpenApiSpex.Schema.example(ExOpenApiUtils.OpenApiSchema.TenantResponse))

IO.inspect(ExOpenApiUtils.OpenApiSchema.BusinessRequest.schema.properties)
IO.inspect("-------------")
IO.inspect(ExOpenApiUtils.OpenApiSchema.BusinessRequest.schema.properties.name)
IO.inspect("-------------")
IO.inspect(ExOpenApiUtils.OpenApiSchema.BusinessResponse.schema)


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

{:ok, tenant} = OpenApiSpex.cast_value(%{name: "ACME Corp 12345", to_be_removed_value: "removed"}, ExOpenApiUtils.OpenApiSchema.TenantRequest.schema)

IO.inspect(tenant)
