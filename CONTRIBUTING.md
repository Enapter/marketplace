# :construction: Contributing to Enapter Device Blueprints

We welcome any contributions when it comes to integrating new devices into the system, whether it's development efforts or testing the blueprints on your hardware.

Feel free to:

- 🐛 Report an issue
- 📖 Improve documentation
- 👨‍💻 Contribute to the code
- 🔌 Provide remote access to your hardware
- 🎥 Create review or tutorial video on Youtube

Feel free to open discussion in [Discord](https://go.enapter.com/discord_handbook) or [GitHub](https://github.com/Enapter/marketplace/discussions)

Go through [the tutorial](https://developers.enapter.com/docs/) to learn about the blueprint concept and development workflow.

## Note About Dot-Fields

`manifest.yml` is validated against [the specification](https://cloud.enapter.com/schemas/json-schemas/blueprints/device/v1/schema.json), although not every aspect of the manifest is ready to be fixed in the specification. Some in-progress features are backed by YAML fields that start with a dot (e.g. `.cloud`). These fields are not documented and ignored in the manifest validation. When the feature is ready, the field will be moved into the main manifest body, and the blueprints will be updated.

## Writing Blueprint README

Please follow this simple checklist for every blueprint README file:

- Level 1 header should contain vendor and full model or product family.
- Intro paragraph should briefly describe the device.
- Make sure that blueprint's use case is clear.
- Some blueprints may require physical connection schematics. You can add it as a picture to the README file or as a link to a PDF file. Place the file into the `.assets` blueprint subdirectory ([example](fuel_cells/intelligent_energy_fcm_801_can/)).
- List the hardware needed for the physical connection. This may be an Enapter UCM model, communication interface converter, etc.
- Device pictures and vendor logos are always welcome, but we ask you to respect the author of said pictures and to follow copyright and licencing guidelines.
- References should be given to the device vendor page, manual, API documentation, etc.

## Linters and Formatters

Blueprint files are validated using several linters:

- [`yamllint`](https://yamllint.readthedocs.io/en/stable/)
- [`luacheck`](https://luacheck.readthedocs.io/en/stable/)
- [`markdownlint`](https://github.com/igorshubovych/markdownlint-cli#readme)
- [`StyLua`](https://github.com/JohnnyMorganz/StyLua)

The configuration can be found in `.yamllint.yml`, `.luacheckrc`, `.markdownlint.yml` and `.stylua.toml` files respectively.

Run the linters locally before creating a pull request:

```bash
luacheck .
yamllint .
markdownlint .
stylua --check .
```

:warning: Some of the existing files have not been auto-formatted yet, so `stylua --check .` will fail. Changes introduced by auto-formatting require [review, which is still in progress](https://github.com/Enapter/marketplace/issues/199).

To automatically run the checks before each commit, consider enabling [pre-commit hooks](https://pre-commit.com):

```bash
pre-commit install
```

## Lua Codestyle

Lua code is expected to be autoformatted with [`StyLua`](https://github.com/JohnnyMorganz/StyLua).

Here are some conventions besides that enforced by the auto-formatter:

- Document with [LDoc](https://stevedonovan.github.io/ldoc/).
- Use `snake_case` for variables and functions.
- Use `CamelCase` for OOP class names.
- Use `UPPER_CASE` for constants. Put top-level constants at the beginning of the file.
- Use `is_` when naming boolean functions, e.g. `is_between()`.
- Typecheck in critical places (`assert(type(myvar) == 'string')`).

Some more coding conventions are available in the [LuaRocks style guide](https://github.com/luarocks/lua-style-guide).

## Community and Support

- <a href="https://go.enapter.com/discord_handbook"><img align="center" src="https://img.shields.io/badge/Discord-Channel-%235865F2?logo=discord&style=for-the-badge&logoColor=white"></a>&nbsp; Join our Discord community!
- <a href="https://developers.enapter.com"><img align="center" src="https://img.shields.io/badge/Developers%20Documentation-Documentation-%2330cccc?logo=readthedocs&style=for-the-badge&logoColor=white"></a>&nbsp; Take a look on our documentation.
- <a href="https://github.com/Enapter/marketplace/discussions"><img align="center" src="https://img.shields.io/badge/GitHub-Discussions-black?logo=github&style=for-the-badge&logoColor=white"></a>&nbsp; Open thread on GitHub!
- <a href="https://www.producthunt.com/products/enapter-energy-management-system-toolkit"><img align="center" src="https://img.shields.io/badge/Producthunt-Upvote%20↑-%23DA552F?logo=producthunt&style=for-the-badge"></a>&nbsp; Support us on ProducHunt with review and upvote!

## License and Authorship

Blueprints in the marketplace should be licensed under the MIT license. Please add [`license: MIT`](https://developers.enapter.com/docs/reference/#license) in your `manifest.yml`.

Also you can specify authorship and support information via [`author`](https://developers.enapter.com/docs/reference/#author), [`contributors`](https://developers.enapter.com/docs/reference/#contributors) and [`support`](https://developers.enapter.com/docs/reference/#support) fields.
