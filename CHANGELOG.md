# Changelog

## [0.11.1](https://github.com/v3-dot-cash/ex_open_api_utils/compare/v0.11.0...v0.11.1) (2025-12-26)


### Bug Fixes

* support OpenApiSpex.Reference in is_readOnly?/is_writeOnly? ([abbaec2](https://github.com/v3-dot-cash/ex_open_api_utils/commit/abbaec2a033cb3c01caa26033eb10725691e91ca))
* support OpenApiSpex.Reference in is_readOnly?/is_writeOnly? ([05d4743](https://github.com/v3-dot-cash/ex_open_api_utils/commit/05d474398b0d7e8781ddc2c52f5dafbafa423ba5)), closes [#13](https://github.com/v3-dot-cash/ex_open_api_utils/issues/13)

## [0.11.0](https://github.com/v3-dot-cash/ex_open_api_utils/compare/v0.10.0...v0.11.0) (2025-12-25)


### Features

* **schema:** add nullable field support to schema generation ([91adb56](https://github.com/v3-dot-cash/ex_open_api_utils/commit/91adb56c82fb3b0e4a7769b177d4c625a1a06d57)), closes [#10](https://github.com/v3-dot-cash/ex_open_api_utils/issues/10)

## [0.10.0](https://github.com/v3-dot-cash/ex_open_api_utils/compare/v0.9.0...v0.10.0) (2025-12-23)


### Features

* **tag:** add OpenAPI 3.2 tag hierarchy support ([e1c93be](https://github.com/v3-dot-cash/ex_open_api_utils/commit/e1c93be9308ab1804d272bf0f36342616e080d3f))
* **tag:** add OpenAPI 3.2 tag hierarchy support ([e0c95b7](https://github.com/v3-dot-cash/ex_open_api_utils/commit/e0c95b7c8c9f161f9b37a66bb0298cdfadccad48))


### Bug Fixes

* credo compliance and CI configuration ([f27adac](https://github.com/v3-dot-cash/ex_open_api_utils/commit/f27adac23faaed89a4e5b70b4223199ebce943ee))

## [0.9.0](https://github.com/v3-dot-cash/ex_open_api_utils/compare/v0.8.1...v0.9.0) (2025-12-22)


### Features

* **helpers:** add OpenAPI extension helpers for TypeScript/NestJS/Drizzle codegen ([7460008](https://github.com/v3-dot-cash/ex_open_api_utils/commit/7460008d6ba9746738dc39ca9c355ddb0b16efb7))
* **helpers:** add OpenAPI extension helpers for TypeScript/NestJS/Drizzle codegen ([6571b44](https://github.com/v3-dot-cash/ex_open_api_utils/commit/6571b4427c86277ec6ee6956aea081ec0e8d8715))


### Bug Fixes

* change 'order' to 'x-order' for OpenAPI spec compliance ([e61f121](https://github.com/v3-dot-cash/ex_open_api_utils/commit/e61f1213eb4ac5b5fb350d8efcf9ac80cd44cda1)), closes [#54](https://github.com/v3-dot-cash/ex_open_api_utils/issues/54)
* formatting issues ([f969b19](https://github.com/v3-dot-cash/ex_open_api_utils/commit/f969b19305342b3756bcd4ec52919ed6be10c4f2))

## [0.8.1](https://github.com/v3-dot-cash/ex_open_api_utils/commits/main) (2024-12-22)

### Features

* Initial release with OpenAPI schema generation from Ecto schemas
* Support for Request/Response schema generation
* x-order extension for field ordering
* Mapper protocol for Ecto ↔ OpenAPI conversion
