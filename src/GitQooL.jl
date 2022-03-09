module GitQooL

using ArgParse
using ODBC
using DataFrames
using LightXML
using YAML

function julia_main()::Cint
    try
        real_main()
    catch
        Base.invokelatest(Base.display_error, Base.catch_stack())
        return 1
    end
    return 0
end

function filecompare(path1::AbstractString, path2::AbstractString)
    stat1, stat2 = stat(path1), stat(path2)
    if !(isfile(stat1) && isfile(stat2)) || filesize(stat1) != filesize(stat2)
        return false
    end
    stat1 == stat2 && return true # same file
    open(path1, "r") do file1
        open(path2, "r") do file2
            buf1 = Vector{UInt8}(undef, 32768)
            buf2 = similar(buf1)
            while !eof(file1) && !eof(file2)
                n1 = readbytes!(file1, buf1)
                n2 = readbytes!(file2, buf2)
                n1 != n2 && return false
                0 != Base._memcmp(buf1, buf2, n1) && return false
            end
            return eof(file1) == eof(file2)
        end
    end
end

function parse_commandline(args)
    s = ArgParseSettings(commands_are_required = true)

    # command list
    @add_arg_table! s begin
        "retrieve-db-objects"
        help = "save db object definitions to chosen repository. if objects already exist in repository, they will be overwritten. if object exists in repository, but does not exist in database, the object will be deleted from local repository."
        action = :command
        "deploy"
        help = "deploy from chosen repository to chosen server"
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

    if username === nothing
        println("Enter user ID for $(servername):")
        username = chomp(readline())
    end

    if password === nothing
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
    rm(joinpath(location,database), recursive = true, force = true)

    # Initialise empty Dict in which to add object meta-data
    metadata = Dict("DatabaseName"=>database,"Objects"=>Dict[])

    # Loop through each object and store each definition in a sql file
    # grouped in folders by type
    for (name, schemaname, type_desc, definition) in zip(
        sqlobjects.name,
        sqlobjects.schemaname,
        sqlobjects.type_desc,
        sqlobjects.definition,
    )
        type_folder = joinpath(location,database,type_desc)
        # println("Saving $(type_desc): $(name)")
        mkpath(type_folder)
        filename =
            schemaname === missing ? "$type_folder/$name.sql" :
            joinpath(type_folder,"$schemaname.$name.sql")
        output_file = open(filename, "w")
        #println(filename)
        write(output_file, definition)
        close(output_file)

        push!(metadata["Objects"],Dict(["fullpath"=>filename, "name"=>name, "schemaname"=>schemaname, "type_desc"=>type_desc]))
    end

    YAML.write_file(joinpath(location,database,"objectmetadata.yml"), metadata)

    println("Closing database connection")
    DBInterface.close!(conn)
end

function deployToDb(servername, database, username, password, location)
    # todo: use extractFilesFromDb to get existing state of $database
    # - either save this in a temp location or save in memory
    # - compare with what is in repository $location
    # - create list of objects to change
    # - perform dependency analysis

    tmpdir = tempname()

    extractFilesFromDb(servername,database,username,password,tmpdir)

    for (root, dirs, files) in walkdir(joinpath(location,database))
        for file in files
            # list all objects that have been changed in/added to repo (to be added/updated in db)
            if !filecompare(joinpath(root,file),joinpath(replace(root,location => "$tmpdir\\"),file))
                println(joinpath(root,file)) # this should be changed to perform deployment for these objects
            end
        end
    end

    for (root, dirs, files) in walkdir(joinpath(tmpdir,database))
        for file in files
            # list all objects exist in db, but are not in repo (to be deleted from db)
            stat1, stat2 = stat(joinpath(replace(root,"$tmpdir\\" => location),file)), stat(joinpath(root,file))
            if !isfile(stat1) && isfile(stat2)
                println("Drop: $(joinpath(root,file))")
            end
        end
    end
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
