defmodule ExOpenApiUtils.PolymorphicTest do
  @moduledoc """
  Full-lifecycle tests for `ExOpenApiUtils.Polymorphic.one_of/1`.

  Covers:

    1. Helper input validation (ArgumentError on bad opts).
    2. Helper output shape (type/oneOf/discriminator/mapping are correct and
       variants have `__type__` locked by enum).
    3. Generated parent schema integration (NotificationRequest embeds the
       polymorphic wrapper exactly as produced by the helper).
    4. Happy-path casts through `OpenApiSpex.Cast` for each variant.
    5. Error paths: missing discriminator, invalid discriminator, focused
       missing-field errors (NOT a `:one_of` wall — that is the whole point
       of the `type: :object` dispatch gate).
    6. Round-trip through `Ecto.Changeset.cast_polymorphic_embed/3` to a
       hydrated Ecto struct.
    7. Custom discriminator field name (`kind` instead of `__type__`).
  """
  use ExUnit.Case, async: true

  alias ExOpenApiUtils.Polymorphic
  alias OpenApiSpex.Cast
  alias OpenApiSpex.Discriminator
  alias OpenApiSpex.Schema

  alias ExOpenApiUtilsTest.OpenApiSchema.EmailRequest
  alias ExOpenApiUtilsTest.OpenApiSchema.NotificationRequest
  alias ExOpenApiUtilsTest.OpenApiSchema.SmsRequest
  alias ExOpenApiUtilsTest.OpenApiSchema.WebhookRequest

  # ------------------------------------------------------------------
  # 1. Input validation
  # ------------------------------------------------------------------

  describe "one_of/1 input validation" do
    test "raises when :discriminator is missing" do
      assert_raise ArgumentError, ~r/requires :discriminator/, fn ->
        Polymorphic.one_of(variants: [{"email", EmailRequest}])
      end
    end

    test "raises when :discriminator is an empty string" do
      assert_raise ArgumentError, ~r/:discriminator must be a non-empty string/, fn ->
        Polymorphic.one_of(discriminator: "", variants: [{"email", EmailRequest}])
      end
    end

    test "raises when :discriminator is not a string" do
      assert_raise ArgumentError, ~r/:discriminator must be a non-empty string/, fn ->
        Polymorphic.one_of(discriminator: :__type__, variants: [{"email", EmailRequest}])
      end
    end

    test "raises when :variants is missing" do
      assert_raise ArgumentError, ~r/requires :variants/, fn ->
        Polymorphic.one_of(discriminator: "__type__")
      end
    end

    test "raises when :variants is empty" do
      assert_raise ArgumentError, ~r/:variants must not be empty/, fn ->
        Polymorphic.one_of(discriminator: "__type__", variants: [])
      end
    end

    test "raises when :variants is not a list" do
      assert_raise ArgumentError, ~r/must be a non-empty list/, fn ->
        Polymorphic.one_of(discriminator: "__type__", variants: %{"email" => EmailRequest})
      end
    end

    test "raises when a variant tuple is malformed" do
      assert_raise ArgumentError, ~r/variant must be a .* tuple/, fn ->
        Polymorphic.one_of(discriminator: "__type__", variants: [{:email, EmailRequest}])
      end
    end

    test "raises when variant type_string is empty" do
      assert_raise ArgumentError, ~r/variant must be a .* tuple/, fn ->
        Polymorphic.one_of(discriminator: "__type__", variants: [{"", EmailRequest}])
      end
    end

    test "raises when variant module does not export schema/0" do
      assert_raise ArgumentError, ~r/must export schema\/0/, fn ->
        Polymorphic.one_of(
          discriminator: "__type__",
          variants: [{"bogus", __MODULE__}]
        )
      end
    end

    test "raises when variant module returns a non-Schema from schema/0" do
      defmodule BogusSchemaExporter do
        @moduledoc false
        def schema, do: %{not: :a_schema}
      end

      assert_raise ArgumentError, ~r/must return an %OpenApiSpex.Schema/, fn ->
        Polymorphic.one_of(
          discriminator: "__type__",
          variants: [{"bogus", BogusSchemaExporter}]
        )
      end
    end

    test "raises when variant module cannot be loaded" do
      assert_raise ArgumentError, ~r/could not load variant module/, fn ->
        Polymorphic.one_of(
          discriminator: "__type__",
          variants: [{"bogus", :"Elixir.This.Module.Does.Not.Exist"}]
        )
      end
    end
  end

  # ------------------------------------------------------------------
  # 2. Output shape — unit tests with inline %Schema{} variants
  # ------------------------------------------------------------------

  describe "one_of/1 output shape (unit)" do
    setup do
      wrapper =
        Polymorphic.one_of(
          discriminator: "__type__",
          variants: [
            {"cat",
             %Schema{
               title: "Cat",
               type: :object,
               properties: %{meow_volume: %Schema{type: :integer}},
               required: [:meow_volume]
             }},
            {"dog",
             %Schema{
               title: "Dog",
               type: :object,
               properties: %{bark_volume: %Schema{type: :integer}},
               required: [:bark_volume]
             }}
          ]
        )

      {:ok, wrapper: wrapper}
    end

    test "sets type: :object on the wrapper (dispatch gate)", %{wrapper: wrapper} do
      assert wrapper.type == :object
    end

    test "wrapper required contains only the discriminator atom", %{wrapper: wrapper} do
      assert wrapper.required == [:__type__]
    end

    test "oneOf has entries in the declared order", %{wrapper: wrapper} do
      assert [%Schema{title: "Cat"}, %Schema{title: "Dog"}] = wrapper.oneOf
    end

    test "each variant has __type__ property locked by enum", %{wrapper: wrapper} do
      [cat, dog] = wrapper.oneOf

      assert %Schema{type: :string, enum: ["cat"]} = cat.properties[:__type__]
      assert %Schema{type: :string, enum: ["dog"]} = dog.properties[:__type__]
    end

    test "each variant has discriminator prepended to required (deduped)", %{wrapper: wrapper} do
      [cat, dog] = wrapper.oneOf
      assert cat.required == [:__type__, :meow_volume]
      assert dog.required == [:__type__, :bark_volume]
    end

    test "discriminator is built with correct propertyName and mapping", %{wrapper: wrapper} do
      assert %Discriminator{
               propertyName: "__type__",
               mapping: %{"cat" => "Cat", "dog" => "Dog"}
             } = wrapper.discriminator
    end

    test "preserves base properties on each variant", %{wrapper: wrapper} do
      [cat, dog] = wrapper.oneOf
      assert Map.has_key?(cat.properties, :meow_volume)
      assert Map.has_key?(dog.properties, :bark_volume)
    end

    test "does not mutate the original variant schema map" do
      base = %Schema{
        title: "Bird",
        type: :object,
        properties: %{chirp_pitch: %Schema{type: :integer}},
        required: [:chirp_pitch]
      }

      _wrapper =
        Polymorphic.one_of(
          discriminator: "__type__",
          variants: [{"bird", base}]
        )

      # The base struct still lacks __type__
      refute Map.has_key?(base.properties, :__type__)
      assert base.required == [:chirp_pitch]
    end

    test "omits variants without titles from the mapping" do
      wrapper =
        Polymorphic.one_of(
          discriminator: "__type__",
          variants: [
            {"titled",
             %Schema{title: "Titled", type: :object, properties: %{a: %Schema{type: :string}}}},
            {"untitled", %Schema{type: :object, properties: %{b: %Schema{type: :string}}}}
          ]
        )

      assert wrapper.discriminator.mapping == %{"titled" => "Titled"}
    end

    test "deduplicates discriminator in required when variant already lists it" do
      wrapper =
        Polymorphic.one_of(
          discriminator: "kind",
          variants: [
            {"x",
             %Schema{
               title: "X",
               type: :object,
               properties: %{kind: %Schema{type: :string}, foo: %Schema{type: :string}},
               required: [:kind, :foo]
             }}
          ]
        )

      [variant] = wrapper.oneOf
      assert Enum.count(variant.required, &(&1 == :kind)) == 1
    end

    test "accepts a mix of %Schema{} and module variants" do
      wrapper =
        Polymorphic.one_of(
          discriminator: "__type__",
          variants: [
            {"email", EmailRequest},
            {"inline",
             %Schema{
               title: "Inline",
               type: :object,
               properties: %{foo: %Schema{type: :string}}
             }}
          ]
        )

      assert length(wrapper.oneOf) == 2
      assert Enum.any?(wrapper.oneOf, &(&1.title == "EmailRequest"))
      assert Enum.any?(wrapper.oneOf, &(&1.title == "Inline"))
    end
  end

  # ------------------------------------------------------------------
  # 3. Integration: generated NotificationRequest schema shape
  # ------------------------------------------------------------------

  describe "generated NotificationRequest schema" do
    setup do
      {:ok,
       schema: NotificationRequest.schema(),
       channel: NotificationRequest.schema().properties[:channel]}
    end

    test "top-level wrapper is type :object with expected title", %{schema: schema} do
      assert schema.type == :object
      assert schema.title == "NotificationRequest"
    end

    test "lists :subject and :channel as required", %{schema: schema} do
      assert :subject in schema.required
      assert :channel in schema.required
    end

    test ":channel property has type :object (dispatch gate)", %{channel: channel} do
      assert channel.type == :object
    end

    test ":channel has three oneOf entries in declared order", %{channel: channel} do
      titles = Enum.map(channel.oneOf, & &1.title)
      assert titles == ["EmailRequest", "SmsRequest", "WebhookRequest"]
    end

    test ":channel discriminator uses __type__ with the expected mapping", %{channel: channel} do
      assert %Discriminator{
               propertyName: "__type__",
               mapping: %{
                 "email" => "EmailRequest",
                 "sms" => "SmsRequest",
                 "webhook" => "WebhookRequest"
               }
             } = channel.discriminator
    end

    test "each oneOf variant has __type__ locked by enum", %{channel: channel} do
      [email, sms, webhook] = channel.oneOf
      assert email.properties[:__type__].enum == ["email"]
      assert sms.properties[:__type__].enum == ["sms"]
      assert webhook.properties[:__type__].enum == ["webhook"]
    end

    test "each oneOf variant has __type__ in required", %{channel: channel} do
      for variant <- channel.oneOf do
        assert :__type__ in variant.required
      end
    end

    test "wrapper :channel has required: [:__type__]", %{channel: channel} do
      assert channel.required == [:__type__]
    end
  end

  # ------------------------------------------------------------------
  # 4. Happy-path casts for each variant
  # ------------------------------------------------------------------

  describe "happy-path casts" do
    test "casts a valid email payload" do
      payload = %{
        "subject" => "Your receipt",
        "channel" => %{
          "__type__" => "email",
          "to" => "buyer@example.com",
          "from" => "store@example.com",
          "body" => "Thanks!"
        }
      }

      assert {:ok, %NotificationRequest{channel: channel} = result} =
               Cast.cast(NotificationRequest.schema(), payload)

      assert result.subject == "Your receipt"

      assert %EmailRequest{to: "buyer@example.com", from: "store@example.com", body: "Thanks!"} =
               channel
    end

    test "casts a valid sms payload" do
      payload = %{
        "subject" => "Auth code",
        "channel" => %{
          "__type__" => "sms",
          "phone_number" => "+15551234567",
          "body" => "Your code is 1234"
        }
      }

      assert {:ok, %NotificationRequest{channel: %SmsRequest{} = channel}} =
               Cast.cast(NotificationRequest.schema(), payload)

      assert channel.phone_number == "+15551234567"
      assert channel.body == "Your code is 1234"
    end

    test "casts a valid webhook payload" do
      payload = %{
        "subject" => "Deploy finished",
        "channel" => %{
          "__type__" => "webhook",
          "url" => "https://hooks.example.com/123",
          "method" => "POST"
        }
      }

      assert {:ok, %NotificationRequest{channel: %WebhookRequest{} = channel}} =
               Cast.cast(NotificationRequest.schema(), payload)

      assert channel.url == "https://hooks.example.com/123"
      assert channel.method == "POST"
    end
  end

  # ------------------------------------------------------------------
  # 5. Error paths — the UX point of the helper
  # ------------------------------------------------------------------

  describe "error paths" do
    test "missing discriminator returns :no_value_for_discriminator" do
      payload = %{"subject" => "x", "channel" => %{"to" => "a@b.com"}}

      assert {:error, [error]} = Cast.cast(NotificationRequest.schema(), payload)
      assert error.reason == :no_value_for_discriminator
      assert error.name == "__type__"
      assert error.path == [:channel]
    end

    test "unknown discriminator value returns :invalid_discriminator_value" do
      payload = %{"subject" => "x", "channel" => %{"__type__" => "carrier_pigeon"}}

      assert {:error, [error]} = Cast.cast(NotificationRequest.schema(), payload)
      assert error.reason == :invalid_discriminator_value
      assert error.name == "__type__"
      assert error.path == [:channel]
    end

    test "valid type but missing required fields gives FOCUSED errors (not a :one_of wall)" do
      # Email variant: missing :to and :from. A broken :one_of fallback would
      # concatenate errors across every variant (EmailRequest missing :to/:from,
      # SmsRequest missing :phone_number, WebhookRequest missing :url/:method)
      # — a wall of ~5+ errors that doesn't tell the user what they did wrong.
      # With discriminator dispatch, OpenApiSpex focuses on the SELECTED
      # variant and only reports the :email branch's missing fields.
      payload = %{
        "subject" => "x",
        "channel" => %{"__type__" => "email", "body" => "hi"}
      }

      assert {:error, errors} = Cast.cast(NotificationRequest.schema(), payload)

      # Every error is under [:channel, <field>] on the email branch only.
      assert Enum.all?(errors, fn e ->
               match?([:channel, _], e.path) and e.reason == :missing_field
             end)

      # Specifically, :to and :from are flagged.
      missing = errors |> Enum.map(& &1.name) |> MapSet.new()
      assert MapSet.subset?(MapSet.new([:to, :from]), missing)

      # And no error mentions fields that belong ONLY to other variants.
      refute Enum.any?(errors, fn e -> e.name in [:phone_number, :url, :method] end)
    end

    test "cross-variant payload shape is caught on the selected branch only" do
      # `__type__ => "email"` but the payload carries sms-shaped fields.
      # Errors should point at the email branch's missing :to/:from/:body,
      # never at sms-specific fields.
      payload = %{
        "subject" => "x",
        "channel" => %{"__type__" => "email", "phone_number" => "+15551234"}
      }

      assert {:error, errors} = Cast.cast(NotificationRequest.schema(), payload)

      # Errors refer only to email branch fields.
      for err <- errors do
        assert err.path |> hd() == :channel
        refute err.name == :phone_number
      end

      assert Enum.any?(errors, &(&1.name == :to and &1.reason == :missing_field))
    end

    test "empty discriminator string returns :no_value_for_discriminator" do
      payload = %{"subject" => "x", "channel" => %{"__type__" => ""}}

      assert {:error, [error]} = Cast.cast(NotificationRequest.schema(), payload)
      assert error.reason == :no_value_for_discriminator
    end
  end

  # ------------------------------------------------------------------
  # 6. Dispatch gate regression test
  # ------------------------------------------------------------------

  describe "type: :object dispatch gate" do
    test "helper always emits type: :object even if user tries to omit it via variants" do
      # No variant has type: :object set on its base schema — the wrapper
      # must still set it.
      wrapper =
        Polymorphic.one_of(
          discriminator: "kind",
          variants: [{"a", %Schema{title: "A", properties: %{x: %Schema{type: :string}}}}]
        )

      assert wrapper.type == :object
    end

    test "a plain oneOf without type: :object silently accepts ANY input (documenting why we set the gate)" do
      # The bug this test locks in: `OpenApiSpex.Cast.cast/1` only routes
      # through `Cast.Discriminator.cast/1` when the composition schema has
      # BOTH `type: :object` AND `discriminator:` set
      # (open_api_spex/cast.ex:173). Without `type: :object`, the schema
      # doesn't match any type-specific cast clause and falls through to the
      # wildcard `%{type: nil}` clause which returns `{:ok, value}`
      # unchanged — meaning the cast silently succeeds with completely
      # invalid input. The helper's `type: :object` guarantee is what
      # prevents this class of bug.
      plain = %Schema{
        oneOf: [
          %Schema{
            title: "A",
            type: :object,
            properties: %{x: %Schema{type: :string}},
            required: [:x]
          },
          %Schema{
            title: "B",
            type: :object,
            properties: %{y: %Schema{type: :string}},
            required: [:y]
          }
        ],
        discriminator: %Discriminator{propertyName: "kind", mapping: %{"a" => "A", "b" => "B"}}
      }

      # No type: :object. Bogus discriminator value => OpenApiSpex silently
      # returns {:ok, _} instead of an error. The returned value may be
      # partially atomized by OpenApiSpex for known property keys, but the
      # critical point is that the cast *succeeds* — no error, no
      # discriminator check, no validation. If this ever changes upstream
      # (i.e. OpenApiSpex starts validating `oneOf` without the gate), this
      # regression-lock will flip and we can reassess the helper's role.
      assert {:ok, _} = Cast.cast(plain, %{"kind" => "bogus", "x" => "hi"})
    end

    test "the same schema WITH type: :object (via our helper) rejects that input" do
      # Contrast with the test above: the only difference is `type: :object`
      # on the wrapper. This is the one-line guarantee `Polymorphic.one_of/1`
      # gives you, and it's the difference between silent acceptance of
      # bogus input and a clean :invalid_discriminator_value error.
      gated =
        Polymorphic.one_of(
          discriminator: "kind",
          variants: [
            {"a",
             %Schema{
               title: "A",
               type: :object,
               properties: %{x: %Schema{type: :string}},
               required: [:x]
             }},
            {"b",
             %Schema{
               title: "B",
               type: :object,
               properties: %{y: %Schema{type: :string}},
               required: [:y]
             }}
          ]
        )

      assert {:error, [error]} =
               Cast.cast(gated, %{"kind" => "bogus", "x" => "hi"})

      assert error.reason == :invalid_discriminator_value
    end
  end

  # ------------------------------------------------------------------
  # 7. Round-trip to Ecto struct via cast_polymorphic_embed
  # ------------------------------------------------------------------

  describe "round-trip through Ecto changeset" do
    alias ExOpenApiUtilsTest.Polymorphic.Email, as: EctoEmail
    alias ExOpenApiUtilsTest.Polymorphic.Notification, as: EctoNotification
    alias ExOpenApiUtilsTest.Polymorphic.Sms, as: EctoSms

    test "valid email payload casts + changesets into a hydrated %Notification{}" do
      payload = %{
        "subject" => "Receipt",
        "channel" => %{
          "__type__" => "email",
          "to" => "buyer@example.com",
          "from" => "store@example.com",
          "body" => "thanks"
        }
      }

      # Step A: OpenApiSpex validates the wire shape (enforces __type__ +
      # discriminator dispatch).
      assert {:ok, %NotificationRequest{}} =
               Cast.cast(NotificationRequest.schema(), payload)

      # Step B: the same raw payload flows into the Ecto changeset, which
      # uses cast_polymorphic_embed/3 to hydrate the variant struct. (Users
      # typically feed the RAW payload to the changeset so __type__ is
      # preserved for cast_polymorphic_embed to select the variant.)
      changeset = EctoNotification.changeset(%EctoNotification{}, payload)

      assert changeset.valid?

      assert %EctoEmail{to: "buyer@example.com", from: "store@example.com", body: "thanks"} =
               Ecto.Changeset.get_change(changeset, :channel)
    end

    test "sms payload hydrates into %Sms{}" do
      payload = %{
        "subject" => "Code",
        "channel" => %{
          "__type__" => "sms",
          "phone_number" => "+15551234567",
          "body" => "your code is 4242"
        }
      }

      assert {:ok, _} = Cast.cast(NotificationRequest.schema(), payload)

      changeset = EctoNotification.changeset(%EctoNotification{}, payload)
      assert changeset.valid?

      assert %EctoSms{phone_number: "+15551234567", body: "your code is 4242"} =
               Ecto.Changeset.get_change(changeset, :channel)
    end

    test "OpenApiSpex rejects before reaching the changeset when the shape is wrong" do
      # Missing :to on an email payload — OpenApiSpex should reject at step A
      # so the changeset never sees a broken payload.
      payload = %{
        "subject" => "x",
        "channel" => %{"__type__" => "email", "body" => "hi"}
      }

      assert {:error, [_ | _]} = Cast.cast(NotificationRequest.schema(), payload)
    end
  end

  # ------------------------------------------------------------------
  # 8. Custom discriminator name
  # ------------------------------------------------------------------

  describe "custom discriminator field name" do
    alias ExOpenApiUtilsTest.OpenApiSchema.AnalyticsRequest
    alias ExOpenApiUtilsTest.Polymorphic.Analytics, as: EctoAnalytics
    alias ExOpenApiUtilsTest.Polymorphic.CustomEvent.Click, as: EctoClick

    test "wrapper uses `kind` as propertyName" do
      event = AnalyticsRequest.schema().properties[:event]
      assert event.discriminator.propertyName == "kind"
    end

    test "each oneOf variant has :kind locked (not :__type__)" do
      event = AnalyticsRequest.schema().properties[:event]

      for variant <- event.oneOf do
        assert Map.has_key?(variant.properties, :kind)
        refute Map.has_key?(variant.properties, :__type__)
        assert :kind in variant.required
      end
    end

    test "casts a payload using `kind` as the discriminator" do
      payload = %{
        "user_id" => "851b18d7-0c88-4095-9969-cbe385926420",
        "event" => %{"kind" => "click", "selector" => "#submit-btn"}
      }

      assert {:ok, _} = Cast.cast(AnalyticsRequest.schema(), payload)
    end

    test "missing `kind` gives :no_value_for_discriminator on the custom field" do
      payload = %{
        "user_id" => "851b18d7-0c88-4095-9969-cbe385926420",
        "event" => %{"selector" => "#x"}
      }

      assert {:error, [error]} = Cast.cast(AnalyticsRequest.schema(), payload)
      assert error.reason == :no_value_for_discriminator
      assert error.name == "kind"
    end

    test "round-trip with custom discriminator hydrates the variant" do
      payload = %{
        "user_id" => "851b18d7-0c88-4095-9969-cbe385926420",
        "event" => %{"kind" => "click", "selector" => "#submit-btn"}
      }

      changeset = EctoAnalytics.changeset(%EctoAnalytics{}, payload)
      assert changeset.valid?

      assert %EctoClick{selector: "#submit-btn"} =
               Ecto.Changeset.get_change(changeset, :event)
    end
  end
end
