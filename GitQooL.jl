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
objectsql = read("sqlObjectDefinitions.sql",String)
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
