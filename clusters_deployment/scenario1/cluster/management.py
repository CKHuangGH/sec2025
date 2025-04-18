from enoslib.api import generate_inventory,run_ansible
from enoslib.infra.enos_vmong5k.provider import VMonG5k
from enoslib.infra.enos_vmong5k.configuration import Configuration
import time
import enoslib as en

en.set_config(ansible_forks=100)

name = "s1-management-1"

clusters = "ecotype"

site = "nantes"

master_nodes = []

duration = "12:00:00"

prod_network = en.G5kNetworkConf(type="prod", roles=["my_network"], site=site)

name_job = name + clusters

role_name = "cluster" + str(clusters)

conf = (
    en.G5kConf.from_settings(job_type="allow_classic_ssh", job_name=name_job, walltime=duration)
    .add_network_conf(prod_network)
    .add_network(
        id="not_linked_to_any_machine", type="slash_22", roles=["my_subnet"], site=site
    )
    .add_machine(
    roles=["role0"], nodes=1, primary_network=prod_network,servers=[f"ecotype-{i}.nantes.grid5000.fr" for i in range(2, 47)]
    )
    .finalize()
)
provider = en.G5k(conf)
roles, networks = provider.init()
roles = en.sync_info(roles, networks)

subnet = networks["my_subnet"]
cp = 1

virt_conf = (
    en.VMonG5kConf.from_settings(image="/home/chuang/images/debian31032025.qcow2")
    .add_machine(
        roles=["cp"],
        number=cp,
        undercloud=roles["role0"],
        flavour_desc={"core": 16, "mem": 32768},
        macs=list(subnet[0].free_macs)[0:1],
    ).finalize()
)

vmroles = en.start_virtualmachines(virt_conf)

inventory_file = "kubefed_inventory_cluster"+ str(name_job) +".ini" 

inventory = generate_inventory(vmroles, networks, inventory_file)

master_nodes.append(vmroles['cp'][0].address)

time.sleep(45)

run_ansible(["afterbuild.yml"], inventory_path=inventory_file)

f = open("node_list", 'a')
f.write(str(master_nodes[0]))
f.write("\n")
f.close()

print("Master nodes ........")
print(master_nodes)