# Changelog

## [0.17.0](https://github.com/v3-dot-cash/ex_open_api_utils/compare/v0.16.0...v0.17.0) (2026-04-12)


### Features

* **encoder:** auto Jason.Encoder for generated schemas via nil-aware reduce ([28957aa](https://github.com/v3-dot-cash/ex_open_api_utils/commit/28957aa4288a4a1296028084db59960ec7e1d4eb)), closes [#41](https://github.com/v3-dot-cash/ex_open_api_utils/issues/41)

## [0.16.0](https://github.com/v3-dot-cash/ex_open_api_utils/compare/v0.15.0...v0.16.0) (2026-04-12)


### Features

* **mapper:** strip nil values for non-nullable properties in to_map/1 ([a1bdafb](https://github.com/v3-dot-cash/ex_open_api_utils/commit/a1bdafb2851a6febc5c3e240db1dbb3bb51302ec)), closes [#38](https://github.com/v3-dot-cash/ex_open_api_utils/issues/38)

## [0.15.0](https://github.com/v3-dot-cash/ex_open_api_utils/compare/v0.14.0...v0.15.0) (2026-04-11)


### Features

* **mapper:** add self_stamp_atom / self_stamp_wire splice to Any.__deriving__/3 ([03f5318](https://github.com/v3-dot-cash/ex_open_api_utils/commit/03f531843d14b6d7e9dab47f301545dca00fe183)), closes [#34](https://github.com/v3-dot-cash/ex_open_api_utils/issues/34)
* **polymorphic:** pass self_stamp options through parent-contextual sibling derive loop ([ace86ca](https://github.com/v3-dot-cash/ex_open_api_utils/commit/ace86cac9a0fedf93fcdef5a23e5af9b5f664803)), closes [#34](https://github.com/v3-dot-cash/ex_open_api_utils/issues/34)

## [0.14.0](https://github.com/v3-dot-cash/ex_open_api_utils/compare/v0.13.1...v0.14.0) (2026-04-11)


### ⚠ BREAKING CHANGES

* **example:** migrate polymorphic fixtures to open_api_polymorphic_property
* **polymorphic:** replace three-macro shape with open_api_polymorphic_property, close GH-30 via allOf siblings

### Features

* **example:** add docker-compose.test.yml with tmpfs Postgres ([873ff59](https://github.com/v3-dot-cash/ex_open_api_utils/commit/873ff590c6630769e791cbaffade14fe2f167d63))
* **example:** add Makefile for local vitest integration tier ([9b473dc](https://github.com/v3-dot-cash/ex_open_api_utils/commit/9b473dcfa1cad7532386cdfc83fed8d8d8c3e29e))
* **example:** add mix openapi.dump task for vitest SDK generation ([979256c](https://github.com/v3-dot-cash/ex_open_api_utils/commit/979256cc5142bb00942fcb48b1ce0a5ac147cee9))
* **example:** add PORT env override to dev endpoint config ([6662a7d](https://github.com/v3-dot-cash/ex_open_api_utils/commit/6662a7dfbc2ab9e7192db81b8037e73da5ea5757))
* **example:** add vitest integration tests and TypeScript client samples ([e6cc7ca](https://github.com/v3-dot-cash/ex_open_api_utils/commit/e6cc7ca50e9e5fa51298b4a84d38b6280cedd30e))
* **example:** migrate polymorphic fixtures to open_api_polymorphic_property ([4d569e1](https://github.com/v3-dot-cash/ex_open_api_utils/commit/4d569e16d2d7cc8e9102ee0712629731461b506b))
* **example:** pivot vitest tier to production-style ky + zod + vite-plugin stack ([25ddd47](https://github.com/v3-dot-cash/ex_open_api_utils/commit/25ddd47117a00a8f6d881f0492eb2ae62e2ed7ed))
* **example:** scaffold vitest integration-tests package and config ([530e22c](https://github.com/v3-dot-cash/ex_open_api_utils/commit/530e22c91c78ea11ef73c844b74f630956baa047))
* **example:** serve OpenAPI spec at GET /api/openapi ([cefe25e](https://github.com/v3-dot-cash/ex_open_api_utils/commit/cefe25eccbc29e9b525637b456ca920b3dec52d0))
* **polymorphic:** replace three-macro shape with open_api_polymorphic_property, close GH-30 via allOf siblings ([1f76b7b](https://github.com/v3-dot-cash/ex_open_api_utils/commit/1f76b7bc4f84f36ed9287b027f72cb99dae6bab3)), closes [#30](https://github.com/v3-dot-cash/ex_open_api_utils/issues/30)

## [0.13.1](https://github.com/v3-dot-cash/ex_open_api_utils/compare/v0.13.0...v0.13.1) (2026-04-11)


### Bug Fixes

* **compile:** resolve preexisting warnings so --warnings-as-errors passes ([b8fa0af](https://github.com/v3-dot-cash/ex_open_api_utils/commit/b8fa0af4962a5325987a77d44b14432199b630e7))
* **polymorphic:** persist discriminator propertyName atom into Mapper impl literal pool ([51daadf](https://github.com/v3-dot-cash/ex_open_api_utils/commit/51daadfb7748f9273abc9f5caec0d4babfe18b2a)), closes [#27](https://github.com/v3-dot-cash/ex_open_api_utils/issues/27)

## [0.13.0](https://github.com/v3-dot-cash/ex_open_api_utils/compare/v0.12.0...v0.13.0) (2026-04-11)


### Features

* **example:** wire notifications resource with polymorphic_embed_discriminator and full controller test coverage ([e92a3e2](https://github.com/v3-dot-cash/ex_open_api_utils/commit/e92a3e2d84e5b633c35d0746126391e9db84145c))
* **polymorphic:** add polymorphic_embed_discriminator macro bridging polymorphic_embed to OpenAPI discriminator ([50fe939](https://github.com/v3-dot-cash/ex_open_api_utils/commit/50fe9397a6ab149b11d8809262aae03d428dd54f))
* **polymorphic:** close GH-24 runtime round-trip via polymorphic_embed_discriminator macro ([2f953c4](https://github.com/v3-dot-cash/ex_open_api_utils/commit/2f953c4f641e99850ebb2db8488962efa715798d))

## [0.12.0](https://github.com/v3-dot-cash/ex_open_api_utils/compare/v0.11.2...v0.12.0) (2026-04-10)


### Features

* **deps:** add polymorphic_embed as test-only dependency ([6e2217e](https://github.com/v3-dot-cash/ex_open_api_utils/commit/6e2217e3d56c6f705cbcbf98903bc0e79b11fa91)), closes [#21](https://github.com/v3-dot-cash/ex_open_api_utils/issues/21)
* **polymorphic:** add Polymorphic.one_of helper ([b495829](https://github.com/v3-dot-cash/ex_open_api_utils/commit/b495829427a4e8a6d3824706cac6bb06e4b4e22b)), closes [#21](https://github.com/v3-dot-cash/ex_open_api_utils/issues/21)

## [0.11.2](https://github.com/v3-dot-cash/ex_open_api_utils/compare/v0.11.1...v0.11.2) (2026-02-15)


### Bug Fixes

* **deps:** make ex_doc a dev-only dependency ([fb168db](https://github.com/v3-dot-cash/ex_open_api_utils/commit/fb168dbf5c3f8b27d55457217c23ea2822bf6f5d))
* **deps:** make ex_doc a dev-only dependency ([8a89461](https://github.com/v3-dot-cash/ex_open_api_utils/commit/8a8946188b840c281bba2fe1672097d2b94036cc)), closes [#18](https://github.com/v3-dot-cash/ex_open_api_utils/issues/18)

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
