# CI/CD Setup

GitHub Actions workflow with multi-provider support (BigQuery, Snowflake, or both).

## Configuration

The configuration is conditional, so **make sure to add only the required secrets**. For instance if the extension is for BigQuery, only configure the BigQuery values and if it is for Snowflake, only Snowflake's.

### BigQuery
**Secrets:**
- `BQ_CREDENTIALS_JSON_CI`: Service account JSON key (raw JSON)

**Variables:**
- `BQ_TEST_PROJECT`: GCP project ID
- `BQ_TEST_DATASET`: Dataset name

### Snowflake
**Secrets:**
- `SF_USER`: Username
- `SF_PASSWORD`: Password  
- `SF_ACCOUNT`: Account identifier

**Variables:**
- `SF_TEST_DATABASE`: Database name
- `SF_TEST_SCHEMA`: Schema name

## Setup

1. **Go to repository Settings → Secrets and variables → Actions**
2. **Add secrets** (encrypted) in Secrets tab
3. **Add variables** (plain text) in Variables tab

## Local Testing

```bash
# Install dependencies
uv pip install -r requirements.txt

# Set environment variables for BigQuery
export BQ_TEST_PROJECT="your-project"
export BQ_TEST_DATASET="your-dataset"
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/key.json"

# ... or Snowflake:
export SF_USER="your-user"
export SF_PASSWORD="your-password"
export SF_ACCOUNT="your-account"
export SF_TEST_DATABASE="your-db"
export SF_TEST_SCHEMA="your-schema"

# Run tests
uv run carto_extension.py test
```

## Troubleshooting

**"No CI environment variables detected"**
- Check secret/variable names are exact matches
- Ensure at least one provider is configured

**BigQuery auth fails**
- Verify JSON is raw (not base64)
- Check service account has BigQuery permissions

**Snowflake connection fails**
- Verify account format: `account.region`
- Check user has database/schema permissions
