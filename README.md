# Extension Packages for CARTO Workflows
Use this template repository as a framework for creating extension packages for CARTO Workflows, containing custom components that are tailored to your specific use cases. 

These packages can be easily distributed and installed within the Workflows application, extending its core functionality with new, specialized operations.

![](https://cdn.prod.website-files.com/6345207a1b18e581fcf67604/66507f26948382ff94fa45be_components.jpg)

Find more documentation about installing and managing extension packages in [this section of the CARTO documentation](https://docs.carto.com/carto-user-manual/workflows/extension-packages).

> Currently, Extension Packages are only supported in Workflows created for **BigQuery** and **Snowflake** connections.

Learn more about building, testing, and distributing extension packages for CARTO Workflows in the following sections: 

### 🧬 [Anatomy of an extension package](./doc/anatomy_of_an_extension.md)
This document describes the different elements that are needed to build an extension package and how they relate to each other. 

Read it carefully to understand how inputs, settings and outputs are defined along with the logic of each component.

It also contains a description of the basic elements required to define automated tests for your component.

There are also specific pages that go in detail about some of the pieces needed to build an extension. Check them once you're familiar with the basic structure of a component: 
* [**Extension's metadata**](./doc/extension_metadata.md)
* [**Component's metadata**](./doc/component_metadata.md)
* [**Stored procedure**](./doc/procedure.md)
* [**Icons**](./doc/icons.md)

### ⚙️ [Build you own extension: step by step](./doc/build_your_extension.md)
This section contains a step by step guide for creating your first extension package. 

### ✅ [Tests](./doc/running_tests.md)
Learn how to configure, run and automate different tests for your components.

### 🧰 [Tools](./doc/tooling.md)
Learn how to use the tools included with this template to help with the creation of extension packages.