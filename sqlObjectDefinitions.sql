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
SELECT	   s.name
		  ,sy.name AS schemaname
		  ,sy.type_desc
		  ,CONCAT(
			   N'CREATE SYNONYM '
			  ,sy.name
			  ,' REFERENCES '
			  ,CASE WHEN sy.base_object_name LIKE '\[%\].\[%\].\[%\].\[%\]' ESCAPE '\' THEN
						REPLACE(
							sy.base_object_name
						   ,LEFT(sy.base_object_name, CHARINDEX('.', sy.base_object_name))
						   ,'{Variable Server Name}.')
				   ELSE sy.base_object_name
			   END) AS definition
FROM	   sys.synonyms AS sy
INNER JOIN sys.schemas AS s
	ON s.schema_id = sy.schema_id;;
