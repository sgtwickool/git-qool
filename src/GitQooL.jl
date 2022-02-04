module GitQooL

using ArgParse
using ODBC
using DataFrames
using LightXML

function julia_main()::Cint
    try
        real_main()
    catch
        Base.invokelatest(Base.display_error, Base.catch_stack())
        return 1
    end
    return 0
end

function parse_commandline(args)
    s = ArgParseSettings(commands_are_required = true)

    # command list
    @add_arg_table! s begin
        "retrieve-db-objects"
        help = "save db object definitions to chosen repository. if objects already exist in repository, they will be overwritten. if object exists in repository, but does not exist in repository, the object will be deleted from local repository."
        action = :command
    end

    # params specific to retrieve-db-objects command
    @add_arg_table! s["retrieve-db-objects"] begin
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

    # params specific to retrieve-db-objects command
    @add_arg_table! s["deploy"] begin
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
        help = "location of folder containing local repository where database object definitions are stored"
        arg_type = String
        default = pwd()
        required = false
    end

    parse_args(args, s)
end

function extractFilesFromDb(servername, database, username, password, location)
    @show ARGS

    if username == nothing
        println("Enter user ID for $(servername):")
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
        println("Enter user ID for $(servername):")
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

    # todo: use extractFilesFromDb to get existing state of $database
    # - either save this in a temp location or save in memory
    # - compare with what is in repository $location
    # - create list of objects to change
    # - perform dependency analysis

    println("Closing database connection")
    DBInterface.close!(conn)
end

function real_main()
    parsed_args = parse_commandline(ARGS)

    # store entered command
    cmd = parsed_args["%COMMAND%"]

    # dict lookup for command gives access to arguments for command
    cmdArgs = parsed_args[cmd]

    if cmd == "retrieve-db-objects"
        extractFilesFromDb(
            cmdArgs["servername"],
            cmdArgs["database"],
            cmdArgs["username"],
            cmdArgs["password"],
            cmdArgs["location"],
        )
    elseif cmd == "deploy"
        deployToDb(
            cmdArgs["servername"],
            cmdArgs["database"],
            cmdArgs["username"],
            cmdArgs["password"],
            cmdArgs["location"],
        )
    else
        println(
            "Please use command. Call \"git-qool --help\" for details of available commands.",
        )
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    real_main()
end

end
