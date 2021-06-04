using ODBC
using DataFrames
using LightXML

println("Enter user ID for IVIEWALPHA:")
userid = readline()
println("Enter password:")
password = readline()

ODBC.adddsn(
    "gk-db01_IVIEWALPHA",
    "SQL Server";
    SERVER = "gk-db01",
    DATABASE = "IVIEWALPHA",
    UID = userid,
    PWD = password,
)
conn = ODBC.Connection("gk-db01_IVIEWALPHA", userid, password)

# Get all object names, types, and definitions from DB
objectsql = """SELECT o.name,m.definition,o.type_desc,s.name AS schemaname
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
WHERE		o.type = 'U';"""
sqlobjects = DBInterface.execute(conn, objectsql) |> DataFrame

# Loop through each object and store each definition in a sql file grouped in folders by type
for (name, schemaname, type_desc, definition) in zip(
    sqlobjects.name,
    sqlobjects.schemaname,
    sqlobjects.type_desc,
    sqlobjects.definition,
)
    mkpath(type_desc)
    filename = "$type_desc/$schemaname.$name.sql"
    output_file = open(filename, "w")
    #println(filename)
    write(output_file, definition)
    close(output_file)
end
