using ArgParse
using ODBC
using DataFrames
using LightXML

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--servername", "-s"
        help = "server name on which your target database is stored"
        arg_type = String
        default = "gk-db01"
        "--database", "-d"
        help = "database name"
        arg_type = String
        default = "IVIEWALPHA"
        "--username", "-u"
        help = "sql server log in username"
        arg_type = String
        required = false
        "--password", "-p"
        help = "sql server log in password"
        arg_type = String
        required = false
    end

    return parse_args(s)
end

function main()
    parsed_args = parse_commandline()

    servername = parsed_args["servername"]
    database = parsed_args["database"]
    username = parsed_args["username"]
    password = parsed_args["password"]

    if username == nothing
        println("Enter user ID for IVIEWALPHA:")
        username = chomp(readline())
    end

    if password == nothing
        println("Enter password:")
        password = chomp(readline())
    end

    dnsname = "$(servername)_$(database)"

    ODBC.adddsn(
        dnsname,
        "SQL Server";
        SERVER = servername,
        DATABASE = database,
        UID = username,
        PWD = password,
    )
    conn = ODBC.Connection(dnsname, username, password)

    # Get all object names, types, and definitions from DB
    objectsql = read("sqlObjectDefinitions.sql", String)
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

    DBInterface.close!(conn)
end

main()
