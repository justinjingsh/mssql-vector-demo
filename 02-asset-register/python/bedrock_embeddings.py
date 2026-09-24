"""
Step 4 - embed the assets with Amazon Titan Text Embeddings V2 on AWS Bedrock.

Needs AssetVectorDemo loaded first (../sql/02-create-database.sql, then
../sql/03-import-data.sql). Step 5 is search_assets.py.

main() reads assets from dbo.Asset in the AssetVectorDemo database (the first
MAX_ASSETS by Id) and handles them one by one: it formats each asset as
labelled lines (SiteName: ..., Attributes: with one indented line per
attribute), sends that text to Bedrock, and saves the vector in
dbo.AssetEmbeddings - updating the asset's row if there is one, or inserting a
new row if not. Each asset is saved as soon as it's done, so if the run stops
part-way the finished ones are kept. An asset that fails is reported and
skipped, and the run carries on.

Usage (PowerShell):
    # 1. Log in to AWS with your SSO profile, e.g. dev:
    #      aws sso login --profile <profile_name>
    aws sso login --profile dev

    # 2. Tell boto3 to use that profile (lasts for this terminal window only):
    $env:AWS_PROFILE = "dev"

    # 3. Run the script:
    python bedrock_embeddings.py

Without step 2, boto3 looks for the default profile and fails with
"NoCredentialsError: Unable to locate credentials". Run step 1 again when the
SSO login expires.

The database connection, dimensions and region are set in the constants
below. The connection uses your Windows login on the local SQL Server and
needs pyodbc (pip install -r requirements.txt) and ODBC Driver 18 for SQL
Server.

AWS credentials can also come from environment variables, ~/.aws/credentials
or an IAM role. If REGION is None, the region comes from AWS_REGION or your
AWS config.
"""

import json

import boto3
import pyodbc

MODEL_ID = "amazon.titan-embed-text-v2:0"

# Titan V2 only accepts these output sizes. The size must match the VECTOR(n)
# column you store the result in.
VALID_DIMENSIONS = (256, 512, 1024)

DIMENSIONS = 1024
REGION = "ap-southeast-2"

# How many assets to embed, lowest Id first. None embeds them all.
MAX_ASSETS = 100

# Local SQL Server, Windows login. "." is this machine's default instance.
CONNECTION_STRING = (
    "DRIVER={ODBC Driver 18 for SQL Server};"
    "SERVER=.;"
    "DATABASE=AssetVectorDemo;"
    "Trusted_Connection=yes;"
    "TrustServerCertificate=yes;"
)

# Each asset as one block of text. Each attribute in the Attributes JSON
# ([{"attributeName": "Asset Tag", "attributeValue": "CBT003688"}, ...])
# becomes an indented "  Asset Tag: CBT003688" line. Blank columns are left out.
ASSET_QUERY = """
SELECT TOP (?)
    a.Id,
    CONCAT_WS(NCHAR(10),
        N'SiteName: '     + a.SiteName,
        N'FacilityName: ' + a.FacilityName,
        N'AreaName: '     + a.AreaName,
        N'SpaceName: '    + a.SpaceName,
        N'CategoryName: ' + a.CategoryName,
        N'ElementName: '  + a.ElementName,
        N'AssemblyName: ' + a.AssemblyName,
        N'Quantity: '     + CAST(a.Quantity AS NVARCHAR(20)),
        N'Condition: '    + a.Condition,
        N'Attributes:',
        (SELECT STRING_AGG(N'  ' + j.attributeName + N': ' + j.attributeValue, NCHAR(10))
         FROM OPENJSON(a.Attributes)
              WITH (attributeName NVARCHAR(250), attributeValue NVARCHAR(MAX)) AS j)
    ) AS Content
FROM dbo.Asset AS a
ORDER BY a.Id;
"""

# Update the asset's embedding if it has one, otherwise insert it. The vector
# is sent as a JSON array string, which SQL Server converts to the
# VECTOR(1024) column. CreatedOn records when the asset was last embedded.
SAVE_EMBEDDING = """
SET NOCOUNT ON;

DECLARE @AssetId    INT           = ?,
        @Embedding  NVARCHAR(MAX) = ?,
        @SourceText NVARCHAR(MAX) = ?,
        @ModelId    NVARCHAR(100) = ?;

UPDATE dbo.AssetEmbeddings
SET Embedding  = @Embedding,
    SourceText = @SourceText,
    ModelId    = @ModelId,
    CreatedOn  = SYSUTCDATETIME()
WHERE AssetId = @AssetId;

DECLARE @Action VARCHAR(10) = CASE WHEN @@ROWCOUNT = 0 THEN 'inserted' ELSE 'updated' END;

IF @Action = 'inserted'
    INSERT dbo.AssetEmbeddings (AssetId, Embedding, SourceText, ModelId)
    VALUES (@AssetId, @Embedding, @SourceText, @ModelId);

SELECT @Action AS Action;
"""


def get_embedding(text, dimensions=1024, normalize=True, region=None, client=None):
    """Return the embedding for `text` as a list of floats."""
    if dimensions not in VALID_DIMENSIONS:
        raise ValueError(f"dimensions must be one of {VALID_DIMENSIONS}, got {dimensions}")

    if client is None:
        client = boto3.client("bedrock-runtime", region_name=region)

    response = client.invoke_model(
        modelId=MODEL_ID,
        contentType="application/json",
        accept="application/json",
        body=json.dumps({
            "inputText": text,
            "dimensions": dimensions,
            # Normalised vectors (length 1) suit cosine distance, which the
            # SQL scripts use.
            "normalize": normalize,
        }),
    )

    result = json.loads(response["body"].read())
    return result["embedding"]


def get_assets(conn, max_assets=MAX_ASSETS):
    """Return a list of (asset id, formatted text), lowest Id first."""
    # TOP (?) needs a number, so "all" is the largest INT.
    limit = 2_147_483_647 if max_assets is None else max_assets
    rows = conn.cursor().execute(ASSET_QUERY, limit).fetchall()
    return [(row.Id, row.Content) for row in rows]


def save_embedding(conn, asset_id, text, embedding):
    """Upsert the embedding into dbo.AssetEmbeddings; return 'inserted' or 'updated'."""
    vector = json.dumps(embedding, separators=(",", ":"))
    action = conn.cursor().execute(
        SAVE_EMBEDDING, asset_id, vector, text, MODEL_ID
    ).fetchone().Action
    conn.commit()
    return action


def main():
    """Embed the first MAX_ASSETS assets and save each one, reporting progress."""
    client = boto3.client("bedrock-runtime", region_name=REGION)

    with pyodbc.connect(CONNECTION_STRING) as conn:
        assets = get_assets(conn)
        if not assets:
            raise RuntimeError("dbo.Asset is empty - run sql/03-import-data.sql first.")

        counts = {"inserted": 0, "updated": 0, "failed": 0}
        for n, (asset_id, text) in enumerate(assets, start=1):
            prefix = f"[{n}/{len(assets)}] Asset {asset_id}:"
            try:
                embedding = get_embedding(text, dimensions=DIMENSIONS, client=client)
                action = save_embedding(conn, asset_id, text, embedding)
            except Exception as error:  # report it and carry on with the next asset
                conn.rollback()
                counts["failed"] += 1
                print(f"{prefix} failed - {error}")
                continue
            counts[action] += 1
            print(f"{prefix} {action}")

    print(f"Done: {counts['inserted']} inserted, {counts['updated']} updated, "
          f"{counts['failed']} failed.")


if __name__ == "__main__":
    main()
