## Prerequisites

Today you are going to solve a high-performance challenge for TikTok with Tarantool.

You will implement a counter of likes for videos. First, you will create base tables and search indexes. Then you will define the HTTP API for mobile clients.

You don't need to write additional code. Everything will be implemented on the Tarantool platform.

If you accidentally do something wrong while following the instructions, there is a magic button that helps you reset all the changes.

It is called **Reset Configuration**. You can find it at the top of the "Cluster" page.


## Configuring a Cluster

**Everything you need to know to get started:**

A Tarantool cluster has two service roles: Router and Storage.

- Storage is used to store the data
- Router is an intermediary between clients and storages. It accepts a client's request, takes data from the proper storage, and returns it to the client.

On the "Cluster" tab, we see that we have 5
unconfigured instances.

![List of all hosts](images/hosts-list.png)

Let's create one Router and one Storage for
start.

First, click the "Configure" button on the "router" instance and configure it
as in the screenshot below:

![Configuring router](images/router-configuration.png)

Next, we configure the "s1-master" instance:

![Configuring s1-master](images/storage-configuration.png)

It will look something like this:

![Cluster view after first configuration](images/first-configuration-result.png)


## Turn on sharding [1 minute]

Let's enable sharding in the cluster using the "Bootstrap vshard" button.
It is located in the "Cluster" tab at the top right.

More details about sharding will be discussed in the next steps.


## Creating a Data Schema [2 minutes]

Get started with a data schema – go to the Code tab on the left.

On this tab, you can create a new file called `schema.yml`. In that file you can describe the data schema for the entire cluster, edit the current schema, validate its correctness and apply it to the whole cluster.

Create the necessary tables. In Tarantool, they are called spaces.

You will need to store:

- users
- videos and their descriptions, with a pre-calculated number of likes
- actual likes

**Create a `schema.yml` file to load the schema into the cluster. Copy and paste
schema to this file. Click on the "Apply" button. After that, the data schema will be described in the cluster.**

The data schema will look like this:

> ```yaml
> spaces:
>   users:
>     engine: memtx
>     is_local: false
>     temporary: false
>     sharding_key:
>     - "user_id"
>     format:
>     - {name: bucket_id, type: unsigned, is_nullable: false}
>     - {name: user_id, type: uuid, is_nullable: false}
>     - {name: fullname, type: string,  is_nullable: false}
>     indexes:
>     - name: user_id
>       unique: true
>       parts: [{path: user_id, type: uuid, is_nullable: false}]
>       type: HASH
>     - name: bucket_id
>       unique: false
>       parts: [{path: bucket_id, type: unsigned, is_nullable: false}]
>       type: TREE
>
>   videos:
>     engine: memtx
>     is_local: false
>     temporary: false
>     sharding_key:
>     - "video_id"
>     format:
>     - {name: bucket_id, type: unsigned, is_nullable: false}
>     - {name: video_id, type: uuid, is_nullable: false}
>     - {name: description, type: string, is_nullable: true}
>     indexes:
>     - name: video_id
>       unique: true
>       parts: [{path: video_id, type: uuid, is_nullable: false}]
>       type: HASH
>     - name: bucket_id
>       unique: false
>       parts: [{path: bucket_id, type: unsigned, is_nullable: false}]
>       type: TREE
>
>   likes:
>     engine: memtx
>     is_local: false
>     temporary: false
>     sharding_key:
>     - "video_id"
>     format:
>     - {name: bucket_id, type: unsigned, is_nullable: false}
>     - {name: like_id, type: uuid, is_nullable: false }
>     - {name: user_id,  type: uuid, is_nullable: false}
>     - {name: video_id, type: uuid, is_nullable: false}
>     - {name: timestamp, type: string,   is_nullable: true}
>     indexes:
>     - name: like_id
>       unique: true
>       parts: [{path: like_id, type: uuid, is_nullable: false}]
>       type: HASH
>     - name: bucket_id
>       unique: false
>       parts: [{path: bucket_id, type: unsigned, is_nullable: false}]
>       type: TREE
> ```

It's simple. Let's take a closer look at the essential points.

Tarantool has two built-in storage engines: memtx and vinyl. Memtx stores all data in RAM while asynchronously writing to disk so that nothing is lost.

Vinyl is a standard on-disk storage engine optimized for write-intensive scenarios.

In this tutorial, you have a large number of both reads and writes. That's why you will use memtx.

You've created three spaces (tables) in memtx, and for each space, you've created the necessary indexes.

There are two of them for each space:

- The first index is a primary key. It is required for reading and writing data.
- The second one is the index on the `bucket_id` field. This is a special field used in sharding.

**Important:** The name `bucket_id` is reserved. If you choose a different name, sharding will not work for that space. If you don't use sharding in the project, you can remove the second index.

To understand which field to shard data by, Tarantool uses
`sharding_key`. `sharding_key` points to the field in the space by which
records will be sharded. Tarantool will take a hash from this field when
insert, will calculate the bucket number and select the required Storage for recording.

Buckets may be repeated, and each storage stores a certain range of buckets.

More interesting facts:

- The `parts` field in the index definition can contain several fields in order to build a composite (multi-part) index. You won't need it in this tutorial.
- Tarantool does not support foreign keys, so you have to check manually that `video_id` and `user_id` exist in the `likes` space.


## Writing Data [5 minutes]

You are going to write data to the Tarantool cluster using the CRUD module. This module defines which shard to read from and which shard to write to, and does it for you.

Important: all cluster operations must be performed only on the router and using the CRUD module.

Plug the CRUD module and declare three procedures:

- creating a user
- adding a video
- liking a video

**The procedures must be described in a special file. To do this, go to the "Code" tab. Create
a new directory called "extensions". And in this directory create the file "api.lua".**

Paste the code described below into this file and click on the "Apply" button.

```lua
local cartridge = require('cartridge')
local crud = require('crud')
local uuid = require('uuid')
local json = require('json')

function add_user(request)
    local fullname = request:post_param("fullname")
    local result, err = crud.insert_object('users', { user_id = uuid.new(), fullname = fullname })
    if err ~= nil then
        return { body = json.encode({status = "Error!", error = err}), status = 500 }
    end

    return { body = json.encode({status = "Success!", result = result}), status = 200 }
end

function add_video(request)
    local description = request:post_param("description")
    local result, err = crud.insert_object('videos', { video_id = uuid.new(), description = description, likes = 0 })
    if err ~= nil then
        return { body = json.encode({status = "Error!", error = err}), status = 500 }
    end

    return { body = json.encode({status = "Success!", result = result}), status = 200 }
end

function like_video(request)
    local video_id = request:post_param("video_id")
    local user_id = request:post_param("user_id")

    local result, err = crud.update('videos', uuid.fromstr(video_id), {{'+', 'likes', 1}})
    if err ~= nil then
        return { body = json.encode({status = "Error!", error = err}), status = 500 }
    end

    result, err = crud.insert_object('likes', { like_id = uuid.new(),
                                                video_id = uuid.fromstr(video_id),
                                                user_id = uuid.fromstr(user_id)})
    if err ~= nil then
        return { body = json.encode({status = "Error!", error = err}), status = 500 }
    end

    return { body = json.encode({status = "Success!", result = result}), status = 200 }
end

return {
    add_user = add_user,
    add_video = add_video,
    like_video = like_video,
}
```

## Setting up HTTP API [2 minutes]

Clients will connect to the Tarantool cluster via the HTTP protocol. The cluster already has its own built-in HTTP server.

**To configure HTTP paths, you need to write a configuration file. To do this, go to the "Code" tab. Create
the "config.yml" file in the "extensions" directory. You created it in the last step.**

```yaml
---
 functions:

   customer_add:
     module: extensions.api
     handler: add_user
     events:
     - http: {path: "/add_user", method: POST}

   account_add:
     module: extensions.api
     handler: add_video
     events:
     - http: {path: "/add_video", method: POST}

   transfer_money:
     module: extensions.api
     handler: like_video
     events:
     - http: {path: "/like_video", method: POST}
...
```

Done! Now send test queries from the console.
Please note: instead of **url**, you must substitute your URL from
query strings up to the first slash. The protocol must be strictly HTTP.

For example: http://artpjcvnmwctc4qppejgf57.try.tarantool.io.

```bash
curl -X POST --data "fullname=Taran Tool" url/add_user
curl -X POST --data "description=My first tiktok" url/add_video
curl -X POST --data "video_id=ab45321d-8f79-49ec-a921-c2896c4a3eba,user_id=bb45321d-9f79-49ec-a921-c2896c4a3eba" url/like_video
```

It goes something like this:

![Тестовые запросы в консоли](images/console.png)

## Looking at the Data [1 minute]

Go to the Space-Explorer tab and see all the cluster nodes. Since you have one storage and one router so far, the data is stored on a single node.

Go to the `s1-master` node, click Connect and select the necessary space.

Check that everything is in place and move on.

![Space Explorer, host list](images/hosts.png)

![Space Explorer, viewing likes](images/likes.png)

Please note: the `space-explorer` tool is only available in the Enterprise version of the product.
In the open-source version, the data can be viewed through the console.

Read [more in the documentation](https://www.tarantool.io/en/doc/latest/reference/reference_lua/box_space/select/).

## Scaling the Cluster [1 minute]

Create a second shard. Go to the Cluster tab, select `s2-master`, and click Configure. Select the roles as shown in the picture:

![Space Explorer, configuring new shard](images/configuring-server.png)

Click on the roles and create a shard (replicaset).

## Checking Sharding [1 minute]

Now you have two shards, or two logical nodes that receive data. The router determines where it sends the data. By default, it uses the hash function for the `sharding_key` field specified in DDL.

To enable a new shard, you have to set its weight to one. Go back to the Cluster tab, open the `s2-master` settings, set Replica set weight to "1" and apply.

Something has already happened. Go to space-explorer and open the `s2-master` node. It turns out that some of the data from the first shard has already migrated here! The scaling is done automatically.

![Cluster, s2-master viewing](images/scaling.png)

Now try to add more data to the cluster using the HTTP API. You can check and make sure that the new data is also evenly distributed among the two shards.

## Disconnecting a Shard for a While [1 minute]

In the `s1-master` settings, set Replica set weight to "0" and apply. Wait for a few seconds, then go to space-explorer and look at the data in `s2-master` – all the data has been migrated to the remaining shard automatically.

Now you can safely disconnect the first shard to perform maintenance.

---

## What's next?

Deploy the environment locally and continue exploring Tarantool.

Four components are used in the example:

- Tarantool — an in-memory database
- Tarantool Cartridge – the cluster UI and framework for distributed applications development based on Tarantool
- [DDL](https://github.com/tarantool/ddl) module — for clusterwide DDL schema application
- [CRUD](https://github.com/tarantool/crud) module —for CRUD (create, read, update, delete) operations in cluster



### Install locally:

#### For Linux/macOS users

- Install Tarantool [from the Download page](https://tarantool.io/ru/download)
- Install the `cartridge-cli` utility using your package manager

```bash
sudo yum install cartridge-cli
```

```bash
brew install cartridge-cli
```

Learn more about installing the `cartridge-cli` utility [here](https://github.com/tarantool/cartridge-cli).

-   Clone the repository [https://github.com/tarantool/try-tarantool-example](https://github.com/tarantool/try-tarantool-example).

    This repository is ready for use.

-   In the folder with the cloned example, run:

    ```bash
    cartridge build
    cartridge start
    ```

    This is necessary to install dependencies and start the project. Here, the dependencies are Tarantool Cartridge, DDL, and CRUD.

Done! You can see the Tarantool Cartridge UI at [http://localhost:8081](http://localhost:8081).

#### For Windows users

Use Docker:

```bash
docker run -p 3301:3301 -p 8081:8081 tarantool/getting-started
```

Ready! At http://localhost:8081 you will see the Tarantool UI.

## See also

- [Study the Tarantool Cartridge documentation](https://www.tarantool.io/ru/doc/latest/book/cartridge/) and create your own distributed application
- Explore the repository [tarantool/examples](https://github.com/tarantool/examples) on Github with ready-made examples on Tarantool Cartridge: cache, MySQL replicator, and others.
- README of the [DDL](https://github.com/tarantool/ddl) module to create your own data schema
- README of the [CRUD](https://github.com/tarantool/crud) module to learn more about API and create your own cluster queries