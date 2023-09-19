etcd_module = import_module("github.com/kurtosis-tech/etcd-package/main.star")

NUM_NODES_ARG = "rabbitmq_num_nodes"
NUM_NODES_ARG_DEFAULT = 3

IMAGE_ARG = "rabbitmq_image"
IMAGE_ARG_DEFAULT = "rabbitmq:3-management"

MANAGEMENT_PORT_ARG = "rabbitmq_management_port"
MANAGEMENT_PORT_ARG_DEFAULT = 15672
MANAGEMENT_PORT_PROTOCOL = "TCP"

AMQP_PORT_ARG = "rabbitmq_amqp_port"
AMQP_PORT_ARG_DEFAULT = 5672
AMQP_PORT_PROTOCOL = "TCP"

ADMIN_USER_ARG = "rabbitmq_admin_user"
ADMIN_USER_ARG_DEFAULT = "admin"

ADMIN_PASSWORD_ARG = "rabbitmq_admin_password"
ADMIN_PASSWORD_ARG_DEFAULT = "admin"

VHOST_ARG = "rabbitmq_vhost"
VHOST_ARG_DEFAULT = "test"

ENV_VARS_ARG = "rabbitmq_env_vars"
ENV_VARS_ARG_DEFAULT = {}

RABBITMQ_NODE_PREFIX = "rabbitmq-node-"

FIRST_NODE_INDEX = 0

CONFIG_DIR = "/etc/rabbitmq"
CONFIG_TEMPLATE_PATH =  "/static_files/rabbitmq.conf.tmpl"
CONFIG_TEMPLATE_FILENAME = "rabbitmq.conf"
ENABLED_PLUGINS_TEMPLATE_PATH =  "/static_files/enabled_plugins.tmpl"
ENABLED_PLUGINS_TEMPLATE_FILENAME = "enabled_plugins"

LIB_DIR = "/var/lib/rabbitmq"
ERLANG_COOKIE_FILENAME = ".erlang.cookie"
ERLANG_COOKIE_PATH =  "/static_files/" + ERLANG_COOKIE_FILENAME
ERLANG_COOKIE_PERMISSIONS = "400"

def run(plan, args):
    num_nodes = args.get(NUM_NODES_ARG, NUM_NODES_ARG_DEFAULT)
    image = args.get(IMAGE_ARG, IMAGE_ARG_DEFAULT)
    management_port = args.get(MANAGEMENT_PORT_ARG, MANAGEMENT_PORT_ARG_DEFAULT)
    amqp_port = args.get(AMQP_PORT_ARG, AMQP_PORT_ARG_DEFAULT)
    admin_user = args.get(ADMIN_USER_ARG, ADMIN_USER_ARG_DEFAULT)
    admin_password = args.get(ADMIN_PASSWORD_ARG, ADMIN_PASSWORD_ARG_DEFAULT)
    vhost = args.get(VHOST_ARG, VHOST_ARG_DEFAULT)
    env_vars = args.get(ENV_VARS_ARG, ENV_VARS_ARG_DEFAULT)

    if num_nodes == 0:
        fail("Need at least 1 node to start the RabbitMQ cluster got 0")

    etcd_run_output = etcd_module.run(plan, args)

    config_template_and_data = {
        CONFIG_TEMPLATE_FILENAME : struct(
            template = read_file(CONFIG_TEMPLATE_PATH),
            data = {
                "ManagementPort": management_port,
                "AMQPPort": amqp_port,
                "EtcdEndpoint": "{}:{}".format(etcd_run_output["hostname"],  etcd_run_output["port"])
            }
        ),
        ENABLED_PLUGINS_TEMPLATE_FILENAME : struct(
            template = read_file(ENABLED_PLUGINS_TEMPLATE_PATH),
            data = {
            }
        ),
    }
    rendered_config_artifact = plan.render_templates(config_template_and_data, name = "config")

    lib_artifact = plan.upload_files(
        src = ERLANG_COOKIE_PATH,
        name = "lib"
    )

    started_nodes = []
    for node in range(0, num_nodes):
        node_name = get_service_name(node)
        config = get_service_config(rendered_config_artifact, lib_artifact, image, management_port, amqp_port, env_vars)
        node = plan.add_service(name = node_name, config = config)
        started_nodes.append(node)

    cluster_status_cmd = "rabbitmqctl cluster_status | grep \"Running Nodes\" -A {} | grep \"rabbit@\" | wc -l | tr -d '\n'".format(num_nodes+1)
    check_cluster = ExecRecipe(
        command = ["/bin/sh", "-c", cluster_status_cmd]
    )
    plan.wait(recipe = check_cluster, field = "output", assertion = "==", target_value = str(num_nodes), timeout = "5m", service_name = get_first_node_name())

    create_vhost_cmd = "rabbitmqctl add_vhost {}".format(vhost)
    delete_guest_user_cmd = "rabbitmqctl delete_user guest"
    configure_admin_user_cmd = "rabbitmqctl add_user {} {}; rabbitmqctl set_permissions -p {} {} \".*\" \".*\" \".*\"; rabbitmqctl set_user_tags {} administrator".format(
        admin_user, admin_password, vhost, admin_user, admin_user, admin_password)
    for cmd in (
        create_vhost_cmd,
        delete_guest_user_cmd,
        configure_admin_user_cmd,
    ):
        recipe = ExecRecipe(command = ["/bin/sh", "-c", cmd])
        plan.exec(recipe = recipe, service_name = get_first_node_name())

    result =  {"node_names": [node.name for node in started_nodes]}

    return result


def get_service_config(config_artifact, lib_artifact, image, management_port, amqp_port, env_vars):
    return ServiceConfig(
        image = image,
        ports = {
            "management" : PortSpec(number = management_port, transport_protocol = "TCP"),
            "amqp" : PortSpec(number = amqp_port, transport_protocol = "TCP"),
        },
        env_vars = env_vars,
        files = {
            CONFIG_DIR: config_artifact,
            LIB_DIR: lib_artifact,
        },
        # TODO productize this - we need to set permissions otherwise rabbit mq is unhappy
        entrypoint = ["/bin/sh", "-c", "chmod {0} {1}/{2} && /usr/local/bin/docker-entrypoint.sh rabbitmq-server".format(ERLANG_COOKIE_PERMISSIONS, LIB_DIR, ERLANG_COOKIE_FILENAME)],
    )


def get_service_name(node_idx):
    return RABBITMQ_NODE_PREFIX + str(node_idx)


def get_first_node_name():
    return get_service_name(FIRST_NODE_INDEX)
