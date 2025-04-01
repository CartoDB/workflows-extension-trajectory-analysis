from dotenv import load_dotenv, dotenv_values
from google.cloud import bigquery
from sys import argv
from textwrap import dedent, indent
from uuid import uuid4
import argparse
import base64
from shapely import wkt
import hashlib
import json
import os
import re
import snowflake.connector
import zipfile
import io
import urllib.request
import pandas as pd
import numpy as np
import math
from typing import Any

WORKFLOWS_TEMP_SCHEMA = "WORKFLOWS_TEMP"
EXTENSIONS_TABLENAME = "WORKFLOWS_EXTENSIONS"
WORKFLOWS_TEMP_PLACEHOLDER = "@@workflows_temp@@"

load_dotenv()

bq_workflows_temp = f"`{os.getenv('BQ_TEST_PROJECT')}.{os.getenv('BQ_TEST_DATASET')}`"
sf_workflows_temp = f"{os.getenv('SF_TEST_DATABASE')}.{os.getenv('SF_TEST_SCHEMA')}"

sf_client_instance = None
bq_client_instance = None


def bq_client():
    global bq_client_instance
    if bq_client_instance is None:
        try:
            bq_client_instance = bigquery.Client(project=os.getenv("BQ_TEST_PROJECT"))
        except Exception as e:
            raise Exception(f"Error connecting to BigQuery: {e}")
    return bq_client_instance


def sf_client():
    global sf_client_instance
    if sf_client_instance is None:
        try:
            sf_client_instance = snowflake.connector.connect(
                user=os.getenv("SF_USER"),
                password=os.getenv("SF_PASSWORD"),
                account=os.getenv("SF_ACCOUNT"),
                database=os.getenv("SF_TEST_DATABASE"),
                schema=os.getenv("SF_TEST_SCHEMA"),
            )
        except Exception as e:
            raise Exception(f"Error connecting to SnowFlake: {e}")
    return sf_client_instance


def add_namespace_to_component_names(metadata):
    for component in metadata["components"]:
        component["name"] = f'{metadata["name"]}.{component["name"]}'
    return metadata


def _encode_image(image_path):
    if not os.path.exists(image_path):
        raise FileNotFoundError(
            f"Icon file '{os.path.basename(image_path)}' not found in icons folder"
        )
    with open(image_path, "rb") as f:
        if image_path.endswith(".svg"):
            return f"data:image/svg+xml;base64,{base64.b64encode(f.read()).decode('utf-8')}"
        else:
            return f"data:image/png;base64,{base64.b64encode(f.read()).decode('utf-8')}"


def create_metadata():
    current_folder = os.path.dirname(os.path.abspath(__file__))
    metadata_file = os.path.join(current_folder, "metadata.json")
    with open(metadata_file, "r") as f:
        metadata = json.load(f)
    components = []
    components_folder = os.path.join(current_folder, "components")
    icon_folder = os.path.join(current_folder, "icons")
    icon_filename = metadata.get("icon")
    if icon_filename:
        icon_full_path = os.path.join(icon_folder, icon_filename)
        metadata["icon"] = _encode_image(icon_full_path)
    for component in metadata["components"]:
        metadata_file = os.path.join(components_folder, component, "metadata.json")
        with open(metadata_file, "r") as f:
            component_metadata = json.load(f)
            component_metadata["group"] = metadata["title"]
            component_metadata["cartoEnvVars"] = component_metadata.get(
                "cartoEnvVars", []
            )
            components.append(component_metadata)

        fullrun_file = os.path.join(components_folder, component, "src", "fullrun.sql")
        with open(fullrun_file, "r") as f:
            fullrun_code = f.read()

        code_hash = (
            int(hashlib.sha256(fullrun_code.encode("utf-8")).hexdigest(), 16) % 10**8
        )
        component_metadata["procedureName"] = f"__proc_{component}_{code_hash}"
        icon_filename = component_metadata.get("icon")
        if icon_filename:
            icon_full_path = os.path.join(icon_folder, icon_filename)
            component_metadata["icon"] = _encode_image(icon_full_path)

    metadata["components"] = components
    return metadata


def get_procedure_code_bq(component):
    current_folder = os.path.dirname(os.path.abspath(__file__))
    components_folder = os.path.join(current_folder, "components")
    fullrun_file = os.path.join(
        components_folder, component["name"], "src", "fullrun.sql"
    )
    with open(fullrun_file, "r") as f:
        fullrun_code = f.read().replace("\n", "\n" + " " * 16)
    dryrun_file = os.path.join(
        components_folder, component["name"], "src", "dryrun.sql"
    )
    with open(dryrun_file, "r") as f:
        dryrun_code = f.read().replace("\n", "\n" + " " * 16)

    newline_and_tab = ",\n" + " " * 12
    params_string = newline_and_tab.join(
        [
            f"{p['name']} {_param_type_to_bq_type(p['type'])[0]}"
            for p in component["inputs"] + component["outputs"]
        ]
    )

    carto_env_vars = component["cartoEnvVars"] if "cartoEnvVars" in component else []
    env_vars = newline_and_tab.join(
        [
            f"DECLARE {v} STRING DEFAULT TO_JSON_STRING(__parsed.{v});"
            for v in carto_env_vars
        ]
    )
    procedure_code = f"""\
        CREATE OR REPLACE PROCEDURE {WORKFLOWS_TEMP_PLACEHOLDER}.`{component["procedureName"]}`(
            {params_string},
            dry_run BOOLEAN,
            env_vars STRING
        )
        BEGIN
            DECLARE __parsed JSON default PARSE_JSON(env_vars);
            {env_vars}
            IF (dry_run) THEN
                BEGIN
                {dryrun_code}
                END;
            ELSE
                BEGIN
                {fullrun_code}
                END;
            END IF;
        END;
        """
    procedure_code = "\n".join(
        [line for line in procedure_code.split("\n") if line.strip()]
    )
    return procedure_code


def create_sql_code_bq(metadata):
    procedures_code = ""
    for component in metadata["components"]:
        procedure_code = get_procedure_code_bq(component)
        procedures_code += "\n" + procedure_code
    procedures = [c["procedureName"] for c in metadata["components"]]
    metadata_string = json.dumps(metadata).replace("\\n", "\\\\n")
    code = dedent(
        f"""\
        DECLARE procedures STRING;
        DECLARE proceduresArray ARRAY<STRING>;
        DECLARE i INT64 DEFAULT 0;

        CREATE TABLE IF NOT EXISTS {WORKFLOWS_TEMP_PLACEHOLDER}.{EXTENSIONS_TABLENAME} (
            name STRING,
            metadata STRING,
            procedures STRING
        );

        -- remove procedures from previous installations

        SET procedures = (
            SELECT procedures
            FROM {WORKFLOWS_TEMP_PLACEHOLDER}.{EXTENSIONS_TABLENAME}
            WHERE name = '{metadata["name"]}'
        );
        IF (procedures IS NOT NULL) THEN
            SET proceduresArray = SPLIT(procedures, ',');
            LOOP
                SET i = i + 1;
                IF i > ARRAY_LENGTH(proceduresArray) THEN
                    LEAVE;
                END IF;
                EXECUTE IMMEDIATE 'DROP PROCEDURE {WORKFLOWS_TEMP_PLACEHOLDER}.' || proceduresArray[ORDINAL(i)];
            END LOOP;
        END IF;

        DELETE FROM {WORKFLOWS_TEMP_PLACEHOLDER}.{EXTENSIONS_TABLENAME}
        WHERE name = '{metadata["name"]}';

        -- create procedures
        {procedures_code}

        -- add to extensions table

        INSERT INTO {WORKFLOWS_TEMP_PLACEHOLDER}.{EXTENSIONS_TABLENAME} (name, metadata, procedures)
        VALUES ('{metadata["name"]}', '''{metadata_string}''', '{','.join(procedures)}');"""
    )

    return dedent(code)


def get_procedure_code_sf(component):
    current_folder = os.path.dirname(os.path.abspath(__file__))
    components_folder = os.path.join(current_folder, "components")
    fullrun_file = os.path.join(
        components_folder, component["name"], "src", "fullrun.sql"
    )
    with open(fullrun_file, "r") as f:
        fullrun_code = f.read().replace("\n", "\n" + " " * 16).replace("'", "\\'")
    dryrun_file = os.path.join(
        components_folder, component["name"], "src", "dryrun.sql"
    )
    with open(dryrun_file, "r") as f:
        dryrun_code = f.read().replace("\n", "\n" + " " * 16).replace("'", "\\'")
    newline_and_tab = ",\n" + " " * 12
    params_string = newline_and_tab.join(
        [
            f"{p['name']} {_param_type_to_sf_type(p['type'])[0]}"
            for p in component["inputs"] + component["outputs"]
        ]
    )

    carto_env_vars = component["cartoEnvVars"] if "cartoEnvVars" in component else []
    env_vars = newline_and_tab.join(
        [
            f"DECLARE {v} VARCHAR DEFAULT JSON_EXTRACT_PATH_TEXT(env_vars, '{v}');"
            for v in carto_env_vars
        ]
    )
    procedure_code = dedent(
        f"""\
        CREATE OR REPLACE PROCEDURE {WORKFLOWS_TEMP_PLACEHOLDER}.{component["procedureName"]}(
            {params_string},
            dry_run BOOLEAN,
            env_vars VARCHAR
        )
        RETURNS VARCHAR
        LANGUAGE SQL
        EXECUTE AS CALLER
        AS '
        BEGIN
            {env_vars}
            IF ( :dry_run ) THEN
                DECLARE
                    _workflows_temp VARCHAR := \\'@@workflows_temp@@\\';
                BEGIN
                    -- TODO: remove once the database is set for dry-runs
                    EXECUTE IMMEDIATE \\'USE DATABASE \\' || SPLIT_PART(_workflows_temp, \\'.\\', 0);

                {dryrun_code}
                END;
            ELSE
                BEGIN
                {fullrun_code}
                END;
            END IF;
        END;
        ';
        """
    )

    procedure_code = "\n".join(
        [line for line in procedure_code.split("\n") if line.strip()]
    )
    return procedure_code


def create_sql_code_sf(metadata):
    procedures_code = ""
    for component in metadata["components"]:
        procedure_code = get_procedure_code_sf(component)
        procedures_code += "\n" + procedure_code
    procedures = []
    for c in metadata["components"]:
        param_types = [f"{p['type']}" for p in c["inputs"]]
        procedures.append(f"{c['procedureName']}({','.join(param_types)})")
    metadata_string = json.dumps(metadata).replace("\\n", "\\\\n").replace("'", "\\'")
    procedures_string =  ';'.join(procedures).replace("'", "\'")
    code = dedent(
        f"""DECLARE
            procedures STRING;
        BEGIN
            CREATE TABLE IF NOT EXISTS {WORKFLOWS_TEMP_PLACEHOLDER}.{EXTENSIONS_TABLENAME} (
                name STRING,
                metadata STRING,
                procedures STRING
            );

            -- remove procedures from previous installations

            procedures := (
                SELECT procedures
                FROM {WORKFLOWS_TEMP_PLACEHOLDER}.{EXTENSIONS_TABLENAME}
                WHERE name = '{metadata["name"]}'
            );

            BEGIN
                EXECUTE IMMEDIATE 'DROP PROCEDURE IF EXISTS {WORKFLOWS_TEMP_PLACEHOLDER}.'
                    || REPLACE(:procedures, ';', ';DROP PROCEDURE IF EXISTS {WORKFLOWS_TEMP_PLACEHOLDER}.');
            EXCEPTION
                WHEN OTHER THEN
                    NULL;
            END;

            DELETE FROM {WORKFLOWS_TEMP_PLACEHOLDER}.{EXTENSIONS_TABLENAME}
            WHERE name = '{metadata["name"]}';

            -- create procedures
            {procedures_code}

            -- add to extensions table

            INSERT INTO {WORKFLOWS_TEMP_PLACEHOLDER}.{EXTENSIONS_TABLENAME} (name, metadata, procedures)
            VALUES ('{metadata["name"]}', '{metadata_string}', '{procedures_string}');
        END;"""
    )

    return code


def deploy_bq(metadata, destination):
    print("Deploying extension to BigQuery...")
    destination = f"`{destination}`" if destination else bq_workflows_temp
    sql_code = create_sql_code_bq(metadata)
    sql_code = sql_code.replace(WORKFLOWS_TEMP_PLACEHOLDER, destination)
    sql_code = substitute_vars(sql_code)
    if verbose:
        print(sql_code)
    query_job = bq_client().query(sql_code)
    query_job.result()
    print("Extension correctly deployed to BigQuery.")


def deploy_sf(metadata, destination):
    print("Deploying extension to SnowFlake...")
    destination = destination or sf_workflows_temp
    sql_code = create_sql_code_sf(metadata)
    sql_code = sql_code.replace(WORKFLOWS_TEMP_PLACEHOLDER, destination)
    sql_code = substitute_vars(sql_code)

    if verbose:
        print(sql_code)
    cur = sf_client().cursor()
    cur.execute(sql_code)
    print("Extension correctly deployed to SnowFlake.")


def deploy(destination):
    metadata = create_metadata()
    if metadata["provider"] == "bigquery":
        deploy_bq(metadata, destination)
    else:
        deploy_sf(metadata, destination)


def substitute_vars(text: str) -> str:
    """Substitute all variables in a string with their values from the environment.

    For a given string, all the variables using the syntax `@@variable_name@@`
    will be interpolated with their values from the corresponding env vars.
    It will raise a ValueError if any variable name is not present in the
    environment.
    """
    pattern = r"@@([a-zA-Z0-9_]+)@@"

    for variable in re.findall(pattern, text, re.MULTILINE):
        env_var_value = os.getenv(variable.upper())
        if env_var_value is None:
            raise ValueError(f"Environment variable {variable} is not set")
        text = text.replace(f"@@{variable}@@", env_var_value)

    return text


def substitute_keys(text: str, dotenv: dict[str, str]) -> str:
    """Substitute all variables in the .env file with their key.

    For a given string, find all occurences of the contents in the .env file and
    substitute them for their respective keys using the `@@variable_name@@`
    syntax. This function is written to be used when capturing results of tests.
    """
    for key, value in dotenv.items():
        if value in text:
            print(f"Changing {value} for @@{key}@@ in the captured results...")
            text = text.replace(value, f"@@{key}@@")

    return text


def infer_schema_field_bq(key: str, value: Any) -> bigquery.SchemaField:
    if isinstance(value, int):
        return bigquery.SchemaField(key, "INT64")
    elif isinstance(value, float):
        return bigquery.SchemaField(key, "FLOAT64")

    elif isinstance(value, str):
        if key.endswith("date"):
            return bigquery.SchemaField(key, "DATE")
        elif key.endswith("timestamp"):
            return bigquery.SchemaField(key, "TIMESTAMP")
        elif key.endswith("datetime"):
            return bigquery.SchemaField(key, "DATETIME")
        else:
            try:
                wkt.loads(value)
                return bigquery.SchemaField(key, "GEOGRAPHY")
            except Exception:
                return bigquery.SchemaField(key, "STRING")

    elif isinstance(value, dict):
        sub_schema = [
            infer_schema_field_bq(sub_key, sub_value)
            for sub_key, sub_value in value.items()
        ]

        return bigquery.SchemaField(key, "RECORD", fields=sub_schema)

    else:
        raise NotImplementedError(
            f"Could not infer a BigQuery SchemaField for {value} ({type(value)})"
        )

def _upload_test_table_bq(filename, component):
    schema = []
    with open(filename) as f:
        data = [json.loads(l) for l in f.readlines()]
    if os.path.exists(filename.replace(".ndjson", ".schema")):
        with open(filename.replace(".ndjson", ".schema")) as f:
            jsonschema = json.load(f)
            for key, value in jsonschema.items():
                schema.append(bigquery.SchemaField(key, value))
    else:
        for key, value in data[0].items():
            schema.append(infer_schema_field_bq(key, value))

    dataset_id = os.getenv("BQ_TEST_DATASET")
    table_id = f"_test_{component['name']}_{os.path.basename(filename).split('.')[0]}"

    dataset_ref = bq_client().dataset(dataset_id)
    table_ref = dataset_ref.table(table_id)
    job_config = bigquery.LoadJobConfig()
    job_config.source_format = bigquery.SourceFormat.NEWLINE_DELIMITED_JSON
    job_config.autodetect = True
    job_config.write_disposition = bigquery.WriteDisposition.WRITE_TRUNCATE
    job_config.schema = schema

    with open(filename, "rb") as source_file:
        processed = io.BytesIO()
        for line in source_file:
            processed_line = substitute_vars(line.decode("utf-8"))
            processed.write(processed_line.encode("utf-8"))

        processed.seek(0)

        job = bq_client().load_table_from_file(
            processed,
            table_ref,
            job_config=job_config,
        )
    try:
        job.result()
    except Exception as e:
        pass


def infer_schema_field_sf(key: str, value: Any) -> bigquery.SchemaField:
    if isinstance(value, int):
        return "NUMBER"
    elif isinstance(value, float):
        return "FLOAT"

    elif isinstance(value, str):
        if key.endswith("date"):
            return "DATE"
        elif key.endswith("timestamp"):
            return "TIMESTAMP"
        elif key.endswith("datetime"):
            return "DATETIME"
        else:
            try:
                wkt.loads(value)
                return "GEOGRAPHY"
            except Exception:
                return "VARCHAR"

    else:
        raise NotImplementedError(
            f"Could not infer a Snowflake SchemaField for {value} ({type(value)})"
        )


def _upload_test_table_sf(filename, component):
    with open(filename) as f:
        data = []
        for l in f.readlines():
            if l.strip():
                data.append(json.loads(substitute_vars(l)))
    if os.path.exists(filename.replace(".ndjson", ".schema")):
        with open(filename.replace(".ndjson", ".schema")) as f:
            data_types = json.load(f)
    else:
        data_types = {
            key: infer_schema_field_sf(key, value)
            for key, value in data[0].items()
        }

    table_id = f"_test_{component['name']}_{os.path.basename(filename).split('.')[0]}"
    create_table_sql = f"CREATE OR REPLACE TABLE {sf_workflows_temp}.{table_id} ("
    for key, value in data[0].items():
        create_table_sql += f"{key} {data_types[key]}, "
    create_table_sql = create_table_sql.rstrip(", ")
    create_table_sql += ");\n"
    cursor = sf_client().cursor()
    cursor.execute(create_table_sql)
    for row in data:
        values = {}
        for key, value in row.items():
            if value is None:
                values[key] = "null"
            elif data_types[key] in ["NUMBER", "FLOAT"]:
                values[key] = str(value)
            else:
                values[key] = f"'{value}'"
        values_string = ", ".join([values[key] for key in row.keys()])
        insert_sql = f"INSERT INTO {sf_workflows_temp}.{table_id} ({', '.join(row.keys())}) VALUES ({values_string})"
        cursor.execute(insert_sql)
    cursor.close()


def _get_test_results(metadata, component):
    if metadata["provider"] == "bigquery":
        upload_function = _upload_test_table_bq
        workflows_temp = bq_workflows_temp
    else:
        upload_function = _upload_test_table_sf
        workflows_temp = sf_workflows_temp
    results = {}
    if component:
        components = [c for c in metadata["components"] if c["name"] == component]
    else:
        components = metadata["components"]
    current_folder = os.path.dirname(os.path.abspath(__file__))
    components_folder = os.path.join(current_folder, "components")

    for component in components:
        component_folder = os.path.join(components_folder, component["name"])
        test_folder = os.path.join(component_folder, "test")
        # upload test tables
        for filename in os.listdir(test_folder):
            if filename.endswith(".ndjson"):
                upload_function(os.path.join(test_folder, filename), component)
        # run tests
        test_configuration_file = os.path.join(test_folder, "test.json")
        with open(test_configuration_file, "r") as f:
            test_configurations = json.loads(substitute_vars(f.read()))

        tables = {}
        component_results = {}
        for test_configuration in test_configurations:
            param_values = []
            test_id = test_configuration["id"]
            component_results[test_id] = {}
            for inputparam in component["inputs"]:
                param_value = test_configuration["inputs"][inputparam["name"]]
                if param_value is None:
                    param_values.append(None)
                else:
                    if inputparam["type"] == "Table":
                        tablename = f"'{workflows_temp}._test_{component['name']}_{param_value}'"
                        param_values.append(tablename)
                    elif inputparam["type"] in [
                        "String",
                        "Selection",
                        "StringSql",
                        "Json",
                        "GeoJson",
                        "Column",
                    ]:
                        param_values.append(f"'{param_value}'")
                    else:
                        param_values.append(param_value)
            tablename = f"{workflows_temp}._table_{uuid4().hex}"
            for outputparam in component["outputs"]:
                param_values.append(f"'{tablename}'")
                tables[outputparam["name"]] = tablename

            env_vars = json.dumps(test_configuration.get("env_vars", None))

            dry_run_params = param_values.copy() + [True, env_vars]
            dry_run_query = _build_query(workflows_temp, component["procedureName"], dry_run_params)

            full_run_params = param_values.copy() + [False, env_vars]
            full_run_query = _build_query(workflows_temp, component["procedureName"], full_run_params)

            # TODO: improve argument passing to _run_query()
            component_results[test_id]["dry"] = _run_query(dry_run_query, component, metadata["provider"], tables)
            component_results[test_id]["full"] = _run_query(full_run_query, component, metadata["provider"], tables)

        results[component["name"]] = component_results

    return results

def _build_query(workflows_temp, component_name, param_values):
    return f"""CALL {workflows_temp}.{component_name}(
        {','.join([str(p) if p is not None else 'null' for p in param_values])}
    );"""

def _run_query(query: str, component: dict, provider: str, tables: dict) -> dict[str, pd.DataFrame]:
    results = dict()

    if verbose:
        print(query)
    if provider == "bigquery":
        query_job = bq_client().query(query)
        result = query_job.result()
        for output in component["outputs"]:
            query = f"SELECT * FROM {tables[output['name']]}"
            query_job = bq_client().query(query)
            results[output["name"]] = query_job.result().to_dataframe()
    else:
        cur = sf_client().cursor()
        cur.execute(query)
        for output in component["outputs"]:
            query = f"SELECT * FROM {tables[output['name']]}"
            cur = sf_client().cursor()
            cur.execute(query)
            # Use .fetch_pandas_all() to include column names
            results[output["name"]] = cur.fetch_pandas_all()

    return results


def test(component):
    print("Testing extension...")
    metadata = create_metadata()
    current_folder = os.path.dirname(os.path.abspath(__file__))
    components_folder = os.path.join(current_folder, "components")
    deploy(None)
    results = _get_test_results(metadata, component)

    for component in metadata["components"]:
        component_folder = os.path.join(components_folder, component["name"])
        for test_id, outputs in results[component["name"]].items():
            test_folder = os.path.join(component_folder, "test", "fixtures")
            test_filename = os.path.join(test_folder, f"{test_id}.json")

            zipped_outputs = [
                (output_name, dry_output, outputs["full"][output_name])
                for output_name, dry_output in outputs["dry"].items()
            ]

            # Test that dry and full runs have the same schema
            for output_name, dry_output, full_output in zipped_outputs:
                if not check_schema(dry_output, full_output):
                    raise AssertionError(
                        f"Dry run and full run schemas do not match "
                        f"in {component['title']} - {test_id} - {output_name}"
                    )
            
            if str(test_id).startswith("skip_"):
                # Don't compare results, it will only throw an error
                # if there is an issue when running on BigQuery
                continue

            # Test that the results match the expected ones
            with open(test_filename, "r") as f:
                expected = json.loads(substitute_vars(f.read()))
                for output_name, test_result_df in outputs["full"].items():
                    output = dataframe_to_dict(test_result_df)
                    if not test_output(expected[output_name], output, decimal_places=3):
                        raise AssertionError(
                            f"Test '{test_id}' failed for component {component['name']} and table {output_name}."
                        )

    print("Extension correctly tested.")


def dataframe_to_dict(df: pd.DataFrame) -> dict[str, Any]:
    """Uniformly convert a pandas DataFrame to a neste structure.

    This function ensures that, once calling `to_dict` on a Python DataFrames,
    only primitive Python types are stored in it. BigQuery tends to download
    the of `ARRAY<...>` columns as np.ndarray, which can generate errors when
    capturing or testing. This functions handles that conversion.
    """
    for column, dtype in df.dtypes.to_dict().items():
        if dtype == 'object':
            try:
                value = df.iloc[0].loc[column]
            except IndexError:
                break

            if isinstance(value, np.ndarray):
                # Convert from numpy to primitive types
                df[column] = df[column].apply(lambda arr: arr.tolist())

    output = df.to_dict(orient="records")
    return output


def check_schema(dry_result, full_result) -> bool:
    """Compare two different DataFrames two have the same columns."""
    dry_schema = dry_result.dtypes.astype(str).to_dict()
    full_schema = full_result.dtypes.astype(str).to_dict()
    return dry_schema.keys() == full_schema.keys()


def normalize_json(original, decimal_places=3):
    """Ensure that the input for a test is in an uniform format.

    This function takes an input and generates a new version of it that does
    comply with an uniform format, including the precision of the floats.
    """
    # GOTCHA: dump and load to pass all values through the JSON parser, to
    # prevent any mismatch in types that cannot be inferred (i.e. Timestamp)
    original = json.loads(json.dumps(original, default=str))

    processed = list()
    for row in _sorted_json(original):
        processed.append(
            {
                column: normalize_element(value, decimal_places)
                for column, value in row.items()
            }
        )

    return processed

def normalize_element(value, decimal_places=3):
    """Format a single scalar value in the desired format."""
    if isinstance(value, dict) or isinstance(value, list):
        return sorted(map(normalize_element, value))
    elif isinstance(value, float) and math.isnan(value):
        return "nan"
    elif isinstance(value, float):
        return round(value, decimal_places)
    elif value is None:
        return "None"
    else:
        return value


def _sorted_json(data):
    """Recursively sort JSON-like structures (lists of dicts) to enable consistent ordering."""
    if isinstance(data, dict):
        return {key: _sorted_json(data[key]) for key in sorted(data)}
    elif isinstance(data, list):
        return sorted(
            (_sorted_json(item) for item in data),
            key=(lambda j: json.dumps(j, default=str))
        )
    else:
        return data


def test_output(expected, result, decimal_places=3):
    expected = normalize_json(_sorted_json(expected), decimal_places=decimal_places)
    result = normalize_json(_sorted_json(result), decimal_places=decimal_places)
    return expected == result


def capture(component):
    print("Capturing fixtures... ")
    metadata = create_metadata()
    current_folder = os.path.dirname(os.path.abspath(__file__))
    components_folder = os.path.join(current_folder, "components")
    deploy(None)
    results = _get_test_results(metadata, component)
    dotenv = dotenv_values()
    for component in metadata["components"]:
        component_folder = os.path.join(components_folder, component["name"])
        for test_id, outputs in results[component["name"]].items():
            test_folder = os.path.join(component_folder, "test", "fixtures")
            os.makedirs(test_folder, exist_ok=True)
            test_filename = os.path.join(test_folder, f"{test_id}.json")
            with open(test_filename, "w") as f:
                outputs = {
                    output_name: output_results.to_dict(orient="records")
                    for output_name, output_results in outputs["full"].items()
                }

                contents = json.dumps(outputs, indent=2, default=str)
                contents = substitute_keys(contents, dotenv=dotenv)
                f.write(contents)

    print("Fixtures correctly captured.")


def package():
    print("Packaging extension...")
    current_folder = os.path.dirname(os.path.abspath(__file__))
    metadata = create_metadata()
    sql_code = (
        create_sql_code_bq(metadata)
        if metadata["provider"] == "bigquery"
        else create_sql_code_sf(metadata)
    )
    package_filename = os.path.join(current_folder, "extension.zip")
    with zipfile.ZipFile(package_filename, "w") as z:
        with z.open("metadata.json", "w") as f:
            f.write(
                json.dumps(add_namespace_to_component_names(metadata), indent=2).encode(
                    "utf-8"
                )
            )
        with z.open("extension.sql", "w") as f:
            f.write(sql_code.encode("utf-8"))

    print(f"Extension correctly packaged to '{package_filename}' file.")


def update():
    download_file("carto_extension.py", os.getcwd())
    download_file("requirements.txt", os.getcwd())


def download_file(
    path_to_file: str,
    destination_dir: str,
    remote_url: str = "https://raw.githubusercontent.com/CartoDB/workflows-extension-template",
    remote_branch: str = "master",
):
    complete_url = f"{remote_url}/{remote_branch}/{path_to_file}"
    complete_path = f"{destination_dir}/{path_to_file}"

    tmp_path = os.path.dirname(complete_path) + ".tmp"
    urllib.request.urlretrieve(complete_url, tmp_path)
    os.replace(tmp_path, complete_path)

    print(f"Downloaded {complete_url} to {complete_path}")


def _param_type_to_bq_type(param_type):
    if param_type in [
        "Table",
        "String",
        "StringSql",
        "Json",
        "GeoJson",
        "GeoJsonDraw",
        "Condition",
        "Range",
        "Selection",
        "SelectionType",
        "SelectColumnType",
        "SelectColumnAggregation",
        "Column",
        "ColumnNumber",
        "SelectColumnNumber",
    ]:
        return ["STRING"]
    elif param_type == "Number":
        return ["FLOAT64", "INT64"]
    elif param_type == "Boolean":
        return ["BOOL", "BOOLEAN"]
    else:
        raise ValueError(f"Parameter type '{param_type}' not supported")


def _param_type_to_sf_type(param_type):
    if param_type in [
        "Table",
        "String",
        "StringSql",
        "Json",
        "GeoJson",
        "GeoJsonDraw",
        "Condition",
        "Range",
        "Selection",
        "SelectionType",
        "SelectColumnType",
        "SelectColumnAggregation",
        "Column",
        "ColumnNumber",
        "SelectColumnNumber",
    ]:
        return ["STRING", "VARCHAR"]
    elif param_type == "Number":
        return ["FLOAT", "INTEGER"]
    elif param_type == "Boolean":
        return ["BOOLEAN"]
    else:
        raise ValueError(f"Parameter type '{param_type}' not supported")


def check():
    print("Checking extension...")
    current_folder = os.path.dirname(os.path.abspath(__file__))
    metadata = create_metadata()
    components_folder = os.path.join(current_folder, "components")
    for component in metadata["components"]:
        component_folder = os.path.join(components_folder, component["name"])
        component_metadata_file = os.path.join(component_folder, "metadata.json")
        with open(component_metadata_file, "r") as f:
            component_metadata = json.load(f)
        required_fields = ["name", "title", "description", "icon", "version"]
        for field in required_fields:
            assert (
                field in component_metadata
            ), f"Component metadata is missing field '{field}'"
    required_fields = [
        "name",
        "title",
        "industry",
        "description",
        "icon",
        "version",
        "lastUpdate",
        "provider",
        "author",
        "license",
        "components",
    ]
    for field in required_fields:
        assert field in metadata, f"Extension metadata is missing field '{field}'"

    print("Extension correctly checked. No errors found.")


parser = argparse.ArgumentParser()
parser.add_argument(
    "action",
    nargs=1,
    type=str,
    choices=["package", "deploy", "test", "capture", "check", "update"],
)
parser.add_argument("-c", "--component", help="Choose one component", type=str)
parser.add_argument(
    "-d",
    "--destination",
    help="Choose an specific destination",
    type=str,
    required="deploy" in argv,
)
parser.add_argument("-v", "--verbose", help="Verbose mode", action="store_true")
args = parser.parse_args()
action = args.action[0]
verbose = args.verbose
if args.component and action not in ["capture", "test"]:
    parser.error("Component can only be used with 'capture' and 'test' actions")
if args.destination and action not in ["deploy"]:
    parser.error("Destination can only be used with 'deploy' action")
if action == "package":
    check()
    package()
elif action == "deploy":
    deploy(args.destination)
elif action == "test":
    test(args.component)
elif action == "capture":
    capture(args.component)
elif action == "check":
    check()
elif action == "update":
    update()
