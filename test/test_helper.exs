# Compile support files before running tests
Code.require_file("support/test_schema.ex", __DIR__)
Code.require_file("support/nullable_schema_test.ex", __DIR__)

defmodule ExOpenApiUtilsTest.CompiledFixtures do
  @moduledoc false
  # Compiles a fixture file and stashes each resulting module's compiled
  # `.beam` binary in `:persistent_term` so that regression tests can read
  # the atom chunk via `:beam_lib.chunks/2` without the file ever landing
  # on disk. Used by the GH-27 discriminator atom persistence test.
  def stash(relative_path) do
    relative_path
    |> Path.expand(File.cwd!())
    |> Code.compile_file()
    |> Enum.each(fn {mod, bin} ->
      :persistent_term.put({__MODULE__, mod}, bin)
    end)
  end

  def beam_binary(module) do
    :persistent_term.get({__MODULE__, module}, nil)
  end
end

# Polymorphic discriminator fixtures: variants must load before parents,
# because parents reference the variants' generated OpenApiSchema sub-modules
# inside the discriminator's oneOf at macro-expansion time. We compile via
# the `stash/1` helper so the resulting binaries — including each module's
# auto-derived Mapper impl — are retrievable by regression tests.
ExOpenApiUtilsTest.CompiledFixtures.stash(
  "test/support/polymorphic_discriminator/email_channel.ex"
)

ExOpenApiUtilsTest.CompiledFixtures.stash("test/support/polymorphic_discriminator/sms_channel.ex")

ExOpenApiUtilsTest.CompiledFixtures.stash(
  "test/support/polymorphic_discriminator/webhook_channel.ex"
)

ExOpenApiUtilsTest.CompiledFixtures.stash(
  "test/support/polymorphic_discriminator/notification.ex"
)

ExOpenApiUtilsTest.CompiledFixtures.stash("test/support/polymorphic_discriminator/click_event.ex")

ExOpenApiUtilsTest.CompiledFixtures.stash(
  "test/support/polymorphic_discriminator/pageview_event.ex"
)

ExOpenApiUtilsTest.CompiledFixtures.stash("test/support/polymorphic_discriminator/analytics.ex")

ExUnit.start()
