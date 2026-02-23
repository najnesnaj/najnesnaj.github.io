---
title: 'Docker'
draft: false
---

# Docker practice

## changes to python code within a container

after making changes to the python code, you need to rebuild the image and restart the container

```bash
docker-compose -f compose.yml up -d
```

## error & solution

if you get an error like this:

ERROR: for nosql_ana_report_1  ‘ContainerConfig’

```bash
docker-compose -f compose.yml down --remove-orphans
docker system prune -f
docker system prune --volumes -f
```

## requirements.txt

if you add new packages to the python code, you need to update the requirements.txt file
In a docker container you will only need those packages that are required to run the code.

```bash
first: install pipreqs
pip install pipreqs

in the container diretory where your python code is located
pipreqs . --force
the --force flag overwrites any existing requirements.txt file in the directory. Without this flag, pipreqs will not overwrite an existing file and will throw an error if one already exists.
```

## moving a database to another machine

In principle a postgres database container has a volume in docker. This volume can be copied to another machine. But this proves complicated.
A simple solution is exporting the database to a file and importing it on the other machine.

```bash
(import the container)
docker load -i /path/to/destination/nosql_api_latest.tar
docker run -d --name nosql_api_1 -p 9080:9080 nosql_api:latest
or
docker run -d --name nosql_api_1   -e POSTGRES_HOST=172.17.0.5   -e POSTGRES_USER=myuser   -e POSTGRES_PASSWORD=mypassword   -e POSTGRES_DB=mydatabase   -e POSTGRES_PORT=5432   nosql_api:latest
(import the database)
docker exec -i postgres-postgres-1 psql -U postgres mydatabase < db_backup.sql
```
