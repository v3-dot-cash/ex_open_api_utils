require ExOpenApiUtils
# ExOpenApiUtils.create_schema(ExOpenApiUtils.Example.User)

# IO.inspect(OpenApiSpex.Schema.example(ExOpenApiUtils.Example.User.OpenApiSchema))

# ExOpenApiUtils.create_schema(ExOpenApiUtils.Example.Tenant)
# ExOpenApiUtils.create_schema(ExOpenApiUtils.Example.Business)

# IO.inspect(OpenApiSpex.Schema.example(ExOpenApiUtils.Example.Tenant.OpenApiSchema))
# IO.inspect(ExOpenApiUtils.Example.Business.OpenApiSchema.schema.properties)
# IO.inspect("-------------")
# IO.inspect(ExOpenApiUtils.Example.Business.OpenApiSchema.schema.properties.name)
# IO.inspect("-------------")
IO.inspect(ExOpenApiUtils.Example.Business.OpenApiSchema.schema)
IO.inspect(ExOpenApiUtils.Example.Business.Request.schema)


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
