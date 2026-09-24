# Python – embeddings from AWS Bedrock

Steps 4 and 5 of [02 – Asset register](../README.md). Load `AssetVectorDemo`
first with `../sql/02-create-database.sql` and `../sql/03-import-data.sql`.

`bedrock_embeddings.py` sends text to **Amazon Titan Text Embeddings V2**
(`amazon.titan-embed-text-v2:0`) on AWS Bedrock and saves the embedding in
`dbo.AssetEmbeddings`, updating the asset's row if it has one or inserting a
new row if not.

SQL Server's `CREATE EXTERNAL MODEL` can't call Bedrock directly (it supports
Azure OpenAI, OpenAI, Ollama and ONNX Runtime), so this script generates the
embeddings outside the database instead.

## Setup

```powershell
cd 02-asset-register/python
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

You also need:

- AWS credentials the script can find, for example from `aws configure` or
  `aws sso login`.
- Access to the Titan Text Embeddings V2 model in your Bedrock region.
- The `bedrock:InvokeModel` IAM permission for that model.

## Usage

The script reads assets from `dbo.Asset` in the `AssetVectorDemo`
database on your local SQL Server (Windows login, ODBC Driver 18), formats each
as labelled lines with one indented line per attribute, and embeds that text.
The connection, number of dimensions and region are set as
`CONNECTION_STRING`, `DIMENSIONS` and `REGION` near the top of the script.
`MAX_ASSETS` sets how many assets to embed, lowest Id first (`None` for all).
They're handled one at a time, and each is saved as soon as it's done. Log
in with your SSO profile (`aws sso login --profile <profile_name>`), tell the
script to use that profile and run it:

```powershell
aws sso login --profile dev
$env:AWS_PROFILE = "dev"      # this terminal window only
python bedrock_embeddings.py
```

Without `AWS_PROFILE`, the script looks for the `default` profile and fails
with `NoCredentialsError: Unable to locate credentials`.

From other Python code:

```python
from bedrock_embeddings import get_embedding

vector = get_embedding("Main switchboard hot spot", dimensions=1024)
```

## Searching in plain English

`search_assets.py` embeds a question with the same model and asks SQL Server
for the closest assets by cosine distance (smaller = closer in meaning). Set
`QUESTION`, `CONDITION` (e.g. `"Good"`, or `None` for any) and `TOP_N` at the
top of the script, then run it:

```powershell
python search_assets.py
```

Filter on condition with `CONDITION` rather than writing "good condition" in
the question: embeddings match meaning, so words like that only nudge the
ranking and won't reliably leave out Fair or Poor assets.

## Using the result in SQL Server

Titan V2 returns 256, 512 or **1,024** numbers (the default is 1,024). The
scripts `05` and `06` in `01-getting-started` use `VECTOR(1536)` for OpenAI's
`text-embedding-3-small`, so for Bedrock embeddings use `VECTOR(1024)` or match
whatever `DIMENSIONS` you set:

```sql
SELECT AssetId, VECTORPROPERTY(Embedding, 'Dimensions') AS dims, ModelId, CreatedOn
FROM dbo.AssetEmbeddings;   -- dims = 1024
```

Embed stored text and search questions with the same model and the same number
of dimensions. Vectors from different models can't be compared.
