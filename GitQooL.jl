using ODBC
using DataFrames

ODBC.adddsn("gk-db01_IVIEWALPHA", "SQL Server"; SERVER="gk-db01", DATABASE ="IVIEWALPHA", UID="sa", PWD="blue")
conn = ODBC.Connection("gk-db01_IVIEWALPHA","sa","blue")

objectsql = """SELECT o.name,m.definition,o.type_desc,s.name AS schemaname
FROM   sys.sql_modules AS m
INNER JOIN sys.objects AS o ON o.object_id = m.object_id
INNER JOIN sys.schemas AS s	ON s.schema_id = o.schema_id;"""
sqlobjects = DBInterface.execute(conn, objectsql) |> DataFrame

for (name, schemaname, type_desc, definition) in zip(sqlobjects.name, sqlobjects.schemaname, sqlobjects.type_desc, sqlobjects.definition)
    mkpath(type_desc)
    filename = "$type_desc/$schemaname.$name.sql"
    output_file = open(filename,"w")
    #println(filename)
    write(output_file, definition)
    close(output_file)
end
