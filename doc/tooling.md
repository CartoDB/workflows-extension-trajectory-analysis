# Tooling
This template comes with a Python tool that help with usual tasks when creating extension packages. 

## Authentication with the Data Warehouse
Some operations (namely `capture`, `test` and `deploy`) require authentication with the data warehouse to run.

If you are creating an extension for **BigQuery** connections, install the [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) and run the following in your console to authenticate:
```bash
$ gcloud auth application-default login
```

If you are working with **Snowflake**, the `deploy` command will require that you set some environmental variables: 
```bash
$ export SF_ACCOUNT=my_snowflake_account
$ export SF_USER=my_snowflake_user
$ export SF_PASSWORD=my_snowflake_password
```
For the `capture` and `test` commands, the authentication is managed in the `.env` file as explained [here](./running-tests.md#data-warehouse-configuration).

## Commands and parameters
* `check`: Checks the extension code definition and metadata.
* `capture`: Captures the output of the components to use as test fixtures.
  * `--component`: The component to capture.
  * `--verbose`: Show more information about the capture process.
* `test`: Runs the tests for the components.
  * `--component`: The component to test.
  * `--verbose`: Show more information about the test process.
* `deploy`: Deploys the extension to the data warehouse.
  * `--destination`: The destination where the extension will be deployed in the data warehouse.
  * `--verbose`: Show more information about the deployment process.
* `package`: Packages the extension into a zip file.
  * `--verbose`: Show more information about the packaging process.


## Updating the carto_extension.py script

Once you create your extension repository using this repo as a template, it will not be linked to the original repository.

That means that you will not get the improvements and fixes that might arrive to the `carto_extension.py` that is used for packaging, capturing fixtures, testing, etc. To keep it in sync and get the latest changes, you can use the `update` command.
```bash
$ python carto_extension.py update
```

That will replace your current script with the latest version in the original template repository.