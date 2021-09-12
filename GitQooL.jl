using ArgParse
using ODBC
using DataFrames
using LightXML

function parse_commandline()
    settings = ArgParseSettings(commands_are_required = false)

    @add_arg_table! settings begin
        "retrieve-db-objects"
        help = "save db object definitions to chosen directory. if objects already exist in directory, they will be overwritten. if object exists in directory, but does not exist in database, the object will be deleted from directory."
        action = :command
    end

    @add_arg_table! settings["retrieve-db-objects"] begin
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
        "--location", "-l"
        help = "location of folder containing local repository where you want to store files"
        arg_type = String
        default = pwd()
        required = false
    end

    parse_args(settings)
end

function getargs()
    parsed_args = parse_commandline()

    (
        servername = parsed_args["servername"],
        database = parsed_args["database"],
        username = parsed_args["username"],
        password = parsed_args["password"],
        location = parsed_args["location"],
        command = parsed_args["%COMMAND%"],
    )
end

function extractFilesFromDb(servername, database, username, password, location)
    if username == nothing
        println("Enter user ID for IVIEWALPHA:")
        username = chomp(readline())
    end

    if password == nothing
        println("Enter password:")
        password = chomp(readline())
    end

    println("Connecting to database")
    conn = ODBC.Connection(
        "Driver=SQL Server;SERVER=$(servername);DATABASE=$(database);UID=$(username);PWD=$(password)",
    )

    # Get all object names, types, and definitions from DB
    objectsql = read("sqlObjectDefinitions.sql", String)
    println("Retrieving database object definitions")
    sqlobjects = DBInterface.execute(conn, objectsql) |> DataFrame

    println("Clearing existing local directory")
    rm("$(location)/$(database)", recursive = true, force = true)

    # Loop through each object and store each definition in a sql file
    # grouped in folders by type
    for (name, schemaname, type_desc, definition) in zip(
        sqlobjects.name,
        sqlobjects.schemaname,
        sqlobjects.type_desc,
        sqlobjects.definition,
    )
        type_folder = "$(location)/$(database)/$(type_desc)"
        println("Saving $(type_desc): $(name)")
        mkpath(type_folder)
        filename =
            schemaname === missing ? "$type_folder/$name.sql" :
            "$type_folder/$schemaname.$name.sql"
        output_file = open(filename, "w")
        #println(filename)
        write(output_file, definition)
        close(output_file)
    end

    println("Closing database connection")
    DBInterface.close!(conn)
end

function deployToDb(servername, database, username, password, location)
    if username == nothing
        println("Enter user ID for IVIEWALPHA:")
        username = chomp(readline())
    end

    if password == nothing
        println("Enter password:")
        password = chomp(readline())
    end

    println("Connecting to database")
    conn = ODBC.Connection(
        "Driver=SQL Server;SERVER=$(servername);DATABASE=$(database);UID=$(username);PWD=$(password)",
    )

    println("Closing database connection")
    DBInterface.close!(conn)
end

a = getargs()

if a.command == "retrieve-db-objects"
    extractFilesFromDb(
        a.servername,
        a.database,
        a.username,
        a.password,
        a.location,
    )
else
    println(
        "Please use command. Call \"git-qool --help\" for details of available commands.",
    )
end
