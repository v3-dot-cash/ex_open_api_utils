defmodule PhoenixEctoOpenApiDemoWeb.Router do
  use PhoenixEctoOpenApiDemoWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug OpenApiSpex.Plug.PutApiSpec, module: PhoenixEctoOpenApiDemoWeb.ApiSpec
  end

  scope "/api", PhoenixEctoOpenApiDemoWeb do
    pipe_through :api
    resources "/tenants", TenantController, except: [:new, :edit]
    resources "/users", UserController, except: [:new, :edit]
    resources "/businesses", BusinessController, except: [:new, :edit]
  end

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:phoenix_ecto_open_api_demo, :dev_routes) do
    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
