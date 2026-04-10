# Compile support files before running tests
Code.require_file("support/test_schema.ex", __DIR__)
Code.require_file("support/nullable_schema_test.ex", __DIR__)

# Polymorphic fixtures: variants must load before parents, because parents
# reference the variants' generated OpenApiSchema sub-modules inside
# `Polymorphic.one_of/1` at macro-expansion time.
Code.require_file("support/polymorphic/email.ex", __DIR__)
Code.require_file("support/polymorphic/sms.ex", __DIR__)
Code.require_file("support/polymorphic/webhook.ex", __DIR__)
Code.require_file("support/polymorphic/notification.ex", __DIR__)

Code.require_file("support/polymorphic/custom_event_click.ex", __DIR__)
Code.require_file("support/polymorphic/custom_event_pageview.ex", __DIR__)
Code.require_file("support/polymorphic/analytics.ex", __DIR__)

ExUnit.start()
