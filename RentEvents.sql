SELECT DISTINCT c.Id,
                q.Id         AS TenancyId,
                y.CurrencyPerSquareFeet,
                q.AgreedRentPa,
				q.AgreedRentPa*1.0/TenancyArea*1.0 as RentCalc,
                case when (q.LeaseCommencementDate) > getdate() then q.CompletionDate else q.LeaseCommencementDate end as LeaseCommencementDate,
                q.LeaseExpiryDate,
				tenq.TenancyArea,
				tenq.TenancyFloors,
                p.Total_area AS BuildingArea,
                p.FloorNum   AS BuildingFloors,
                s.PropertyName,
                s.PropertyNumber,
                s.Line1,
                s.Line2,
                s.Line3,
                s.City,
                s.Postcode,
                s.County,
                s.uprnkey    AS UPRN,
                s.udprnkey   AS UDPRN,
                q.CompletionDate,
                c.EstimatedCompletionDate,
                c.LaunchDate,
                br.Code      AS BREEAMrating,
                ma.MaxPropSize,
				sz.SizeNIA,
                gr.Grade,
				ag.Age

FROM   [HubLive].[dbo].[Tenancy] q
       LEFT JOIN [HubLive].[dbo].[Asset] c
              ON q.assetid = c.id
       LEFT JOIN [HubLive].[dbo].[Address] s
              ON c.addressid = s.id
       LEFT JOIN [HubLive].[dbo].[MeasurementUnitValue] y
              ON q.AgreedRentPerUnitMaxId = y.Id
       LEFT JOIN (SELECT Id,
       Sum(SquareFeet) AS Total_area,
       Max(FloorNum)   AS FloorNum
FROM   (SELECT Id,
               SquareFeet,
               CASE
                 WHEN FloorNum LIKE '%.%'
                       OR FloorNum LIKE '%-%' THEN NULL
                 ELSE Cast(FloorNum AS INT)
               END AS FloorNum
        FROM   (SELECT w.Id,
                       m.SquareFeet,
                       LEFT(Substring(f.NAME, Patindex('%[0-9.-]%', f.NAME),
8000),
Patindex('%[^0-9.-]%', Substring(f.NAME, Patindex('%[0-9.-]%',
                  f.NAME),
                  8000)
                  + 'X') - 1) AS FloorNum
FROM   [HubLive].[dbo].[Asset] w
LEFT JOIN [HubLive].[dbo].[Address] j
  ON w.addressid = j.id
LEFT JOIN [HubLive].[dbo].[PropertyFloor] f
  ON w.id = f.PropertyId
LEFT JOIN [HubLive].[dbo].[PropertyArea] k
  ON f.Id = k.FloorId
LEFT JOIN [HubLive].[dbo].[MeasurementUnitValue] m
  ON k.SizeId = m.Id
LEFT JOIN [HubLive].[dbo].[PropertyType] o
  ON w.PropertyTypeId = o.Id
WHERE  j.City = 'London'
AND o.code LIKE '%office%'
AND w.Deleted = 0)k
WHERE  k.FloorNum <> ''
--and id = '72516FD9-B3EF-E611-80CE-005056820A11'
--and  m.squarefeet  is not null
)st
GROUP  BY Id ) p
              ON c.Id = p.Id
       LEFT JOIN [HubLive].[dbo].[PropertyType] z
              ON c.PropertyTypeId = z.Id
       LEFT JOIN [HubLive].[dbo].[TenancyPropertyArea] tpa
              ON q.id = tpa.TenancyId
       LEFT JOIN [HubLive].[dbo].[PropertyFloor] pf
              ON tpa.FloorId = pf.id
       LEFT JOIN (SELECT DISTINCT a.[AssetId],
                                  b.NameKey,
                                  c.Code
                  FROM   [HubLive].[dbo].[AssetAttributeValue] a
                         INNER JOIN [HubLive].[dbo].[Attribute] b
                                 ON a.AttributeId = b.id
                         INNER JOIN [HubLive].[dbo].[EnumTypeItem] c
                                 ON a.enumvalueid = c.id
                  WHERE  [Deleted] = 0
                         --AssetId='9def9a9b-183d-e611-80c5-005056820a11'
                         AND NameKey LIKE '%breeam%')br
              ON c.Id = br.AssetId
       LEFT JOIN (SELECT DISTINCT a.[AssetId],
                                  c.SquareFeet AS MaxPropSize
                  FROM   [HubLive].[dbo].[AssetAttributeValue] a
                         INNER JOIN [HubLive].[dbo].[Attribute] b
                                 ON a.AttributeId = b.id
                         INNER JOIN [HubLive].[dbo].MeasurementUnitValue c
                                 ON a.MaxNumberWithUnitValueId = c.id
                  WHERE  [Deleted] = 0
                         --AssetId='9def9a9b-183d-e611-80c5-005056820a11'
                         AND NameKey LIKE '%propertyarea%') ma
              ON c.Id = ma.AssetId
       LEFT JOIN (SELECT kaq.Id,
                         vaq.Grade
                  FROM   (SELECT DISTINCT Id,
                                          ActivityId
                          FROM   [HubLive].[dbo].[Tenancy]) kaq
                         INNER JOIN (SELECT DISTINCT Id,
                                                     RIGHT(LEFT(GradeLocalised,Charindex(',', GradeLocalised) - 2),Len(LEFT(GradeLocalised,Charindex(',',GradeLocalised)- 2))- Len('{"en":"')) AS Grade
                                     FROM   (SELECT Id,
                                                    [GradeLocalised]
                                             FROM
                                    [HubLive].[dbo].[ElasticSearchActivity]
                                             WHERE  LEFT(tenancytypeid, 1) = '9'
                                                    AND
                         gradeid <> '07501D04-E1F7-45F8-A1F7-5DE9EC11930A'
                                 AND gradeid IS NOT NULL
                                 AND Deleted = 0)laq)vaq
                                 ON kaq.ActivityId = vaq.Id) gr
              ON q.Id = gr.Id
	 LEFT JOIN (select [TenancyId], STRING_AGG(Floor, ', ') as TenancyFloors, sum(SquareFeet) as TenancyArea
from (
SELECT [TenancyId]
      ,[TenancyPropertyAreaId]
      ,[PropertyAreaId]
      ,[FloorId]
      ,[SizeId]
	  ,mv.SquareFeet
	  ,pf.Name as Floor
  FROM [HubLive].[dbo].[TenancyPropertyArea] tpa
  left join [HubLive].dbo.MeasurementUnitValue mv
   ON tpa.SizeId = mv.Id
     left join [HubLive].dbo.PropertyFloor pf
	 on tpa.FloorId=pf.Id
 -- where tenancyid='9DB28FD8-B3C5-EA11-A95E-000D3AB20BC5'
)b
 group by [TenancyId]
	 ) tenq
on q.Id=tenq.TenancyId

LEFT JOIN (
SELECT DISTINCT a.AssetId, a.StringValue as Age

                  FROM   [HubLive].[dbo].[AssetAttributeValue] a
                         INNER JOIN [HubLive].[dbo].[Attribute] b
                                 ON a.AttributeId = b.id
                  WHERE[Deleted] = 0
                         AND NameKey LIKE 'Age%'
)ag
on c.Id=ag.AssetId

LEFT JOIN (
select a.AssetId, c.SquareFeet as SizeNIA from [HubLive].[dbo].[AssetAttributeValue] a
INNER JOIN [HubLive].[dbo].[Attribute] b
                                 ON a.AttributeId = b.id 
INNER JOIN [HubLive].[dbo].MeasurementUnitValue c
                                 ON a.NumberWithUnitValueId = c.id
where deleted=0
and b.NameKey like '%Size%'
) sz
on c.Id = sz.AssetId
WHERE  LEFT(q.tenancytypeid, 1) = '9'
       AND s.City = 'London'
       --   and c.id='72516FD9-B3EF-E611-80CE-005056820A11'
       AND (y.CurrencyPerSquareFeet IS NOT NULL or (q.AgreedRentPa is not null and tenq.TenancyArea is not null) )
       AND z.code LIKE '%office%'
       --  and postcode=
       AND c.Deleted = 0
	  -- and q.LeaseCommencementDate >GETDATE()
ORDER  BY c.Id,
          q.Id 