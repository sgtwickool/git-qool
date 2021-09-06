SELECT	   o.name
		  ,s.name AS schemaname
		  ,o.type_desc
		  ,m.definition
FROM	   sys.sql_modules AS m
INNER JOIN sys.objects AS o
	ON o.object_id = m.object_id
INNER JOIN sys.schemas AS s
	ON s.schema_id = o.schema_id
UNION ALL
SELECT		o.name
		   ,s.name AS schemaname
		   ,o.type_desc
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
WHERE		o.type = 'U'
UNION ALL
SELECT		tt.name
		   ,s.name AS schemaname
		   ,o.type_desc
		   ,CONCAT(
				N'CREATE TYPE ' , s.name, '.', tt.name, ' AS TABLE (', CHAR(13), CHAR(10), c.coldef, CHAR(13), CHAR(10), ')') AS definition
FROM		sys.objects AS o
INNER JOIN	sys.table_types AS tt
	ON tt.type_table_object_id = o.object_id
INNER JOIN	sys.schemas AS s
	ON s.schema_id = tt.schema_id
OUTER APPLY (SELECT STUFF((	  SELECT	 CONCAT(CHAR(13)
											   ,CHAR(10)
											   ,'  ,'
											   ,cols.name
											   ,' '
											   ,t.name
											   ,CASE cols.is_nullable
													WHEN 1 THEN ' NULL'
													ELSE ' NOT NULL'
												END)
							  FROM		 sys.columns AS cols
							  INNER JOIN sys.types AS t
								  ON t.system_type_id = cols.system_type_id
							  WHERE		 cols.object_id = o.object_id
							  ORDER BY	 cols.column_id
							  FOR XML PATH(''), TYPE).value('.', 'varchar(max)')
						 ,1
						 ,5
						 ,'   ') AS coldef) AS c
WHERE		o.type = 'TT'
UNION ALL
SELECT	   sy.name
		  ,s.name AS schemaname
		  ,sy.type_desc
		  ,CONCAT(
			   N'CREATE SYNONYM '
			  ,sy.name
			  ,N' REFERENCES '
			  ,CASE WHEN sy.base_object_name LIKE '\[%\].\[%\].\[%\].\[%\]' ESCAPE '\' THEN
						REPLACE(
							sy.base_object_name
						   ,LEFT(sy.base_object_name, CHARINDEX('.', sy.base_object_name))
						   ,'{$server_name$}.')
				   ELSE sy.base_object_name
			   END) AS definition
FROM	   sys.synonyms AS sy
INNER JOIN sys.schemas AS s
	ON s.schema_id = sy.schema_id
UNION ALL
SELECT	   a.name
		  ,NULL AS schemaname
		  ,N'ASSEMBLY' AS type_desc
		  ,CONCAT(
			   N'CREATE ASSEMBLY '
			  ,QUOTENAME(a.name)
			  ,N' AUTHORIZATION '
			  ,QUOTENAME(dp.name)
			  ,N' FROM '
			  ,CONVERT(VARCHAR(MAX), af.content, 1)
			  ,CASE a.permission_set
				   WHEN 3 THEN N' WITH PERMISSION_SET=UNSAFE'
			   END) AS definitiviewalphion
FROM	   sys.assemblies AS a
INNER JOIN sys.assembly_files AS af
	ON af.assembly_id = a.assembly_id
INNER JOIN sys.database_principals AS dp
	ON dp.principal_id = a.principal_id
WHERE	   a.is_user_defined = 1
UNION ALL
SELECT	   t.name
		  ,NULL AS schemaname
		  ,N'DATABASE_TRIGGER' AS type_desc
		  ,sm.definition
FROM	   sys.triggers AS t
INNER JOIN sys.sql_modules AS sm
	ON sm.object_id = t.object_id
WHERE	   t.parent_class = 0 --DATABASE parent_class;
UNION ALL
SELECT	   s.name
		  ,NULL AS schemaname
		  ,N'SCHEMA'
		  ,CONCAT(N'CREATE SCHEMA ', QUOTENAME(s.name), CHAR(13), CHAR(10), N'AUTHORIZATION ', QUOTENAME(dp.name)) AS definition
FROM	   sys.schemas AS s
INNER JOIN sys.database_principals AS dp
	ON dp.principal_id = s.principal_id
WHERE	   s.principal_id = 1
UNION ALL
SELECT	   s.name
		  ,sch.name
		  ,s.type_desc
		  ,CONCAT(
			   N'CREATE SEQUENCE '
			  ,QUOTENAME(sch.name)
			  ,N'.'
			  ,QUOTENAME(s.name)
			  ,CHAR(13)
			  ,CHAR(10)
			  ,N'AS '
			  ,UPPER(ISNULL(tu.name, ts.name))
			  ,CHAR(13)
			  ,CHAR(10)
			  ,N'START WITH '
			  ,CAST(s.start_value AS INT)
			  ,CHAR(13)
			  ,CHAR(10)
			  ,N'INCREMENT BY '
			  ,CAST(s.increment AS INT)
			  ,CHAR(13)
			  ,CHAR(10)
			  ,N'MINVALUE '
			  ,CAST(s.minimum_value AS BIGINT)
			  ,CHAR(13)
			  ,CHAR(10)
			  ,N'MAXVALUE '
			  ,CAST(s.maximum_value AS BIGINT)
			  ,CHAR(13)
			  ,CHAR(10)
			  ,CASE s.is_cycling
				   WHEN 1 THEN 'CYCLE'
				   ELSE 'NO CYCLE'
			   END
			  ,CHAR(13)
			  ,CHAR(10)
			  ,CASE s.is_cached
				   WHEN 1 THEN 'CACHE'
				   ELSE 'NO CACHE'
			   END) AS definition
FROM	   sys.sequences AS s
INNER JOIN sys.schemas AS sch
	ON sch.schema_id = s.schema_id
LEFT JOIN  sys.types AS ts
	ON ts.system_type_id = s.system_type_id
LEFT JOIN  sys.types AS tu
	ON tu.user_type_id = s.user_type_id;