"""
Step 5 - search the asset register in plain English.

The question is embedded with the same Bedrock model as the assets (Titan
Text Embeddings V2, 1,024 numbers), then SQL Server ranks the saved
embeddings in dbo.AssetEmbeddings by cosine distance: the smaller the
distance, the closer the asset is in meaning. Only assets that have been
embedded by bedrock_embeddings.py can be found.

Condition works best as an exact filter (CONDITION below) rather than as
words in the question: embeddings match meaning, so "good condition" in the
question nudges the ranking but won't reliably exclude Fair or Poor assets.

Usage (PowerShell), after logging in as described in bedrock_embeddings.py:
    $env:AWS_PROFILE = "dev"
    python search_assets.py

It imports get_embedding and the settings from bedrock_embeddings.py, so keep
the two files in the same folder.
"""

import json

import boto3
import pyodbc

from bedrock_embeddings import CONNECTION_STRING, DIMENSIONS, REGION, get_embedding

# What to search for. Edit these and re-run.
#QUESTION = "emergency and exit lighting"
QUESTION = "find the asset that is related to fire door"
CONDITION = "Excellent"   # Excellent, Good, Fair, Poor, Very Poor - or None for any
TOP_N = 5

SEARCH_QUERY = """
SET NOCOUNT ON;

-- pyodbc sends the long JSON array as ntext, which can't be cast to VECTOR
-- directly, so take it as NVARCHAR(MAX) first.
DECLARE @QuestionJson NVARCHAR(MAX) = ?,
        @Condition    NVARCHAR(50)  = ?,
        @TopN         INT           = ?;

DECLARE @Question VECTOR(1024) = CAST(@QuestionJson AS VECTOR(1024));

SELECT TOP (@TopN)
    a.Id,
    a.AssemblyName,
    a.SpaceName,
    a.FacilityName,
    a.Condition,
    VECTOR_DISTANCE('cosine', e.Embedding, @Question) AS Distance
FROM dbo.AssetEmbeddings AS e
INNER JOIN dbo.Asset AS a ON a.Id = e.AssetId
WHERE @Condition IS NULL OR a.Condition = @Condition
ORDER BY Distance;
"""


def search(question, condition=CONDITION, top_n=TOP_N, client=None):
    """Return the top_n closest assets to `question` as a list of pyodbc rows."""
    vector = get_embedding(question, dimensions=DIMENSIONS, client=client)
    with pyodbc.connect(CONNECTION_STRING) as conn:
        return conn.cursor().execute(
            SEARCH_QUERY, json.dumps(vector, separators=(",", ":")), condition, top_n
        ).fetchall()


def main():
    """Run the search for QUESTION and print the matches, closest first."""
    client = boto3.client("bedrock-runtime", region_name=REGION)
    rows = search(QUESTION, client=client)

    print(f'Question:  "{QUESTION}"')
    print(f"Condition: {CONDITION or 'any'}")
    print()
    if not rows:
        print("No matches - have the assets been embedded (bedrock_embeddings.py)?")
        return
    for row in rows:
        print(f"{row.Distance:.3f}  #{row.Id} {row.AssemblyName} - {row.SpaceName}, "
              f"{row.FacilityName} ({row.Condition})")


if __name__ == "__main__":
    main()
