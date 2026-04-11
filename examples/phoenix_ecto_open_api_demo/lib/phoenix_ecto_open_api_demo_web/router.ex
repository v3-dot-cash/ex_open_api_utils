defmodule PhoenixEctoOpenApiDemoWeb.Router do
  use PhoenixEctoOpenApiDemoWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug OpenApiSpex.Plug.PutApiSpec, module: PhoenixEctoOpenApiDemoWeb.ApiSpec
  end

  scope "/api" do
    pipe_through :api

    # Serve the resolved OpenAPI spec over HTTP. Primarily used by the
    # local vitest integration tier's health check (the Makefile polls
    # this endpoint to know when Phoenix is ready) and by contributors
    # who want to fetch the spec in a browser without running
    # `mix openapi.dump`. `OpenApiSpex.Plug.PutApiSpec` in the :api
    # pipeline above seeds the spec into `conn` for this plug to render.
    get "/openapi", OpenApiSpex.Plug.RenderSpec, []
  end

  scope "/api", PhoenixEctoOpenApiDemoWeb do
    pipe_through :api
    resources "/tenants", TenantController, except: [:new, :edit]
    resources "/users", UserController, except: [:new, :edit]
    resources "/businesses", BusinessController, except: [:new, :edit]
    resources "/notifications", NotificationController, except: [:new, :edit]
    resources "/subscriptions", SubscriptionController, except: [:new, :edit]
  end

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:phoenix_ecto_open_api_demo, :dev_routes) do
    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
