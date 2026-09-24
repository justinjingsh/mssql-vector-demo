/*
    01 - Export asset data
    No AI model needed. Run against the source asset database (the one with
    dbo.AssemblyAssessments, dbo.Assemblies, dbo.Site and so on), not against
    AssetVectorDemo.

    Returns the 100 most recent assembly assessments as flat rows: where the
    asset is (site > facility > area > space), what it is (category > element
    > assembly), how many were counted, its attributes as a JSON string and an
    overall condition. Save the result as a JSON array to data/asset-data.json,
    one object per row with the column names as keys - 03-import-data.sql
    reads that file.

    The output holds real customer records. data/*.json is in .gitignore:
    keep it out of git.

    Read-only. NOLOCK avoids blocking the live database; for a one-off export
    the risk of reading a half-finished change is acceptable.
*/

SELECT TOP 100
    ST.SiteName,
    F.FacilityName,
    AR.AreaName,
    SP.SpaceName,
    C.CategoryName, 
    E.ElementName,
    A.AssemblyName,
    AA.CountedUnits,                 -- imported as dbo.Asset.Quantity
    -- All of the assessment's attributes as one JSON array string:
    -- [{"attributeName":"Asset Tag","attributeValue":"CBT003688"}, ...]
    (
        SELECT [AT].AttributeTypeName AS attributeName,
               AAA.AttributeValue     AS attributeValue
        FROM dbo.AssemblyAssessmentAttribute AS AAA WITH (NOLOCK)
        INNER JOIN dbo.AttributeType AS [AT] WITH (NOLOCK)
            ON AAA.AttributeTypeID = [AT].AttributeTypeID
        WHERE AAA.AssemblyAssessmentID = AA.AssemblyAssessmentID   -- link to the outer row
        FOR JSON PATH
    ) AS [AttributeJson],
    -- Average grade (from the CROSS APPLY below) turned back into a label.
    CASE
        WHEN T.AvgCondition = 0   THEN NULL          -- nothing counted
        WHEN T.AvgCondition < 1.5 THEN 'Excellent'
        WHEN T.AvgCondition < 2.5 THEN 'Good'
        WHEN T.AvgCondition < 3.5 THEN 'Fair'
        WHEN T.AvgCondition < 4.5 THEN 'Poor'
        ELSE 'Very Poor'
    END AS Condition
FROM dbo.AssemblyAssessments AS AA WITH (NOLOCK)
INNER JOIN dbo.Assemblies AS A WITH (NOLOCK) ON AA.AssemblyID = A.AssemblyID
INNER JOIN dbo.Elements AS E WITH (NOLOCK) ON A.ElementID = E.ElementID
INNER JOIN dbo.Categories AS C WITH (NOLOCK) ON E.CategoryID = C.CategoryID
INNER JOIN dbo.Space AS SP WITH (NOLOCK) ON AA.SpaceID = SP.SpaceID
INNER JOIN dbo.Area AS AR WITH (NOLOCK) ON SP.AreaID = AR.AreaID
INNER JOIN dbo.Facility AS F WITH (NOLOCK) ON AR.FacilityID = F.FacilityID
INNER JOIN dbo.Site AS ST WITH (NOLOCK) ON F.SiteID = ST.SiteID
-- Units are counted per condition grade (1 = Excellent ... 5 = Very Poor).
-- Weight each grade by its unit count to get the assessment's average grade.
CROSS APPLY (
    SELECT CASE
        WHEN AA.CountedUnits = 0 THEN 0
        ELSE (AA.UnitsInExcellent1Condition * 1
            + AA.UnitsInGood2Condition      * 2
            + AA.UnitsInFair3Condition      * 3
            + AA.UnitsInPoor4Condition      * 4
            + AA.UnitsInVeryPoor5Condition  * 5) * 1.0 / AA.CountedUnits
    END AS AvgCondition
) AS T
-- Leave out these two clients' facilities.
WHERE F.ClientID != 155 AND F.ClientID != 267
ORDER BY AA.AssemblyAssessmentID DESC;   -- newest assessments first
