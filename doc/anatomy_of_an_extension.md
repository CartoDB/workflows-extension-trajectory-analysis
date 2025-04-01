# Anatomy of an Extension Package

Each extension package contains a single file with **metadata** about the extension and one or more **components**.
This is a simplified diagram of the folder structure of an extension package:

```
extension-package/
├── metadata.json
└── components/
    ├── component_A/
    │   ├── doc/
    │   ├── test/
    │   ├── src/
    |   |   ├── dryrun.sql
    │   │   └── fullrun.sql
    │   └── metadata.json
    └── component_B/
        ├── doc/
        ├── test/
        ├── src/
        |   ├── dryrun.sql
        │   └── fullrun.sql
        └── metadata.json
```

---

## Extension's metadata

The extension's metadata file defines attributes like its name, the industry the extension belongs, version, author, description, icon, etc.

Extension's metadata is defined in a [`metadata.json`](../metadata.json) file in the root folder of this repo.

Find more information about the extension's metadata in the specific [documentation](./extension_metadata.md).

---

## Components

Components should aim to cover specific functionality, like adding a new column with a UUID, running an analysis and storing the result on an additional column or sending an HTTP request to a specific endpoint.

Tipically, a component receives one or more inputs; it has some settings that influence the execution of the code; and produce an output.

In Workflows, most components produce a table that contains the same columns from the input plus an additional set of columns that contain the result. This is not a hard requirement though, and your component doesn't need to follow this pattern.

Each component should be created on a separate folder inside [`/components`](../components/) and it's defined by **metadata** and **logic** (implemented as a stored procedure).

### Component's metadata

Each component has its own [`metadata.json`](../components/template/metadata.json) file, where you can define a name, title, description, icon, etc. And most importantly, **inputs**, **outputs** and some optional environmental variables.

Find more information about the component's metadata in the specific [documentation](./component_metadata.md).

### Logic

The logic for each component is defined as [stored procedures](procedure.md) in the [`components/<component_name>/src/fullrun.sql`](../components/template/src/fullrun.sql) and [`components/<component_name>/src/dryrun.sql`](../components/template/src/dryrun.sql)file.

Find a more complete documentation about creating stored procedures for custom components in [this documentation](./procedure.md).

### Inputs, outputs and `cartoEnvVars` as variables

All the inputs, outputs and environmental variables declared in the [component's metadata](../components/template/metadata.json) are accessible as variables in the stored procedures (both `dryrun.sql` and `fullrun.sql`). Read [this section](procedure.md#variables) to learn more about it.

---

## Test

Each component can also have its own set of tests to validate the results when running the component.

Tests are optional, but highly recommended.

Learn more about how to run these tests in your data warehouse in [this document](./running-tests.md).

---

## Component's documentation

Inside each component's folder, there can be a `/doc` subfolder with any number of additional Markdown files to document your component's usage.

This is completely optional, but we recommend documenting your custom components comprehensively.

---

## Icons

Custom icons are supported, for the extension and also for each component.

Place your SVG files in the [`icons`](../icons/) folder, and make sure that you reference them using their name in the `metadata.json` files for the extension and each component.

[Learn more about how to create custom icons](./icons.md).
