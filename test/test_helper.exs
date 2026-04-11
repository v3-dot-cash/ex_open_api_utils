# Compile support files before running tests
Code.require_file("support/test_schema.ex", __DIR__)
Code.require_file("support/nullable_schema_test.ex", __DIR__)

# Polymorphic discriminator fixtures: variants must load before parents,
# because parents reference the variants' generated OpenApiSchema sub-modules
# inside the discriminator's oneOf at macro-expansion time.
Code.require_file("support/polymorphic_discriminator/email_channel.ex", __DIR__)
Code.require_file("support/polymorphic_discriminator/sms_channel.ex", __DIR__)
Code.require_file("support/polymorphic_discriminator/webhook_channel.ex", __DIR__)
Code.require_file("support/polymorphic_discriminator/notification.ex", __DIR__)

Code.require_file("support/polymorphic_discriminator/click_event.ex", __DIR__)
Code.require_file("support/polymorphic_discriminator/pageview_event.ex", __DIR__)
Code.require_file("support/polymorphic_discriminator/analytics.ex", __DIR__)

ExUnit.start()
