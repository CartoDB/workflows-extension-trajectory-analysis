CREATE OR REPLACE FUNCTION
    @@workflows_temp@@.`PYTHON_FIXED_VALUE`
(
    value STRING
)
RETURNS STRING
LANGUAGE python
OPTIONS (
  entry_point='main',
  runtime_version='python-3.11'
)
AS r"""
import platform


def main(value):
    return f"{value} from Python {platform.python_version()}"
""";
