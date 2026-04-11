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
      beam_path = :code.which(module)
      refute beam_path in [:non_existing, :preloaded, :cover_compiled]

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
