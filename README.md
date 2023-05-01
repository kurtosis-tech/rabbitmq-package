### RabbitMQ Package

This is a [Kurtosis Starlark Package](https://docs.kurtosis.com/quickstart) that allows you to spin up an `n node` RabbitMQ Cluster. It spins up 3 nodes by default but you can tweak it. An etcd instance is also started to manage clustering.

### Run

This assumes you have the [Kurtosis CLI](https://docs.kurtosis.com/cli) installed.

Simply run

```bash
kurtosis run github.com/kurtosis-tech/rabbitmq-package
```

Both the management (default: 15672) and AMQP (default: 5672) ports are exposed.  An administrator user "admin" is created with a default password set to "admin".

#### Configuration

<details>
    <summary>Click to see configuration</summary>

You can configure this package using a JSON structure as an argument to the `kurtosis run` function. The full structure that this package accepts is as follows, with default values shown (note that the `//` lines are not valid JSON and should be removed!):

```javascript
{
    // The number of nodes
    "rabbitmq_num_nodes": 3,

    // The image to run
    "rabbitmq_image": "rabbitmq:3-management",

    // The management interface port number
    "rabbitmq_management_port": 15672,

    // The AMQP interface port number
    "rabbitmq_amqp_port": 5672,

    // The administrator user name and password
    "rabbitmq_admin_user": "admin",
    "rabbitmq_admin_password": "admin",

    // The virtual host to create
    "rabbitmq_vhost": "test",

    // Additional environment variables that will be set on the container
    "rabbitmq_env_vars": {}
}
```

These arguments can either be provided manually:

```bash
kurtosis run github.com/kurtosis-tech/rabbitmq-package '{"rabbitmq_image":"rabbitmq:3-management"}'
```

or by loading via a file, for instance using the [args.json](args.json) file in this repo:

```bash
kurtosis run github.com/kurtosis-tech/rabbitmq-package --enclave rabbitmq "$(cat args.json)"
```

</details>

### etcd

This package leverages the [Kurtosis etcd Package](https://github.com/kurtosis-tech/etcd-package) to spin up an instance of etcd to manage the RabbitMQ clustering.  Once the etcd instance and the RabbitMQ cluster are up, you can list the RabbitMQ keys stored in the etcd database.

```bash
$ etcdctl get --prefix /rabbitmq
/rabbitmq/discovery/rabbitmq/clusters/default/nodes/rabbit@0a16a671bb48
{"lease_id":7587869983329495568,"node":"rabbit@0a16a671bb48","ttl":61}
/rabbitmq/discovery/rabbitmq/clusters/default/nodes/rabbit@2dff34180bf4
{"lease_id":7587869983329495558,"node":"rabbit@2dff34180bf4","ttl":61}
/rabbitmq/discovery/rabbitmq/clusters/default/nodes/rabbit@6b14a7ccfa6d
{"lease_id":7587869983329495578,"node":"rabbit@6b14a7ccfa6d","ttl":61}
```

### Using this in your own package

Kurtosis Packages can be used within other Kurtosis Packages, through what we call composition internally. Assuming you want to spin up RabbitMQ and your own service
together you just need to do the following

```py
main_rabbitmq_module = import_module("github.com/kurtosis-tech/rabbitmq-package/main.star")

# main.star of your RabbitMQ + Service package
def run(plan, args):
    plan.print("Spinning up the RabbitMQ Package")
    # this will spin up RabbitMQ and return the output of the RabbitMQ package [rabbitmq-node-0 .. rabbitmq-node-n]
    # any args (including num_nodes) parsed to your package would get passed down to the RabbitMQ Package
    rabbitmq_run_output = main_rabbitmq_module.run(plan, args)
```
