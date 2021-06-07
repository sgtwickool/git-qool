SELECT o.name,m.definition,o.type_desc,s.name AS schemaname
FROM   sys.sql_modules AS m
INNER JOIN sys.objects AS o ON o.object_id = m.object_id
INNER JOIN sys.schemas AS s	ON s.schema_id = o.schema_id
UNION ALL
SELECT		o.name
		   ,CONCAT(
				N'CREATE TABLE '
			   ,s.name
			   ,'.'
			   ,o.name
			   ,' ('
			   ,CHAR(13)
			   ,CHAR(10)
			   ,REPLACE(c.coldef, '~%', CONCAT(CHAR(13), CHAR(10), '  ,'))
			   ,CHAR(13)
			   ,CHAR(10)
			   ,')') AS definition
		   ,o.type_desc
		   ,s.name
FROM		sys.objects AS o
INNER JOIN	sys.schemas AS s
	ON s.schema_id = o.schema_id
OUTER APPLY (SELECT STUFF(
					(	SELECT	 CONCAT('~%'
									   ,cols.name
									   ,' '
									   ,cols.system_type_name
									   ,CASE cols.is_nullable
											WHEN 1 THEN ' NULL'
											ELSE ' NOT NULL'
										END)
						FROM	 sys.dm_exec_describe_first_result_set(
									 CONCAT(N'SELECT * FROM ', s.name, '.', o.name), NULL, NULL) AS cols
						ORDER BY cols.column_ordinal
						FOR XML PATH(''))
				   ,1
				   ,2
				   ,'   ') AS coldef) AS c
WHERE		o.type = 'U';
