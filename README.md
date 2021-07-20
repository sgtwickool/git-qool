---
description: Basic user guide for GitQooL git interface for SQL Server code/parameters
---

# Getting started

## Clone repository

To begin with, navigate to where you would like to hold GitQooL and clone repository to your local machine \(in this example we will store it in the home directory ~/\):

```bash
cd ~/
git clone --recursive "https://github.com/sgtwickool/git-qool.git"
```

## Refresh local repository folder with database objects

To call this operation using Julia from within the GitQooL repository root \(git-qool created in home directory in previous section\):

```bash
cd ~/databases/ # change this to wherever you would like to store your database scripts
julia ~/git-qool/GitQool.jl retrieve-db-objects -s {servername} -d {database} -u {sql server username} -p {sql server password}
```

{% hint style="info" %}
Replace values in curly brackets \(e.g. {servername}\) with details for the database you would like to retrieve code from
{% endhint %}

The above code will create a new folder, with the same name as the database name, within the current directory \(e.g. ~/databases/AdventureWorks/ if -d set to "AdventureWorks"\). If you would like to define a different location to store your database code, use the **-l** or **--location** option with the full path of your chosen location, e.g.:

```bash
-l "~/git-repos/databases/"
```





