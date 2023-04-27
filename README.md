### RabbitMQ Package

This is a [Kurtosis Starlark Package](https://docs.kurtosis.com/quickstart) that allows you to spin up an `n node` RabbitMQ Cluster. It spins up 3 nodes by default but you can tweak it. An etcd instance is also started to manage clustering.

### Run

This assumes you have the [Kurtosis CLI](https://docs.kurtosis.com/cli) installed.

Simply run

```bash
kurtosis run github.com/kurtosis-tech/rabbitmq-package
```

If you want to override the number of nodes:

```
kurtosis run github.com/kurtosis-tech/rabbitmq-package '{"num_nodes": <required_number_of_nodes>}'
```

Both the management (15672) and AMQP (5672) ports are exposed.  An administrator user "admin" is created with a default password set to "admin".

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
