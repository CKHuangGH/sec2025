from enoslib.api import generate_inventory,run_ansible
from enoslib.infra.enos_vmong5k.provider import VMonG5k
from enoslib.infra.enos_vmong5k.configuration import Configuration
import time
import enoslib as en

en.set_config(ansible_forks=100)

name = "s1-management-1"

clusters = ["ecotype"]

master_nodes = []

duration = "12:00:00"

for i in range(0, len(clusters)):

    name_job = name + clusters[i] + str(i)

    role_name = "cluster" + str(clusters[i])
    
    conf = Configuration.from_settings(job_name=name_job,
                                       walltime=duration,
                                       image="/home/chuang/images/debian31032025.qcow2")\
                        .add_machine(roles=[role_name],
                                     cluster=clusters[i],
                                     flavour_desc={"core": 16, "mem": 32768},
                                     number=1)\
                        .finalize()
    
    provider = VMonG5k(conf)
    
    roles, networks = provider.init()

    inventory_file = "kubefed_inventory_cluster" + str(name_job) + ".ini" 

    inventory = generate_inventory(roles, networks, inventory_file)

    master_nodes.append(roles[role_name][0].address)

    time.sleep(45)

    run_ansible(["afterbuild.yml"], inventory_path=inventory_file)
    
f = open("node_list", 'a')
f.write(str(master_nodes[0]))
f.write("\n")
f.close

print("Master nodes ........")
print(master_nodes)