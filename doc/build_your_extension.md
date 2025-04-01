## Build your own extension

##### A step by step guide

1. Create a new repository from this template. [See the oficial GitHub docs](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-repository-from-a-template).

2. Navigate to the repository folder and install the requirements needed by the repository scripts. Python 3 is required to run the repository scripts:

    ```bash
    $ pip install -r ./requirements.txt
    ```

3. Edit the `metadata.json` file in the root folder of the repo so it contains the correct information for the extension. [Learn more about the extension's metadata](./anatomy_of_an_extension.md#extensions-metadata).

4. Copy the `components/template` folder and rename it with the name of the component that you're going to develop (i.e. `mycomponent`).

5. Edit the component metadata file in `components/mycomponent/metadata.json`. For a complete reference of the available options, see [this page](./doc/component_metadata.md).

6. Edit the `components/mycomponent/src/fullrun.sql` and `components/mycomponent/src/dryrun.sql` files to define the logic of the new component. For a complete guide, see [here](./doc/procedure.md).

> 💡 **Tip**
>
> Please read [this section](./procedure.md#variables) carefully to understand how to define inputs and outputs and use them as variables in your stored procedures.

7. (Optional) Write the component documentation in the `components/mycomponent/doc/README.md` file and/or other markdown files in that same directory.

8. (Optional) Include some icons for your extension and components. If not included, CARTO Workflows will render default ones for your components. [Learn more about creating icons for the extension and components](./icons.md).

9. Repeat steps 3-8 for each component that is part of your extension package.

10. Use the `check` script to ensure that the extension is correctly defined.
    ```bash
    $ python carto_extension.py check
    Checking extension...
    Extension correctly checked. No errors found.
    ```

> 💡 **Tip**
>
> At this point, it is highly recommended that you create and run some tests for your components, so that consistency on the results is easy to check across different versions. Check [this section](./running-tests.md) to learn more about creating and running tests for your components.

11. Use the `deploy` command to create the components in a specific destination in your data warehouse. This is specially useful while developing, as it will avoid having to package and manually install the extension with every change.

    > 📍 **IMPORTANT**
    >
    > Just make sure that your destination matches the Workflows temp. location that is defined for the CARTO connection that you're using with Workflows.
    >
    > By default, this is a `workflows_temp` dataset in your BigQuery billing project or a `WORKFLOWS_TEMP` schema in your Snowflake database.

    **BigQuery**

    ```bash
    $ python carto_extension.py deploy --destination=myproject.mydataset
    ```

    **Snowflake**

    ```bash
    $ python carto_extension.py deploy --destination=MY_DATABASE.MY_SCHEMA
    ```

> 💡 **Tip**
>
> Make sure that your authenticated with your data warehouse before running the `deploy` command. Check [this section](./tooling.md#authentication-with-the-data-warehouse) to learn how to do it for different providers.

12. Run the `package` command to create an `extension.zip` file that is ready to be distributed and installed in a CARTO Workflow. [Learn more about managing extension packages](https://docs.carto.com/carto-user-manual/workflows/extension-packages#managing-extension-packages).

    ```bash
    $ python carto_extension.py package
    ```

🚀 **Congratulations!** You have created your extension package and now it's ready to be used with Workflows.
