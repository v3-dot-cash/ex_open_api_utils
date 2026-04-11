defmodule PhoenixEctoOpenApiDemo.AuditContextTest do
  @moduledoc """
  Context-only paranoia coverage for `polymorphic_embed_discriminator/1`.

  The audit fixture exists specifically to lock the GH-27 bytecode
  persistence guarantee in a scenario that has no Phoenix controller
  wrapping it — the library consumer touches only the Ecto context.

  The `:audit_kind` wire discriminator is chosen so that it does not
  appear as an atom literal anywhere else in the project. Under the
  GH-27 bug, the only place the atom could exist is the runtime atom
  table at compile time; after the fix, it is baked into the derived
  Mapper impl module's `.beam` atom chunk.
  """
  use PhoenixEctoOpenApiDemo.DataCase

  import PhoenixEctoOpenApiDemo.AuditContextFixtures

  alias PhoenixEctoOpenApiDemo.AuditContext
  alias PhoenixEctoOpenApiDemo.AuditContext.AuditEvent
  alias PhoenixEctoOpenApiDemo.AuditContext.DataExportEvent
  alias PhoenixEctoOpenApiDemo.AuditContext.UserLoginEvent

  describe "create_audit_event/1" do
    test "round-trips a user-login payload through polymorphic_embed" do
      event = user_login_audit_fixture()
      reloaded = AuditContext.get_audit_event!(event.id)

      assert %AuditEvent{
               actor: "api-token-42",
               payload: %UserLoginEvent{
                 user_id: "u_123",
                 ip_address: "10.0.0.1"
               }
             } = reloaded
    end

    test "round-trips a data-export payload through polymorphic_embed" do
      event = data_export_audit_fixture()
      reloaded = AuditContext.get_audit_event!(event.id)

      assert %AuditEvent{
               actor: "api-token-42",
               payload: %DataExportEvent{
                 resource: "users",
                 row_count: 42
               }
             } = reloaded
    end
  end

  describe "generated OpenApiSchema submodules (audit tier)" do
    # The audit tier is deliberately context-only — there's no Phoenix
    # controller exercising the generated OpenApiSchema submodules via
    # a full cast pipeline. These smoke tests call each submodule's
    # auto-generated `schema/0` reflection helper so the generated
    # functions get exercised at least once from the test path. Also
    # verifies that the parent-contextual siblings from the GH-30 fix
    # (AuditEventUserLoginEvent* / AuditEventDataExportEvent*) are
    # actually emitted by the library's __before_compile__.

    alias PhoenixEctoOpenApiDemo.OpenApiSchema.AuditEventDataExportEventRequest
    alias PhoenixEctoOpenApiDemo.OpenApiSchema.AuditEventDataExportEventResponse
    alias PhoenixEctoOpenApiDemo.OpenApiSchema.AuditEventRequest
    alias PhoenixEctoOpenApiDemo.OpenApiSchema.AuditEventResponse
    alias PhoenixEctoOpenApiDemo.OpenApiSchema.AuditEventUserLoginEventRequest
    alias PhoenixEctoOpenApiDemo.OpenApiSchema.AuditEventUserLoginEventResponse
    alias PhoenixEctoOpenApiDemo.OpenApiSchema.DataExportEventRequest
    alias PhoenixEctoOpenApiDemo.OpenApiSchema.DataExportEventResponse
    alias PhoenixEctoOpenApiDemo.OpenApiSchema.UserLoginEventRequest
    alias PhoenixEctoOpenApiDemo.OpenApiSchema.UserLoginEventResponse

    test "AuditEventRequest / AuditEventResponse expose the expected parent shape" do
      assert %OpenApiSpex.Schema{title: "AuditEventRequest", type: :object} =
               AuditEventRequest.schema()

      assert %OpenApiSpex.Schema{title: "AuditEventResponse", type: :object} =
               AuditEventResponse.schema()
    end

    test "flat variant siblings (UserLoginEvent, DataExportEvent) are generated" do
      assert %OpenApiSpex.Schema{title: "UserLoginEventRequest"} =
               UserLoginEventRequest.schema()

      assert %OpenApiSpex.Schema{title: "UserLoginEventResponse"} =
               UserLoginEventResponse.schema()

      assert %OpenApiSpex.Schema{title: "DataExportEventRequest"} =
               DataExportEventRequest.schema()

      assert %OpenApiSpex.Schema{title: "DataExportEventResponse"} =
               DataExportEventResponse.schema()
    end

    test "parent-contextual siblings from the GH-30 fix are generated via allOf" do
      # AuditEventUserLoginEventRequest / Response etc. are created by
      # AuditEvent's __before_compile__ from the open_api_polymorphic_property
      # declaration. Each one has an allOf composition body that carries the
      # discriminator as a real defstruct field.
      assert %OpenApiSpex.Schema{allOf: all_of_req} =
               AuditEventUserLoginEventRequest.schema()

      assert length(all_of_req) == 2

      assert %OpenApiSpex.Schema{allOf: all_of_res} =
               AuditEventUserLoginEventResponse.schema()

      assert length(all_of_res) == 2

      assert %OpenApiSpex.Schema{allOf: _} = AuditEventDataExportEventRequest.schema()
      assert %OpenApiSpex.Schema{allOf: _} = AuditEventDataExportEventResponse.schema()
    end

    test "parent-contextual sibling defstruct carries :audit_kind from the GH-30 fix" do
      # Real defstruct field — not added via Map.put at runtime. This is
      # what lets Kernel.struct/2 preserve it through Cast.AllOf.
      keys = %AuditEventUserLoginEventResponse{} |> Map.from_struct() |> Map.keys()
      assert :audit_kind in keys

      keys = %AuditEventDataExportEventResponse{} |> Map.from_struct() |> Map.keys()
      assert :audit_kind in keys
    end
  end

  describe "Mapper.to_map/1 outbound serialization" do
    test "emits wire key \"audit_kind\" for a user-login payload" do
      event = user_login_audit_fixture()
      map = ExOpenApiUtils.Mapper.to_map(event)

      assert map["actor"] == "api-token-42"
      assert map["payload"]["audit_kind"] == "user_login"
      assert map["payload"]["user_id"] == "u_123"
      assert map["payload"]["ip_address"] == "10.0.0.1"
    end

    test "emits wire key \"audit_kind\" for a data-export payload" do
      event = data_export_audit_fixture()
      map = ExOpenApiUtils.Mapper.to_map(event)

      assert map["payload"]["audit_kind"] == "data_export"
      assert map["payload"]["resource"] == "users"
      assert map["payload"]["row_count"] == 42
    end
  end

  describe "Mapper round-trip coverage for generated submodules" do
    # The audit tier is context-only, so the full Phoenix cast pipeline
    # never runs against audit structs. The library still derives a
    # Mapper impl for every auto-generated submodule, though — both the
    # Request/Response flavors and the parent-contextual siblings from
    # the GH-30 fix. These tests exercise each one directly by
    # constructing the struct and calling Mapper.to_map/1, asserting
    # that the result is a plain atom-keyed map carrying the expected
    # fields. Covers every `ExOpenApiUtils.Mapper.PhoenixEctoOpenApiDemo.
    # OpenApiSchema.*` impl that the audit fixture generates.

    alias PhoenixEctoOpenApiDemo.OpenApiSchema.AuditEventDataExportEventRequest
    alias PhoenixEctoOpenApiDemo.OpenApiSchema.AuditEventDataExportEventResponse
    alias PhoenixEctoOpenApiDemo.OpenApiSchema.AuditEventRequest
    alias PhoenixEctoOpenApiDemo.OpenApiSchema.AuditEventResponse
    alias PhoenixEctoOpenApiDemo.OpenApiSchema.AuditEventUserLoginEventRequest
    alias PhoenixEctoOpenApiDemo.OpenApiSchema.AuditEventUserLoginEventResponse
    alias PhoenixEctoOpenApiDemo.OpenApiSchema.DataExportEventRequest
    alias PhoenixEctoOpenApiDemo.OpenApiSchema.DataExportEventResponse
    alias PhoenixEctoOpenApiDemo.OpenApiSchema.UserLoginEventRequest
    alias PhoenixEctoOpenApiDemo.OpenApiSchema.UserLoginEventResponse

    test "Mapper.to_map on AuditEventRequest emits expected inbound shape" do
      struct = %AuditEventRequest{
        actor: "api-token-42",
        payload: %AuditEventUserLoginEventRequest{
          user_id: "u_123",
          ip_address: "10.0.0.1",
          audit_kind: "user_login"
        }
      }

      map = ExOpenApiUtils.Mapper.to_map(struct)

      assert is_map(map)
      assert map[:actor] == "api-token-42"
      assert is_map(map[:payload])
    end

    test "Mapper.to_map on AuditEventResponse emits expected outbound shape" do
      struct = %AuditEventResponse{
        id: "evt_123",
        actor: "api-token-42",
        payload: %AuditEventUserLoginEventResponse{
          user_id: "u_123",
          ip_address: "10.0.0.1",
          audit_kind: "user_login"
        }
      }

      map = ExOpenApiUtils.Mapper.to_map(struct)

      assert is_map(map)
      assert map[:id] == "evt_123"
      assert map[:actor] == "api-token-42"
      assert is_map(map[:payload])
    end

    test "Mapper.to_map on parent-contextual sibling Request variants" do
      for struct <- [
            %AuditEventUserLoginEventRequest{
              user_id: "u_123",
              ip_address: "10.0.0.1",
              audit_kind: "user_login"
            },
            %AuditEventDataExportEventRequest{
              resource: "users",
              row_count: 42,
              audit_kind: "data_export"
            }
          ] do
        map = ExOpenApiUtils.Mapper.to_map(struct)
        assert is_map(map)
        refute Map.has_key?(map, :__struct__)
      end
    end

    test "Mapper.to_map on parent-contextual sibling Response variants" do
      for struct <- [
            %AuditEventUserLoginEventResponse{
              user_id: "u_123",
              ip_address: "10.0.0.1",
              audit_kind: "user_login"
            },
            %AuditEventDataExportEventResponse{
              resource: "users",
              row_count: 42,
              audit_kind: "data_export"
            }
          ] do
        map = ExOpenApiUtils.Mapper.to_map(struct)
        assert is_map(map)
        refute Map.has_key?(map, :__struct__)
      end
    end

    test "Mapper.to_map on standalone flat variant Request submodules" do
      for struct <- [
            %UserLoginEventRequest{user_id: "u_123", ip_address: "10.0.0.1"},
            %DataExportEventRequest{resource: "users", row_count: 42}
          ] do
        map = ExOpenApiUtils.Mapper.to_map(struct)
        assert is_map(map)
        refute Map.has_key?(map, :__struct__)
      end
    end

    test "Mapper.to_map on standalone flat variant Response submodules" do
      for struct <- [
            %UserLoginEventResponse{user_id: "u_123", ip_address: "10.0.0.1"},
            %DataExportEventResponse{resource: "users", row_count: 42}
          ] do
        map = ExOpenApiUtils.Mapper.to_map(struct)
        assert is_map(map)
        refute Map.has_key?(map, :__struct__)
      end
    end
  end

  describe "discriminator atom persistence (GH-27 regression lock, context-only)" do
    # Bytecode-level assertion: walk the `abstract_code` chunk of the
    # compiled Mapper impl's .beam and verify that `:audit_kind` is
    # present as an `{:atom, line, name}` literal.
    #
    # A check against the `:atoms` chunk (`AtU8`) would miss atoms that
    # live only in the literal pool (`LitT`), which is where
    # `Macro.escape`-d compile-time maps get stored.  The BEAM loader
    # materializes those atoms at module-load time, so the abstract_code
    # walk is the right way to verify the atom will survive into any
    # freshly started BEAM.
    #
    # Both Request and Response Mapper impls are covered because each
    # receives its own `Protocol.derive` call inside `__before_compile__`.

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

    test "AuditEventRequest Mapper impl .beam contains :audit_kind" do
      atoms =
        literal_atoms_in(
          ExOpenApiUtils.Mapper.PhoenixEctoOpenApiDemo.OpenApiSchema.AuditEventRequest
        )

      assert :audit_kind in atoms
    end

    test "AuditEventResponse Mapper impl .beam contains :audit_kind" do
      atoms =
        literal_atoms_in(
          ExOpenApiUtils.Mapper.PhoenixEctoOpenApiDemo.OpenApiSchema.AuditEventResponse
        )

      assert :audit_kind in atoms
    end
  end
end
