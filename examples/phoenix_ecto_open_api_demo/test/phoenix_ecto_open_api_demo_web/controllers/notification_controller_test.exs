defmodule PhoenixEctoOpenApiDemoWeb.NotificationControllerTest do
  @moduledoc """
  End-to-end tests for the polymorphic-embed backed `Notification` resource.

  Every create/update/show test:

    1. Goes through the full Phoenix pipeline with
       `OpenApiSpex.Plug.CastAndValidate` on the request side — the request
       body is cast into a typed `%NotificationRequest{channel: %*Request{}}`
       struct via discriminator dispatch before the controller runs.

    2. Takes the raw JSON response body and feeds it back through
       `OpenApiSpex.Cast.cast/4` against the resolved
       `NotificationResponse` schema in `@api_spec.components.schemas`.
       The call uses `read_write_scope: :read` so required `writeOnly`
       fields are skipped on the response side. On success it returns a
       real `%NotificationResponseSchema{}` struct whose `:channel` is the
       correct variant struct (`%NotificationEmailResponse{}`, `%NotificationSmsResponse{}`, or
       `%NotificationWebhookResponse{}`) dispatched from the oneOf.

    3. Does a full deep pattern-match on the cast struct — every variant
       field asserted by name and value — and separately verifies the
       persisted Ecto variant struct hydrated from JSONB matches the same
       values verbatim.

  The response-side `Cast.cast` call is the GH-21 regression lock (the
  focused-cast-errors path runs on every test), and the deep channel
  checks + persistence round-trips are the GH-24 regression lock.
  """
  use PhoenixEctoOpenApiDemoWeb.ConnCase

  import PhoenixEctoOpenApiDemo.NotificationContextFixtures

  alias OpenApiSpex.Cast
  alias PhoenixEctoOpenApiDemo.NotificationContext
  alias PhoenixEctoOpenApiDemo.NotificationContext.Email
  alias PhoenixEctoOpenApiDemo.NotificationContext.Notification
  alias PhoenixEctoOpenApiDemo.NotificationContext.Sms
  alias PhoenixEctoOpenApiDemo.NotificationContext.Webhook

  # Auto-generated OpenApiSpex response submodules. They are real Elixir
  # structs (OpenApiSpex.schema/1 sets x-struct to the module itself), so
  # Cast.cast returns typed struct values we can pattern-match on. The
  # parent-contextual siblings (NotificationEmailResponse, etc.) are the
  # modules the GH-30 fix generates via open_api_polymorphic_property/1's
  # allOf composition — they carry the discriminator as a real defstruct
  # field and are the ones the parent's discriminator.mapping routes to.
  alias PhoenixEctoOpenApiDemo.OpenApiSchema.NotificationEmailResponse
  alias PhoenixEctoOpenApiDemo.OpenApiSchema.NotificationResponse, as: NotificationResponseSchema
  alias PhoenixEctoOpenApiDemo.OpenApiSchema.NotificationSmsResponse
  alias PhoenixEctoOpenApiDemo.OpenApiSchema.NotificationWebhookResponse

  @api_spec PhoenixEctoOpenApiDemoWeb.ApiSpec.spec()

  @email_attrs %{
    subject: "Your order has shipped",
    channel: %{
      channel_type: "email",
      to: "buyer@example.com",
      from: "store@example.com",
      body: "Tracking: 1Z999AA10123456784"
    }
  }

  @sms_attrs %{
    subject: "Verification code",
    channel: %{
      channel_type: "sms",
      phone_number: "+15551234567",
      body: "Your code is 4242"
    }
  }

  @webhook_attrs %{
    subject: "Order event",
    channel: %{
      channel_type: "webhook",
      url: "https://hooks.example.com/abc",
      method: "POST"
    }
  }

  setup %{conn: conn} do
    {:ok,
     conn:
       conn
       |> put_req_header("accept", "application/json")
       |> put_req_header("content-type", "application/json")}
  end

  describe "index" do
    test "returns empty list when no notifications exist", %{conn: conn} do
      conn = get(conn, ~p"/api/notifications")
      assert json_response(conn, 200) == []
    end

    test "returns a mixed list where each channel casts to its variant struct", %{conn: conn} do
      email_notification_fixture()
      sms_notification_fixture()
      webhook_notification_fixture()

      conn = get(conn, ~p"/api/notifications")
      body = json_response(conn, 200)
      assert length(body) == 3

      # Cast each item individually against NotificationResponse so the
      # oneOf dispatch produces a concrete variant struct for every row.
      schemas = @api_spec.components.schemas
      notification_schema = Map.fetch!(schemas, "NotificationResponse")

      cast_items =
        Enum.map(body, fn item ->
          assert {:ok, cast} =
                   Cast.cast(notification_schema, item, schemas, read_write_scope: :read)

          cast
        end)

      by_variant =
        Enum.group_by(cast_items, fn
          %NotificationResponseSchema{channel: %NotificationEmailResponse{}} -> :email
          %NotificationResponseSchema{channel: %NotificationSmsResponse{}} -> :sms
          %NotificationResponseSchema{channel: %NotificationWebhookResponse{}} -> :webhook
        end)

      assert length(by_variant[:email]) == 1
      assert length(by_variant[:sms]) == 1
      assert length(by_variant[:webhook]) == 1

      assert [
               %NotificationResponseSchema{
                 id: email_id,
                 subject: "Your order has shipped",
                 channel: %NotificationEmailResponse{
                   to: "buyer@example.com",
                   from: "store@example.com",
                   body: "Tracking: 1Z999AA10123456784"
                 }
               }
             ] = by_variant[:email]

      assert is_binary(email_id)

      assert [
               %NotificationResponseSchema{
                 subject: "Verification code",
                 channel: %NotificationSmsResponse{
                   phone_number: "+15551234567",
                   body: "Your code is 4242"
                 }
               }
             ] = by_variant[:sms]

      assert [
               %NotificationResponseSchema{
                 subject: "Order event",
                 channel: %NotificationWebhookResponse{
                   url: "https://hooks.example.com/abc",
                   method: "POST"
                 }
               }
             ] = by_variant[:webhook]
    end
  end

  describe "create email notification" do
    test "returns 201, cast body is %NotificationResponseSchema{channel: %NotificationEmailResponse{}}",
         %{
           conn: conn
         } do
      conn = post(conn, ~p"/api/notifications", @email_attrs)
      body = json_response(conn, 201)

      schemas = @api_spec.components.schemas
      schema = Map.fetch!(schemas, "NotificationResponse")

      assert {:ok, cast} = Cast.cast(schema, body, schemas, read_write_scope: :read)

      # Deep pattern match on the cast struct — every variant field checked
      # by name, variant struct asserted, nothing from other variants
      # allowed through.
      assert %NotificationResponseSchema{
               id: id,
               subject: "Your order has shipped",
               channel: %NotificationEmailResponse{
                 to: "buyer@example.com",
                 from: "store@example.com",
                 body: "Tracking: 1Z999AA10123456784"
               }
             } = cast

      assert is_binary(id)
      assert {:ok, _} = Ecto.UUID.cast(id)

      # Persistence round-trip: the Ecto variant struct hydrated from JSONB
      # must contain every field verbatim.
      assert %Notification{
               id: ^id,
               subject: "Your order has shipped",
               channel: %Email{
                 to: "buyer@example.com",
                 from: "store@example.com",
                 body: "Tracking: 1Z999AA10123456784"
               }
             } = NotificationContext.get_notification!(id)
    end

    test "returns 422 when required email field is missing", %{conn: conn} do
      invalid = %{subject: "x", channel: %{channel_type: "email", to: "a@b"}}
      conn = post(conn, ~p"/api/notifications", invalid)
      assert %{"errors" => _} = json_response(conn, 422)
    end

    test "returns 422 when discriminator is missing (:no_value_for_discriminator)", %{conn: conn} do
      invalid = %{subject: "x", channel: %{to: "a@b", from: "c@d", body: "e"}}
      conn = post(conn, ~p"/api/notifications", invalid)
      assert %{"errors" => _} = json_response(conn, 422)
    end

    test "returns 422 when discriminator is bogus (:invalid_discriminator_value)", %{conn: conn} do
      invalid = %{subject: "x", channel: %{channel_type: "carrier_pigeon"}}
      conn = post(conn, ~p"/api/notifications", invalid)
      assert %{"errors" => _} = json_response(conn, 422)
    end
  end

  describe "create sms notification" do
    test "returns 201, cast body is %NotificationResponseSchema{channel: %NotificationSmsResponse{}}",
         %{
           conn: conn
         } do
      conn = post(conn, ~p"/api/notifications", @sms_attrs)
      body = json_response(conn, 201)

      schemas = @api_spec.components.schemas
      schema = Map.fetch!(schemas, "NotificationResponse")

      assert {:ok, cast} = Cast.cast(schema, body, schemas, read_write_scope: :read)

      assert %NotificationResponseSchema{
               id: id,
               subject: "Verification code",
               channel: %NotificationSmsResponse{
                 phone_number: "+15551234567",
                 body: "Your code is 4242"
               }
             } = cast

      assert is_binary(id)
      assert {:ok, _} = Ecto.UUID.cast(id)

      assert %Notification{
               id: ^id,
               subject: "Verification code",
               channel: %Sms{
                 phone_number: "+15551234567",
                 body: "Your code is 4242"
               }
             } = NotificationContext.get_notification!(id)
    end

    test "returns 422 when phone_number missing", %{conn: conn} do
      invalid = %{subject: "x", channel: %{channel_type: "sms", body: "hi"}}
      conn = post(conn, ~p"/api/notifications", invalid)
      assert %{"errors" => _} = json_response(conn, 422)
    end

    test "returns 422 when body missing", %{conn: conn} do
      invalid = %{subject: "x", channel: %{channel_type: "sms", phone_number: "+15551234567"}}
      conn = post(conn, ~p"/api/notifications", invalid)
      assert %{"errors" => _} = json_response(conn, 422)
    end
  end

  describe "create webhook notification" do
    test "returns 201, cast body is %NotificationResponseSchema{channel: %NotificationWebhookResponse{}}",
         %{
           conn: conn
         } do
      conn = post(conn, ~p"/api/notifications", @webhook_attrs)
      body = json_response(conn, 201)

      schemas = @api_spec.components.schemas
      schema = Map.fetch!(schemas, "NotificationResponse")

      assert {:ok, cast} = Cast.cast(schema, body, schemas, read_write_scope: :read)

      assert %NotificationResponseSchema{
               id: id,
               subject: "Order event",
               channel: %NotificationWebhookResponse{
                 url: "https://hooks.example.com/abc",
                 method: "POST"
               }
             } = cast

      assert is_binary(id)
      assert {:ok, _} = Ecto.UUID.cast(id)

      assert %Notification{
               id: ^id,
               subject: "Order event",
               channel: %Webhook{
                 url: "https://hooks.example.com/abc",
                 method: "POST"
               }
             } = NotificationContext.get_notification!(id)
    end

    test "returns 422 when method is not one of the enum", %{conn: conn} do
      invalid = %{
        subject: "x",
        channel: %{
          channel_type: "webhook",
          url: "https://hooks.example.com/abc",
          method: "TELEPORT"
        }
      }

      conn = post(conn, ~p"/api/notifications", invalid)
      assert %{"errors" => _} = json_response(conn, 422)
    end
  end

  describe "show notification" do
    test "shows an email notification, cast.channel is %NotificationEmailResponse{}", %{
      conn: conn
    } do
      notification = email_notification_fixture()

      conn = get(conn, ~p"/api/notifications/#{notification.id}")
      body = json_response(conn, 200)

      schemas = @api_spec.components.schemas
      schema = Map.fetch!(schemas, "NotificationResponse")
      assert {:ok, cast} = Cast.cast(schema, body, schemas, read_write_scope: :read)

      assert %NotificationResponseSchema{
               id: notification_id,
               subject: "Your order has shipped",
               channel: %NotificationEmailResponse{
                 to: "buyer@example.com",
                 from: "store@example.com",
                 body: "Tracking: 1Z999AA10123456784"
               }
             } = cast

      assert notification_id == notification.id
    end

    test "shows an sms notification, cast.channel is %NotificationSmsResponse{}", %{conn: conn} do
      notification = sms_notification_fixture()

      conn = get(conn, ~p"/api/notifications/#{notification.id}")
      body = json_response(conn, 200)

      schemas = @api_spec.components.schemas
      schema = Map.fetch!(schemas, "NotificationResponse")
      assert {:ok, cast} = Cast.cast(schema, body, schemas, read_write_scope: :read)

      assert %NotificationResponseSchema{
               id: notification_id,
               subject: "Verification code",
               channel: %NotificationSmsResponse{
                 phone_number: "+15551234567",
                 body: "Your code is 4242"
               }
             } = cast

      assert notification_id == notification.id
    end

    test "shows a webhook notification, cast.channel is %NotificationWebhookResponse{}", %{
      conn: conn
    } do
      notification = webhook_notification_fixture()

      conn = get(conn, ~p"/api/notifications/#{notification.id}")
      body = json_response(conn, 200)

      schemas = @api_spec.components.schemas
      schema = Map.fetch!(schemas, "NotificationResponse")
      assert {:ok, cast} = Cast.cast(schema, body, schemas, read_write_scope: :read)

      assert %NotificationResponseSchema{
               id: notification_id,
               subject: "Order event",
               channel: %NotificationWebhookResponse{
                 url: "https://hooks.example.com/abc",
                 method: "POST"
               }
             } = cast

      assert notification_id == notification.id
    end

    test "returns 404 for a non-existent id", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, ~p"/api/notifications/851b18d7-0c88-4095-9969-cbe385926420")
      end
    end
  end

  describe "update notification" do
    test "updates only the subject, cast.channel still %NotificationEmailResponse{}", %{
      conn: conn
    } do
      notification = email_notification_fixture()

      update_attrs = %{
        subject: "Updated subject",
        channel: %{
          channel_type: "email",
          to: "buyer@example.com",
          from: "store@example.com",
          body: "Tracking: 1Z999AA10123456784"
        }
      }

      conn = put(conn, ~p"/api/notifications/#{notification}", update_attrs)
      body = json_response(conn, 200)

      schemas = @api_spec.components.schemas
      schema = Map.fetch!(schemas, "NotificationResponse")
      assert {:ok, cast} = Cast.cast(schema, body, schemas, read_write_scope: :read)

      assert %NotificationResponseSchema{
               id: id,
               subject: "Updated subject",
               channel: %NotificationEmailResponse{
                 to: "buyer@example.com",
                 from: "store@example.com",
                 body: "Tracking: 1Z999AA10123456784"
               }
             } = cast

      assert id == notification.id
    end

    test "switches channel variant from email to sms (on_replace: :update)", %{conn: conn} do
      notification = email_notification_fixture()

      update_attrs = %{
        subject: "Now over SMS",
        channel: %{
          channel_type: "sms",
          phone_number: "+15551234567",
          body: "Your code is 4242"
        }
      }

      conn = put(conn, ~p"/api/notifications/#{notification}", update_attrs)
      body = json_response(conn, 200)

      schemas = @api_spec.components.schemas
      schema = Map.fetch!(schemas, "NotificationResponse")
      assert {:ok, cast} = Cast.cast(schema, body, schemas, read_write_scope: :read)

      # The channel must have cast into the new variant, not the original.
      assert %NotificationResponseSchema{
               id: id,
               subject: "Now over SMS",
               channel: %NotificationSmsResponse{
                 phone_number: "+15551234567",
                 body: "Your code is 4242"
               }
             } = cast

      assert id == notification.id

      assert %Notification{
               id: ^id,
               channel: %Sms{
                 phone_number: "+15551234567",
                 body: "Your code is 4242"
               }
             } = NotificationContext.get_notification!(id)
    end

    test "switches channel variant from sms to webhook", %{conn: conn} do
      notification = sms_notification_fixture()

      update_attrs = %{
        subject: "Now over webhook",
        channel: %{
          channel_type: "webhook",
          url: "https://hooks.example.com/new",
          method: "POST"
        }
      }

      conn = put(conn, ~p"/api/notifications/#{notification}", update_attrs)
      body = json_response(conn, 200)

      schemas = @api_spec.components.schemas
      schema = Map.fetch!(schemas, "NotificationResponse")
      assert {:ok, cast} = Cast.cast(schema, body, schemas, read_write_scope: :read)

      assert %NotificationResponseSchema{
               id: id,
               subject: "Now over webhook",
               channel: %NotificationWebhookResponse{
                 url: "https://hooks.example.com/new",
                 method: "POST"
               }
             } = cast

      assert id == notification.id

      assert %Notification{
               id: ^id,
               channel: %Webhook{
                 url: "https://hooks.example.com/new",
                 method: "POST"
               }
             } = NotificationContext.get_notification!(id)
    end

    test "returns 422 when update is invalid", %{conn: conn} do
      notification = email_notification_fixture()

      invalid = %{
        subject: "x",
        channel: %{channel_type: "email", to: "only-to"}
      }

      conn = put(conn, ~p"/api/notifications/#{notification}", invalid)
      assert %{"errors" => _} = json_response(conn, 422)
    end
  end

  describe "delete notification" do
    test "deletes the notification", %{conn: conn} do
      notification = webhook_notification_fixture()

      conn = delete(conn, ~p"/api/notifications/#{notification}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/notifications/#{notification}")
      end
    end
  end

  describe "discriminator atom persistence (GH-27 regression lock, Phoenix flow)" do
    # Bytecode-level assertion: walk the `abstract_code` chunk of the
    # compiled Mapper impl's .beam and verify that `:channel_type` is
    # present as an `{:atom, line, name}` literal.  This is the canonical
    # pre-optimization AST emitted by the Elixir compiler — if the atom
    # is anywhere in the compiled module, it will show up here.
    #
    # A simple check against the `:atoms` chunk (`AtU8`) would miss atoms
    # that live only in the literal pool (`LitT`), which is where
    # `Macro.escape`-d compile-time maps end up.  The BEAM loader
    # materializes those atoms at module-load time regardless of AtU8
    # membership, so the abstract_code walk is both broader and stricter.
    #
    # The example app compiles its test support to real .beam files via
    # `elixirc_paths(:test) -> ["lib", "test/support"]`, so `:code.which/1`
    # returns an on-disk path and `:beam_lib.chunks/2` reads it directly.

    defp collect_atoms({:atom, _line, name}, acc) when is_atom(name) do
      MapSet.put(acc, name)
    end

    defp collect_atoms(tuple, acc) when is_tuple(tuple) do
      tuple
      |> Tuple.to_list()
      |> Enum.reduce(acc, &collect_atoms/2)
    end

    defp collect_atoms(list, acc) when is_list(list) do
      Enum.reduce(list, acc, &collect_atoms/2)
    end

    defp collect_atoms(_, acc), do: acc

    defp literal_atoms_in(module) do
      # Build the beam path directly from Mix.Project.compile_path/0
      # instead of via :code.which/1. Under `mix test --cover` the cover
      # tool replaces the in-memory loaded module with a cover-instrumented
      # version, and :code.which/1 then returns :cover_compiled instead
      # of the on-disk path — which breaks the beam_lib read. The plain
      # compile's .beam is still on disk untouched, and that's the
      # artifact GH-27 actually cares about (it's the one the BEAM loader
      # will materialize in production), so read it directly.
      beam_path =
        Mix.Project.compile_path()
        |> Path.join("#{module}.beam")
        |> String.to_charlist()

      {:ok, {_, [{:abstract_code, {:raw_abstract_v1, forms}}]}} =
        :beam_lib.chunks(beam_path, [:abstract_code])

      collect_atoms(forms, MapSet.new())
    end

    test "NotificationRequest Mapper impl .beam contains :channel_type" do
      atoms =
        literal_atoms_in(
          ExOpenApiUtils.Mapper.PhoenixEctoOpenApiDemo.OpenApiSchema.NotificationRequest
        )

      assert :channel_type in atoms
    end

    test "NotificationResponse Mapper impl .beam contains :channel_type" do
      atoms =
        literal_atoms_in(
          ExOpenApiUtils.Mapper.PhoenixEctoOpenApiDemo.OpenApiSchema.NotificationResponse
        )

      assert :channel_type in atoms
    end
  end

  describe "Mapper round-trip coverage for generated notification submodules" do
    # Phoenix's Controller.json/2 goes straight to Jason.encode! on
    # response structs, so the library-derived :from_open_api Mapper
    # impls on Notification's response submodules and on the original
    # flat variant submodules never get called through the normal HTTP
    # pipeline. These tests exercise each one directly by constructing
    # the struct and calling Mapper.to_map/1, proving that consumers
    # who want to re-serialize a response struct (for example via
    # `response |> Mapper.to_map() |> cast_to_schema(NotificationResponse)`)
    # get the expected atom-keyed shape out.

    alias PhoenixEctoOpenApiDemo.OpenApiSchema.EmailRequest
    alias PhoenixEctoOpenApiDemo.OpenApiSchema.EmailResponse
    alias PhoenixEctoOpenApiDemo.OpenApiSchema.SmsRequest
    alias PhoenixEctoOpenApiDemo.OpenApiSchema.SmsResponse
    alias PhoenixEctoOpenApiDemo.OpenApiSchema.WebhookRequest
    alias PhoenixEctoOpenApiDemo.OpenApiSchema.WebhookResponse

    test "Mapper.to_map on NotificationResponse + parent-contextual email channel" do
      struct = %NotificationResponseSchema{
        id: "n_123",
        subject: "Your order has shipped",
        channel: %NotificationEmailResponse{
          to: "buyer@example.com",
          from: "store@example.com",
          body: "Tracking: 1Z999",
          channel_type: "email"
        }
      }

      map = ExOpenApiUtils.Mapper.to_map(struct)

      assert is_map(map)
      assert map[:id] == "n_123"
      assert map[:subject] == "Your order has shipped"
      assert is_map(map[:channel])
    end

    test "Mapper.to_map on NotificationResponse + parent-contextual sms channel" do
      struct = %NotificationResponseSchema{
        id: "n_124",
        subject: "Verification code",
        channel: %NotificationSmsResponse{
          phone_number: "+15551234567",
          body: "Your code is 4242",
          channel_type: "sms"
        }
      }

      map = ExOpenApiUtils.Mapper.to_map(struct)
      assert map[:id] == "n_124"
      assert is_map(map[:channel])
    end

    test "Mapper.to_map on NotificationResponse + parent-contextual webhook channel" do
      struct = %NotificationResponseSchema{
        id: "n_125",
        subject: "Order event",
        channel: %NotificationWebhookResponse{
          url: "https://hooks.example.com/abc",
          method: "POST",
          channel_type: "webhook"
        }
      }

      map = ExOpenApiUtils.Mapper.to_map(struct)
      assert map[:id] == "n_125"
      assert is_map(map[:channel])
    end

    test "Mapper.to_map on standalone flat variant Request submodules" do
      for struct <- [
            %EmailRequest{to: "a@b", from: "c@d", body: "x"},
            %SmsRequest{phone_number: "+15551234567", body: "y"},
            %WebhookRequest{url: "https://example.com", method: "POST"}
          ] do
        map = ExOpenApiUtils.Mapper.to_map(struct)
        assert is_map(map)
        refute Map.has_key?(map, :__struct__)
      end
    end

    test "Mapper.to_map on standalone flat variant Response submodules" do
      for struct <- [
            %EmailResponse{to: "a@b", from: "c@d", body: "x"},
            %SmsResponse{phone_number: "+15551234567", body: "y"},
            %WebhookResponse{url: "https://example.com", method: "POST"}
          ] do
        map = ExOpenApiUtils.Mapper.to_map(struct)
        assert is_map(map)
        refute Map.has_key?(map, :__struct__)
      end
    end
  end
end
